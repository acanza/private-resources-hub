# ------------------------------------------------------------------------------
# Module: frontend_delivery — Variables
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

variable "frontend_domain_aliases" {
  description = <<-EOT
    Optional list of custom domain names (CNAMEs) for the CloudFront distribution.
    When provided, acm_certificate_arn must also be set.
    Leave empty to use the default *.cloudfront.net domain.
  EOT
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = <<-EOT
    ARN of an ACM certificate in us-east-1 to use for HTTPS on custom domain aliases.
    Required when frontend_domain_aliases is non-empty.
    Ignored when no aliases are configured.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.acm_certificate_arn == null || can(regex("^arn:aws:acm:us-east-1:", var.acm_certificate_arn))
    error_message = "acm_certificate_arn must be an ACM certificate ARN in us-east-1 (required by CloudFront)."
  }
}

variable "price_class" {
  description = <<-EOT
    CloudFront price class. Controls which edge locations serve the distribution.
    - PriceClass_100: US, Canada, Europe (lowest cost).
    - PriceClass_200: + Asia Pacific, Middle East, Africa.
    - PriceClass_All: all edge locations (highest availability, highest cost).
  EOT
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be one of: PriceClass_100, PriceClass_200, PriceClass_All."
  }
}

variable "tags" {
  description = "Map of tags to apply to all resources in this module."
  type        = map(string)
  default     = {}
}
