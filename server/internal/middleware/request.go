package middleware

import (
	"asriel.cn/asaas/server/internal/platform/logger"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func Request() gin.HandlerFunc {
	return func(c *gin.Context) {
		id := uuid.New().String()
		c.Request = c.Request.WithContext(logger.WithRequestID(c.Request.Context(), id))
		c.Next()
	}
}

func Module(module string) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Request = c.Request.WithContext(logger.WithModule(c.Request.Context(), module))
		c.Next()
	}
}

func Action(action string) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Request = c.Request.WithContext(logger.WithAction(c.Request.Context(), action))
		c.Next()
	}
}
