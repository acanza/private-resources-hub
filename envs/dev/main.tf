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

# ------------------------------------------------------------------------------
# Modules below are not yet implemented.
# Uncomment each block as the corresponding module under modules/ is built.
# ------------------------------------------------------------------------------

# module "auth_cognito" {
#   source       = "../../modules/auth_cognito"
#   project_name = var.project_name
#   environment  = var.environment
#   tags         = var.tags
# }

# module "data_dynamodb" {
#   source       = "../../modules/data_dynamodb"
#   project_name = var.project_name
#   environment  = var.environment
#   tags         = var.tags
# }

# module "private_content_delivery" {
#   source       = "../../modules/private_content_delivery"
#   project_name = var.project_name
#   environment  = var.environment
#   tags         = var.tags
# }

# module "backend_iam" {
#   source                  = "../../modules/backend_iam"
#   project_name            = var.project_name
#   environment             = var.environment
#   dynamodb_table_arn      = module.data_dynamodb.table_arn
#   private_distribution_id = module.private_content_delivery.private_distribution_id
#   tags                    = var.tags
# }

# module "backend_api" {
#   source                           = "../../modules/backend_api"
#   project_name                     = var.project_name
#   environment                      = var.environment
#   lambda_role_arn                  = module.backend_iam.lambda_role_arn
#   cognito_user_pool_issuer_url     = module.auth_cognito.user_pool_issuer_url
#   cognito_user_pool_client_id      = module.auth_cognito.user_pool_client_id
#   dynamodb_table_name              = module.data_dynamodb.table_name
#   private_distribution_domain_name = module.private_content_delivery.private_distribution_domain_name
#   tags                             = var.tags
# }
