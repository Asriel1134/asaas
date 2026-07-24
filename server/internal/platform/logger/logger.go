package logger

import (
	"context"
	"os"

	"asriel.cn/asaas/server/internal/config"
	"github.com/natefinch/lumberjack"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

var (
	L *zap.Logger
	S *zap.SugaredLogger
)

func Init() {
	level := parseLevel(config.Config.Logger.Level)

	fileCore := zapcore.NewCore(
		zapcore.NewJSONEncoder(zapcore.EncoderConfig{
			TimeKey:        "timestamp",
			LevelKey:       "level",
			NameKey:        "logger",
			CallerKey:      "caller",
			FunctionKey:    zapcore.OmitKey,
			MessageKey:     "msg",
			StacktraceKey:  "stacktrace",
			LineEnding:     zapcore.DefaultLineEnding,
			EncodeLevel:    zapcore.LowercaseLevelEncoder,
			EncodeTime:     zapcore.EpochTimeEncoder,
			EncodeDuration: zapcore.SecondsDurationEncoder,
			EncodeCaller:   zapcore.ShortCallerEncoder,
		}),
		zapcore.AddSync(&lumberjack.Logger{
			Filename:   config.Config.Logger.File.Filename,
			MaxSize:    config.Config.Logger.File.MaxSize,
			MaxBackups: config.Config.Logger.File.MaxBackups,
			MaxAge:     config.Config.Logger.File.MaxAge,
			Compress:   config.Config.Logger.File.Compress,
			LocalTime:  true,
		}),
		level,
	)

	consoleCore := zapcore.NewCore(
		zapcore.NewConsoleEncoder(zapcore.EncoderConfig{
			TimeKey:        "T",
			LevelKey:       "L",
			NameKey:        "N",
			CallerKey:      "C",
			FunctionKey:    zapcore.OmitKey,
			MessageKey:     "M",
			StacktraceKey:  "S",
			LineEnding:     zapcore.DefaultLineEnding,
			EncodeLevel:    zapcore.CapitalLevelEncoder,
			EncodeTime:     zapcore.ISO8601TimeEncoder,
			EncodeDuration: zapcore.StringDurationEncoder,
			EncodeCaller:   zapcore.ShortCallerEncoder,
		}),
		zapcore.AddSync(os.Stdout),
		level,
	)

	core := zapcore.NewTee(fileCore, consoleCore)

	L = zap.New(core, zap.AddCaller(), zap.AddStacktrace(zapcore.ErrorLevel))
	withs()
	S = L.Sugar()
}

func withs() {
	L = L.With(zap.String("service", config.Config.Server.Name))
}

func Sync() {
	_ = L.Sync()
}

func parseLevel(s string) zapcore.Level {
	var l zapcore.Level
	_ = l.UnmarshalText([]byte(s))
	return l
}

func FromContext(ctx context.Context) *zap.SugaredLogger {
	fields := []any{
		"request_id", GetRequestID(ctx),
		"module", GetModule(ctx),
		"action", GetAction(ctx),
	}
	return S.With(fields...)
}
