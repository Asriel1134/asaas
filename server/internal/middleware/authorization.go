package middleware

import (
	"errors"
	"fmt"
	"net/http"
	"slices"

	"asriel.cn/asaas/server/internal/modules/iam/db/sqlc"
	"asriel.cn/asaas/server/internal/modules/iam/service"
	"asriel.cn/asaas/server/internal/pkg/access"
	"asriel.cn/asaas/server/internal/platform/i18n"
	"asriel.cn/asaas/server/internal/platform/response"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

var whitelist = []string{
	"/api/v1/auth/login/password",
}

func Authorization() gin.HandlerFunc {
	return func(c *gin.Context) {
		if slices.Contains(whitelist, c.Request.URL.Path) {
			c.Next()
			return
		}

		sessionService := service.SessionService{}
		session, err := sessionService.GetSession(c)
		lang := i18n.GetLanguage(c.Request.Context())
		if err != nil {
			if errors.Is(err, service.ErrSessionExpired) || errors.Is(err, service.ErrSessionRevoked) || errors.Is(err, service.ErrSessionSecurityChange) {
				response.Result(c, http.StatusUnauthorized, response.AuthenticationErrorCode,
					i18n.T(lang, "authorization.session_invalid"), nil)
				c.Abort()
				return
			}
			response.Result(c, http.StatusUnauthorized, response.AuthenticationErrorCode,
				i18n.T(lang, "authorization.unauthorized"), nil)
			c.Abort()
			return
		}

		acc := access.Context{
			UserID:    session.UserID,
			SessionID: session.ID,
		}

		switch session.ContextType {
		case sqlc.SessionContextTypePending:
			if session.ContextTenantID.Valid {
				response.Result(c, http.StatusUnauthorized, response.AuthenticationErrorCode,
					i18n.T(lang, "authorization.session_invalid"), nil)
				c.Abort()
				return
			}
			acc.Realm = access.RealmPending

		case sqlc.SessionContextTypeTenant:
			if !session.ContextTenantID.Valid ||
				!session.MemberStatus.Valid || session.MemberStatus.TenantMemberStatus != sqlc.TenantMemberStatusActive ||
				!session.TenantStatus.Valid || (session.TenantStatus.TenantsStatus != sqlc.TenantsStatusActive && session.TenantStatus.TenantsStatus != sqlc.TenantsStatusReadonly) {
				response.Result(c, http.StatusForbidden, response.AuthenticationErrorCode,
					i18n.T(lang, "authorization.member_inactive"), nil)
				c.Abort()
				return
			}
			acc.Realm = access.RealmTenant
			acc.TenantID = session.ContextTenantID.Bytes
			if session.DefaultWorkspaceID.Valid {
				acc.WorkspaceID = session.DefaultWorkspaceID.Bytes
			}

		case sqlc.SessionContextTypePlatform:
			if session.ContextTenantID.Valid {
				response.Result(c, http.StatusUnauthorized, response.AuthenticationErrorCode,
					i18n.T(lang, "authorization.session_invalid"), nil)
				c.Abort()
				return
			}
			isPlatformUser, platformErr := (&service.PermissionService{}).IsPlatformUser(c.Request.Context(), session.UserID)
			if platformErr != nil || !isPlatformUser {
				response.Result(c, http.StatusForbidden, response.AuthenticationErrorCode,
					i18n.T(lang, "authorization.platform_access_denied"), nil)
				c.Abort()
				return
			}
			acc.Realm = access.RealmPlatform

		default:
			response.Result(c, http.StatusUnauthorized, response.AuthenticationErrorCode,
				i18n.T(lang, "authorization.session_invalid"), nil)
			c.Abort()
			return
		}

		c.Request = c.Request.WithContext(access.Set(c.Request.Context(), acc))
		c.Next()
	}
}

func RequireRealm(realm access.Realm) gin.HandlerFunc {
	return func(c *gin.Context) {
		acc, ok := access.Get(c.Request.Context())
		if !ok || acc.Realm != realm {
			lang := i18n.GetLanguage(c.Request.Context())
			response.Result(c, http.StatusForbidden, response.AuthenticationErrorCode,
				i18n.T(lang, "authorization.realm_mismatch"), nil)
			c.Abort()
			return
		}
		c.Next()
	}
}

func PermissionCacheKey(tenantID, userID uuid.UUID, tenantVer, memberVer int64) string {
	return fmt.Sprintf("authz:%s:%s:%d:%d", tenantID, userID, tenantVer, memberVer)
}
