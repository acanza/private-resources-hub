# ------------------------------------------------------------------------------
# Module: backend_api — Locals
# ------------------------------------------------------------------------------

locals {
  function_name    = "${var.project_name}-${var.environment}-backend"
  lambda_log_group = "/aws/lambda/${local.function_name}"
  api_gw_log_group = "/aws/apigateway/${var.project_name}-${var.environment}-backend-api"
  api_name         = "${var.project_name}-${var.environment}-backend-api"
  authorizer_name  = "${var.project_name}-${var.environment}-cognito-jwt-authorizer"
  integration_name = "${var.project_name}-${var.environment}-lambda-integration"
}
