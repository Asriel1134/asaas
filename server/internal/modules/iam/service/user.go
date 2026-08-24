package service

import (
	"context"
	"errors"
	"regexp"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"asriel.cn/asaas/server/internal/config"
	"asriel.cn/asaas/server/internal/modules/iam/auth"
	"asriel.cn/asaas/server/internal/modules/iam/db/sqlc"
	"asriel.cn/asaas/server/internal/pkg/id"
	"asriel.cn/asaas/server/internal/platform/database"
	"asriel.cn/asaas/server/internal/platform/i18n"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

const (
	minPasswordLength = 8
	maxPasswordLength = 16
	maxFailedAttempts = 5
	lockDuration      = 30 * time.Minute
)

var (
	emailRegex = regexp.MustCompile(`^[^\s@]+@[^\s@]+\.[^\s@]+$`)
	phoneRegex = regexp.MustCompile(`^\+?[0-9]{6,20}$`)
)

var (
	ErrUserAlreadyExists       = errors.New("user already exists")
	ErrInvalidPasswordFormat   = errors.New("invalid password format")
	ErrInvalidIdentifierFormat = errors.New("invalid identifier format")
)

type UserService struct {
}

func (*UserService) CreateUser(ctx context.Context, username string, password string, timezone string) (uuid.UUID, error) {
	if !ValidatePasswordFormat(password) {
		return uuid.Nil, ErrInvalidPasswordFormat
	}
	if !ValidateIdentifierFormat(sqlc.IdentifierKindUsername, username) {
		return uuid.Nil, ErrInvalidIdentifierFormat
	}
	normalized, err := NormalizedIdentifier(username)
	if err != nil {
		return uuid.Nil, err
	}

	return database.Tx[uuid.UUID](ctx, func(tx pgx.Tx) (uuid.UUID, error) {
		queries := sqlc.New(tx)
		existing, err := queries.ExistingIdentifier(ctx, sqlc.ExistingIdentifierParams{
			Kind:            sqlc.IdentifierKindUsername,
			NormalizedValue: username,
		})
		if err != nil && !errors.Is(err, pgx.ErrNoRows) {
			return uuid.Nil, err
		}
		if existing != uuid.Nil {
			return uuid.Nil, ErrUserAlreadyExists
		}

		userId, err := queries.CreateUser(ctx, sqlc.CreateUserParams{
			ID:          id.UUID(),
			DisplayName: username,
			Locale:      pgtype.Text{String: i18n.GetLanguage(ctx), Valid: true},
			Timezone:    resolveTimezone(timezone),
			CreatedAt:   time.Now(),
		})
		if err != nil {
			return uuid.Nil, err
		}

		err = queries.CreateIdentifier(ctx, sqlc.CreateIdentifierParams{
			ID:              id.UUID(),
			UserID:          userId,
			Kind:            sqlc.IdentifierKindUsername,
			Value:           username,
			NormalizedValue: normalized,
			VerifiedAt: pgtype.Timestamptz{
				Time:  time.Now(),
				Valid: true,
			},
			IsPrimary: true,
			CreatedAt: time.Now(),
		})
		if err != nil {
			return uuid.Nil, err
		}

		hash, err := auth.HashPassword(password, &auth.DefaultParams)
		if err != nil {
			return uuid.Nil, err
		}
		err = queries.CreateCredential(ctx, sqlc.CreateCredentialParams{
			UserID:            userId,
			PasswordHash:      hash,
			PasswordAlgorithm: string(auth.PasswordAlgorithmArgon2id),
			PasswordChangedAt: time.Now(),
			UpdatedAt:         time.Now(),
		})
		if err != nil {
			return uuid.Nil, err
		}

		return userId, nil
	})
}

func ValidateIdentifierFormat(kind sqlc.IdentifierKind, value string) bool {
	value = strings.TrimSpace(value)
	if value == "" {
		return false
	}

	switch kind {
	case sqlc.IdentifierKindEmail:
		return emailRegex.MatchString(value) && len(value) <= 255
	case sqlc.IdentifierKindPhone:
		return phoneRegex.MatchString(value)
	case sqlc.IdentifierKindUsername:
		length := utf8.RuneCountInString(value)
		return length >= 3 && length <= 32
	default:
		return false
	}
}

func resolveTimezone(tz string) pgtype.Text {
	if tz != "" {
		return pgtype.Text{String: tz, Valid: true}
	}
	if config.Config.Server.Timezone != "" {
		return pgtype.Text{String: config.Config.Server.Timezone, Valid: true}
	}
	return pgtype.Text{}
}

func NormalizedIdentifier(identifier string) (string, error) {
	normalized := strings.TrimSpace(identifier)
	normalized = strings.ToLower(normalized)
	return normalized, nil
}

func ValidatePasswordFormat(password string) bool {
	length := utf8.RuneCountInString(password)
	if length < minPasswordLength || length > maxPasswordLength {
		return false
	}

	var (
		hasUpper   bool
		hasLower   bool
		hasDigit   bool
		hasSpecial bool
	)
	for _, r := range password {
		switch {
		case unicode.IsUpper(r):
			hasUpper = true
		case unicode.IsLower(r):
			hasLower = true
		case unicode.IsDigit(r):
			hasDigit = true
		case unicode.IsPunct(r) || unicode.IsSymbol(r):
			hasSpecial = true
		}
	}

	return hasUpper && hasLower && hasDigit && hasSpecial
}

func (*UserService) RecordFailedAttempt(ctx context.Context, userID uuid.UUID) error {
	_, err := database.Tx[any](ctx, func(tx pgx.Tx) (any, error) {
		_, err := sqlc.New(tx).IncrementFailedAttempts(ctx, sqlc.IncrementFailedAttemptsParams{
			UserID:    userID,
			Threshold: maxFailedAttempts,
			LockUntil: pgtype.Timestamptz{Time: time.Now().Add(lockDuration), Valid: true},
			UpdatedAt: time.Now(),
		})
		return nil, err
	})
	return err
}

func (*UserService) ResetFailedAttempts(ctx context.Context, userID uuid.UUID) error {
	_, err := database.Tx[any](ctx, func(tx pgx.Tx) (any, error) {
		return nil, sqlc.New(tx).ResetFailedAttempts(ctx, sqlc.ResetFailedAttemptsParams{
			UserID:    userID,
			UpdatedAt: time.Now(),
		})
	})
	return err
}
