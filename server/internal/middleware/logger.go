package middleware

import (
	"time"

	logger2 "asriel.cn/asaas/server/internal/platform/logger"
	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

func Logger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		raw := c.Request.URL.RawQuery

		c.Next()

		latency := time.Since(start)
		if raw != "" {
			path = path + "?" + raw
		}

		fields := []zap.Field{
			zap.String("module", logger2.GetModule(c.Request.Context())),
			zap.String("action", logger2.GetAction(c.Request.Context())),
			zap.String("request_id", logger2.GetRequestID(c.Request.Context())),
			zap.String("trace_id", ""),
			zap.String("tenant_id", ""),
			zap.String("user_id", ""),
			zap.Int("status", c.Writer.Status()),
			zap.String("method", c.Request.Method),
			zap.String("path", path),
			zap.Int64("latency", latency.Milliseconds()),
			zap.String("client_ip", c.ClientIP()),
			zap.String("user_agent", c.Request.UserAgent()),
		}

		if len(c.Errors) > 0 {
			fields = append(fields, zap.String("errors", c.Errors.String()))
		}

		switch {
		case c.Writer.Status() >= 500:
			logger2.L.Error("request failed", fields...)
		case c.Writer.Status() >= 400:
			logger2.L.Warn("request rejected", fields...)
		default:
			logger2.L.Info("request completed", fields...)
		}
	}
}
