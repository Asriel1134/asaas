package middleware

import (
	"errors"
	"net/http"
	"slices"

	"asriel.cn/asaas/server/internal/modules/iam/db/sqlc"
	"asriel.cn/asaas/server/internal/modules/iam/service"
	"asriel.cn/asaas/server/internal/pkg/access"
	"asriel.cn/asaas/server/internal/platform/i18n"
	"asriel.cn/asaas/server/internal/platform/response"
	"github.com/gin-gonic/gin"
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
			UserID:               session.UserID,
			SessionID:            session.ID,
			CatalogAuthzVersion:  session.PermissionCatalogVersion,
			TenantAuthzVersion:   session.TenantAuthzVersion,
			PlatformAuthzVersion: session.PlatformGlobalAuthzVersion,
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
				!session.TenantStatus.Valid || (session.TenantStatus.TenantStatus != sqlc.TenantStatusActive && session.TenantStatus.TenantStatus != sqlc.TenantStatusReadonly) {
				response.Result(c, http.StatusForbidden, response.AuthenticationErrorCode,
					i18n.T(lang, "authorization.member_inactive"), nil)
				c.Abort()
				return
			}
			acc.Realm = access.RealmTenant
			acc.SubjectAuthzVersion = session.MemberAuthzVersion
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
			if !session.IsPlatformUser {
				response.Result(c, http.StatusForbidden, response.AuthenticationErrorCode,
					i18n.T(lang, "authorization.platform_access_denied"), nil)
				c.Abort()
				return
			}
			acc.Realm = access.RealmPlatform
			acc.SubjectAuthzVersion = session.PlatformUserAuthzVersion

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
