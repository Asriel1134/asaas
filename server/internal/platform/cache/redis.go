package cache

import (
	"context"
	"encoding"
	"errors"
	"fmt"
	"time"

	"asriel.cn/asaas/server/internal/config"
	"github.com/redis/go-redis/v9"
)

type cache struct {
	client *redis.Client
}

var Cache *cache

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
		panic(fmt.Errorf("failed to connect to cache: %w", err))
	}

	Cache = &cache{
		client: client,
	}
}

// Close gracefully closes the Redis client connection pool.
func Close() {
	if Cache.client != nil {
		_ = Cache.client.Close()
	}
}

type Cacheable interface {
	encoding.BinaryMarshaler
	encoding.BinaryUnmarshaler
}

func (c *cache) GetOrSet(ctx context.Context, key string, dest Cacheable, ttl time.Duration, loader func() error) error {
	found, err := c.Get(ctx, key, dest)
	if err != nil {
		return err
	}
	if found {
		return nil
	}
	if err := loader(); err != nil {
		return err
	}
	return c.Set(ctx, key, dest, ttl)
}

func (c *cache) Get(ctx context.Context, key string, dest Cacheable) (bool, error) {
	val, err := c.client.Get(ctx, key).Bytes()
	if errors.Is(err, redis.Nil) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	if err := dest.UnmarshalBinary(val); err != nil {
		return false, err
	}
	return true, nil
}

func (c *cache) Set(ctx context.Context, key string, value Cacheable, ttl time.Duration) error {
	data, err := value.MarshalBinary()
	if err != nil {
		return err
	}
	return c.client.Set(ctx, key, data, ttl).Err()
}
