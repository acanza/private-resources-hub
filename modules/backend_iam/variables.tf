# ------------------------------------------------------------------------------
# Module: backend_iam — Variables
# ------------------------------------------------------------------------------

variable "project_name" {
  description = "Short name of the project. Used to derive resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment (e.g. dev, stage, prod)."
  type        = string

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "environment must be one of: dev, stage, prod."
  }
}

variable "dynamodb_table_arn" {
  description = <<-EOT
    ARN of the DynamoDB resource access table.
    Used to scope the DynamoDB read policy to this specific table and its indexes.
  EOT
  type        = string

  validation {
    condition     = can(regex("^arn:aws:dynamodb:", var.dynamodb_table_arn))
    error_message = "dynamodb_table_arn must be a valid DynamoDB table ARN."
  }
}

variable "private_key_secret_arn" {
  description = <<-EOT
    ARN of the Secrets Manager secret that stores the RSA private key used to
    generate CloudFront signed URLs and cookies.
    The Lambda execution role will be granted GetSecretValue on this secret only.
  EOT
  type        = string

  validation {
    condition     = can(regex("^arn:aws:secretsmanager:", var.private_key_secret_arn))
    error_message = "private_key_secret_arn must be a valid Secrets Manager secret ARN."
  }
}

variable "private_distribution_id" {
  description = <<-EOT
    ID of the private CloudFront distribution.
    Stored as a tag on the role for traceability. Reserved for a future
    cloudfront:CreateInvalidation policy if cache management is added.
  EOT
  type        = string
}

variable "private_content_bucket_arn" {
  description = <<-EOT
    ARN of the S3 bucket that holds the private hub resources.
    Used to scope the S3 list policy to this specific bucket.
  EOT
  type        = string

  validation {
    condition     = can(regex("^arn:aws:s3:::[a-z0-9.-]+$", var.private_content_bucket_arn))
    error_message = "private_content_bucket_arn must be a valid S3 bucket ARN."
  }
}

variable "tags" {
  description = "Map of tags to apply to all taggable resources in this module."
  type        = map(string)
  default     = {}
}
