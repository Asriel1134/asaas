package middleware

import (
	"net/http"

	"asriel.cn/asaas/server/internal/modules/iam/service"
	"asriel.cn/asaas/server/internal/pkg/access"
	"asriel.cn/asaas/server/internal/platform/i18n"
	"asriel.cn/asaas/server/internal/platform/response"
	"github.com/gin-gonic/gin"
)

const permissionSnapshotContextKey = "permission_snapshot"

func RequirePermission(permissionCode string) gin.HandlerFunc {
	return func(c *gin.Context) {
		lang := i18n.GetLanguage(c.Request.Context())
		acc, ok := access.Get(c.Request.Context())
		if !ok || acc.Realm == access.RealmPending {
			response.Result(c, http.StatusForbidden, response.AuthorizationErrorCode,
				i18n.T(lang, "authorization.realm_mismatch"), nil)
			c.Abort()
			return
		}

		snapshot, err := (&service.PermissionService{}).GetSnapshot(c.Request.Context(), acc)
		if err != nil {
			response.Result(c, http.StatusInternalServerError, response.ServerErrorCode,
				i18n.T(lang, "authorization.permission_check_failed"), nil)
			c.Abort()
			return
		}
		if snapshot.Realm != acc.Realm || !snapshot.Has(permissionCode) {
			response.Result(c, http.StatusForbidden, response.AuthorizationErrorCode,
				i18n.T(lang, "authorization.permission_denied"), nil)
			c.Abort()
			return
		}

		c.Set(permissionSnapshotContextKey, snapshot)
		c.Next()
	}
}
