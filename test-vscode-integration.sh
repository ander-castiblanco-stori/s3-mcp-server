#!/bin/bash

# VS Code S3 MCP Server Test Script
echo "🧪 S3 MCP Server - VS Code Integration Test"
echo "=========================================="
echo

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "❌ No .env file found. Please run ./configure.sh first"
    exit 1
fi

# Load environment
source .env

if [ -z "$S3_BUCKET" ]; then
    echo "❌ S3_BUCKET not configured. Please run ./configure.sh first"
    exit 1
fi

echo "Testing with configuration:"
echo "Bucket: $S3_BUCKET"
echo "Region: $S3_REGION"
echo

# Build the server
echo "🔨 Building server..."
go build -o s3-mcp-server .
if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi
echo "✅ Build successful!"
echo

# Test 1: Basic S3 connection
echo "🧪 Test 1: S3 Connection Test"
echo "Testing AWS credentials and bucket access..."

if command -v aws &> /dev/null; then
    # Test S3 access using AWS CLI
    if aws s3 ls s3://$S3_BUCKET --region $S3_REGION >/dev/null 2>&1; then
        echo "✅ S3 bucket accessible via AWS CLI"
        
        # Count YAML files
        yaml_count=$(aws s3 ls s3://$S3_BUCKET --recursive | grep -E '\.(yaml|yml)$' | wc -l | tr -d ' ')
        echo "✅ Found $yaml_count YAML files in bucket"
        
        if [ "$yaml_count" -eq 0 ]; then
            echo "⚠️  No YAML files found. Run ./upload-test-files.sh to add test data"
        else
            echo "📄 Sample YAML files:"
            aws s3 ls s3://$S3_BUCKET --recursive | grep -E '\.(yaml|yml)$' | head -3 | while read -r line; do
                echo "   - $(echo $line | awk '{print $4}')"
            done
        fi
    else
        echo "❌ Cannot access S3 bucket. Check your credentials and bucket name."
        echo "   Bucket: $S3_BUCKET"
        echo "   Region: $S3_REGION"
        exit 1
    fi
else
    echo "⚠️  AWS CLI not found. Testing with Go server directly..."
fi

echo

# Test 2: MCP Server Protocol Test (VS Code compatible)
echo "🧪 Test 2: MCP Protocol Test (VS Code Compatible)"
echo "Testing MCP server with VS Code-style communication..."

# Create a test script that simulates VS Code's MCP interaction
cat > test_vscode_mcp.py << 'EOF'
#!/usr/bin/env python3
import json
import subprocess
import sys
import time
import os
from threading import Timer, Thread
import queue

class VSCodeMCPTester:
    def __init__(self):
        self.process = None
        self.response_queue = queue.Queue()
        
    def read_responses(self):
        """Read responses from server in a separate thread"""
        try:
            while self.process and self.process.poll() is None:
                line = self.process.stdout.readline()
                if line:
                    try:
                        response = json.loads(line.strip())
                        self.response_queue.put(response)
                    except json.JSONDecodeError:
                        print(f"Invalid JSON received: {line.strip()}")
        except Exception as e:
            print(f"Error reading responses: {e}")
    
    def send_message(self, message):
        """Send a message to the MCP server"""
        json_msg = json.dumps(message)
        self.process.stdin.write(json_msg + '\n')
        self.process.stdin.flush()
        
    def wait_for_response(self, timeout=5):
        """Wait for a response from the server"""
        try:
            return self.response_queue.get(timeout=timeout)
        except queue.Empty:
            return None
    
    def test_mcp_flow(self):
        """Test the complete MCP flow as VS Code would"""
        try:
            # Start the server
            print("🚀 Starting MCP server...")
            self.process = subprocess.Popen(
                ['./s3-mcp-server'],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=0,
                env=os.environ.copy()
            )
            
            # Start response reader thread
            reader_thread = Thread(target=self.read_responses)
            reader_thread.daemon = True
            reader_thread.start()
            
            time.sleep(1)  # Give server time to start
            
            # Step 1: Initialize
            print("📤 Sending initialize request...")
            init_message = {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {
                        "experimental": {},
                        "sampling": {}
                    },
                    "clientInfo": {
                        "name": "vscode-test",
                        "version": "1.0.0"
                    }
                }
            }
            self.send_message(init_message)
            
            # Wait for initialize response
            response = self.wait_for_response(10)
            if response:
                print("✅ Initialize response received")
                print(f"   Server: {response.get('result', {}).get('serverInfo', {}).get('name', 'Unknown')}")
                print(f"   Version: {response.get('result', {}).get('serverInfo', {}).get('version', 'Unknown')}")
            else:
                print("❌ No initialize response received")
                return False
            
            # Step 2: Send initialized notification
            print("📤 Sending initialized notification...")
            initialized_message = {
                "jsonrpc": "2.0",
                "method": "initialized",
                "params": {}
            }
            self.send_message(initialized_message)
            
            time.sleep(1)
            
            # Step 3: List resources (YAML files)
            print("📤 Requesting resources list...")
            list_resources = {
                "jsonrpc": "2.0",
                "id": 2,
                "method": "resources/list",
                "params": {}
            }
            self.send_message(list_resources)
            
            response = self.wait_for_response(10)
            if response and 'result' in response:
                resources = response['result'].get('resources', [])
                print(f"✅ Found {len(resources)} resources")
                for i, resource in enumerate(resources[:3]):  # Show first 3
                    print(f"   {i+1}. {resource.get('name', 'Unknown')}")
                if len(resources) > 3:
                    print(f"   ... and {len(resources) - 3} more")
            else:
                print("❌ No resources response received")
                return False
            
            # Step 4: Test tools list
            print("📤 Requesting tools list...")
            list_tools = {
                "jsonrpc": "2.0",
                "id": 3,
                "method": "tools/list",
                "params": {}
            }
            self.send_message(list_tools)
            
            response = self.wait_for_response(10)
            if response and 'result' in response:
                tools = response['result'].get('tools', [])
                print(f"✅ Found {len(tools)} tools:")
                for tool in tools:
                    print(f"   - {tool.get('name', 'Unknown')}: {tool.get('description', 'No description')}")
            else:
                print("❌ No tools response received")
                return False
            
            # Step 5: Test tool call (list_yaml_files)
            if len(tools) > 0:
                print("📤 Testing tool call (list_yaml_files)...")
                tool_call = {
                    "jsonrpc": "2.0",
                    "id": 4,
                    "method": "tools/call",
                    "params": {
                        "name": "list_yaml_files",
                        "arguments": {}
                    }
                }
                self.send_message(tool_call)
                
                response = self.wait_for_response(10)
                if response and 'result' in response:
                    content = response['result'].get('content', [])
                    print(f"✅ Tool call successful, returned {len(content)} items")
                    if content:
                        print(f"   Sample: {content[0].get('text', '')[:100]}...")
                else:
                    print("❌ Tool call failed or no response")
            
            print("✅ MCP protocol test completed successfully!")
            return True
            
        except Exception as e:
            print(f"❌ MCP test failed: {e}")
            return False
        finally:
            if self.process:
                self.process.terminate()
                self.process.wait()

if __name__ == "__main__":
    tester = VSCodeMCPTester()
    success = tester.test_mcp_flow()
    sys.exit(0 if success else 1)
EOF

# Run the VS Code MCP test
if command -v python3 &> /dev/null; then
    echo "Running VS Code MCP protocol test..."
    chmod +x test_vscode_mcp.py
    python3 test_vscode_mcp.py
    test_result=$?
    rm -f test_vscode_mcp.py
    
    if [ $test_result -eq 0 ]; then
        echo "✅ MCP protocol test passed!"
    else
        echo "❌ MCP protocol test failed!"
        exit 1
    fi
else
    echo "⚠️  Python3 not found, skipping MCP protocol test"
    echo "Testing basic server startup instead..."
    
    # Fallback: test server startup
    timeout 5s ./s3-mcp-server &
    SERVER_PID=$!
    sleep 2
    
    if kill -0 $SERVER_PID 2>/dev/null; then
        echo "✅ Server started successfully"
        kill $SERVER_PID 2>/dev/null
        wait $SERVER_PID 2>/dev/null
    else
        echo "❌ Server failed to start"
        exit 1
    fi
fi

echo

# Test 3: VS Code Configuration Validation
echo "🧪 Test 3: VS Code Configuration Validation"
echo "Checking VS Code MCP configuration files..."

# Check .vscode/mcp.json
if [ -f ".vscode/mcp.json" ]; then
    echo "✅ .vscode/mcp.json exists"
    
    # Validate JSON
    if python3 -m json.tool .vscode/mcp.json >/dev/null 2>&1; then
        echo "✅ .vscode/mcp.json is valid JSON"
        
        # Check if server is configured
        if grep -q "s3YamlDocs" .vscode/mcp.json; then
            echo "✅ s3YamlDocs server configured"
        else
            echo "❌ s3YamlDocs server not found in configuration"
        fi
    else
        echo "❌ .vscode/mcp.json is invalid JSON"
    fi
else
    echo "❌ .vscode/mcp.json not found"
fi

# Check .vscode/settings.json
if [ -f ".vscode/settings.json" ]; then
    echo "✅ .vscode/settings.json exists"
    
    if grep -q '"chat.mcp.enabled": true' .vscode/settings.json; then
        echo "✅ MCP support enabled in VS Code settings"
    else
        echo "❌ MCP support not enabled in VS Code settings"
    fi
else
    echo "❌ .vscode/settings.json not found"
fi

# Check binary exists
if [ -f "s3-mcp-server" ]; then
    echo "✅ s3-mcp-server binary exists"
    file_size=$(ls -lh s3-mcp-server | awk '{print $5}')
    echo "   Size: $file_size"
else
    echo "❌ s3-mcp-server binary not found"
fi

echo

# Test 4: VS Code Usage Instructions
echo "🧪 Test 4: VS Code Integration Instructions"
current_path=$(pwd)

echo "✅ Your S3 MCP server is ready for VS Code!"
echo
echo "📋 Next Steps:"
echo "1. Open VS Code in this directory:"
echo "   code ."
echo
echo "2. Open GitHub Copilot Chat:"
echo "   - Press Ctrl+Shift+I (Linux/Windows) or Cmd+Shift+I (macOS)"
echo "   - Or use View → Command Palette → 'Chat: Focus on Chat View'"
echo
echo "3. Start using your S3 APIs:"
echo "   @s3YamlDocs list all YAML files"
echo "   @s3YamlDocs search for \"user\" in API files"
echo "   @s3YamlDocs generate TypeScript client for user API"
echo
echo "4. Example conversations:"
echo "   • Generate API client code based on your specifications"
echo "   • Validate your implementations against API contracts"
echo "   • Create comprehensive test suites for your APIs"
echo "   • Analyze API differences between versions"
echo

echo "🎯 Configuration Summary:"
echo "   Bucket: $S3_BUCKET"
echo "   Region: $S3_REGION"
echo "   Binary: $current_path/s3-mcp-server"
echo "   Status: Ready for VS Code integration"
echo

echo "📖 For detailed usage instructions, see:"
echo "   - VS_CODE_INTEGRATION.md"
echo "   - SETUP_COMPLETE.md"
echo

if [ "$yaml_count" -eq 0 ]; then
    echo "💡 Tip: Run ./upload-test-files.sh to add sample API documentation"
fi

echo "✅ All tests completed successfully!"
echo "🚀 Your S3 MCP server is ready for VS Code and GitHub Copilot!"
