# ------------------------------------------------------------------------------
# Module: auth_cognito — Locals
# ------------------------------------------------------------------------------

locals {
  user_pool_name = "${var.project_name}-${var.environment}-user-pool"
  client_name    = "${var.project_name}-${var.environment}-app-client"

  # Cognito hosted UI domain prefix. Must be globally unique across all AWS accounts.
  # Pattern: <project>-<env>-<suffix> — suffix from variable to allow uniqueness tuning.
  hosted_ui_domain_prefix = "${var.project_name}-${var.environment}-${var.hosted_ui_domain_suffix}"

  # Cognito issues JWTs from this URL. The API Gateway JWT authorizer uses it
  # to verify token signatures.
  user_pool_issuer_url = "https://cognito-idp.${data.aws_region.current.region}.amazonaws.com/${aws_cognito_user_pool.main.id}"
}

data "aws_region" "current" {}
