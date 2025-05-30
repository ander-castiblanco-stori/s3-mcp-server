# S3 MCP Server Makefile

# Version information
VERSION ?= $(shell git describe --tags --dirty --always 2>/dev/null || echo "dev")
COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build flags
LDFLAGS := -s -w -X main.Version=$(VERSION) -X main.GitCommit=$(COMMIT) -X main.BuildDate=$(BUILD_DATE)

# Go parameters
GOCMD := go
GOBUILD := $(GOCMD) build
GOCLEAN := $(GOCMD) clean
GOTEST := $(GOCMD) test
GOGET := $(GOCMD) get
GOMOD := $(GOCMD) mod

# Binary info
BINARY_NAME := s3-mcp-server
BINARY_PATH := ./$(BINARY_NAME)

# Default target
.PHONY: all
all: test build

# Build the binary
.PHONY: build
build:
	$(GOBUILD) -ldflags="$(LDFLAGS)" -o $(BINARY_PATH) .

# Build for all platforms
.PHONY: build-all
build-all: build-linux build-darwin build-windows

.PHONY: build-linux
build-linux:
	GOOS=linux GOARCH=amd64 $(GOBUILD) -ldflags="$(LDFLAGS)" -o $(BINARY_NAME)-linux-amd64 .
	GOOS=linux GOARCH=arm64 $(GOBUILD) -ldflags="$(LDFLAGS)" -o $(BINARY_NAME)-linux-arm64 .

.PHONY: build-darwin
build-darwin:
	GOOS=darwin GOARCH=amd64 $(GOBUILD) -ldflags="$(LDFLAGS)" -o $(BINARY_NAME)-darwin-amd64 .
	GOOS=darwin GOARCH=arm64 $(GOBUILD) -ldflags="$(LDFLAGS)" -o $(BINARY_NAME)-darwin-arm64 .

.PHONY: build-windows
build-windows:
	GOOS=windows GOARCH=amd64 $(GOBUILD) -ldflags="$(LDFLAGS)" -o $(BINARY_NAME)-windows-amd64.exe .

# Test the application
.PHONY: test
test:
	$(GOTEST) -v ./...

# Run basic server test
.PHONY: test-server
test-server: build
	./test.sh

# Run VS Code integration test
.PHONY: test-vscode
test-vscode: build
	./test-vscode-integration.sh

# Run endpoint tool test
.PHONY: test-endpoint
test-endpoint: build
	./test-new-tool.sh

# Clean build artifacts
.PHONY: clean
clean:
	$(GOCLEAN)
	rm -f $(BINARY_NAME)
	rm -f $(BINARY_NAME)-*

# Update dependencies
.PHONY: deps
deps:
	$(GOMOD) download
	$(GOMOD) tidy

# Run the server
.PHONY: run
run: build
	$(BINARY_PATH)

# Show version
.PHONY: version
version:
	@echo "Version: $(VERSION)"
	@echo "Commit: $(COMMIT)"
	@echo "Build Date: $(BUILD_DATE)"

# Install locally
.PHONY: install
install: build
	cp $(BINARY_PATH) /usr/local/bin/

# Docker build
.PHONY: docker-build
docker-build:
	docker build --build-arg VERSION=$(VERSION) -t s3-mcp-server:$(VERSION) .
	docker tag s3-mcp-server:$(VERSION) s3-mcp-server:latest

# Docker build for multi-platform
.PHONY: docker-build-multi
docker-build-multi:
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg VERSION=$(VERSION) \
		-t ghcr.io/andersoncastiblanco/s3-mcp-server:$(VERSION) \
		-t ghcr.io/andersoncastiblanco/s3-mcp-server:latest \
		.

# Docker push to GHCR
.PHONY: docker-push
docker-push: docker-build-multi
	docker push ghcr.io/andersoncastiblanco/s3-mcp-server:$(VERSION)
	docker push ghcr.io/andersoncastiblanco/s3-mcp-server:latest

# Docker compose up
.PHONY: docker-up
docker-up:
	docker-compose up --build

# Docker compose down
.PHONY: docker-down
docker-down:
	docker-compose down

# Docker test
.PHONY: docker-test
docker-test: docker-build
	docker run --rm s3-mcp-server:$(VERSION) ./s3-mcp-server --version

# Help
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  build       - Build the binary"
	@echo "  build-all   - Build for all platforms"
	@echo "  test        - Run tests"
	@echo "  test-server - Run basic server test"
	@echo "  test-vscode - Run VS Code integration test"
	@echo "  clean       - Clean build artifacts"
	@echo "  deps        - Update dependencies"
	@echo "  run         - Build and run the server"
	@echo "  install     - Install binary to /usr/local/bin"
	@echo "  docker-build    - Build Docker image"
	@echo "  docker-build-multi - Build multi-platform Docker image"
	@echo "  docker-push     - Build and push to GitHub Container Registry"
	@echo "  docker-up       - Start with Docker Compose"
	@echo "  docker-down     - Stop Docker Compose"
	@echo "  docker-test     - Test Docker image"
	@echo "  version         - Show version information"
	@echo "  help            - Show this help"
