# Build stage
FROM golang:1.21-alpine AS builder

# Build argument for version
ARG VERSION=dev

WORKDIR /app

# Install git for version info
RUN apk add --no-cache git

# Copy go mod and sum files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application with version info
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-s -w -X main.Version=${VERSION}" \
    -o s3-mcp-server .

# Final stage
FROM alpine:latest

# Install ca-certificates and tzdata for HTTPS and timezone
RUN apk --no-cache add ca-certificates tzdata && \
    adduser -D -s /bin/sh mcp

WORKDIR /home/mcp

# Copy the binary from builder stage
COPY --from=builder /app/s3-mcp-server .

# Change ownership to non-root user
RUN chown mcp:mcp s3-mcp-server

# Switch to non-root user
USER mcp

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ./s3-mcp-server --version || exit 1

# Set default environment variables
ENV LOG_LEVEL=info

# Run the binary
CMD ["./s3-mcp-server"]
