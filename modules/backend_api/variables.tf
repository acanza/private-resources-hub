# ------------------------------------------------------------------------------
# Module: backend_api — Variables
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

# ------------------------------------------------------------------------------
# Lambda packaging
# ------------------------------------------------------------------------------

variable "lambda_role_arn" {
  description = "ARN of the IAM execution role for the Lambda function. Provided by the backend_iam module."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:iam::", var.lambda_role_arn))
    error_message = "lambda_role_arn must be a valid IAM role ARN."
  }
}

variable "lambda_s3_bucket" {
  description = <<-EOT
    Name of the S3 bucket that contains the Lambda deployment package (zip).
    The bucket must exist and the package must be uploaded before terraform apply.
  EOT
  type        = string
}

variable "lambda_s3_key" {
  description = "S3 key (path) to the Lambda zip file inside lambda_s3_bucket."
  type        = string
}

variable "lambda_runtime" {
  description = "Lambda runtime identifier."
  type        = string
  default     = "python3.12"
}

variable "lambda_handler" {
  description = "Lambda handler in the format <module>.<function>."
  type        = string
  default     = "main.handler"
}

variable "lambda_memory_size" {
  description = "Memory allocated to the Lambda function in MB."
  type        = number
  default     = 128

  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "lambda_memory_size must be between 128 and 10240 MB."
  }
}

variable "lambda_timeout" {
  description = "Maximum execution time for the Lambda function in seconds."
  type        = number
  default     = 30

  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "lambda_timeout must be between 1 and 900 seconds."
  }
}

# ------------------------------------------------------------------------------
# Cognito / JWT authorizer
# ------------------------------------------------------------------------------

variable "cognito_user_pool_issuer_url" {
  description = <<-EOT
    JWT issuer URL of the Cognito User Pool.
    Used by the API Gateway JWT authorizer to verify token signatures.
    Format: https://cognito-idp.<region>.amazonaws.com/<user_pool_id>
  EOT
  type        = string

  validation {
    condition     = can(regex("^https://cognito-idp\\.", var.cognito_user_pool_issuer_url))
    error_message = "cognito_user_pool_issuer_url must be a Cognito issuer URL starting with https://cognito-idp."
  }
}

variable "cognito_user_pool_client_id" {
  description = "App client ID of the Cognito User Pool. Used as the JWT audience in the authorizer."
  type        = string
}

# ------------------------------------------------------------------------------
# CORS
# ------------------------------------------------------------------------------

variable "cors_allowed_origins" {
  description = <<-EOT
    List of origins allowed to call the API from a browser.
    Should include the CloudFront frontend domain and, for dev, localhost.
    Example: {"prod":["https://d111abcdef.cloudfront.net"], "dev":["http://localhost:3000"]}
    Never set to ["*"] in stage or prod.
  EOT
  type        = map(list(string))

  validation {
    condition     = length(var.cors_allowed_origins) > 0
    error_message = "At least one CORS allowed origin must be provided."
  }
}

# ------------------------------------------------------------------------------
# Backend runtime configuration (passed as Lambda environment variables)
# ------------------------------------------------------------------------------

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB resource access table. Injected into Lambda as DYNAMODB_TABLE_NAME."
  type        = string
}

variable "s3_private_bucket_name" {
  description = <<-EOT
    Name of the S3 bucket that holds the private hub resources.
    Injected into Lambda as S3_BUCKET_NAME so it can read and serve private content.
  EOT
  type        = string
}

variable "private_distribution_domain_name" {
  description = <<-EOT
    Domain name of the private CloudFront distribution.
    Injected into Lambda as PRIVATE_DISTRIBUTION_DOMAIN_NAME so it can construct
    the base URL for signed URLs and cookies.
  EOT
  type        = string
}

variable "cloudfront_public_key_id" {
  description = <<-EOT
    ID of the CloudFront public key registered for signed URL / cookie verification.
    Injected into Lambda as CLOUDFRONT_KEY_PAIR_ID so it can include the correct
    key identifier when generating signed tokens.
  EOT
  type        = string
}

variable "cloudfront_secret_name" {
  description = <<-EOT
    Name of the Secrets Manager secret that stores the RSA private key used to
    sign CloudFront cookies. Injected into Lambda as CLOUDFRONT_SECRET_NAME so
    it can retrieve the key at runtime and generate signed tokens.
    Example: prh/dev/cloudfront-private-key
  EOT
  type        = string

  validation {
    condition     = length(var.cloudfront_secret_name) > 0
    error_message = "cloudfront_secret_name must not be empty."
  }
}

# ------------------------------------------------------------------------------
# Observability
# ------------------------------------------------------------------------------

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days for Lambda and API Gateway log groups."
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a value accepted by CloudWatch Logs (e.g. 1, 3, 5, 7, 14, 30, 60, 90, 365)."
  }
}

variable "tags" {
  description = "Map of tags to apply to all taggable resources in this module."
  type        = map(string)
  default     = {}
}
