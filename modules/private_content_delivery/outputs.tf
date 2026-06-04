# ------------------------------------------------------------------------------
# Module: private_content_delivery — Outputs
# ------------------------------------------------------------------------------

output "private_bucket_name" {
  description = "Name of the S3 bucket that stores the private content files."
  value       = aws_s3_bucket.private_content.id
}

output "private_bucket_arn" {
  description = "ARN of the private content S3 bucket. Used in IAM policies if direct upload access is needed."
  value       = aws_s3_bucket.private_content.arn
}

output "private_distribution_id" {
  description = "ID of the CloudFront distribution serving private content. Passed to backend_iam for IAM scoping."
  value       = aws_cloudfront_distribution.private_content.id
}

output "private_distribution_domain_name" {
  description = <<-EOT
    Domain name of the private CloudFront distribution (e.g. d111111abcdef8.cloudfront.net).
    Passed to the backend Lambda so it can construct signed URL base paths.
  EOT
  value       = aws_cloudfront_distribution.private_content.domain_name
}

output "private_distribution_arn" {
  description = "ARN of the private CloudFront distribution."
  value       = aws_cloudfront_distribution.private_content.arn
}

output "cloudfront_key_group_id" {
  description = "ID of the CloudFront key group used to validate signed URLs and cookies."
  value       = aws_cloudfront_key_group.private_content.id
}

output "cloudfront_public_key_id" {
  description = <<-EOT
    ID of the CloudFront public key registered for signed URL / signed cookie verification.
    The backend Lambda uses this ID when constructing signed URL parameters.
  EOT
  value       = aws_cloudfront_public_key.private_content.id
}
