package middleware

import (
	"errors"
	"fmt"
	"net/http"
	"slices"

	"asriel.cn/asaas/server/internal/modules/iam/service"
	"asriel.cn/asaas/server/internal/pkg/access"
	"asriel.cn/asaas/server/internal/platform/i18n"
	"asriel.cn/asaas/server/internal/platform/response"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

var whitelist = []string{
	"/api/v1/login/password",
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

		if session.TenantHint.Valid {
			if !session.MemberStatus.Valid || session.MemberStatus.TenantMemberStatus != "active" {
				response.Result(c, http.StatusForbidden, response.AuthenticationErrorCode,
					i18n.T(lang, "authorization.member_inactive"), nil)
				c.Abort()
				return
			}
		}

		acc := access.Context{
			UserID:    session.UserID,
			SessionID: session.ID,
		}
		if session.TenantHint.Valid {
			acc.TenantID = session.TenantHint.Bytes
		}
		if session.DefaultWorkspaceID.Valid {
			acc.WorkspaceID = session.DefaultWorkspaceID.Bytes
		}

		c.Request = c.Request.WithContext(access.Set(c.Request.Context(), acc))
		c.Next()
	}
}

func PermissionCacheKey(tenantID, userID uuid.UUID, tenantVer, memberVer int64) string {
	return fmt.Sprintf("authz:%s:%s:%d:%d", tenantID, userID, tenantVer, memberVer)
}
