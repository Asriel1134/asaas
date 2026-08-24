package service

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"net/netip"
	"time"

	"asriel.cn/asaas/server/internal/modules/iam/auth"
	"asriel.cn/asaas/server/internal/modules/iam/db/sqlc"
	"asriel.cn/asaas/server/internal/pkg/access"
	"asriel.cn/asaas/server/internal/pkg/id"
	"asriel.cn/asaas/server/internal/platform/database"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

const (
	sessionIdleTimeout     = 24 * time.Hour
	sessionAbsoluteTimeout = 24 * time.Hour * 30
)

var (
	ErrSessionExpired         = errors.New("session expired")
	ErrSessionRevoked         = errors.New("session revoked")
	ErrSessionSecurityChange  = errors.New("session invalidated by security change")
	ErrContextSelectionDenied = errors.New("session context selection denied")
)

type SessionService struct {
}

func (*SessionService) CreateSession(c *gin.Context, identifier sqlc.GetLoginIdentifierRow) error {
	token, err := auth.GenerateToken()
	if err != nil {
		return err
	}

	hash, err := auth.HashToken(token)
	if err != nil {
		return err
	}

	now := time.Now()
	clientIP := parseClientIP(c.ClientIP())
	uaHash := hashUserAgent(c.GetHeader("User-Agent"))

	_, err = database.Tx[any](c.Request.Context(),
		func(tx pgx.Tx) (any, error) {
			return nil, sqlc.New(database.DB).CreateSession(c.Request.Context(),
				sqlc.CreateSessionParams{
					ID:                id.UUID(),
					UserID:            identifier.UserID,
					TokenHash:         hash,
					SecurityVersion:   identifier.SecurityVersion,
					AuthnLevel:        sqlc.AuthnLevelPassword,
					DeviceID:          pgtype.Text{},
					DeviceName:        pgtype.Text{},
					IpCreated:         clientIP,
					IpLast:            clientIP,
					UserAgentHash:     uaHash,
					ContextTenantID:   pgtype.UUID{},
					Status:            sqlc.SessionStatusActive,
					IssuedAt:          now,
					LastSeenAt:        now,
					IdleExpiresAt:     now.Add(sessionIdleTimeout),
					AbsoluteExpiresAt: now.Add(sessionAbsoluteTimeout),
				})
		})
	if err != nil {
		return err
	}

	c.SetCookie(
		auth.SessionCookieName,
		token,
		int(sessionAbsoluteTimeout.Seconds()),
		"/",
		"",
		true,
		true,
	)

	return nil
}

func (*SessionService) GetSession(c *gin.Context) (sqlc.GetSessionByTokenHashRow, error) {
	token, err := c.Cookie(auth.SessionCookieName)
	if err != nil {
		return sqlc.GetSessionByTokenHashRow{}, err
	}

	hash, err := auth.HashToken(token)
	if err != nil {
		return sqlc.GetSessionByTokenHashRow{}, err
	}

	session, err := sqlc.New(database.DB).GetSessionByTokenHash(c.Request.Context(), hash)
	if err != nil {
		return sqlc.GetSessionByTokenHashRow{}, err
	}

	now := time.Now()
	if now.After(session.AbsoluteExpiresAt) || now.After(session.IdleExpiresAt) {
		_ = sqlc.New(database.DB).ExpireSession(c.Request.Context(), session.ID)
		return sqlc.GetSessionByTokenHashRow{}, ErrSessionExpired
	}
	if session.Status != sqlc.SessionStatusActive {
		return sqlc.GetSessionByTokenHashRow{}, ErrSessionRevoked
	}
	if session.SecurityVersion < session.CurrentSecurityVersion {
		return sqlc.GetSessionByTokenHashRow{}, ErrSessionSecurityChange
	}

	clientIP := parseClientIP(c.ClientIP())
	_ = sqlc.New(database.DB).UpdateSessionLastSeen(c.Request.Context(), sqlc.UpdateSessionLastSeenParams{
		ID:            session.ID,
		LastSeenAt:    now,
		IpLast:        clientIP,
		IdleExpiresAt: now.Add(sessionIdleTimeout),
	})

	return session, nil
}

func (*SessionService) RevokeSession(c *gin.Context) error {
	acc, ok := access.Get(c.Request.Context())
	if !ok {
		return nil
	}

	_ = sqlc.New(database.DB).RevokeSession(c.Request.Context(), acc.SessionID)

	c.SetCookie(
		auth.SessionCookieName,
		"",
		-1,
		"/",
		"",
		true,
		true,
	)

	return nil
}

func (*SessionService) SelectTenantContext(ctx context.Context, sessionID, tenantID uuid.UUID) error {
	rows, err := sqlc.New(database.DB).SelectTenantContext(ctx, sqlc.SelectTenantContextParams{
		Sessionid: sessionID,
		Tenantid:  pgtype.UUID{Bytes: tenantID, Valid: true},
	})
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrContextSelectionDenied
	}
	return nil
}

func (*SessionService) SelectPlatformContext(ctx context.Context, sessionID uuid.UUID) error {
	rows, err := sqlc.New(database.DB).SelectPlatformContext(ctx, sessionID)
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrContextSelectionDenied
	}
	return nil
}

func (*SessionService) GetAuthorizationContext(ctx context.Context, sessionID uuid.UUID) (access.Context, error) {
	state, err := sqlc.New(database.DB).GetSessionAuthorizationState(ctx, sessionID)
	if err != nil {
		return access.Context{}, err
	}

	acc := access.Context{
		UserID:               state.UserID,
		SessionID:            sessionID,
		CatalogAuthzVersion:  state.PermissionCatalogVersion,
		TenantAuthzVersion:   state.TenantAuthzVersion,
		PlatformAuthzVersion: state.PlatformGlobalAuthzVersion,
	}

	switch state.ContextType {
	case sqlc.SessionContextTypeTenant:
		acc.Realm = access.RealmTenant
		acc.SubjectAuthzVersion = state.MemberAuthzVersion
		if state.ContextTenantID.Valid {
			acc.TenantID = state.ContextTenantID.Bytes
		}
		if state.DefaultWorkspaceID.Valid {
			acc.WorkspaceID = state.DefaultWorkspaceID.Bytes
		}
	case sqlc.SessionContextTypePlatform:
		acc.Realm = access.RealmPlatform
		acc.SubjectAuthzVersion = state.PlatformUserAuthzVersion
	default:
		acc.Realm = access.RealmPending
	}

	return acc, nil
}

func parseClientIP(ip string) *netip.Addr {
	addr, err := netip.ParseAddr(ip)
	if err != nil {
		return nil
	}
	return &addr
}

func hashUserAgent(ua string) pgtype.Text {
	if ua == "" {
		return pgtype.Text{}
	}
	sum := sha256.Sum256([]byte(ua))
	return pgtype.Text{String: fmt.Sprintf("%x", sum), Valid: true}
}
