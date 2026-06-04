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

# data_dynamodb outputs

output "dynamodb_table_name" {
  description = "Name of the DynamoDB resource access table."
  value       = module.data_dynamodb.table_name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB resource access table."
  value       = module.data_dynamodb.table_arn
}

# private_content_delivery outputs

output "private_bucket_name" {
  description = "Name of the S3 bucket storing private content. Used to upload test fixtures."
  value       = module.private_content_delivery.private_bucket_name
}

output "private_distribution_domain_name" {
  description = "Domain name of the private CloudFront distribution. Used to construct signed URL base paths."
  value       = module.private_content_delivery.private_distribution_domain_name
}

output "cloudfront_public_key_id" {
  description = "ID of the CloudFront public key. The Lambda uses this as CLOUDFRONT_KEY_PAIR_ID when signing URLs."
  value       = module.private_content_delivery.cloudfront_public_key_id
}

# backend_api outputs

output "api_endpoint" {
  description = "API Gateway invoke URL. Pass this to the frontend as the API base URL."
  value       = module.backend_api.api_endpoint
}

output "lambda_function_name" {
  description = "Name of the backend Lambda function."
  value       = module.backend_api.lambda_function_name
}
