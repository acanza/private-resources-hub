# ------------------------------------------------------------------------------
# Module: private_content_delivery — Locals and Data Sources
# ------------------------------------------------------------------------------

locals {
  # Deterministic resource names derived from project and environment.
  # Pattern: <project>-<env>-<resource-purpose>
  bucket_name     = "${var.project_name}-${var.environment}-private-content"
  oac_name        = "${var.project_name}-${var.environment}-private-content-oac"
  s3_origin_id    = "${var.project_name}-${var.environment}-private-content-s3-origin"
  public_key_name = "${var.project_name}-${var.environment}-cf-public-key"
  key_group_name  = "${var.project_name}-${var.environment}-cf-key-group"
}

# ------------------------------------------------------------------------------
# IAM policy document: allow CloudFront OAC to read S3 objects.
#
# The condition ties access to this specific distribution ARN. Without it,
# any CloudFront distribution sharing the OAC could serve objects from this
# bucket unintentionally.
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "private_content_oac_policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadOnly"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.private_content.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.private_content.arn]
    }
  }
}
