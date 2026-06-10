# ==============================================================================
# Module: github_actions_iam
#
# Creates an OIDC Identity Provider for GitHub Actions and a least-privilege
# IAM role that GitHub Actions can assume to:
# 1. Deploy frontend assets to S3 (PutObject, DeleteObject, ListBucket)
# 2. Invalidate CloudFront cache (CreateInvalidation)
#
# No long-lived credentials are created. GitHub generates short-lived JWT
# tokens for each workflow run, which can only be exchanged for AWS temporary
# credentials if the token contains the expected audience, repository owner,
# and branch (if specified).
# ==============================================================================

# ==============================================================================
# Data Source: Current AWS Account
#
# Used to construct ARNs for the trust policy and outputs.
# ==============================================================================

data "aws_caller_identity" "current" {}

# ==============================================================================
# GitHub OIDC Identity Provider
#
# Registers the GitHub Actions OIDC endpoint as a trusted identity provider.
# AWS uses this to validate JWT tokens signed by GitHub during workflow runs.
# ==============================================================================

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [
    # GitHub's OIDC provider certificate thumbprint (SHA1).
    # This is the current thumbprint as of 2023 and is stable.
    # AWS docs: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc_verify-thumbprint.html
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]

  tags = merge(local.common_tags, {
    Name = "github-actions-oidc"
  })
}

# ==============================================================================
# IAM Role — GitHub Actions
#
# Trust policy: Allow GitHub Actions to assume this role when:
# - JWT is issued by GitHub OIDC provider
# - JWT audience is "sts.amazonaws.com"
# - JWT repo claim matches github_repository_owner/github_repository_name
# - JWT ref claim matches github_repository_branch (if specified)
#
# When all conditions are met, GitHub Actions can exchange the JWT for
# temporary AWS credentials (valid for 15 minutes by default).
# ==============================================================================

resource "aws_iam_role" "github_actions" {
  name = local.role_name

  assume_role_policy = data.aws_iam_policy_document.trust_policy.json

  tags = merge(local.common_tags, {
    Name = local.role_name
  })
}

# ==============================================================================
# Trust Policy: OIDC Conditions
#
# Restricts role assumption to GitHub Actions running in the specified
# repository and branch. Each GitHub Actions workflow run generates a unique
# JWT that contains these claims, ensuring only authorized workflows can
# access AWS credentials.
# ==============================================================================

data "aws_iam_policy_document" "trust_policy" {
  statement {
    sid    = "GitHubActionsOIDCTrust"
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repository_owner}/${var.github_repository_name}:${var.github_repository_branch == "" ? "*" : "ref:refs/heads/${var.github_repository_branch}"}"
      ]
    }
  }
}

# ==============================================================================
# Permissions Policy: S3 and CloudFront
#
# Permissions granted to the role:
# - S3: ListBucket, PutObject, DeleteObject (scoped to frontend_bucket_arn)
# - CloudFront: CreateInvalidation (scoped to frontend distribution ID)
#
# Least-privilege rationale:
# - ListBucket: Enumerate existing objects before upload
# - PutObject/DeleteObject: Deploy and clean assets
# - CreateInvalidation: Refresh cache after deployment
# ==============================================================================

data "aws_iam_policy_document" "permissions_policy" {
  statement {
    sid    = "S3FrontendBucketList"
    effect = "Allow"

    actions = [
      "s3:ListBucket"
    ]

    resources = [
      var.frontend_bucket_arn
    ]
  }

  statement {
    sid    = "S3FrontendObjectWrite"
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObject" # Optional: allows GitHub Actions to verify uploads by reading objects back
    ]

    resources = [
      "${var.frontend_bucket_arn}/*"
    ]
  }

  statement {
    sid    = "CloudFrontInvalidation"
    effect = "Allow"

    actions = [
      "cloudfront:CreateInvalidation"
    ]

    resources = [
      "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${var.frontend_distribution_id}"
    ]
  }
}

# ==============================================================================
# Inline Policy: Attach permissions to the role
# ==============================================================================

resource "aws_iam_role_policy" "github_actions" {
  name   = "${local.role_name}-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.permissions_policy.json
}
