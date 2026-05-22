# ------------------------------------------------------------------------------
# Module: auth_cognito — Outputs
# ------------------------------------------------------------------------------

output "user_pool_id" {
  description = "ID of the Cognito User Pool. Used by the API Gateway JWT authorizer."
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "ARN of the Cognito User Pool."
  value       = aws_cognito_user_pool.main.arn
}

output "user_pool_client_id" {
  description = "ID of the app client. Passed to the frontend as a non-secret configuration value."
  value       = aws_cognito_user_pool_client.app.id
}

output "user_pool_issuer_url" {
  description = <<-EOT
    JWT issuer URL for this User Pool. Used by the API Gateway JWT authorizer
    to verify token signatures.
    Format: https://cognito-idp.<region>.amazonaws.com/<user_pool_id>
  EOT
  value = local.user_pool_issuer_url
}

output "hosted_ui_domain" {
  description = <<-EOT
    Full Cognito hosted UI domain (e.g. https://<prefix>.auth.<region>.amazoncognito.com).
    Empty string when enable_hosted_ui = false.
  EOT
  value = var.enable_hosted_ui ? "https://${aws_cognito_user_pool_domain.hosted_ui[0].domain}.auth.${data.aws_region.current.name}.amazoncognito.com" : ""
}
