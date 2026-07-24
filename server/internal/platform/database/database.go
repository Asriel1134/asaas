package database

import (
	"context"
	"fmt"
	"net/url"
	"time"

	"asriel.cn/asaas/server/internal/config"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var DB *pgxpool.Pool

func Init() {
	cfg, err := pgxpool.ParseConfig(dsn())
	if err != nil {
		panic(fmt.Errorf("failed to parse database config: %w", err))
	}
	cfg.MaxConns = config.Config.Database.Pool.MaxConns
	cfg.MinConns = config.Config.Database.Pool.MinConns
	cfg.MaxConnLifetime = config.Config.Database.Pool.MaxLifetime
	cfg.MaxConnIdleTime = config.Config.Database.Pool.MaxIdleTime
	cfg.HealthCheckPeriod = 30 * time.Second

	if len(config.Config.Server.Name) != 0 {
		cfg.ConnConfig.RuntimeParams["application_name"] = config.Config.Server.Name
	}

	if len(config.Config.Server.Timezone) != 0 {
		cfg.ConnConfig.RuntimeParams["timezone"] = config.Config.Server.Timezone
		cfg.AfterConnect = func(ctx context.Context, conn *pgx.Conn) error {
			_, err := conn.Exec(ctx, "SET TIME ZONE '"+config.Config.Server.Timezone+"'")
			return err
		}
	}

	ctx, cancel := context.WithTimeout(
		context.Background(),
		10*time.Second,
	)
	defer cancel()

	pool, err := pgxpool.NewWithConfig(ctx, cfg)

	if err != nil {
		panic(fmt.Errorf("failed to create PostgreSQL pool: %w", err))
	}

	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		panic(fmt.Errorf("failed to ping PostgreSQL: %w", err))
	}

	DB = pool
}

func dsn() string {
	c := config.Config.Database
	u := url.URL{
		Scheme: "postgres",
		User:   url.UserPassword(c.Username, c.Password),
		Host:   c.Host + ":" + c.Port,
		Path:   c.Database,
	}
	if c.Params != "" {
		u.RawQuery = c.Params
	}
	return u.String()
}

func Close() {
	if DB != nil {
		DB.Close()
	}
}
