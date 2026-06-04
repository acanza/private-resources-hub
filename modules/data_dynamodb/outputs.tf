# ------------------------------------------------------------------------------
# Module: data_dynamodb — Outputs
# ------------------------------------------------------------------------------

output "table_name" {
  description = "Name of the DynamoDB table. Passed to the backend Lambda as an environment variable."
  value       = aws_dynamodb_table.main.name
}

output "table_arn" {
  description = "ARN of the DynamoDB table. Used by backend_iam to scope the read policy."
  value       = aws_dynamodb_table.main.arn
}
