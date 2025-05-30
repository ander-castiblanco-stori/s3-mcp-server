#!/bin/bash

# S3 MCP Server Installation Script
# This script installs the S3 MCP server binary and sets up VS Code configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Constants
REPO="ander-castiblanco-stori/s3-mcp-server"
BINARY_NAME="s3-mcp-server"
INSTALL_DIR="/usr/local/bin"

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}🚀 S3 MCP Server Installer${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
}

print_step() {
    echo -e "${YELLOW}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if running on supported OS
check_os() {
    case "$(uname -s)" in
        Darwin*)    OS="darwin" ;;
        Linux*)     OS="linux" ;;
        CYGWIN*|MINGW*) OS="windows" ;;
        *)          print_error "Unsupported operating system: $(uname -s)"; exit 1 ;;
    esac
}

# Check architecture
check_arch() {
    case "$(uname -m)" in
        x86_64|amd64)   ARCH="amd64" ;;
        arm64|aarch64)  ARCH="arm64" ;;
        *)              print_error "Unsupported architecture: $(uname -m)"; exit 1 ;;
    esac
}

# Get latest release version
get_latest_version() {
    print_step "Getting latest release version..."
    VERSION=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$VERSION" ]; then
        print_error "Failed to get latest version"
        exit 1
    fi
    print_success "Latest version: ${VERSION}"
}

# Download and install binary
install_binary() {
    print_step "Downloading ${BINARY_NAME}..."
    
    BINARY_SUFFIX="${OS}-${ARCH}"
    if [ "$OS" = "windows" ]; then
        BINARY_SUFFIX="${BINARY_SUFFIX}.exe"
        BINARY_NAME="${BINARY_NAME}.exe"
    fi
    
    DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${BINARY_NAME}-${BINARY_SUFFIX}"
    
    # Create temporary directory
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    
    # Download binary
    if ! curl -L -o "$BINARY_NAME" "$DOWNLOAD_URL"; then
        print_error "Failed to download binary from $DOWNLOAD_URL"
        exit 1
    fi
    
    # Make executable
    chmod +x "$BINARY_NAME"
    
    # Install to system directory
    print_step "Installing to ${INSTALL_DIR}..."
    if [ "$EUID" -eq 0 ]; then
        # Running as root
        mv "$BINARY_NAME" "$INSTALL_DIR/"
    else
        # Use sudo
        sudo mv "$BINARY_NAME" "$INSTALL_DIR/"
    fi
    
    # Cleanup
    cd - > /dev/null
    rm -rf "$TMP_DIR"
    
    print_success "Binary installed to ${INSTALL_DIR}/${BINARY_NAME}"
}

# Check if VS Code is installed
check_vscode() {
    if command -v code >/dev/null 2>&1; then
        print_success "VS Code detected"
        return 0
    else
        print_error "VS Code not found. Please install VS Code first."
        return 1
    fi
}

# Setup VS Code configuration
setup_vscode_config() {
    print_step "Setting up VS Code MCP configuration..."
    
    # Check if we're in a workspace directory
    if [ ! -d ".vscode" ]; then
        print_step "Creating .vscode directory..."
        mkdir -p .vscode
    fi
    
    # Create MCP configuration
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

    # Create VS Code settings if they don't exist
    if [ ! -f ".vscode/settings.json" ]; then
        cat > .vscode/settings.json << 'EOF'
{
  "chat.mcp.enabled": true
}
EOF
    else
        # Update existing settings.json to enable MCP if not already enabled
        if ! grep -q '"chat.mcp.enabled"' .vscode/settings.json; then
            # Add MCP setting to existing file
            jq '. + {"chat.mcp.enabled": true}' .vscode/settings.json > .vscode/settings.json.tmp && mv .vscode/settings.json.tmp .vscode/settings.json 2>/dev/null || {
                print_error "Failed to update settings.json. Please manually add: \"chat.mcp.enabled\": true"
            }
        fi
    fi
    
    # Create environment template
    if [ ! -f ".env" ]; then
        cat > .env << 'EOF'
# S3 Configuration
S3_BUCKET=your-bucket-name
S3_REGION=us-east-1

# AWS Credentials (optional if using IAM roles or AWS CLI)
# S3_ACCESS_KEY=your-access-key
# S3_SECRET_KEY=your-secret-key

# Optional: Custom S3 endpoint (for S3-compatible services)
# S3_ENDPOINT=https://your-s3-endpoint.com

# Logging
LOG_LEVEL=info
EOF
    fi
    
    print_success "VS Code configuration created"
    echo -e "${YELLOW}📝 Don't forget to update .vscode/mcp.json and .env with your S3 credentials!${NC}"
}

# Print usage instructions
print_usage() {
    echo
    echo -e "${GREEN}🎉 Installation Complete!${NC}"
    echo
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo "1. Update your S3 configuration:"
    echo "   - Edit .vscode/mcp.json with your S3 bucket name"
    echo "   - Update .env with your AWS credentials"
    echo
    echo "2. Test the installation:"
    echo "   ${BINARY_NAME} --help"
    echo
    echo "3. Use in VS Code:"
    echo "   - Open this directory in VS Code: code ."
    echo "   - Open GitHub Copilot Chat (Ctrl+Shift+I / Cmd+Shift+I)"
    echo "   - Try: @s3YamlDocs list all YAML files"
    echo
    echo -e "${BLUE}📚 Documentation:${NC}"
    echo "https://github.com/${REPO}"
    echo
}

# Main installation flow
main() {
    print_header
    
    check_os
    check_arch
    get_latest_version
    install_binary
    
    if check_vscode; then
        setup_vscode_config
    fi
    
    print_usage
}

# Run installation
main "$@"
