#!/bin/bash

# Docker Build and Push Script for S3 MCP Server
# This script builds and pushes to GitHub Container Registry

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_NAME="andersoncastiblanco/s3-mcp-server"
GHCR_IMAGE="ghcr.io/${REPO_NAME}"

print_step() {
    echo -e "${YELLOW}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Get version from git tag or use 'dev'
get_version() {
    if git describe --tags --exact-match HEAD 2>/dev/null; then
        VERSION=$(git describe --tags --exact-match HEAD)
    else
        VERSION="dev"
    fi
    echo "Version: $VERSION"
}

# Build Docker image
build_image() {
    print_step "Building Docker image..."
    
    docker build \
        --build-arg VERSION="$VERSION" \
        --platform linux/amd64,linux/arm64 \
        -t "$GHCR_IMAGE:$VERSION" \
        -t "$GHCR_IMAGE:latest" \
        .
    
    print_success "Docker image built successfully"
}

# Test the image locally
test_image() {
    print_step "Testing Docker image..."
    
    # Test version command
    if docker run --rm "$GHCR_IMAGE:$VERSION" ./s3-mcp-server --version; then
        print_success "Image test passed"
    else
        print_error "Image test failed"
        exit 1
    fi
}

# Push to GitHub Container Registry
push_to_ghcr() {
    print_step "Pushing to GitHub Container Registry..."
    
    # Check if logged in
    if ! docker system info | grep -q "Username:"; then
        print_error "Not logged in to Docker registry"
        echo "Please run: echo \$GITHUB_TOKEN | docker login ghcr.io -u <username> --password-stdin"
        exit 1
    fi
    
    docker push "$GHCR_IMAGE:$VERSION"
    
    if [ "$VERSION" != "dev" ]; then
        docker push "$GHCR_IMAGE:latest"
    fi
    
    print_success "Pushed to GitHub Container Registry"
}

# Main function
main() {
    echo -e "${BLUE}🐳 Docker Build and Push Script${NC}"
    echo
    
    get_version
    build_image
    test_image
    
    # Ask for confirmation before pushing
    read -p "Push to GitHub Container Registry? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        push_to_ghcr
        echo
        print_success "Docker image published successfully!"
        echo
        echo -e "${BLUE}📋 Usage:${NC}"
        echo "docker pull $GHCR_IMAGE:$VERSION"
        echo "docker run -it --rm -e S3_BUCKET=your-bucket $GHCR_IMAGE:$VERSION"
    else
        echo "Skipping push to registry"
    fi
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
