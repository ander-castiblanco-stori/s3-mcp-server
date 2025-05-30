package server

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"strings"

	"github.com/andersoncastiblanco/s3-mcp-server/internal/config"
	"github.com/andersoncastiblanco/s3-mcp-server/internal/s3"
	"github.com/andersoncastiblanco/s3-mcp-server/pkg/mcp"
)

// Server represents the MCP server
type Server struct {
	config   *config.Config
	s3Client *s3.Client
	reader   *bufio.Reader
	writer   io.Writer
}

// New creates a new MCP server instance
func New() (*Server, error) {
	cfg := config.Load()

	// Validate required configuration
	if cfg.S3Bucket == "" {
		return nil, fmt.Errorf("S3_BUCKET environment variable is required")
	}

	// Create S3 client
	s3Client, err := s3.New(cfg.S3Region, cfg.S3Bucket, cfg.S3AccessKey, cfg.S3SecretKey, cfg.S3Endpoint)
	if err != nil {
		return nil, fmt.Errorf("failed to create S3 client: %w", err)
	}

	return &Server{
		config:   cfg,
		s3Client: s3Client,
		reader:   bufio.NewReader(os.Stdin),
		writer:   os.Stdout,
	}, nil
}

// Start starts the MCP server
func (s *Server) Start(ctx context.Context) error {
	log.Printf("Starting S3 MCP Server - Bucket: %s, Region: %s", s.config.S3Bucket, s.config.S3Region)

	// Test S3 connection
	if err := s.s3Client.TestConnection(ctx); err != nil {
		return fmt.Errorf("S3 connection test failed: %w", err)
	}

	log.Println("S3 connection successful")
	log.Println("Server ready - listening for MCP messages...")

	// Main message processing loop
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
			if err := s.processMessage(ctx); err != nil {
				if err == io.EOF {
					log.Println("Client disconnected")
					return nil
				}
				log.Printf("Error processing message: %v", err)
				continue
			}
		}
	}
}

// processMessage reads and processes a single MCP message
func (s *Server) processMessage(ctx context.Context) error {
	line, err := s.reader.ReadString('\n')
	if err != nil {
		return err
	}

	line = strings.TrimSpace(line)
	if line == "" {
		return nil
	}

	var request mcp.RequestMessage
	if err := json.Unmarshal([]byte(line), &request); err != nil {
		return s.sendError(nil, -32700, "Parse error")
	}

	return s.handleRequest(ctx, &request)
}

// handleRequest handles an MCP request
func (s *Server) handleRequest(ctx context.Context, request *mcp.RequestMessage) error {
	switch request.Method {
	case "initialize":
		return s.handleInitialize(request)
	case "initialized":
		return s.handleInitialized(request)
	case "resources/list":
		return s.handleListResources(ctx, request)
	case "resources/read":
		return s.handleReadResource(ctx, request)
	case "tools/list":
		return s.handleListTools(request)
	case "tools/call":
		return s.handleCallTool(ctx, request)
	default:
		return s.sendError(request.ID, -32601, fmt.Sprintf("Method not found: %s", request.Method))
	}
}

// handleInitialize handles the initialize request
func (s *Server) handleInitialize(request *mcp.RequestMessage) error {
	result := &mcp.InitializeResult{
		ProtocolVersion: "2024-11-05",
		Capabilities: mcp.ServerCapabilities{
			Resources: &mcp.ResourceCapabilities{
				Subscribe:   false,
				ListChanged: false,
			},
			Tools: &mcp.ToolCapabilities{
				ListChanged: false,
			},
		},
		ServerInfo: mcp.ServerInfo{
			Name:    "s3-yaml-mcp-server",
			Version: "1.0.0",
		},
	}

	return s.sendResponse(request.ID, result)
}

// handleInitialized handles the initialized notification
func (s *Server) handleInitialized(request *mcp.RequestMessage) error {
	log.Println("Client initialized")
	return nil
}

// handleListResources lists all YAML resources in S3
func (s *Server) handleListResources(ctx context.Context, request *mcp.RequestMessage) error {
	files, err := s.s3Client.ListYAMLFiles(ctx, "")
	if err != nil {
		return s.sendError(request.ID, -32603, fmt.Sprintf("Failed to list YAML files: %v", err))
	}

	var resources []mcp.Resource
	for _, file := range files {
		resources = append(resources, mcp.Resource{
			URI:         fmt.Sprintf("s3://%s/%s", s.config.S3Bucket, file.Key),
			Name:        file.Name,
			Description: fmt.Sprintf("Swagger/OpenAPI YAML documentation (Size: %d bytes, Modified: %s)", file.Size, file.LastModified),
			MimeType:    "application/x-yaml",
		})
	}

	result := &mcp.ListResourcesResult{
		Resources: resources,
	}

	return s.sendResponse(request.ID, result)
}

// handleReadResource reads a specific YAML resource
func (s *Server) handleReadResource(ctx context.Context, request *mcp.RequestMessage) error {
	var params mcp.ReadResourceParams
	if err := s.unmarshalParams(request.Params, &params); err != nil {
		return s.sendError(request.ID, -32602, "Invalid params")
	}

	// Extract S3 key from URI
	key := s.extractS3Key(params.URI)
	if key == "" {
		return s.sendError(request.ID, -32602, "Invalid S3 URI")
	}

	file, err := s.s3Client.GetYAMLFile(ctx, key)
	if err != nil {
		return s.sendError(request.ID, -32603, fmt.Sprintf("Failed to read file: %v", err))
	}

	result := &mcp.ReadResourceResult{
		Contents: []mcp.ResourceContent{
			{
				URI:      params.URI,
				MimeType: "application/x-yaml",
				Text:     file.Content,
			},
		},
	}

	return s.sendResponse(request.ID, result)
}

// handleListTools lists available tools
func (s *Server) handleListTools(request *mcp.RequestMessage) error {
	tools := []mcp.Tool{
		{
			Name:        "search_yaml_files",
			Description: "Search for YAML files by name or content pattern",
			InputSchema: map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"pattern": map[string]interface{}{
						"type":        "string",
						"description": "Search pattern for file names",
					},
				},
				"required": []string{"pattern"},
			},
		},
		{
			Name:        "list_yaml_files",
			Description: "List all YAML files in the S3 bucket with optional prefix filter",
			InputSchema: map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"prefix": map[string]interface{}{
						"type":        "string",
						"description": "Optional prefix to filter files",
					},
				},
			},
		},
		{
			Name:        "get_endpoint_details",
			Description: "Get detailed information about a specific API endpoint including request/response schemas",
			InputSchema: map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"path": map[string]interface{}{
						"type":        "string",
						"description": "API endpoint path (e.g., '/users', '/cards/{id}')",
					},
					"method": map[string]interface{}{
						"type":        "string",
						"description": "HTTP method (optional: GET, POST, PUT, DELETE, PATCH)",
					},
				},
				"required": []string{"path"},
			},
		},
	}

	result := &mcp.ListToolsResult{
		Tools: tools,
	}

	return s.sendResponse(request.ID, result)
}

// handleCallTool handles tool execution
func (s *Server) handleCallTool(ctx context.Context, request *mcp.RequestMessage) error {
	var params mcp.CallToolParams
	if err := s.unmarshalParams(request.Params, &params); err != nil {
		return s.sendError(request.ID, -32602, "Invalid params")
	}

	switch params.Name {
	case "search_yaml_files":
		return s.handleSearchYAMLFiles(ctx, request, params.Arguments)
	case "list_yaml_files":
		return s.handleListYAMLFilesTool(ctx, request, params.Arguments)
	case "get_endpoint_details":
		return s.handleGetEndpointDetails(ctx, request, params.Arguments)
	default:
		return s.sendError(request.ID, -32601, fmt.Sprintf("Unknown tool: %s", params.Name))
	}
}

// handleSearchYAMLFiles handles the search_yaml_files tool
func (s *Server) handleSearchYAMLFiles(ctx context.Context, request *mcp.RequestMessage, args map[string]interface{}) error {
	pattern, ok := args["pattern"].(string)
	if !ok {
		return s.sendError(request.ID, -32602, "Pattern parameter is required and must be a string")
	}

	files, err := s.s3Client.SearchYAMLFiles(ctx, pattern)
	if err != nil {
		return s.sendError(request.ID, -32603, fmt.Sprintf("Search failed: %v", err))
	}

	var resultText strings.Builder
	resultText.WriteString(fmt.Sprintf("Found %d YAML files matching pattern '%s':\n\n", len(files), pattern))

	for _, file := range files {
		resultText.WriteString(fmt.Sprintf("📄 **%s**\n", file.Name))
		resultText.WriteString(fmt.Sprintf("   - S3 Key: %s\n", file.Key))
		resultText.WriteString(fmt.Sprintf("   - Size: %d bytes\n", file.Size))
		resultText.WriteString(fmt.Sprintf("   - Modified: %s\n", file.LastModified))
		resultText.WriteString(fmt.Sprintf("   - URI: s3://%s/%s\n\n", s.config.S3Bucket, file.Key))
	}

	result := &mcp.ToolResult{
		Content: []mcp.ToolContent{
			{
				Type: "text",
				Text: resultText.String(),
			},
		},
	}

	return s.sendResponse(request.ID, result)
}

// handleListYAMLFilesTool handles the list_yaml_files tool
func (s *Server) handleListYAMLFilesTool(ctx context.Context, request *mcp.RequestMessage, args map[string]interface{}) error {
	prefix := ""
	if p, ok := args["prefix"].(string); ok {
		prefix = p
	}

	files, err := s.s3Client.ListYAMLFiles(ctx, prefix)
	if err != nil {
		return s.sendError(request.ID, -32603, fmt.Sprintf("Failed to list files: %v", err))
	}

	var resultText strings.Builder
	if prefix != "" {
		resultText.WriteString(fmt.Sprintf("Found %d YAML files with prefix '%s':\n\n", len(files), prefix))
	} else {
		resultText.WriteString(fmt.Sprintf("Found %d YAML files in bucket:\n\n", len(files)))
	}

	for _, file := range files {
		resultText.WriteString(fmt.Sprintf("📄 **%s**\n", file.Name))
		resultText.WriteString(fmt.Sprintf("   - S3 Key: %s\n", file.Key))
		resultText.WriteString(fmt.Sprintf("   - Size: %d bytes\n", file.Size))
		resultText.WriteString(fmt.Sprintf("   - Modified: %s\n", file.LastModified))
		resultText.WriteString(fmt.Sprintf("   - URI: s3://%s/%s\n\n", s.config.S3Bucket, file.Key))
	}

	result := &mcp.ToolResult{
		Content: []mcp.ToolContent{
			{
				Type: "text",
				Text: resultText.String(),
			},
		},
	}

	return s.sendResponse(request.ID, result)
}

// handleGetEndpointDetails handles the get_endpoint_details tool
func (s *Server) handleGetEndpointDetails(ctx context.Context, request *mcp.RequestMessage, args map[string]interface{}) error {
	path, ok := args["path"].(string)
	if !ok {
		return s.sendError(request.ID, -32602, "Path parameter is required and must be a string")
	}

	method := ""
	if m, ok := args["method"].(string); ok {
		method = strings.ToUpper(m)
	}

	// Get all YAML files
	files, err := s.s3Client.ListYAMLFiles(ctx, "")
	if err != nil {
		return s.sendError(request.ID, -32603, fmt.Sprintf("Failed to list YAML files: %v", err))
	}

	var resultText strings.Builder
	var foundEndpoints []string

	// Search through each YAML file
	for _, file := range files {
		yamlFile, err := s.s3Client.GetYAMLFile(ctx, file.Key)
		if err != nil {
			log.Printf("Failed to read file %s: %v", file.Key, err)
			continue
		}

		endpointInfo := s.searchEndpointInContent(yamlFile.Content, path, method, file.Name)
		if endpointInfo != "" {
			foundEndpoints = append(foundEndpoints, fmt.Sprintf("📄 **Found in %s**:\n%s\n", file.Name, endpointInfo))
		}
	}

	if len(foundEndpoints) == 0 {
		resultText.WriteString(fmt.Sprintf("❌ No endpoints found matching path '%s'", path))
		if method != "" {
			resultText.WriteString(fmt.Sprintf(" with method %s", method))
		}
		resultText.WriteString("\n\nTip: Try searching with a partial path like '/cards' or '/users'")
	} else {
		resultText.WriteString(fmt.Sprintf("🎯 Found %d endpoint(s) matching path '%s'", len(foundEndpoints), path))
		if method != "" {
			resultText.WriteString(fmt.Sprintf(" with method %s", method))
		}
		resultText.WriteString(":\n\n")

		for _, endpoint := range foundEndpoints {
			resultText.WriteString(endpoint)
			resultText.WriteString("\n")
		}
	}

	result := &mcp.ToolResult{
		Content: []mcp.ToolContent{
			{
				Type: "text",
				Text: resultText.String(),
			},
		},
	}

	return s.sendResponse(request.ID, result)
}

// searchEndpointInContent searches for endpoint details in YAML content
func (s *Server) searchEndpointInContent(content, searchPath, method, fileName string) string {
	lines := strings.Split(content, "\n")
	var result strings.Builder
	var currentPath string
	var currentMethod string
	var inPaths bool
	var inEndpoint bool
	var pathMatches bool
	var methodMatches bool
	var indentLevel int
	var endpointDetails []string

	for i, line := range lines {
		trimmed := strings.TrimSpace(line)

		// Detect paths section
		if trimmed == "paths:" {
			inPaths = true
			continue
		}

		if !inPaths {
			continue
		}

		// Calculate indentation
		indent := len(line) - len(strings.TrimLeft(line, " "))

		// Check if we're entering a new path
		if strings.HasSuffix(trimmed, ":") && indent <= 2 && !strings.Contains(trimmed, " ") {
			// Reset state for new path
			if inEndpoint && pathMatches && (method == "" || methodMatches) {
				// Save previous endpoint if it matched
				result.WriteString(s.formatEndpointDetails(currentPath, currentMethod, endpointDetails))
			}

			currentPath = strings.TrimSuffix(trimmed, ":")
			pathMatches = s.pathMatches(currentPath, searchPath)
			inEndpoint = false
			methodMatches = false
			endpointDetails = []string{}
			indentLevel = indent
			continue
		}

		// Check if we're entering a method
		if pathMatches && strings.HasSuffix(trimmed, ":") && indent > indentLevel {
			methodName := strings.TrimSuffix(trimmed, ":")
			if s.isHTTPMethod(methodName) {
				currentMethod = strings.ToUpper(methodName)
				methodMatches = (method == "" || method == currentMethod)
				inEndpoint = true
				endpointDetails = []string{}
				continue
			}
		}

		// Collect endpoint details if we're in a matching endpoint
		if inEndpoint && pathMatches && methodMatches {
			// Look for important fields
			if strings.Contains(trimmed, "summary:") ||
				strings.Contains(trimmed, "description:") ||
				strings.Contains(trimmed, "responses:") ||
				strings.Contains(trimmed, "requestBody:") ||
				strings.Contains(trimmed, "parameters:") ||
				strings.Contains(trimmed, "blocked_reason") ||
				strings.Contains(trimmed, "schema:") ||
				strings.Contains(trimmed, "$ref:") ||
				strings.Contains(trimmed, "type:") ||
				strings.Contains(trimmed, "properties:") ||
				strings.Contains(trimmed, "example:") {
				endpointDetails = append(endpointDetails, line)
			}

			// Also include the next few lines after responses: to capture schema details
			if strings.Contains(trimmed, "responses:") && i+10 < len(lines) {
				for j := i + 1; j < len(lines) && j < i+20; j++ {
					nextLine := lines[j]
					nextTrimmed := strings.TrimSpace(nextLine)
					nextIndent := len(nextLine) - len(strings.TrimLeft(nextLine, " "))

					// Stop if we hit another major section at same or lower indent
					if nextIndent <= indent && (strings.HasSuffix(nextTrimmed, ":") && !strings.Contains(nextTrimmed, " ")) {
						break
					}

					endpointDetails = append(endpointDetails, nextLine)
				}
			}
		}
	}

	// Handle the last endpoint if it matched
	if inEndpoint && pathMatches && (method == "" || methodMatches) {
		result.WriteString(s.formatEndpointDetails(currentPath, currentMethod, endpointDetails))
	}

	return result.String()
}

// pathMatches checks if the search path matches the endpoint path
func (s *Server) pathMatches(endpointPath, searchPath string) bool {
	// Exact match
	if endpointPath == searchPath {
		return true
	}

	// Partial match - endpoint contains search path
	if strings.Contains(endpointPath, searchPath) {
		return true
	}

	// Handle parameter paths like /users/{id} matching /users
	if strings.Contains(endpointPath, "{") {
		basePath := strings.Split(endpointPath, "{")[0]
		basePath = strings.TrimSuffix(basePath, "/")
		if basePath == searchPath || strings.Contains(basePath, searchPath) {
			return true
		}
	}

	return false
}

// isHTTPMethod checks if a string is an HTTP method
func (s *Server) isHTTPMethod(method string) bool {
	httpMethods := []string{"get", "post", "put", "delete", "patch", "head", "options"}
	method = strings.ToLower(method)
	for _, m := range httpMethods {
		if m == method {
			return true
		}
	}
	return false
}

// formatEndpointDetails formats the collected endpoint details
func (s *Server) formatEndpointDetails(path, method string, details []string) string {
	var result strings.Builder

	result.WriteString(fmt.Sprintf("🔍 **%s %s**\n", method, path))

	if len(details) == 0 {
		result.WriteString("   No detailed information found.\n")
		return result.String()
	}

	// Group details by section
	var summary, description, parameters, requestBody, responses []string
	var inResponsesSection bool

	for _, detail := range details {
		trimmed := strings.TrimSpace(detail)

		if strings.Contains(trimmed, "summary:") {
			summary = append(summary, detail)
		} else if strings.Contains(trimmed, "description:") && !inResponsesSection {
			description = append(description, detail)
		} else if strings.Contains(trimmed, "parameters:") {
			parameters = append(parameters, detail)
		} else if strings.Contains(trimmed, "requestBody:") {
			requestBody = append(requestBody, detail)
		} else if strings.Contains(trimmed, "responses:") {
			inResponsesSection = true
			responses = append(responses, detail)
		} else if inResponsesSection {
			responses = append(responses, detail)
		}
	}

	// Format each section
	if len(summary) > 0 {
		result.WriteString("   📝 Summary:\n")
		for _, s := range summary {
			result.WriteString(fmt.Sprintf("   %s\n", s))
		}
	}

	if len(description) > 0 {
		result.WriteString("   📖 Description:\n")
		for _, d := range description {
			result.WriteString(fmt.Sprintf("   %s\n", d))
		}
	}

	if len(parameters) > 0 {
		result.WriteString("   🔧 Parameters:\n")
		for _, p := range parameters {
			result.WriteString(fmt.Sprintf("   %s\n", p))
		}
	}

	if len(requestBody) > 0 {
		result.WriteString("   📤 Request Body:\n")
		for _, r := range requestBody {
			result.WriteString(fmt.Sprintf("   %s\n", r))
		}
	}

	if len(responses) > 0 {
		result.WriteString("   📥 Responses:\n")
		// Highlight lines containing blocked_reason
		for _, r := range responses {
			if strings.Contains(strings.ToLower(r), "blocked_reason") {
				result.WriteString(fmt.Sprintf("   🔴 %s\n", r))
			} else {
				result.WriteString(fmt.Sprintf("   %s\n", r))
			}
		}
	}

	return result.String()
}

// Helper methods

// sendResponse sends a successful response
func (s *Server) sendResponse(id interface{}, result interface{}) error {
	response := mcp.NewResponseMessage(id, result)
	return s.sendMessage(response)
}

// sendError sends an error response
func (s *Server) sendError(id interface{}, code int, message string) error {
	response := mcp.NewErrorResponse(id, code, message)
	return s.sendMessage(response)
}

// sendMessage sends a message to the client
func (s *Server) sendMessage(message interface{}) error {
	data, err := json.Marshal(message)
	if err != nil {
		return err
	}

	_, err = fmt.Fprintf(s.writer, "%s\n", data)
	return err
}

// unmarshalParams unmarshals request parameters
func (s *Server) unmarshalParams(params interface{}, target interface{}) error {
	if params == nil {
		return nil
	}

	data, err := json.Marshal(params)
	if err != nil {
		return err
	}

	return json.Unmarshal(data, target)
}

// extractS3Key extracts the S3 key from an S3 URI
func (s *Server) extractS3Key(uri string) string {
	// Remove s3:// prefix and bucket name
	prefix := fmt.Sprintf("s3://%s/", s.config.S3Bucket)
	if strings.HasPrefix(uri, prefix) {
		return strings.TrimPrefix(uri, prefix)
	}
	return ""
}
