package service

import (
	"context"
	"errors"
	"regexp"
	"time"

	"asriel.cn/asaas/server/internal/modules/iam/db/sqlc"
	"asriel.cn/asaas/server/internal/pkg/access"
	"asriel.cn/asaas/server/internal/pkg/id"
	"asriel.cn/asaas/server/internal/platform/database"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

var (
	slugRegex = regexp.MustCompile(`^[a-z0-9]([a-z0-9-]*[a-z0-9])?$`)

	ErrInvalidSlug       = errors.New("invalid slug format")
	ErrInvalidTenantName = errors.New("invalid tenant name")
	ErrNoAccessContext   = errors.New("no access context")
	ErrAlreadyMember     = errors.New("user is already a member")
)

type TenantService struct {
}

func (*TenantService) CreateTenant(ctx context.Context, slug string, name string) (uuid.UUID, error) {
	acc, ok := access.Get(ctx)
	if !ok {
		return uuid.Nil, ErrNoAccessContext
	}

	if !slugRegex.MatchString(slug) || len(slug) < 3 || len(slug) > 64 {
		return uuid.Nil, ErrInvalidSlug
	}
	if len(name) == 0 || len(name) > 64 {
		return uuid.Nil, ErrInvalidTenantName
	}

	tenantID := id.UUID()
	now := time.Now()

	_, err := database.Tx[any](ctx, func(tx pgx.Tx) (any, error) {
		queries := sqlc.New(tx)

		if err := queries.CreateTenant(ctx, sqlc.CreateTenantParams{
			ID:        tenantID,
			Slug:      slug,
			Name:      name,
			CreatedBy: acc.UserID,
			CreatedAt: now,
		}); err != nil {
			return nil, err
		}

		if err := queries.CreateMember(ctx, sqlc.CreateMemberParams{
			TenantID:  tenantID,
			UserID:    acc.UserID,
			JoinedAt:  now,
			CreatedAt: now,
		}); err != nil {
			return nil, err
		}

		return nil, nil
	})

	return tenantID, err
}

func (*TenantService) InviteMember(ctx context.Context, tenantID uuid.UUID, userID uuid.UUID) error {
	if err := validateTenantAccess(ctx, tenantID); err != nil {
		return err
	}
	now := time.Now()
	_, err := database.Tx[any](ctx, func(tx pgx.Tx) (any, error) {
		err := sqlc.New(tx).CreateMember(ctx, sqlc.CreateMemberParams{
			TenantID: tenantID, UserID: userID, JoinedAt: now, CreatedAt: now,
		})
		return nil, err
	})
	if err != nil {
		return ErrAlreadyMember
	}
	return nil
}

func (*TenantService) DisableMember(ctx context.Context, tenantID uuid.UUID, userID uuid.UUID) error {
	if err := validateTenantAccess(ctx, tenantID); err != nil {
		return err
	}
	now := time.Now()
	_, err := database.Tx[any](ctx, func(tx pgx.Tx) (any, error) {
		err := sqlc.New(tx).DisableMember(ctx, sqlc.DisableMemberParams{
			TenantID: tenantID, UserID: userID,
			DisabledAt: pgtype.Timestamptz{Time: now, Valid: true},
		})
		return nil, err
	})
	return err
}

func (*TenantService) RemoveMember(ctx context.Context, tenantID uuid.UUID, userID uuid.UUID) error {
	if err := validateTenantAccess(ctx, tenantID); err != nil {
		return err
	}
	now := time.Now()
	_, err := database.Tx[any](ctx, func(tx pgx.Tx) (any, error) {
		err := sqlc.New(tx).RemoveMember(ctx, sqlc.RemoveMemberParams{
			TenantID: tenantID, UserID: userID,
			RemovedAt: pgtype.Timestamptz{Time: now, Valid: true},
		})
		return nil, err
	})
	return err
}

func validateTenantAccess(ctx context.Context, tenantID uuid.UUID) error {
	acc, ok := access.Get(ctx)
	if !ok || acc.Realm != access.RealmTenant || acc.TenantID != tenantID {
		return ErrNoAccessContext
	}
	return nil
}
