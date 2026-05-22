# ------------------------------------------------------------------------------
# Module: frontend_delivery
#
# Hosts static frontend assets (SPA or static site) in a private S3 bucket
# and delivers them through a CloudFront distribution.
#
# Direct public S3 access is blocked. CloudFront reaches the bucket through
# an Origin Access Control (OAC), which is the current AWS-recommended
# approach over the legacy Origin Access Identity (OAI).
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# S3 Bucket — frontend assets
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "frontend" {
  bucket = local.bucket_name

  tags = merge(var.tags, {
    Name = local.bucket_name
  })
}

# Versioning is disabled for the frontend bucket.
# Frontend assets are replaced on each deployment, not incrementally updated.
resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = "Disabled"
  }
}

# Server-side encryption at rest (AES-256 managed by S3).
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all forms of public access to the bucket.
# CloudFront accesses the bucket through OAC, so public access is not required.
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy: allow CloudFront service principal to read objects.
# The condition restricts access to the specific CloudFront distribution by ARN,
# preventing other distributions from serving bucket objects unintentionally.
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_oac_policy.json

  # The public access block must be fully applied before the bucket policy,
  # otherwise Terraform may fail with a conflicting-policy error.
  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

# ------------------------------------------------------------------------------
# CloudFront Origin Access Control (OAC)
# ------------------------------------------------------------------------------

# OAC replaces the legacy Origin Access Identity (OAI).
# AWS recommendation since 2022: use OAC for S3 origins to enable SSE-KMS
# and to use SigV4 request signing.
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = local.oac_name
  description                       = "OAC for ${local.bucket_name} frontend bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ------------------------------------------------------------------------------
# CloudFront Distribution — frontend
# ------------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name}-${var.environment} frontend"
  default_root_object = "index.html"
  price_class         = var.price_class

  # Custom domain aliases are optional. When provided, a valid ACM certificate
  # must also be supplied via acm_certificate_arn.
  aliases = var.frontend_domain_aliases

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  # Default cache behavior: forward nothing sensitive, cache aggressively.
  default_cache_behavior {
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    # CachingOptimized managed policy (AWS-managed cache policy ID).
    # Suitable for S3 static assets. Forwards no headers, cookies, or query strings.
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    compress = true
  }

  # SPA fallback: return index.html for any 403/404 response from S3.
  # S3 returns 403 (not 404) for missing objects when bucket policy is restrictive.
  # This enables client-side routing in single-page applications.
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  # Geo-restriction: disabled by default.
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Viewer certificate configuration.
  # When no custom domain aliases are provided, use the CloudFront default
  # certificate (*.cloudfront.net). When aliases are provided, require a
  # valid ACM certificate in us-east-1 (requirement for CloudFront).
  dynamic "viewer_certificate" {
    for_each = length(var.frontend_domain_aliases) == 0 ? [1] : []
    content {
      cloudfront_default_certificate = true
    }
  }

  dynamic "viewer_certificate" {
    for_each = length(var.frontend_domain_aliases) > 0 ? [1] : []
    content {
      acm_certificate_arn      = var.acm_certificate_arn
      ssl_support_method       = "sni-only"
      minimum_protocol_version = "TLSv1.2_2021"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-frontend-distribution"
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}
