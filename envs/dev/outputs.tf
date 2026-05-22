# ------------------------------------------------------------------------------
# Environment: dev — Outputs
# ------------------------------------------------------------------------------

# frontend_delivery outputs

output "frontend_bucket_name" {
  description = "Name of the S3 bucket storing frontend assets."
  value       = module.frontend_delivery.frontend_bucket_name
}

output "frontend_distribution_id" {
  description = "ID of the CloudFront distribution serving the frontend. Use this for cache invalidations."
  value       = module.frontend_delivery.frontend_distribution_id
}

output "frontend_distribution_domain_name" {
  description = "CloudFront domain name for the frontend (e.g. d111111abcdef8.cloudfront.net). This is the dev access URL."
  value       = module.frontend_delivery.frontend_distribution_domain_name
}

# auth_cognito outputs

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID. Needed by the API Gateway JWT authorizer."
  value       = module.auth_cognito.user_pool_id
}

output "cognito_user_pool_client_id" {
  description = "Cognito app client ID. Safe to expose to the frontend as a configuration value."
  value       = module.auth_cognito.user_pool_client_id
}

output "cognito_user_pool_issuer_url" {
  description = "JWT issuer URL. Used by API Gateway to verify Cognito tokens."
  value       = module.auth_cognito.user_pool_issuer_url
}
