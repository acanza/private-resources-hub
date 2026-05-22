# ------------------------------------------------------------------------------
# Module: auth_cognito
#
# Provisions a Cognito User Pool and a public app client (no secret) intended
# for a single-page application authenticating via the Authorization Code flow
# with PKCE.
#
# Optionally creates a Cognito-hosted UI domain for environments that need the
# managed login/signup UI.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# User Pool
# ------------------------------------------------------------------------------

resource "aws_cognito_user_pool" "main" {
  name = local.user_pool_name

  # ------------------------------------------------------------------
  # Alias: users sign in with email, not a generated username.
  # ------------------------------------------------------------------
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  username_configuration {
    # Treat user@example.com and User@EXAMPLE.COM as the same account.
    case_sensitive = false
  }

  # ------------------------------------------------------------------
  # Password policy — strong defaults required by security spec.
  # ------------------------------------------------------------------
  password_policy {
    minimum_length                   = var.password_minimum_length
    require_uppercase                = true
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  # ------------------------------------------------------------------
  # Self sign-up: enabled so users can register without admin action.
  # Set to false for environments that require admin-only provisioning.
  # ------------------------------------------------------------------
  admin_create_user_config {
    allow_admin_create_user_only = var.admin_only_user_creation
  }

  # ------------------------------------------------------------------
  # Account recovery: email only (no phone fallback in MVP).
  # ------------------------------------------------------------------
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # ------------------------------------------------------------------
  # MFA: optional by default (MVP). Set to OPTIONAL or ON in higher
  # environments when MFA adoption is required.
  # ------------------------------------------------------------------
  mfa_configuration = var.mfa_configuration

  # ------------------------------------------------------------------
  # Email verification message (uses the default Cognito sender unless
  # SES is configured separately).
  # ------------------------------------------------------------------
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
  }

  # ------------------------------------------------------------------
  # Schema attributes: only standard attributes used; custom attributes
  # are avoided in MVP to keep the data model simple.
  # ------------------------------------------------------------------
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 3
      max_length = 254
    }
  }

  tags = merge(var.tags, {
    Name = local.user_pool_name
  })
}

# ------------------------------------------------------------------------------
# App Client — public client for SPA (no client secret).
#
# SPAs cannot safely store a client secret, so this client is configured
# without one. PKCE must be enforced in the application code.
#
# Token validity is set explicitly rather than relying on Cognito defaults,
# as required by the security specification.
# ------------------------------------------------------------------------------

resource "aws_cognito_user_pool_client" "app" {
  name         = local.client_name
  user_pool_id = aws_cognito_user_pool.main.id

  # No client secret — public client for browser-based SPA.
  generate_secret = false

  # Allowed auth flows: USER_SRP_AUTH is the secure SRP-based flow.
  # ALLOW_REFRESH_TOKEN_AUTH is required for token refresh.
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  # OAuth 2.0 settings.
  allowed_oauth_flows                  = var.allowed_oauth_flows
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = var.allowed_oauth_scopes
  supported_identity_providers         = ["COGNITO"]

  callback_urls = var.callback_urls
  logout_urls   = var.logout_urls

  # Prevent user-enumeration: Cognito returns a generic error for both
  # "user does not exist" and "wrong password", hiding whether an account
  # is registered. Required by the security specification.
  prevent_user_existence_errors = "ENABLED"

  # Token validity — explicitly configured as required by security spec.
  # Keeping access/id tokens short-lived minimises exposure if intercepted.
  access_token_validity  = var.access_token_validity_hours
  id_token_validity      = var.id_token_validity_hours
  refresh_token_validity = var.refresh_token_validity_days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # Do not read all attributes back to the client unless explicitly needed.
  read_attributes  = ["email", "email_verified"]
  write_attributes = ["email"]
}

# ------------------------------------------------------------------------------
# Hosted UI domain (optional).
#
# Creates a Cognito-managed login/signup UI at:
#   https://<prefix>.auth.<region>.amazoncognito.com
#
# Only created when enable_hosted_ui = true. The domain prefix must be globally
# unique. A suffix variable is provided to allow disambiguation per environment.
# ------------------------------------------------------------------------------

resource "aws_cognito_user_pool_domain" "hosted_ui" {
  count        = var.enable_hosted_ui ? 1 : 0
  domain       = local.hosted_ui_domain_prefix
  user_pool_id = aws_cognito_user_pool.main.id
}
