# ------------------------------------------------------------------------------
# Module: auth_cognito — Variables
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
# OAuth / App Client
# ------------------------------------------------------------------------------

variable "callback_urls" {
  description = <<-EOT
    List of allowed redirect (callback) URLs after a successful login.
    Must include at least one URL. For dev, typically http://localhost:3000/callback.
    For production, must be HTTPS only.
  EOT
  type        = list(string)

  validation {
    condition     = length(var.callback_urls) > 0
    error_message = "At least one callback URL must be provided."
  }
}

variable "logout_urls" {
  description = <<-EOT
    List of allowed URLs Cognito will redirect to after logout.
    Must include at least one URL. Should match the callback URL origins.
  EOT
  type        = list(string)

  validation {
    condition     = length(var.logout_urls) > 0
    error_message = "At least one logout URL must be provided."
  }
}

variable "allowed_oauth_flows" {
  description = <<-EOT
    OAuth 2.0 grant types enabled for the app client.
    Recommended: ["code"] (Authorization Code with PKCE, safe for SPAs).
    "implicit" is deprecated and must not be used in new applications.
  EOT
  type        = list(string)
  default     = ["code"]

  validation {
    condition     = !contains(var.allowed_oauth_flows, "implicit")
    error_message = "The implicit OAuth flow is deprecated and must not be used."
  }
}

variable "allowed_oauth_scopes" {
  description = <<-EOT
    OAuth 2.0 scopes the app client may request.
    email and openid are required for the frontend to read user identity.
    profile is optional; include only if the frontend needs display name, etc.
  EOT
  type        = list(string)
  default     = ["openid", "email"]
}

# ------------------------------------------------------------------------------
# Password policy
# ------------------------------------------------------------------------------

variable "password_minimum_length" {
  description = "Minimum number of characters required in a user password."
  type        = number
  default     = 12

  validation {
    condition     = var.password_minimum_length >= 8
    error_message = "password_minimum_length must be at least 8 (Cognito minimum)."
  }
}

# ------------------------------------------------------------------------------
# Token validity
# ------------------------------------------------------------------------------

variable "access_token_validity_hours" {
  description = <<-EOT
    Lifetime of the Cognito access token in hours.
    Keep short to limit exposure. Default: 1 hour.
    Valid range: 5 minutes to 24 hours (set units in token_validity_units).
  EOT
  type        = number
  default     = 1

  validation {
    condition     = var.access_token_validity_hours >= 1 && var.access_token_validity_hours <= 24
    error_message = "access_token_validity_hours must be between 1 and 24."
  }
}

variable "id_token_validity_hours" {
  description = <<-EOT
    Lifetime of the Cognito ID token in hours.
    Should match access_token_validity_hours in most cases.
    Default: 1 hour.
  EOT
  type        = number
  default     = 1

  validation {
    condition     = var.id_token_validity_hours >= 1 && var.id_token_validity_hours <= 24
    error_message = "id_token_validity_hours must be between 1 and 24."
  }
}

variable "refresh_token_validity_days" {
  description = <<-EOT
    Lifetime of the Cognito refresh token in days.
    Controls how long users stay logged in without re-authenticating.
    Default: 30 days. Reduce for higher-security environments.
  EOT
  type        = number
  default     = 30

  validation {
    condition     = var.refresh_token_validity_days >= 1 && var.refresh_token_validity_days <= 3650
    error_message = "refresh_token_validity_days must be between 1 and 3650."
  }
}

# ------------------------------------------------------------------------------
# Operational settings
# ------------------------------------------------------------------------------

variable "mfa_configuration" {
  description = <<-EOT
    MFA enforcement level for the user pool.
    - OFF: MFA disabled (suitable for dev/MVP).
    - OPTIONAL: users may enrol but it is not required.
    - ON: all users must configure MFA (recommended for prod).
  EOT
  type    = string
  default = "OFF"

  validation {
    condition     = contains(["OFF", "OPTIONAL", "ON"], var.mfa_configuration)
    error_message = "mfa_configuration must be one of: OFF, OPTIONAL, ON."
  }
}

variable "admin_only_user_creation" {
  description = <<-EOT
    When true, only administrators can create user accounts (self sign-up is disabled).
    Set to false (default) to allow open registration in dev and stage.
    Consider setting to true in prod if access is invite-only.
  EOT
  type    = bool
  default = false
}

variable "enable_hosted_ui" {
  description = <<-EOT
    When true, creates a Cognito-hosted UI domain at:
      https://<prefix>.auth.<region>.amazoncognito.com
    Requires hosted_ui_domain_suffix to be unique across all AWS accounts.
  EOT
  type    = bool
  default = false
}

variable "hosted_ui_domain_suffix" {
  description = <<-EOT
    Short suffix appended to the hosted UI domain prefix to ensure global uniqueness.
    The resulting prefix will be: <project_name>-<environment>-<suffix>
    Example suffix: "a1b2" produces "private-resources-hub-dev-a1b2.auth...".
    Required when enable_hosted_ui = true; ignored otherwise.
  EOT
  type    = string
  default = ""
}

variable "tags" {
  description = "Map of tags to apply to all resources in this module."
  type        = map(string)
  default     = {}
}
