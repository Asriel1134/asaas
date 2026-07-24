package logger

import (
	"context"
)

func getContextValue(ctx context.Context, key any) string {
	if value, ok := ctx.Value(key).(string); ok {
		return value
	}
	return ""
}

type requestIDKey struct{}

func WithRequestID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, requestIDKey{}, id)
}

func GetRequestID(ctx context.Context) string {
	return getContextValue(ctx, requestIDKey{})
}

type moduleKey struct{}

func WithModule(ctx context.Context, module string) context.Context {
	return context.WithValue(ctx, moduleKey{}, module)
}

func GetModule(ctx context.Context) string {
	return getContextValue(ctx, moduleKey{})
}

type actionKey struct{}

func WithAction(ctx context.Context, action string) context.Context {
	return context.WithValue(ctx, actionKey{}, action)
}

func GetAction(ctx context.Context) string {
	return getContextValue(ctx, actionKey{})
}
