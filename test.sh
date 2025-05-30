#!/bin/bash

# Test script for S3 MCP Server
# This script tests the server initialization without requiring S3 credentials

echo "Testing S3 MCP Server..."
echo "Note: This test will fail with S3 connection error unless you have valid credentials"
echo

# Set minimal environment for testing
export S3_BUCKET="test-bucket"
export S3_REGION="us-east-1"
export LOG_LEVEL="info"

# Run the server for a few seconds to test initialization
timeout 5s ./s3-mcp-server || echo "Server initialization test completed (expected to timeout)"

echo
echo "If you see 'S3 connection test failed', that's expected without valid S3 credentials."
echo "To test with real S3:"
echo "1. Copy .env.example to .env"
echo "2. Fill in your S3 bucket and AWS credentials"
echo "3. Run: ./s3-mcp-server"
