package config

import (
	"fmt"
	"time"

	"github.com/spf13/pflag"
	"github.com/spf13/viper"
)

type Configuration struct {
	Server   Server
	Database Database
	Redis    Redis
	Logger   Logger
}

type Server struct {
	Name     string
	Mode     string
	Host     string
	Port     int
	Timezone string
}

type Database struct {
	Host     string
	Port     string
	Username string
	Password string
	Database string
	Params   string
	Pool     DatabasePool
}

type DatabasePool struct {
	MaxConns    int32
	MinConns    int32
	MaxLifetime time.Duration
	MaxIdleTime time.Duration
}

type Redis struct {
	Addr     string
	Password string
	DB       int
	Protocol int
	Pool     RedisPool
}

type RedisPool struct {
	Size int
}

type Logger struct {
	Level string
	File  File
}

type File struct {
	Filename   string
	MaxSize    int
	MaxBackups int
	MaxAge     int
	Compress   bool
}

var Config = Configuration{
	Server: Server{
		Name: "asaas",
		Mode: "debug",
		Host: "0.0.0.0",
		Port: 8080,
	},
	Database: Database{
		Host:     "localhost",
		Port:     "5432",
		Username: "postgres",
		Password: "postgres",
		Database: "postgres",
		Pool: DatabasePool{
			MaxOpen:     25,
			MaxIdle:     10,
			MaxLifetime: 15 * time.Minute,
			MaxIdleTime: 5 * time.Minute,
		},
	},
	Redis: Redis{
		Addr:     "localhost:6379",
		Password: "",
		DB:       0,
		Protocol: 2,
		Pool: RedisPool{
			Size: 10,
		},
	},
	Logger: Logger{
		Level: "info",
		File: File{
			Filename:   "logs/asaas.log",
			MaxSize:    100,
			MaxBackups: 10,
			MaxAge:     30,
			Compress:   true,
		},
	},
}

func Init() {
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")

	viper.SetEnvPrefix("asaas")
	viper.AutomaticEnv()

	viper.AddConfigPath(".")

	aliases()
	cmd()

	err := viper.ReadInConfig()
	if err != nil {
		panic(fmt.Errorf("fatal error config file: %w", err))
	}

	err = viper.Unmarshal(&Config)
	if err != nil {
		panic(fmt.Errorf("unable to decode into struct, %v", err))
	}
}

func aliases() {
	viper.RegisterAlias("mode", "server.mode")
	viper.RegisterAlias("host", "server.host")
	viper.RegisterAlias("port", "server.port")
}

func cmd() {
	pflag.String("mode", "debug", "")
	pflag.String("host", "0.0.0.0", "server listen host")
	pflag.Int("port", 8080, "server listen port")
	pflag.Parse()

	err := viper.BindPFlags(pflag.CommandLine)
	if err != nil {
		return
	}
}

func Save() {
	err := viper.WriteConfig()
	if err != nil {
		return
	}
}
