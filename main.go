package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"

	"github.com/andersoncastiblanco/s3-mcp-server/internal/server"
)

func main() {
	// Parse command line flags
	var showVersion = flag.Bool("version", false, "Show version information")
	var showHelp = flag.Bool("help", false, "Show help information")
	flag.Parse()

	if *showVersion {
		fmt.Printf("S3 MCP Server\n")
		fmt.Printf("Version: %s\n", Version)
		fmt.Printf("Git Commit: %s\n", GitCommit)
		fmt.Printf("Build Date: %s\n", BuildDate)
		os.Exit(0)
	}

	if *showHelp {
		fmt.Printf("S3 MCP Server - Model Context Protocol server for S3 YAML files\n\n")
		fmt.Printf("Usage: %s [options]\n\n", os.Args[0])
		fmt.Printf("Options:\n")
		flag.PrintDefaults()
		fmt.Printf("\nEnvironment Variables:\n")
		fmt.Printf("  S3_BUCKET      S3 bucket name (required)\n")
		fmt.Printf("  S3_REGION      AWS region (default: us-east-1)\n")
		fmt.Printf("  S3_ACCESS_KEY  AWS access key (optional)\n")
		fmt.Printf("  S3_SECRET_KEY  AWS secret key (optional)\n")
		fmt.Printf("  S3_ENDPOINT    Custom S3 endpoint (optional)\n")
		fmt.Printf("  LOG_LEVEL      Log level (default: info)\n")
		fmt.Printf("\nFor more information, visit:\n")
		fmt.Printf("https://github.com/andersoncastiblanco/s3-mcp-server\n")
		os.Exit(0)
	}

	ctx := context.Background()

	// Initialize the MCP server
	mcpServer, err := server.New()
	if err != nil {
		log.Fatalf("Failed to create MCP server: %v", err)
	}

	// Start the server
	if err := mcpServer.Start(ctx); err != nil {
		log.Fatalf("Failed to start MCP server: %v", err)
	}
}
