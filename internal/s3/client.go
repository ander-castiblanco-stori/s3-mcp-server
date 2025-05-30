package s3

import (
	"context"
	"fmt"
	"io"
	"path/filepath"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

// Client wraps the AWS S3 client with additional functionality
type Client struct {
	client *s3.Client
	bucket string
}

// YAMLFile represents a YAML file in S3
type YAMLFile struct {
	Key          string
	Name         string
	Size         int64
	LastModified string
	Content      string
}

// New creates a new S3 client
func New(region, bucket, accessKey, secretKey, endpoint string) (*Client, error) {
	var cfg aws.Config
	var err error

	if accessKey != "" && secretKey != "" {
		// Use explicit credentials
		cfg, err = config.LoadDefaultConfig(context.TODO(),
			config.WithRegion(region),
			config.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(accessKey, secretKey, "")),
		)
	} else {
		// Use default credential chain (IAM roles, etc.)
		cfg, err = config.LoadDefaultConfig(context.TODO(),
			config.WithRegion(region),
		)
	}

	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config: %w", err)
	}

	// Create S3 client
	client := s3.NewFromConfig(cfg, func(o *s3.Options) {
		if endpoint != "" {
			o.BaseEndpoint = aws.String(endpoint)
			o.UsePathStyle = true
		}
	})

	return &Client{
		client: client,
		bucket: bucket,
	}, nil
}

// ListYAMLFiles lists all YAML files in the S3 bucket
func (c *Client) ListYAMLFiles(ctx context.Context, prefix string) ([]YAMLFile, error) {
	var files []YAMLFile

	paginator := s3.NewListObjectsV2Paginator(c.client, &s3.ListObjectsV2Input{
		Bucket: aws.String(c.bucket),
		Prefix: aws.String(prefix),
	})

	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx)
		if err != nil {
			return nil, fmt.Errorf("failed to list objects: %w", err)
		}

		for _, obj := range page.Contents {
			key := aws.ToString(obj.Key)

			// Filter for YAML files
			if isYAMLFile(key) {
				files = append(files, YAMLFile{
					Key:          key,
					Name:         extractFileName(key),
					Size:         obj.Size,
					LastModified: obj.LastModified.Format("2006-01-02 15:04:05"),
				})
			}
		}
	}

	return files, nil
}

// GetYAMLFile downloads and returns the content of a YAML file
func (c *Client) GetYAMLFile(ctx context.Context, key string) (*YAMLFile, error) {
	if !isYAMLFile(key) {
		return nil, fmt.Errorf("file %s is not a YAML file", key)
	}

	// Get object metadata
	headResp, err := c.client.HeadObject(ctx, &s3.HeadObjectInput{
		Bucket: aws.String(c.bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to get object metadata: %w", err)
	}

	// Get object content
	resp, err := c.client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(c.bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to get object: %w", err)
	}
	defer resp.Body.Close()

	content, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read object content: %w", err)
	}

	return &YAMLFile{
		Key:          key,
		Name:         extractFileName(key),
		Size:         headResp.ContentLength,
		LastModified: headResp.LastModified.Format("2006-01-02 15:04:05"),
		Content:      string(content),
	}, nil
}

// SearchYAMLFiles searches for YAML files by name pattern
func (c *Client) SearchYAMLFiles(ctx context.Context, pattern string) ([]YAMLFile, error) {
	allFiles, err := c.ListYAMLFiles(ctx, "")
	if err != nil {
		return nil, err
	}

	var matches []YAMLFile
	pattern = strings.ToLower(pattern)

	for _, file := range allFiles {
		if strings.Contains(strings.ToLower(file.Name), pattern) ||
			strings.Contains(strings.ToLower(file.Key), pattern) {
			matches = append(matches, file)
		}
	}

	return matches, nil
}

// TestConnection tests the S3 connection
func (c *Client) TestConnection(ctx context.Context) error {
	_, err := c.client.HeadBucket(ctx, &s3.HeadBucketInput{
		Bucket: aws.String(c.bucket),
	})
	if err != nil {
		return fmt.Errorf("failed to access bucket %s: %w", c.bucket, err)
	}
	return nil
}

// Helper functions

// isYAMLFile checks if a file is a YAML file based on its extension
func isYAMLFile(key string) bool {
	ext := strings.ToLower(filepath.Ext(key))
	return ext == ".yaml" || ext == ".yml"
}

// extractFileName extracts the filename from a full S3 key
func extractFileName(key string) string {
	return filepath.Base(key)
}
