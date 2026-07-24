package main

import (
	"fmt"
	"net/http"

	"asriel.cn/asaas/server/internal/config"
	"asriel.cn/asaas/server/internal/middleware"
	"asriel.cn/asaas/server/internal/platform/database"
	"asriel.cn/asaas/server/internal/platform/i18n"
	"asriel.cn/asaas/server/internal/platform/logger"
	"asriel.cn/asaas/server/internal/platform/redis"
	"github.com/gin-gonic/gin"
)

func main() {
	config.Init()

	logger.Init()
	defer logger.Sync()

	database.Init()
	defer database.Close()

	redis.Init()
	defer redis.Close()

	i18n.Init()

	gin.SetMode(config.Config.Server.Mode)
	engine := gin.New()
	engine.Use(
		middleware.Request(),
		middleware.I18n(),
		middleware.Logger(),
		gin.Recovery())

	engine.GET("/ping", middleware.Action("PING"), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"message": "pong",
		})
	})

	err := engine.Run(fmt.Sprintf("%s:%d", config.Config.Server.Host, config.Config.Server.Port))

	if err != nil {
		panic(fmt.Errorf("fatal error starting server: %w", err))
	}
}
