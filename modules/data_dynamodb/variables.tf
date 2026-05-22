# ------------------------------------------------------------------------------
# Module: data_dynamodb — Variables
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

variable "billing_mode" {
  description = <<-EOT
    DynamoDB billing mode. PAY_PER_REQUEST is the default for MVP (no capacity planning needed).
    Use PROVISIONED only when read/write patterns are predictable and cost optimisation is required.
  EOT
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "billing_mode must be PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "tags" {
  description = "Map of tags to apply to all taggable resources in this module."
  type        = map(string)
  default     = {}
}
