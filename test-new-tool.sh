#!/bin/bash

# Test script for the new get_endpoint_details tool
echo "🚀 Testing the new get_endpoint_details MCP tool"
echo "=============================================="

# Check if binary exists
if [ ! -f "./s3-mcp-server" ]; then
    echo "❌ s3-mcp-server binary not found. Building..."
    go build -o s3-mcp-server .
    if [ $? -ne 0 ]; then
        echo "❌ Build failed"
        exit 1
    fi
    echo "✅ Build successful"
fi

# Check environment variables
if [ -z "$S3_BUCKET" ]; then
    echo "⚠️  S3_BUCKET not set. Using default: ander-mcp-test"
    export S3_BUCKET="ander-mcp-test"
fi

if [ -z "$S3_REGION" ]; then
    echo "⚠️  S3_REGION not set. Using default: us-east-1"
    export S3_REGION="us-east-1"
fi

echo ""
echo "📋 Configuration:"
echo "   S3_BUCKET: $S3_BUCKET"
echo "   S3_REGION: $S3_REGION"
echo ""

# Function to send MCP request
send_mcp_request() {
    local method="$1"
    local params="$2"
    
    if [ -z "$params" ]; then
        request='{"jsonrpc":"2.0","id":1,"method":"'$method'"}'
    else
        request='{"jsonrpc":"2.0","id":1,"method":"'$method'","params":'$params'}'
    fi
    
    echo "$request" | ./s3-mcp-server | tail -1
}

# Test 1: Initialize server
echo "1️⃣  Testing server initialization..."
init_params='{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test-client","version":"1.0.0"}}'
response=$(send_mcp_request "initialize" "$init_params")
echo "Response: $response"
echo ""

# Test 2: List tools to verify new tool exists
echo "2️⃣  Listing available tools..."
response=$(send_mcp_request "tools/list")
echo "Response: $response"
echo ""

# Test 3: Test the new get_endpoint_details tool
echo "3️⃣  Testing get_endpoint_details tool..."

# Test case 1: Search for cards endpoints
echo "🔍 Searching for '/cards' endpoints..."
params='{"name":"get_endpoint_details","arguments":{"path":"/cards"}}'
response=$(send_mcp_request "tools/call" "$params")
echo "Response: $response"
echo ""

# Test case 2: Search for users endpoints with specific method
echo "🔍 Searching for 'GET /users' endpoint..."
params='{"name":"get_endpoint_details","arguments":{"path":"/users","method":"GET"}}'
response=$(send_mcp_request "tools/call" "$params")
echo "Response: $response"
echo ""

# Test case 3: Search for anything containing "blocked"
echo "🔍 Searching for endpoints containing 'blocked'..."
params='{"name":"get_endpoint_details","arguments":{"path":"blocked"}}'
response=$(send_mcp_request "tools/call" "$params")
echo "Response: $response"
echo ""

echo "✅ Testing complete!"
echo ""
echo "💡 Usage examples:"
echo "   - Search for any cards endpoint: path='/cards'"
echo "   - Search for specific method: path='/users', method='GET'"
echo "   - Search for blocked endpoints: path='blocked'"
echo "   - Search partial paths: path='/api/v1/cards'"
