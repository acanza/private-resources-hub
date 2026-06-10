# ==============================================================================
# Module: github_actions_iam — Variables
#
# Inputs required to create the GitHub Actions OIDC Identity Provider,
# IAM role, and least-privilege policies.
# ==============================================================================

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

variable "github_repository_owner" {
  description = "GitHub account owner (username or organization) for OIDC token trust policy."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]*$", var.github_repository_owner))
    error_message = "github_repository_owner must be a valid GitHub username or org name."
  }
}

variable "github_repository_name" {
  description = "GitHub repository name for OIDC token trust policy."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]+$", var.github_repository_name))
    error_message = "github_repository_name must be a valid GitHub repository name."
  }
}

variable "github_repository_branch" {
  description = "GitHub branch name to limit OIDC token trust (e.g. main). Empty string means all branches."
  type        = string
  default     = "main"

  validation {
    condition     = var.github_repository_branch == "" || can(regex("^[a-zA-Z0-9/_.-]+$", var.github_repository_branch))
    error_message = "github_repository_branch must be a valid branch name or empty string."
  }
}

variable "frontend_bucket_arn" {
  description = "ARN of the S3 bucket that stores frontend assets (used for object operations)."
  type        = string
}

variable "frontend_distribution_id" {
  description = "ID of the CloudFront distribution serving the frontend (used for cache invalidation)."
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
  default     = {}
}
