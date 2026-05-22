# ------------------------------------------------------------------------------
# Module: frontend_delivery — Locals and Data Sources
# ------------------------------------------------------------------------------

locals {
  # Deterministic resource names derived from project and environment.
  # Pattern: <project>-<env>-<resource-purpose>
  bucket_name  = "${var.project_name}-${var.environment}-frontend"
  oac_name     = "${var.project_name}-${var.environment}-frontend-oac"
  s3_origin_id = "${var.project_name}-${var.environment}-frontend-s3-origin"
}

# ------------------------------------------------------------------------------
# IAM policy document: allow CloudFront OAC to read S3 objects.
#
# The condition ties access to the specific distribution ARN. Without this
# condition, any CloudFront distribution with the same OAC could serve
# objects from this bucket.
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "frontend_oac_policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadOnly"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.frontend.arn]
    }
  }
}
