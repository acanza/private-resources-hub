# ------------------------------------------------------------------------------
# Module: backend_api — Outputs
# ------------------------------------------------------------------------------

output "api_id" {
  description = "ID of the API Gateway HTTP API."
  value       = aws_apigatewayv2_api.backend.id
}

output "api_endpoint" {
  description = <<-EOT
    Invoke URL of the API Gateway $default stage.
    Format: https://<api-id>.execute-api.<region>.amazonaws.com
    Pass this to the frontend as the API base URL.
  EOT
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "lambda_function_name" {
  description = "Name of the backend Lambda function."
  value       = aws_lambda_function.backend.function_name
}

output "lambda_function_arn" {
  description = "ARN of the backend Lambda function."
  value       = aws_lambda_function.backend.arn
}
