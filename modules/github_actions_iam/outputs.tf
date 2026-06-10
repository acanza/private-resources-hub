# ==============================================================================
# Module: github_actions_iam — Outputs
#
# Role ARN and OIDC configuration for GitHub Actions CI/CD setup.
# ==============================================================================

output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions. Use in GitHub Actions workflow: jobs.deploy.permissions.id-token: write"
  value       = aws_iam_role.github_actions.arn
}

output "github_actions_role_name" {
  description = "Name of the IAM role for GitHub Actions."
  value       = aws_iam_role.github_actions.name
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC Identity Provider."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "policy_document_size" {
  description = "Approximate size of the inline policy (informational, for monitoring policy size limits)."
  value       = length(jsonencode(data.aws_iam_policy_document.permissions_policy.json))
}
