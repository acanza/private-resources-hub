# ------------------------------------------------------------------------------
# Module: backend_api
#
# Deploys the backend Lambda function and exposes it through an API Gateway
# HTTP API (v2). All routes are protected by a JWT authorizer backed by
# the Cognito User Pool provisioned in the auth_cognito module.
#
# Resource order in this file follows the dependency chain:
#   Log groups → Lambda → API → Authorizer → Integration → Route → Stage → Permission
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# CloudWatch Log Groups
#
# Both log groups are created explicitly so that retention is enforced from the
# first invocation. Without this, Lambda and API Gateway would auto-create
# log groups with no retention policy (logs kept indefinitely).
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "lambda" {
  name              = local.lambda_log_group
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = local.api_gw_log_group
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Lambda Function
#
# Deployment package is loaded from S3. The bucket and key must exist before
# terraform apply — uploading the artifact is handled outside Terraform (CI/CD
# or manual upload). Environment variables are the only runtime configuration
# the Lambda needs to connect to downstream services.
# ------------------------------------------------------------------------------

resource "aws_lambda_function" "backend" {
  function_name = local.function_name
  role          = var.lambda_role_arn

  s3_bucket = var.lambda_s3_bucket
  s3_key    = var.lambda_s3_key

  runtime = var.lambda_runtime
  handler = var.lambda_handler

  memory_size = var.lambda_memory_size
  timeout     = var.lambda_timeout

  # Runtime configuration injected as environment variables.
  # The Lambda reads these at startup — no hardcoded values in function code.
  environment {
    variables = {
      DYNAMODB_TABLE_NAME              = var.dynamodb_table_name
      PRIVATE_DISTRIBUTION_DOMAIN_NAME = var.private_distribution_domain_name
      CLOUDFRONT_KEY_PAIR_ID           = var.cloudfront_public_key_id
    }
  }

  # The log group must exist before the function is created, otherwise Lambda
  # will auto-create it without retention settings.
  depends_on = [aws_cloudwatch_log_group.lambda]

  tags = merge(var.tags, {
    Name = local.function_name
  })
}

# ------------------------------------------------------------------------------
# API Gateway HTTP API
#
# Protocol type HTTP (v2) is used instead of REST (v1): lower latency, simpler
# JWT integration, and native CORS support — well-suited for MVP SPA backends.
#
# CORS is configured at the API level and applied to all routes automatically.
# Allowed origins must be explicitly provided; no wildcard in stage/prod.
# ------------------------------------------------------------------------------

resource "aws_apigatewayv2_api" "backend" {
  name          = local.api_name
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = var.cors_allowed_origins
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Authorization", "Content-Type"]
    max_age       = 300
  }

  tags = merge(var.tags, {
    Name = local.api_name
  })
}

# ------------------------------------------------------------------------------
# JWT Authorizer
#
# Validates the Bearer token in the Authorization header against the Cognito
# User Pool issuer. API Gateway verifies the token signature, expiry, and
# audience before forwarding the request to the Lambda integration.
#
# Requests without a valid token receive a 401 Unauthorized response and
# never reach the Lambda function.
# ------------------------------------------------------------------------------

resource "aws_apigatewayv2_authorizer" "jwt" {
  api_id           = aws_apigatewayv2_api.backend.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = local.authorizer_name

  jwt_configuration {
    # audience: the app client ID that must appear in the token's aud claim.
    audience = [var.cognito_user_pool_client_id]
    # issuer: the Cognito User Pool URL used to fetch the public JWKS for verification.
    issuer = var.cognito_user_pool_issuer_url
  }
}

# ------------------------------------------------------------------------------
# Lambda Integration
#
# AWS_PROXY (Lambda proxy) passes the full HTTP request to the Lambda and lets
# the function construct the full HTTP response. Payload format version 2.0
# uses the simplified event/response structure for HTTP APIs.
# ------------------------------------------------------------------------------

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.backend.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.backend.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# ------------------------------------------------------------------------------
# Default Route — catch-all with JWT enforcement
#
# The $default route key matches every method and path not covered by a more
# specific route. Using $default with a JWT authorizer means all requests to
# this API require a valid Cognito token, satisfying the security requirement
# that every route be protected.
#
# The Lambda function handles method and path routing internally.
# ------------------------------------------------------------------------------

resource "aws_apigatewayv2_route" "default" {
  api_id             = aws_apigatewayv2_api.backend.id
  route_key          = "$default"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
  target             = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# ------------------------------------------------------------------------------
# Stage — $default with auto-deploy and access logging
#
# The $default stage is the standard single-stage deployment model for HTTP
# APIs. auto_deploy = true means every route/integration change is deployed
# immediately without a separate deployment resource.
#
# Access logs are written to a dedicated CloudWatch log group, separate from
# the Lambda execution logs, for easier operational filtering.
# ------------------------------------------------------------------------------

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.backend.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
  }

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Lambda Permission — allow API Gateway to invoke the function
#
# Without this permission, API Gateway receives a 403 from the Lambda service
# when it attempts to invoke the function. The source_arn is scoped to this
# specific API to prevent cross-API invocation.
# ------------------------------------------------------------------------------

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backend.function_name
  principal     = "apigateway.amazonaws.com"

  # Restrict to this API only. The wildcard on method and path allows the $default
  # route to invoke the function regardless of the HTTP method or path used.
  source_arn = "${aws_apigatewayv2_api.backend.execution_arn}/*/*"
}
