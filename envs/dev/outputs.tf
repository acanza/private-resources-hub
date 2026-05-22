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
