# Module: `github_actions_iam`

Provides an OIDC Identity Provider for GitHub Actions with a least-privilege IAM role to deploy React + Vite frontend assets to S3 and invalidate CloudFront cache.

## Purpose

This module creates:
- An **OIDC Identity Provider** that trusts GitHub Actions' token signing service
- An **IAM role** that GitHub Actions can assume (no long-lived credentials)
- A **minimal inline policy** granting only:
  - S3: List, upload, and delete objects in the frontend bucket
  - CloudFront: Invalidate cache for the frontend distribution

**Key benefits over long-lived credentials:**
- ✅ No access keys to rotate or manage
- ✅ Credentials expire after 15 minutes (cannot be reused)
- ✅ Each workflow run gets unique credentials
- ✅ Fails fast if the JWT is tampered with
- ✅ GitHub-generated tokens are short-lived and cannot be long-term stolen
- ✅ Repository and branch are verified in the JWT before role assumption

## Usage

```hcl
module "github_actions_iam" {
  source = "../../modules/github_actions_iam"

  project_name              = var.project_name
  environment               = var.environment
  github_repository_owner   = "acanza"  # Your GitHub username or org
  github_repository_name    = "private-resources-hub-frontend"
  github_repository_branch  = "main"  # Optional; empty string = all branches

  frontend_bucket_arn       = module.frontend_delivery.frontend_bucket_arn
  frontend_distribution_id  = module.frontend_delivery.frontend_distribution_id

  tags = var.tags
}
```

## Outputs

| Output | Description |
|--------|-------------|
| `github_actions_role_arn` | ARN of the OIDC-assumable role (use in workflow) |
| `github_actions_role_name` | Name of the role |
| `github_oidc_provider_arn` | ARN of the GitHub OIDC Identity Provider |
| `policy_document_size` | Inline policy size (bytes) |

## GitHub Actions Setup

### 1. Store the Role ARN

After applying the module, retrieve the role ARN:

```bash
terraform output github_actions_role_arn
```

Add it as a GitHub Secret: **Settings → Secrets and variables → Actions**

```
GITHUB_ACTIONS_ROLE_ARN = (output value)
```

### 2. Example Workflow (`.github/workflows/deploy-frontend.yml`)

```yaml
name: Deploy Frontend

on:
  push:
    branches:
      - main
    paths:
      - 'frontend/**'

permissions:
  contents: read
  id-token: write  # ← Required for OIDC token generation

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'

      - name: Install dependencies
        working-directory: ./frontend
        run: npm ci

      - name: Build
        working-directory: ./frontend
        run: npm run build

      # Assume the AWS role using OIDC (no access keys!)
      - name: Assume AWS Role
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.GITHUB_ACTIONS_ROLE_ARN }}
          aws-region: us-east-1  # Adjust as needed

      - name: Deploy to S3
        env:
          S3_BUCKET: ${{ secrets.S3_BUCKET_NAME }}  # Add this secret: frontend bucket name
        run: |
          # Sync build output to S3 (remove old files)
          aws s3 sync ./frontend/dist/ "s3://${S3_BUCKET}/" \
            --delete \
            --cache-control "max-age=31536000,immutable" \
            --exclude "*.html" \
            --region us-east-1

          # Upload HTML files with no-cache
          aws s3 cp ./frontend/dist/ "s3://${S3_BUCKET}/" \
            --recursive \
            --include "*.html" \
            --cache-control "no-cache,no-store,must-revalidate" \
            --content-type "text/html" \
            --region us-east-1

      - name: Invalidate CloudFront
        env:
          CLOUDFRONT_DISTRIBUTION_ID: ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }}
        run: |
          aws cloudfront create-invalidation \
            --distribution-id "${CLOUDFRONT_DISTRIBUTION_ID}" \
            --paths "/*" \
            --region us-east-1
```

### 3. Add Required Secrets

In GitHub: **Settings → Secrets and variables → Actions**

```
GITHUB_ACTIONS_ROLE_ARN = (terraform output github_actions_role_arn)
S3_BUCKET_NAME = (terraform output frontend_bucket_name)
CLOUDFRONT_DISTRIBUTION_ID = (terraform output frontend_distribution_id)
```

## OIDC How It Works

1. **Workflow runs**: GitHub Actions generates a JWT token signed with GitHub's private key
2. **Token contains**:
   - `aud: "sts.amazonaws.com"` (audience)
   - `sub: "repo:owner/repo:ref:refs/heads/main"` (subject = repository + branch)
   - JWT expires in ~5 minutes
3. **AWS verifies**: Uses the GitHub OIDC endpoint certificate to validate the JWT signature
4. **Trust check**: Verifies `sub` and `aud` match the role's trust policy conditions
5. **Role assumed**: If verified, GitHub Actions receives temporary AWS credentials (valid 15 min)

## Security Model

- **No long-lived credentials**: Credentials expire after 15 minutes and cannot be refreshed
- **Repository + branch verification**: The JWT's `sub` claim is verified against the trust policy
- **Token signing**: Only GitHub can create valid tokens (cryptographically signed)
- **Audit trail**: AWS CloudTrail shows the JWT subject (which repo/branch made the call)

## Policy Size

The inline policy is well under the 2048-byte AWS limit. Output `policy_document_size` shows the actual size.

### Least-Privilege Details

**S3 Permissions:**
- `s3:ListBucket`: Required to enumerate existing objects before uploading
- `s3:PutObject`: Deploy new/updated assets
- `s3:DeleteObject`: Remove old assets during sync operations

**CloudFront Permissions:**
- `cloudfront:CreateInvalidation`: Clear cache after deployment to serve updated content immediately

**Scope:**
- All S3 actions are scoped to the specific frontend bucket ARN
- CloudFront action is scoped to the specific distribution ID
- No wildcard permissions or access to other buckets/distributions

## Modifying Repository or Branch

To deploy from a different repository or branch, update the module:

```hcl
module "github_actions_iam" {
  # ...
  github_repository_owner   = "new-owner"
  github_repository_name    = "new-repo"
  github_repository_branch  = "develop"  # or empty string for all branches
  # ...
}
```

Then apply and update the GitHub Secrets accordingly.

## Related Modules

- `frontend_delivery`: Creates the S3 bucket and CloudFront distribution

## Terraform Validation

Before planning or applying:

```bash
terraform fmt -recursive
terraform validate
```

