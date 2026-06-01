# ==============================================================================
# Environment: dev
#
# Composes the reusable modules defined under modules/ for the dev environment.
# Module sources use relative paths so no remote registry is required.
#
# Modules not yet implemented are listed as commented stubs.
# Activate each stub as its module implementation is completed.
# ==============================================================================

# ------------------------------------------------------------------------------
# Module: frontend_delivery
#
# Hosts static frontend assets in a private S3 bucket and delivers them
# through a CloudFront distribution using Origin Access Control (OAC).
# ------------------------------------------------------------------------------

module "frontend_delivery" {
  source = "../../modules/frontend_delivery"

  project_name            = var.project_name
  environment             = var.environment
  price_class             = var.price_class
  frontend_domain_aliases = var.frontend_domain_aliases
  acm_certificate_arn     = var.acm_certificate_arn
  tags                    = var.tags
}

module "auth_cognito" {
  source = "../../modules/auth_cognito"

  project_name = var.project_name
  environment  = var.environment

  callback_urls = var.cognito_callback_urls
  logout_urls   = var.cognito_logout_urls

  allowed_oauth_flows  = var.cognito_allowed_oauth_flows
  allowed_oauth_scopes = var.cognito_allowed_oauth_scopes

  password_minimum_length     = var.cognito_password_minimum_length
  access_token_validity_hours = var.cognito_access_token_validity_hours
  id_token_validity_hours     = var.cognito_id_token_validity_hours
  refresh_token_validity_days = var.cognito_refresh_token_validity_days

  mfa_configuration        = var.cognito_mfa_configuration
  admin_only_user_creation = var.cognito_admin_only_user_creation
  enable_hosted_ui         = var.cognito_enable_hosted_ui
  hosted_ui_domain_suffix  = var.cognito_hosted_ui_domain_suffix

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Module: data_dynamodb
#
# Single-table DynamoDB table for resource metadata and user access records.
# ------------------------------------------------------------------------------

module "data_dynamodb" {
  source = "../../modules/data_dynamodb"

  project_name = var.project_name
  environment  = var.environment
  tags         = var.tags
}

# ------------------------------------------------------------------------------
# Module: private_content_delivery
#
# Private S3 bucket + CloudFront distribution for signed-URL-protected content.
# The public key is registered with CloudFront; the private key lives in
# Secrets Manager (see cloudfront_private_key_secret_arn).
# ------------------------------------------------------------------------------

module "private_content_delivery" {
  source = "../../modules/private_content_delivery"

  project_name              = var.project_name
  environment               = var.environment
  cloudfront_public_key_pem = var.cloudfront_public_key_pem
  price_class               = var.price_class
  tags                      = var.tags
}

# ------------------------------------------------------------------------------
# Module: backend_iam
#
# IAM execution role for the backend Lambda with least-privilege policies
# scoped to DynamoDB, CloudWatch Logs, and the signing key secret.
# ------------------------------------------------------------------------------

module "backend_iam" {
  source = "../../modules/backend_iam"

  project_name            = var.project_name
  environment             = var.environment
  dynamodb_table_arn      = module.data_dynamodb.table_arn
  private_distribution_id = module.private_content_delivery.private_distribution_id
  private_key_secret_arn  = var.cloudfront_private_key_secret_arn
  tags                    = var.tags
}

# ------------------------------------------------------------------------------
# Module: backend_api
#
# Lambda function + API Gateway HTTP API with Cognito JWT authorizer.
# Receives cross-module outputs as inputs to avoid hidden data lookups.
# ------------------------------------------------------------------------------

module "backend_api" {
  source = "../../modules/backend_api"

  project_name = var.project_name
  environment  = var.environment

  lambda_role_arn  = module.backend_iam.lambda_role_arn
  lambda_s3_bucket = var.lambda_s3_bucket
  lambda_s3_key    = var.lambda_s3_key
  lambda_handler   = "src.main.handler"

  cognito_user_pool_issuer_url = module.auth_cognito.user_pool_issuer_url
  cognito_user_pool_client_id  = module.auth_cognito.user_pool_client_id

  cors_allowed_origins = var.cors_allowed_origins

  dynamodb_table_name              = module.data_dynamodb.table_name
  s3_private_bucket_name           = module.private_content_delivery.private_bucket_name
  private_distribution_domain_name = module.private_content_delivery.private_distribution_domain_name
  cloudfront_public_key_id         = module.private_content_delivery.cloudfront_public_key_id

  log_retention_days = var.log_retention_days

  tags = var.tags
}
