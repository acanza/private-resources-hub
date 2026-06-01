# ------------------------------------------------------------------------------
# Module: private_content_delivery
#
# Stores private files in a fully private S3 bucket and serves them exclusively
# through a CloudFront distribution. Direct S3 access is blocked.
#
# Access to private content is controlled via CloudFront signed URLs or signed
# cookies. The backend Lambda generates signed tokens using the RSA private key
# whose corresponding public key is registered here as a CloudFront key group.
#
# Key design decisions:
# - OAC (not OAI): current AWS recommendation for S3 origins.
# - Trusted key group on all cache behaviors: every request must be signed.
# - Public key managed in Terraform: backend_iam outputs the key ID so the
#   Lambda knows which key to sign with.
# - Private key lives in Secrets Manager (not in Terraform).
# - Versioning enabled: private content is valuable; versioning allows recovery.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# S3 Bucket — private content
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "private_content" {
  bucket = local.bucket_name

  tags = merge(var.tags, {
    Name = local.bucket_name
  })
}

# Versioning enabled: private assets benefit from accidental-deletion recovery.
resource "aws_s3_bucket_versioning" "private_content" {
  bucket = aws_s3_bucket.private_content.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption at rest (AES-256 managed by S3).
resource "aws_s3_bucket_server_side_encryption_configuration" "private_content" {
  bucket = aws_s3_bucket.private_content.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all forms of public access. No object in this bucket should ever be
# accessible without going through the CloudFront distribution.
resource "aws_s3_bucket_public_access_block" "private_content" {
  bucket = aws_s3_bucket.private_content.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy: only the specific CloudFront distribution may read objects.
# Any other principal — including other distributions — is denied by default.
resource "aws_s3_bucket_policy" "private_content" {
  bucket = aws_s3_bucket.private_content.id
  policy = data.aws_iam_policy_document.private_content_oac_policy.json

  depends_on = [aws_s3_bucket_public_access_block.private_content]
}

# ------------------------------------------------------------------------------
# CloudFront Origin Access Control (OAC)
# ------------------------------------------------------------------------------

resource "aws_cloudfront_origin_access_control" "private_content" {
  name                              = local.oac_name
  description                       = "OAC for ${local.bucket_name} private content bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ------------------------------------------------------------------------------
# CloudFront Public Key and Key Group — signed URL / signed cookie support
#
# The RSA public key is registered with CloudFront so it can verify signatures
# on signed URLs and signed cookies. The corresponding private key is stored
# in AWS Secrets Manager and used exclusively by the backend Lambda to sign.
#
# The key group wraps the public key so it can be referenced in cache behaviors
# as a trusted signer. CloudFront enforces that every request to a behavior
# with a trusted_key_groups entry carries a valid signature.
# ------------------------------------------------------------------------------

resource "aws_cloudfront_public_key" "private_content" {
  name        = local.public_key_name
  encoded_key = var.cloudfront_public_key_pem
  comment     = "Signing key for ${var.project_name}-${var.environment} private content"
}

resource "aws_cloudfront_key_group" "private_content" {
  name    = local.key_group_name
  items   = [aws_cloudfront_public_key.private_content.id]
  comment = "Key group for ${var.project_name}-${var.environment} private content distribution"
}

# ------------------------------------------------------------------------------
# CloudFront Distribution — private content
# ------------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "private_content" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${var.project_name}-${var.environment} private content"
  price_class     = var.price_class

  # Custom domain aliases are optional. Omit for dev/stage where the default
  # *.cloudfront.net domain is sufficient.
  aliases = var.private_content_domain_aliases

  origin {
    domain_name              = aws_s3_bucket.private_content.bucket_regional_domain_name
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.private_content.id
  }

  # Default cache behavior — all requests must carry a valid CloudFront
  # signed URL or signed cookie. Unsigned requests are rejected by CloudFront
  # before reaching the origin.
  default_cache_behavior {
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    # CachingOptimized managed policy (AWS-managed).
    # CloudFront validates the signature before serving from cache, so signed
    # URL parameters do not pollute the cache key.
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    # Enforce signed access on every request. CloudFront rejects any request
    # that does not carry a signature verifiable by one of the keys in this group.
    trusted_key_groups = [aws_cloudfront_key_group.private_content.id]

    compress = true
  }

  # Geo-restriction: disabled. Add country-level restrictions here if required
  # by content licensing or compliance rules in later iterations.
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Viewer certificate: use the CloudFront default cert when no custom aliases
  # are configured, or the provided ACM certificate otherwise.
  dynamic "viewer_certificate" {
    for_each = length(var.private_content_domain_aliases) == 0 ? [1] : []
    content {
      cloudfront_default_certificate = true
    }
  }

  dynamic "viewer_certificate" {
    for_each = length(var.private_content_domain_aliases) > 0 ? [1] : []
    content {
      acm_certificate_arn      = var.acm_certificate_arn
      ssl_support_method       = "sni-only"
      minimum_protocol_version = "TLSv1.2_2021"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-private-content-distribution"
  })

  depends_on = [aws_s3_bucket_public_access_block.private_content]
}

# ------------------------------------------------------------------------------
# S3 Folder Prefixes — optional, environment-driven content categories
#
# Each entry in var.folder_prefixes becomes a zero-byte object with a trailing
# "/", which is the S3 convention for folder placeholders. Using for_each means
# individual prefixes can be added or removed without affecting the others.
# ------------------------------------------------------------------------------

resource "aws_s3_object" "folder" {
  for_each = toset(var.folder_prefixes)

  bucket  = aws_s3_bucket.private_content.id
  key     = "${each.key}/"
  content = ""
}
