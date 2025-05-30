<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

# S3 MCP Server - Copilot Instructions

## Project Overview
This is a Model Context Protocol (MCP) server written in Go that connects to AWS S3 to provide access to YAML files containing Swagger/OpenAPI documentation.

## Key Context
You can find more info and examples at https://modelcontextprotocol.io/llms-full.txt

## Architecture Guidelines

### MCP Protocol Implementation
- Follow MCP 2024-11-05 specification strictly
- Implement JSON-RPC 2.0 message format
- Support required methods: initialize, initialized, resources/list, resources/read
- Support tools: tools/list, tools/call
- Handle errors with proper MCP error codes

### Go Best Practices
- Use context.Context for all operations that may timeout
- Implement proper error handling and logging
- Follow Go naming conventions (exported vs unexported)
- Use interfaces for testability
- Implement graceful shutdown

### S3 Integration
- Use AWS SDK v2 for Go
- Support both AWS S3 and S3-compatible services
- Handle AWS credentials securely (environment variables, IAM roles)
- Implement efficient pagination for large buckets
- Filter for YAML files (.yaml, .yml extensions)

### Code Organization
- `main.go`: Entry point and server startup
- `internal/config`: Configuration management with environment variables
- `internal/s3`: S3 client wrapper and file operations
- `internal/server`: MCP server implementation and message handling
- `pkg/mcp`: MCP protocol types and utilities (reusable)

### Security Considerations
- Never log AWS credentials
- Validate S3 URIs before processing
- Implement proper input validation for all parameters
- Use least-privilege IAM permissions

### Error Handling
- Use MCP standard error codes (-32700 to -32603)
- Provide descriptive error messages
- Log errors appropriately without exposing sensitive information
- Handle S3 service errors gracefully

### Performance
- Use streaming for large files when possible
- Implement connection pooling for S3 client
- Cache metadata when appropriate
- Use efficient JSON marshaling/unmarshaling

## File Patterns
- Configuration in `internal/config/config.go`
- S3 operations in `internal/s3/client.go`
- MCP server logic in `internal/server/server.go`
- MCP types in `pkg/mcp/types.go`
- Main entry point in `main.go`

## Dependencies
- AWS SDK v2 for Go (github.com/aws/aws-sdk-go-v2/*)
- Standard library only for core functionality
- Avoid unnecessary external dependencies

## Testing Considerations
- Mock S3 client for unit tests
- Test MCP message handling
- Validate JSON-RPC compliance
- Test error conditions and edge cases
