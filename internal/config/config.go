package config

import (
	"os"
)

// Config holds the configuration for the S3 MCP server
type Config struct {
	// S3 Configuration
	S3Region    string
	S3Bucket    string
	S3AccessKey string
	S3SecretKey string
	S3Endpoint  string // Optional: for S3-compatible services

	// Server Configuration
	LogLevel string
}

// Load loads configuration from environment variables
func Load() *Config {
	return &Config{
		S3Region:    getEnvOrDefault("S3_REGION", "us-east-1"),
		S3Bucket:    getEnvOrDefault("S3_BUCKET", ""),
		S3AccessKey: getEnvOrDefault("AWS_ACCESS_KEY_ID", ""),
		S3SecretKey: getEnvOrDefault("AWS_SECRET_ACCESS_KEY", ""),
		S3Endpoint:  getEnvOrDefault("S3_ENDPOINT", ""),
		LogLevel:    getEnvOrDefault("LOG_LEVEL", "info"),
	}
}

func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
