# S3 YAML MCP Server

A Model Context Protocol (MCP) server that connects to AWS S3 to provide access to YAML files containing Swagger/OpenAPI documentation. Designed for seamless integration with VS Code and GitHub Copilot.

## 🎯 What is MCP?

Model Context Protocol (MCP) is an open protocol that standardizes how applications provide context to Large Language Models (LLMs). It enables AI assistants to securely access data sources and tools.

## ✨ Features

- **🔗 S3 Integration**: Connect to any S3-compatible storage service
- **📁 YAML File Discovery**: Automatically list and discover YAML/YML files
- **📖 Content Access**: Read and provide YAML content to AI assistants
- **🔍 Advanced Search**: Search for files and specific API endpoint details
- **🚀 VS Code Native**: Built-in integration with VS Code and GitHub Copilot
- **🔒 Secure Authentication**: Uses AWS CLI credentials or IAM roles

## 🚀 Installation

### Method 1: One-Line Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/andersoncastiblanco/s3-mcp-server/main/install.sh | bash
```

This will:

- Download the latest binary for your platform
- Install it to `/usr/local/bin`
- Set up VS Code configuration files

### Method 2: Go Install

```bash
go install github.com/andersoncastiblanco/s3-mcp-server@latest
```

### Method 3: Download Binary

Visit the [releases page](https://github.com/andersoncastiblanco/s3-mcp-server/releases) and download the binary for your platform.

### Method 4: Docker

```bash
docker pull ghcr.io/andersoncastiblanco/s3-mcp-server:latest
```

## 🐳 Docker Usage

### Quick Start with Docker

```bash
# Pull from GitHub Container Registry
docker pull ghcr.io/andersoncastiblanco/s3-mcp-server:latest

# Run with environment variables
docker run -it --rm \
  -e S3_BUCKET=your-bucket \
  -e S3_REGION=us-east-1 \
  -e AWS_ACCESS_KEY_ID=your-key \
  -e AWS_SECRET_ACCESS_KEY=your-secret \
  ghcr.io/andersoncastiblanco/s3-mcp-server:latest
```

### Using with Docker Compose

```yaml
# In your project's docker-compose.yml
version: '3.8'

services:
  s3-mcp-server:
    image: ghcr.io/andersoncastiblanco/s3-mcp-server:latest
    environment:
      - S3_BUCKET=your-api-docs-bucket
      - S3_REGION=us-east-1
    volumes:
      - ~/.aws:/home/mcp/.aws:ro
    stdin_open: true
    tty: true
```

### VS Code Integration with Docker

```json
// .vscode/mcp.json
{
  "mcpServers": {
    "s3YamlDocs": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-e", "S3_BUCKET=${input:s3-bucket}",
        "-e", "S3_REGION=${input:aws-region}",
        "-v", "${env:HOME}/.aws:/home/mcp/.aws:ro",
        "ghcr.io/andersoncastiblanco/s3-mcp-server:latest"
      ]
    }
  }
}
```

### Building Docker Images Locally

```bash
# Using Makefile
make docker-build          # Build local image
make docker-test           # Test the image
make docker-push           # Build and push to GHCR

# Using script
./docker-build.sh          # Interactive build and push

# Manual commands
docker build --build-arg VERSION=v1.0.0 -t s3-mcp-server:v1.0.0 .
docker run --rm s3-mcp-server:v1.0.0 ./s3-mcp-server --version
```

## 🚀 Quick Start

### Prerequisites

- AWS credentials configured (via AWS CLI, IAM roles, or environment variables)
- S3 bucket containing YAML files
- VS Code with GitHub Copilot extension

### Setup

1. **Install the server** (choose one method above)

2. **Configure environment**:

```bash
# In your project directory, create configuration
cat > .env << 'EOF'
S3_BUCKET=your-api-docs-bucket
S3_REGION=us-east-1
EOF
```

3. **Set up VS Code** (if not done by installer):

```bash
# Create VS Code MCP configuration
mkdir -p .vscode
cat > .vscode/mcp.json << 'EOF'
{
  "mcpServers": {
    "s3YamlDocs": {
      "command": "s3-mcp-server",
      "args": [],
      "env": {
        "S3_BUCKET": "your-bucket-name",
        "S3_REGION": "us-east-1"
      }
    }
  }
}
EOF
```

4. **Test the connection**:

```bash
./test-vscode-integration.sh
```

4. **Open in VS Code**:

```bash
code .
```

5. **Start using with GitHub Copilot**:
   - Open GitHub Copilot Chat (`Cmd+Shift+I` on macOS)
   - Type: `@s3YamlDocs list all YAML files in my bucket`

## 🛠️ MCP Capabilities

### Resources

- Lists all YAML files in the S3 bucket as MCP resources
- Each file is exposed with metadata (size, modification date)
- Files are accessible via S3 URIs: `s3://bucket-name/path/to/file.yaml`

### Tools

- **search_yaml_files**: Search for YAML files by name pattern
- **list_yaml_files**: List all YAML files with optional prefix filtering
- **get_endpoint_details**: Get detailed information about specific API endpoints including request/response schemas

## 💡 Usage Examples with GitHub Copilot

### Generate API Client Code

```
@s3YamlDocs I need to create a TypeScript client for the user management API.
Can you find the user API specification and generate a complete client with all methods?
```

### Find Specific Endpoint Details

```
@s3YamlDocs Use get_endpoint_details to find information about the /v1/cards/{card_id}/pan endpoint
```

### Validate Implementation

```
@s3YamlDocs Compare my Express.js routes in src/routes/users.js with the user API
specification to ensure I'm following the contract correctly.
```

### Generate Test Cases

```
@s3YamlDocs Based on the payment API specification, generate comprehensive
Jest test cases that cover all endpoints and error scenarios.
```

### Search and Analysis

```
@s3YamlDocs Search for all authentication-related endpoints across all my APIs
@s3YamlDocs Find all endpoints that return blocked_reason in the response
```

## ⚙️ Configuration

### Environment Variables

Create a `.env` file based on `.env.example`:

```bash
# Required
S3_BUCKET=your-api-docs-bucket

# Optional (defaults shown)
S3_REGION=us-east-1
AWS_ACCESS_KEY_ID=your-access-key     # Optional if using IAM/AWS CLI
AWS_SECRET_ACCESS_KEY=your-secret-key # Optional if using IAM/AWS CLI
S3_ENDPOINT=                          # For S3-compatible services
LOG_LEVEL=info
```

### AWS Authentication

The server supports multiple authentication methods:

1. **AWS CLI credentials** (recommended): `aws configure`
2. **IAM roles** (for EC2/Lambda deployments)
3. **Environment variables** (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)

### S3 Permissions

Your AWS credentials need these S3 permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket",
        "s3:HeadBucket",
        "s3:HeadObject"
      ],
      "Resource": [
        "arn:aws:s3:::your-bucket-name",
        "arn:aws:s3:::your-bucket-name/*"
      ]
    }
  ]
}
```

### Recommended S3 File Organization

```
your-s3-bucket/
├── apis/
│   ├── user-service/
│   │   ├── v1/openapi.yaml
│   │   └── v2/swagger.yaml
│   ├── payment-service/
│   │   └── api-spec.yml
│   └── notification-service/
│       └── swagger.yaml
└── legacy/
    └── old-api.yaml
```

## 🏗️ Development

### Project Structure

```
s3-mcp-server/
├── main.go                    # Entry point
├── internal/
│   ├── config/               # Configuration management
│   ├── s3/                   # S3 client and operations
│   └── server/               # MCP server implementation
├── pkg/
│   └── mcp/                  # MCP protocol types and utilities
├── .vscode/
│   └── mcp.json              # VS Code MCP configuration
├── .env.example              # Environment configuration template
└── README.md
```

### Building and Testing

```bash
# Using Makefile (recommended)
make build          # Build binary
make test           # Run tests
make test-vscode    # Test VS Code integration
make install        # Install to /usr/local/bin

# Manual build
go build -o s3-mcp-server

# Test scripts
./test-vscode-integration.sh
./test-new-tool.sh
./test.sh
```

## 📦 Distribution & Publishing

This project supports multiple distribution methods:

### 🏷️ Creating Releases

1. **Tag a version**:

```bash
git tag v1.0.0
git push origin v1.0.0
```

2. **GitHub Actions automatically**:
   - Builds binaries for all platforms (Linux, macOS, Windows)
   - Creates a GitHub release
   - Uploads platform-specific binaries

### 🐳 Docker Distribution

```bash
# Build Docker image
make docker-build

# Run with Docker
docker run --rm -e S3_BUCKET=your-bucket s3-mcp-server:latest
```

### 📋 Installation Methods Summary

| Method               | Command                                                                                                  | Use Case                       |
| -------------------- | -------------------------------------------------------------------------------------------------------- | ------------------------------ |
| **One-line install** | `curl -fsSL https://raw.githubusercontent.com/andersoncastiblanco/s3-mcp-server/main/install.sh \| bash` | Production use across projects |
| **Go install**       | `go install github.com/andersoncastiblanco/s3-mcp-server@latest`                                         | Go developers                  |
| **Binary download**  | Download from [releases](https://github.com/andersoncastiblanco/s3-mcp-server/releases)                  | Manual installation            |
| **Docker**           | `docker pull ghcr.io/andersoncastiblanco/s3-mcp-server:latest`                                           | Container environments         |
| **Clone & build**    | `git clone && make build`                                                                                | Development                    |

### 🔄 Using Across Multiple Projects

Once installed globally, you can use the S3 MCP server in any project:

1. **Create VS Code config in any project**:

```bash
mkdir -p .vscode
cat > .vscode/mcp.json << 'EOF'
{
  "mcpServers": {
    "s3YamlDocs": {
      "command": "s3-mcp-server",
      "args": [],
      "env": {
        "S3_BUCKET": "your-api-docs-bucket",
        "S3_REGION": "us-east-1"
      }
    }
  }
}
EOF
```

2. **Open VS Code and use GitHub Copilot**:

```
@s3YamlDocs list all YAML files
@s3YamlDocs find endpoints for user authentication
```

## 🔧 Troubleshooting

### Common Issues

**❌ S3 Connection Failed**

- Verify AWS credentials: `aws sts get-caller-identity`
- Check bucket permissions and region
- Ensure bucket exists: `aws s3 ls s3://your-bucket-name`

**❌ No Files Found**

- Verify YAML files exist with `.yaml` or `.yml` extensions
- Check S3 bucket contents: `aws s3 ls s3://your-bucket-name --recursive`

**❌ VS Code Integration Issues**

- Ensure VS Code is updated to latest version
- Check GitHub Copilot extension is active
- Verify `.vscode/mcp.json` configuration
- Check VS Code Output → "GitHub Copilot Chat" for errors

**❌ Permission Denied**

- Review IAM policies match required S3 permissions
- Check bucket policy allows access
- Verify region configuration matches bucket region

### Debug Mode

Enable debug logging:

```bash
LOG_LEVEL=debug ./s3-mcp-server
```

## 📚 Learn More

- **MCP Protocol**: https://modelcontextprotocol.io/
- **VS Code MCP Support**: https://code.visualstudio.com/docs/copilot/copilot-mcp
- **AWS S3 Go SDK**: https://aws.github.io/aws-sdk-go-v2/docs/

## 📄 License

MIT License - see LICENSE file for details.
