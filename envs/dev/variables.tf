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
