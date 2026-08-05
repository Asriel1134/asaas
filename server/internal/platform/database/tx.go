package database

import (
	"context"
	"fmt"

	"asriel.cn/asaas/server/internal/pkg/access"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

func Tx[T any](ctx context.Context, f func(tx pgx.Tx) (T, error)) (T, error) {
	var zero T

	tx, err := DB.BeginTx(ctx, pgx.TxOptions{
		IsoLevel: pgx.ReadCommitted,
	})
	if err != nil {
		return zero, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer func() {
		_ = tx.Rollback(ctx)
	}()

	acc, ok := access.Get(ctx)
	if ok && acc.TenantID != uuid.Nil {
		_, err = tx.Exec(
			ctx,
			`SELECT set_config('app.tenant_id', $1, true)`,
			acc.TenantID.String(),
		)
		if err != nil {
			return zero, fmt.Errorf("failed to set tenant context: %w", err)
		}
	}

	result, err := f(tx)
	if err != nil {
		return zero, err
	}

	if err := tx.Commit(ctx); err != nil {
		return zero, fmt.Errorf("failed to commit transaction: %w", err)
	}

	return result, nil
}
