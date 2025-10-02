# =============================================================================
# API GATEWAY CONFIGURATION
# =============================================================================
# This file creates an API Gateway that acts as a managed entry point for
# our microservices. It provides features like authentication, rate limiting,
# request/response transformation, and monitoring.

# -----------------------------------------------------------------------------
# API Gateway REST API
# -----------------------------------------------------------------------------
# Creates the main API Gateway REST API resource
# This serves as the container for all API resources and methods
resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-api"
  description = "API Gateway for ${var.project_name} - Routes requests to EKS services"

  # Configure API Gateway endpoint type
  # REGIONAL: Optimized for clients in the same region, lower latency
  # EDGE: Uses CloudFront for global distribution (higher cost)
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  # Enable binary media types for file uploads
  binary_media_types = [
    "application/octet-stream",
    "image/*",
    "multipart/form-data"
  ]

  tags = {
    Name        = "${var.project_name}-api-gateway"
    Environment = var.environment
    Purpose     = "API routing and management"
  }
}

# -----------------------------------------------------------------------------
# API GATEWAY DOMAIN NAME (Custom Domain)
# -----------------------------------------------------------------------------
# Creates a custom domain name for the API Gateway
# This allows users to access the API via a friendly domain name
resource "aws_api_gateway_domain_name" "main" {
  domain_name              = "api.${var.domain_name}"
  regional_certificate_arn = aws_acm_certificate.api.arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name = "${var.project_name}-api-domain"
  }

  depends_on = [aws_acm_certificate_validation.api]
}

# -----------------------------------------------------------------------------
# ACM Certificate for API Gateway
# -----------------------------------------------------------------------------
# Creates SSL/TLS certificate for the API Gateway custom domain
resource "aws_acm_certificate" "api" {
  domain_name       = "api.${var.domain_name}"
  validation_method = "DNS"

  # Certificate lifecycle management
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-api-cert"
  }
}

# Certificate validation (requires DNS records to be created)
resource "aws_acm_certificate_validation" "api" {
  certificate_arn = aws_acm_certificate.api.arn
  
  # Timeout for certificate validation
  timeouts {
    create = "5m"
  }
}

# -----------------------------------------------------------------------------
# API GATEWAY RESOURCES (URL Paths)
# -----------------------------------------------------------------------------
# Creates API resources that represent different URL paths
# Each resource can have multiple HTTP methods (GET, POST, etc.)

# Health check resource - /health
resource "aws_api_gateway_resource" "health" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "health"
}

# API version 1 resource - /v1
resource "aws_api_gateway_resource" "v1" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "v1"
}

# Users resource under v1 - /v1/users
resource "aws_api_gateway_resource" "users" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "users"
}

# Individual user resource - /v1/users/{id}
resource "aws_api_gateway_resource" "user_id" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.users.id
  path_part   = "{id}"
}

# -----------------------------------------------------------------------------
# API GATEWAY METHODS (HTTP Methods)
# -----------------------------------------------------------------------------
# Defines HTTP methods for each resource (GET, POST, PUT, DELETE)

# Health check - GET /health
resource "aws_api_gateway_method" "health_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.health.id
  http_method   = "GET"
  authorization = "NONE"  # No authentication required for health checks

  # Enable CORS for browser-based applications
  request_parameters = {
    "method.request.header.Content-Type" = false
  }
}

# Get all users - GET /v1/users
resource "aws_api_gateway_method" "users_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.users.id
  http_method   = "GET"
  authorization = "AWS_IAM"  # Requires AWS IAM authentication

  # Request validation
  request_validator_id = aws_api_gateway_request_validator.main.id
}

# Create user - POST /v1/users
resource "aws_api_gateway_method" "users_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.users.id
  http_method   = "POST"
  authorization = "AWS_IAM"

  # Request validation and model
  request_validator_id = aws_api_gateway_request_validator.main.id
  request_models = {
    "application/json" = aws_api_gateway_model.user_create.name
  }
}

# Get specific user - GET /v1/users/{id}
resource "aws_api_gateway_method" "user_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.user_id.id
  http_method   = "GET"
  authorization = "AWS_IAM"

  # Path parameter validation
  request_parameters = {
    "method.request.path.id" = true
  }
}

# -----------------------------------------------------------------------------
# API GATEWAY INTEGRATIONS (Backend Connections)
# -----------------------------------------------------------------------------
# Connects API Gateway methods to backend services (EKS in our case)

# Health check integration - connects to EKS service
resource "aws_api_gateway_integration" "health" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.health.id
  http_method = aws_api_gateway_method.health_get.http_method

  # Integration type: HTTP for direct HTTP calls to EKS services
  type                    = "HTTP"
  integration_http_method = "GET"
  
  # URI points to the internal load balancer (ALB) of EKS
  # This will be updated after EKS deployment
  uri = "http://${aws_lb.main.dns_name}/health"

  # Connection type: VPC_LINK for private network access
  connection_type = "VPC_LINK"
  connection_id   = aws_api_gateway_vpc_link.main.id

  # Request/response transformation
  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }

  # Timeout configuration (max 29 seconds for API Gateway)
  timeout_milliseconds = 29000
}

# Users GET integration
resource "aws_api_gateway_integration" "users_get" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.users.id
  http_method = aws_api_gateway_method.users_get.http_method

  type                    = "HTTP"
  integration_http_method = "GET"
  uri                     = "http://${aws_lb.main.dns_name}/api/users"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.main.id

  # Pass through headers and query parameters
  request_parameters = {
    "integration.request.header.Accept" = "'application/json'"
  }

  timeout_milliseconds = 29000
}

# Users POST integration
resource "aws_api_gateway_integration" "users_post" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.users.id
  http_method = aws_api_gateway_method.users_post.http_method

  type                    = "HTTP"
  integration_http_method = "POST"
  uri                     = "http://${aws_lb.main.dns_name}/api/users"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.main.id

  # Content type mapping
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/json'"
  }

  timeout_milliseconds = 29000
}

# User by ID integration
resource "aws_api_gateway_integration" "user_get" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.user_id.id
  http_method = aws_api_gateway_method.user_get.http_method

  type                    = "HTTP"
  integration_http_method = "GET"
  uri                     = "http://${aws_lb.main.dns_name}/api/users/{id}"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.main.id

  # Path parameter mapping
  request_parameters = {
    "integration.request.path.id" = "method.request.path.id"
  }

  timeout_milliseconds = 29000
}

# -----------------------------------------------------------------------------
# VPC LINK (Private Network Connection)
# -----------------------------------------------------------------------------
# Creates a VPC Link to connect API Gateway to private resources (ALB)
# This allows API Gateway to reach services in private subnets securely
resource "aws_api_gateway_vpc_link" "main" {
  name        = "${var.project_name}-vpc-link"
  description = "VPC Link for API Gateway to connect to internal ALB"
  
  # Target the internal Application Load Balancer
  target_arns = [aws_lb.main.arn]

  tags = {
    Name = "${var.project_name}-vpc-link"
  }
}

# -----------------------------------------------------------------------------
# API GATEWAY MODELS (Request/Response Schemas)
# -----------------------------------------------------------------------------
# Defines data models for request/response validation

# User creation model
resource "aws_api_gateway_model" "user_create" {
  rest_api_id  = aws_api_gateway_rest_api.main.id
  name         = "UserCreate"
  content_type = "application/json"

  # JSON Schema for user creation request
  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "User Create Schema"
    type      = "object"
    properties = {
      name = {
        type        = "string"
        minLength   = 1
        maxLength   = 100
        description = "User's full name"
      }
      email = {
        type        = "string"
        format      = "email"
        description = "User's email address"
      }
      age = {
        type        = "integer"
        minimum     = 0
        maximum     = 150
        description = "User's age"
      }
    }
    required = ["name", "email"]
  })
}

# -----------------------------------------------------------------------------
# REQUEST VALIDATOR
# -----------------------------------------------------------------------------
# Validates incoming requests against defined models and parameters
resource "aws_api_gateway_request_validator" "main" {
  name                        = "${var.project_name}-validator"
  rest_api_id                 = aws_api_gateway_rest_api.main.id
  validate_request_body       = true
  validate_request_parameters = true
}

# -----------------------------------------------------------------------------
# API GATEWAY RESPONSES (Error Handling)
# -----------------------------------------------------------------------------
# Defines standard error responses for better API consistency

# 400 Bad Request response
resource "aws_api_gateway_gateway_response" "bad_request" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  response_type = "BAD_REQUEST_BODY"
  status_code   = "400"

  response_templates = {
    "application/json" = jsonencode({
      error   = "Bad Request"
      message = "$context.error.validationErrorString"
    })
  }

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin" = "'*'"
  }
}

# 429 Too Many Requests response
resource "aws_api_gateway_gateway_response" "throttled" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  response_type = "THROTTLED"
  status_code   = "429"

  response_templates = {
    "application/json" = jsonencode({
      error   = "Too Many Requests"
      message = "Request rate limit exceeded"
    })
  }
}

# -----------------------------------------------------------------------------
# API GATEWAY DEPLOYMENT
# -----------------------------------------------------------------------------
# Deploys the API Gateway configuration to a stage
resource "aws_api_gateway_deployment" "main" {
  depends_on = [
    aws_api_gateway_integration.health,
    aws_api_gateway_integration.users_get,
    aws_api_gateway_integration.users_post,
    aws_api_gateway_integration.user_get,
  ]

  rest_api_id = aws_api_gateway_rest_api.main.id

  # Trigger redeployment when configuration changes
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.health.id,
      aws_api_gateway_resource.v1.id,
      aws_api_gateway_resource.users.id,
      aws_api_gateway_resource.user_id.id,
      aws_api_gateway_method.health_get.id,
      aws_api_gateway_method.users_get.id,
      aws_api_gateway_method.users_post.id,
      aws_api_gateway_method.user_get.id,
      aws_api_gateway_integration.health.id,
      aws_api_gateway_integration.users_get.id,
      aws_api_gateway_integration.users_post.id,
      aws_api_gateway_integration.user_get.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# API GATEWAY STAGE
# -----------------------------------------------------------------------------
# Creates a deployment stage with specific configuration
resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment

  # Enable detailed CloudWatch metrics
  xray_tracing_enabled = true

  # Access logging configuration
  access_log_destination_arn = aws_cloudwatch_log_group.api_gateway.arn
  access_log_format = jsonencode({
    requestId      = "$context.requestId"
    ip             = "$context.identity.sourceIp"
    caller         = "$context.identity.caller"
    user           = "$context.identity.user"
    requestTime    = "$context.requestTime"
    httpMethod     = "$context.httpMethod"
    resourcePath   = "$context.resourcePath"
    status         = "$context.status"
    protocol       = "$context.protocol"
    responseLength = "$context.responseLength"
    responseTime   = "$context.responseTime"
    error          = "$context.error.message"
    errorType      = "$context.error.messageString"
  })

  tags = {
    Name = "${var.project_name}-api-stage"
  }
}

# -----------------------------------------------------------------------------
# USAGE PLAN & API KEYS (Rate Limiting & Authentication)
# -----------------------------------------------------------------------------
# Creates usage plans to control API access and implement rate limiting

# Usage plan for different tiers of access
resource "aws_api_gateway_usage_plan" "main" {
  name         = "${var.project_name}-usage-plan"
  description  = "Usage plan for ${var.project_name} API"

  # API stages this plan applies to
  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }

  # Rate limiting configuration
  throttle_settings {
    rate_limit  = 1000  # Requests per second
    burst_limit = 2000  # Burst capacity
  }

  # Quota configuration
  quota_settings {
    limit  = 10000  # Requests per period
    period = "DAY"  # DAY, WEEK, or MONTH
  }

  tags = {
    Name = "${var.project_name}-usage-plan"
  }
}

# API Key for authentication
resource "aws_api_gateway_api_key" "main" {
  name        = "${var.project_name}-api-key"
  description = "API key for ${var.project_name}"
  enabled     = true

  tags = {
    Name = "${var.project_name}-api-key"
  }
}

# Associate API key with usage plan
resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.main.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.main.id
}

# -----------------------------------------------------------------------------
# CLOUDWATCH LOG GROUP (API Gateway Logs)
# -----------------------------------------------------------------------------
# Creates CloudWatch log group for API Gateway access logs
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-api-gateway-logs"
  }
}

# -----------------------------------------------------------------------------
# BASE PATH MAPPING (Custom Domain Routing)
# -----------------------------------------------------------------------------
# Maps the custom domain to the API Gateway stage
resource "aws_api_gateway_base_path_mapping" "main" {
  api_id      = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  domain_name = aws_api_gateway_domain_name.main.domain_name
}
