# ------------------------------------------------------------------------------
# Module: backend_iam
#
# Defines the IAM execution role for the backend Lambda function and attaches
# three least-privilege managed policies, one per service concern:
#
#   1. CloudWatch Logs  — write structured logs from the function.
#   2. DynamoDB         — read resource access records and metadata.
#   3. Secrets Manager  — retrieve the RSA private key for CloudFront signing.
#
# Policies are kept separate so each can be reviewed, audited, or replaced
# independently without affecting the others.
#
# The private_distribution_id input is stored as a role tag for traceability.
# A cloudfront:CreateInvalidation policy can be added here in a later iteration
# if cache management becomes a requirement.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# IAM Role — Lambda execution role
# ------------------------------------------------------------------------------

resource "aws_iam_role" "lambda" {
  name               = local.role_name
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = merge(var.tags, {
    Name                  = local.role_name
    PrivateDistributionId = var.private_distribution_id
  })
}

# ------------------------------------------------------------------------------
# Managed Policy 1: CloudWatch Logs
# Grants the Lambda permission to create and write to its own log group.
# Scoped to log groups matching the project/environment prefix only.
# ------------------------------------------------------------------------------

resource "aws_iam_policy" "lambda_logs" {
  name        = local.policy_logs_name
  description = "Allow ${var.project_name}-${var.environment} Lambda to write CloudWatch Logs."
  policy      = data.aws_iam_policy_document.lambda_logs.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda_logs.arn
}

# ------------------------------------------------------------------------------
# Managed Policy 2: DynamoDB read
# Grants GetItem and Query on the resource access table and its indexes.
# Write operations are intentionally excluded — the backend only reads access
# records in the MVP; data is seeded through a separate administrative path.
# ------------------------------------------------------------------------------

resource "aws_iam_policy" "lambda_dynamodb" {
  name        = local.policy_dynamodb_name
  description = "Allow ${var.project_name}-${var.environment} Lambda to read the DynamoDB resource access table."
  policy      = data.aws_iam_policy_document.lambda_dynamodb.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda_dynamodb.arn
}

# ------------------------------------------------------------------------------
# Managed Policy 3: Secrets Manager — signing key
# Grants GetSecretValue on the single secret that holds the RSA private key
# used to generate CloudFront signed URLs and cookies.
# Scoped to the exact secret ARN; no wildcard.
# ------------------------------------------------------------------------------

resource "aws_iam_policy" "lambda_secrets" {
  name        = local.policy_secrets_name
  description = "Allow ${var.project_name}-${var.environment} Lambda to retrieve the CloudFront RSA signing key from Secrets Manager."
  policy      = data.aws_iam_policy_document.lambda_secrets.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_secrets" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda_secrets.arn
}
