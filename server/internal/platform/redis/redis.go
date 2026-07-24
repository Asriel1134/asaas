package redis

import (
	"context"
	"fmt"

	"asriel.cn/asaas/server/internal/config"
	"github.com/redis/go-redis/v9"
)

var Client *redis.Client

// Init initializes the Redis client from configuration.
// Panics if the connection cannot be established.
func Init() {
	cfg := config.Config.Redis

	client := redis.NewClient(&redis.Options{
		Addr:     cfg.Addr,
		Password: cfg.Password,
		DB:       cfg.DB,
		Protocol: cfg.Protocol,
		PoolSize: cfg.Pool.Size,
	})

	if err := client.Ping(context.Background()).Err(); err != nil {
		panic(fmt.Errorf("failed to connect to redis: %w", err))
	}

	Client = client
}

// Close gracefully closes the Redis client connection pool.
func Close() {
	if Client != nil {
		_ = Client.Close()
	}
}
