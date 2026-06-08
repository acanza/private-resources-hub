# ------------------------------------------------------------------------------
# Module: backend_iam — Locals and Data Sources
# ------------------------------------------------------------------------------

locals {
  role_name            = "${var.project_name}-${var.environment}-lambda-role"
  policy_logs_name     = "${var.project_name}-${var.environment}-lambda-logs-policy"
  policy_dynamodb_name = "${var.project_name}-${var.environment}-lambda-dynamodb-policy"
  policy_secrets_name  = "${var.project_name}-${var.environment}-lambda-secrets-policy"
  policy_s3_list_name  = "${var.project_name}-${var.environment}-lambda-s3-list-policy"

  # CloudWatch log group prefix for this environment's Lambda functions.
  # Scoping the logs policy to this prefix avoids granting write access to
  # log groups belonging to unrelated functions.
  log_group_prefix = "/aws/lambda/${var.project_name}-${var.environment}-"
}

# ------------------------------------------------------------------------------
# Trust policy: allow the Lambda service to assume this role.
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    sid     = "AllowLambdaAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ------------------------------------------------------------------------------
# Policy documents — one per service concern (logs, DynamoDB, Secrets Manager).
# Keeping them separate makes each policy auditable and stays well within the
# 6 144-character managed policy size limit.
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "lambda_logs" {
  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    # Scoped to the project/environment log group prefix only.
    resources = [
      "arn:aws:logs:*:*:log-group:${local.log_group_prefix}*",
      "arn:aws:logs:*:*:log-group:${local.log_group_prefix}*:log-stream:*",
    ]
  }
}

data "aws_iam_policy_document" "lambda_dynamodb" {
  statement {
    sid    = "AllowDynamoDBRead"
    effect = "Allow"

    actions = [
      "dynamodb:GetItem",
      "dynamodb:Query",
    ]

    # Scoped to the specific table and its Global Secondary Indexes.
    resources = [
      var.dynamodb_table_arn,
      "${var.dynamodb_table_arn}/index/*",
    ]
  }
}

data "aws_iam_policy_document" "lambda_secrets" {
  statement {
    sid    = "AllowGetSigningKey"
    effect = "Allow"

    actions = ["secretsmanager:GetSecretValue"]

    # Scoped to the single secret that holds the CloudFront RSA private key.
    resources = [var.private_key_secret_arn]
  }
}

data "aws_iam_policy_document" "lambda_s3_list" {
  statement {
    sid    = "AllowListS3Bucket"
    effect = "Allow"

    actions = ["s3:ListBucket"]

    # Scoped to the single bucket that holds the private content.
    resources = [var.private_content_bucket_arn]
  }
}
