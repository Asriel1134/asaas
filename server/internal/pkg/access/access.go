package access

import (
	"context"

	"github.com/google/uuid"
)

type ctxKey string

const accessCtxKey ctxKey = "access"

type Context struct {
	UserID      uuid.UUID
	TenantID    uuid.UUID
	WorkspaceID uuid.UUID
	SessionID   uuid.UUID
}

// Set stores access info into the context.
func Set(ctx context.Context, acc Context) context.Context {
	return context.WithValue(ctx, accessCtxKey, acc)
}

// Get retrieves access info from the context.
func Get(ctx context.Context) (Context, bool) {
	v := ctx.Value(accessCtxKey)
	if v == nil {
		return Context{}, false
	}
	acc, ok := v.(Context)
	return acc, ok
}
