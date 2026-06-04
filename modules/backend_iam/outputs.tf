# ------------------------------------------------------------------------------
# Module: backend_iam — Outputs
# ------------------------------------------------------------------------------

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role. Passed to the backend_api module as lambda_role_arn."
  value       = aws_iam_role.lambda.arn
}

output "lambda_role_name" {
  description = "Name of the Lambda execution role. Useful for targeted policy attachments outside this module."
  value       = aws_iam_role.lambda.name
}
