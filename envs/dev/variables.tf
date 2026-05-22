# ------------------------------------------------------------------------------
# Environment: dev — Variables
# ------------------------------------------------------------------------------

variable "project_name" {
  description = "Short name of the project. Used to derive resource names and tags."
  type        = string
  default     = "private-resources-hub"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment. This folder is scoped to dev only."
  type        = string
  default     = "dev"

  validation {
    condition     = var.environment == "dev"
    error_message = "This environment folder is for dev only. Use stage/ or prod/ for other environments."
  }
}

variable "aws_region" {
  description = "AWS region where resources are deployed."
  type        = string
  default     = "us-east-1"
}

variable "price_class" {
  description = <<-EOT
    CloudFront price class for the frontend distribution.
    PriceClass_100 (US, Canada, Europe) is the default for dev to minimize cost.
    Options: PriceClass_100, PriceClass_200, PriceClass_All.
  EOT
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be one of: PriceClass_100, PriceClass_200, PriceClass_All."
  }
}

variable "frontend_domain_aliases" {
  description = <<-EOT
    Optional custom domain aliases (CNAMEs) for the CloudFront frontend distribution.
    Leave empty in dev to use the default *.cloudfront.net domain.
    When set, acm_certificate_arn must also be provided.
  EOT
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = <<-EOT
    ARN of an ACM certificate in us-east-1 for HTTPS on custom domain aliases.
    Required only when frontend_domain_aliases is non-empty.
    Must be in us-east-1 (CloudFront requirement).
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.acm_certificate_arn == null || can(regex("^arn:aws:acm:us-east-1:", var.acm_certificate_arn))
    error_message = "acm_certificate_arn must be an ACM certificate ARN in us-east-1."
  }
}

variable "tags" {
  description = <<-EOT
    Additional tags merged into all resources.
    Project, Environment, and ManagedBy are set automatically via provider default_tags.
  EOT
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# auth_cognito inputs
# ------------------------------------------------------------------------------

variable "cognito_callback_urls" {
  description = "Allowed redirect URLs after Cognito login. In dev, localhost is acceptable."
  type        = list(string)
  default     = ["http://localhost:3000/callback"]
}

variable "cognito_logout_urls" {
  description = "Allowed redirect URLs after Cognito logout."
  type        = list(string)
  default     = ["http://localhost:3000"]
}

variable "cognito_allowed_oauth_flows" {
  description = "OAuth 2.0 grant types for the app client. Default: Authorization Code only."
  type        = list(string)
  default     = ["code"]
}

variable "cognito_allowed_oauth_scopes" {
  description = "OAuth scopes the app client may request."
  type        = list(string)
  default     = ["openid", "email"]
}

variable "cognito_password_minimum_length" {
  description = "Minimum password length for user accounts."
  type        = number
  default     = 12
}

variable "cognito_access_token_validity_hours" {
  description = "Access token lifetime in hours."
  type        = number
  default     = 1
}

variable "cognito_id_token_validity_hours" {
  description = "ID token lifetime in hours."
  type        = number
  default     = 1
}

variable "cognito_refresh_token_validity_days" {
  description = "Refresh token lifetime in days."
  type        = number
  default     = 30
}

variable "cognito_mfa_configuration" {
  description = "MFA enforcement level: OFF, OPTIONAL, or ON."
  type        = string
  default     = "OFF"
}

variable "cognito_admin_only_user_creation" {
  description = "When true, self sign-up is disabled. Default false for dev."
  type        = bool
  default     = false
}

variable "cognito_enable_hosted_ui" {
  description = "When true, provisions a Cognito-managed hosted login UI domain."
  type        = bool
  default     = false
}

variable "cognito_hosted_ui_domain_suffix" {
  description = "Short unique suffix for the hosted UI domain prefix. Required when cognito_enable_hosted_ui = true."
  type        = string
  default     = ""
}

# ------------------------------------------------------------------------------
# backend_iam inputs
# ------------------------------------------------------------------------------

variable "cloudfront_private_key_secret_arn" {
  description = <<-EOT
    ARN of the Secrets Manager secret that stores the RSA private key used by
    the backend Lambda to generate CloudFront signed URLs and cookies.
    Created manually before terraform apply — never stored in source control.
  EOT
  type        = string

  validation {
    condition     = can(regex("^arn:aws:secretsmanager:", var.cloudfront_private_key_secret_arn))
    error_message = "cloudfront_private_key_secret_arn must be a valid Secrets Manager secret ARN."
  }
}
