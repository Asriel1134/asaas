package middleware

import (
	"asriel.cn/asaas/server/internal/platform/i18n"
	"github.com/gin-gonic/gin"
)

func I18n() gin.HandlerFunc {
	return func(c *gin.Context) {
		lang := i18n.MatchLanguage(c.GetHeader("Accept-Language"))
		c.Request = c.Request.WithContext(i18n.WithLanguage(c.Request.Context(), lang))
		c.Next()
	}
}
