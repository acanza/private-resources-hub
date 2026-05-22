# ------------------------------------------------------------------------------
# Module: frontend_delivery — Outputs
# ------------------------------------------------------------------------------

output "frontend_bucket_name" {
  description = "Name of the S3 bucket that stores the frontend assets."
  value       = aws_s3_bucket.frontend.id
}

output "frontend_bucket_arn" {
  description = "ARN of the frontend S3 bucket. Required to grant access in IAM policies."
  value       = aws_s3_bucket.frontend.arn
}

output "frontend_distribution_id" {
  description = "ID of the CloudFront distribution serving the frontend. Used for cache invalidations."
  value       = aws_cloudfront_distribution.frontend.id
}

output "frontend_distribution_domain_name" {
  description = "Domain name of the CloudFront distribution (e.g. d111111abcdef8.cloudfront.net)."
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "frontend_distribution_arn" {
  description = "ARN of the CloudFront distribution."
  value       = aws_cloudfront_distribution.frontend.arn
}
