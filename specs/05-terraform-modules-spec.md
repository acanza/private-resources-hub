# 05 — Terraform Modules Specification

## Project Name

Private Resource Hub

## Purpose

This specification defines the Terraform module strategy for the Private Resource Hub MVP.

It translates the target architecture into reusable, auditable, and environment-ready Terraform modules.

The module design must prioritize:

1. Security by default.
2. Small and reviewable infrastructure changes.
3. Reuse across environments.
4. Clear ownership of each AWS service.

---

## Scope

This specification covers module definitions for the AWS services already defined in the architecture:

- Amazon S3 (frontend bucket and private content bucket)
- Amazon CloudFront (frontend distribution and private content distribution)
- Amazon Cognito User Pool
- Amazon API Gateway HTTP API (with JWT authorizer)
- AWS Lambda (backend)
- Amazon DynamoDB (resource access table)
- AWS IAM (execution and integration permissions)

Out of scope for this document:

- CI/CD pipeline setup
- Runtime application code details
- Monitoring dashboards beyond minimum log groups

---

## Target Terraform Structure

```txt
modules/
  frontend_delivery/
  auth_cognito/
  data_access_dynamodb/
  backend_api/
  private_content_delivery/
  backend_iam/

envs/
  dev/
    main.tf
    variables.tf
    terraform.tf
    terraform.tfvars.example
    outputs.tf
  stage/
  prod/
```

Design rule:

- Modules under `modules/` must be reusable and environment-agnostic.
- Environment folders under `envs/` must compose modules and set environment-specific values.

---

## Module Catalog

## 1) Module: `frontend_delivery`

Purpose:

- Host static frontend assets in S3.
- Deliver frontend via CloudFront.
- Prevent direct public S3 access using CloudFront Origin Access Control (OAC).

Resources (minimum):

- `aws_s3_bucket` (frontend)
- `aws_s3_bucket_public_access_block` (frontend)
- `aws_cloudfront_origin_access_control`
- `aws_cloudfront_distribution` (frontend)
- `aws_s3_bucket_policy` (allow CloudFront service principal)

Key inputs:

- `project_name`
- `environment`
- `frontend_domain_aliases` (optional)
- `acm_certificate_arn` (optional, required for custom domain)
- `tags`

Key outputs:

- `frontend_bucket_name`
- `frontend_distribution_id`
- `frontend_distribution_domain_name`

Security requirements:

- `block_public_acls = true`
- `block_public_policy = true`
- `ignore_public_acls = true`
- `restrict_public_buckets = true`

---

## 2) Module: `auth_cognito`

Purpose:

- Provide user authentication for frontend and API access.

Resources (minimum):

- `aws_cognito_user_pool`
- `aws_cognito_user_pool_client`
- `aws_cognito_user_pool_domain` (optional, if hosted UI is used)

Key inputs:

- `project_name`
- `environment`
- `callback_urls`
- `logout_urls`
- `allowed_oauth_flows` (if OAuth flow is enabled)
- `tags`

Key outputs:

- `user_pool_id`
- `user_pool_client_id`
- `user_pool_issuer_url`

Security requirements:

- Strong password policy enabled.
- User existence error responses hidden when possible.
- Token validity values explicitly configured.

---

## 3) Module: `data_access_dynamodb`

Purpose:

- Store resource metadata and user-to-resource access relationships.

Resources (minimum):

- `aws_dynamodb_table` (single-table model)

Key inputs:

- `project_name`
- `environment`
- `table_name` (default: `resource_access`)
- `billing_mode` (default: `PAY_PER_REQUEST`)
- `tags`

Key outputs:

- `table_name`
- `table_arn`

Data model constraints:

- Partition key name: `pk`
- Sort key name: `sk`
- Attribute types: string

Security requirements:

- Point-in-time recovery enabled.
- Server-side encryption enabled.

---

## 4) Module: `backend_iam`

Purpose:

- Define least-privilege permissions for the backend Lambda.

Resources (minimum):

- `aws_iam_role` (Lambda execution role)
- `aws_iam_policy` (managed policy for DynamoDB read)
- `aws_iam_policy` (managed policy for CloudFront signed URL/cookie operations if required by implementation)
- `aws_iam_role_policy_attachment`

Key inputs:

- `project_name`
- `environment`
- `dynamodb_table_arn`
- `private_distribution_id`
- `private_key_secret_arn` (if key material is loaded from Secrets Manager)
- `tags`

Key outputs:

- `lambda_role_arn`
- `lambda_role_name`

IAM policy design rules:

- Prefer managed policies over large inline policies.
- Split policies by service concern (DynamoDB, CloudFront, secrets).
- Keep each policy below practical size threshold.

---

## 5) Module: `backend_api`

Purpose:

- Deploy backend Lambda and expose it through API Gateway HTTP API.
- Enforce JWT authentication using Cognito issuer and audience.

Resources (minimum):

- `aws_lambda_function`
- `aws_cloudwatch_log_group` (Lambda)
- `aws_apigatewayv2_api`
- `aws_apigatewayv2_integration`
- `aws_apigatewayv2_route`
- `aws_apigatewayv2_authorizer` (JWT)
- `aws_apigatewayv2_stage`
- `aws_lambda_permission` (invoke permission for API Gateway)

Key inputs:

- `project_name`
- `environment`
- `lambda_role_arn`
- `lambda_s3_bucket` and `lambda_s3_key` (or image URI strategy)
- `cognito_user_pool_issuer_url`
- `cognito_user_pool_client_id`
- `dynamodb_table_name`
- `private_distribution_domain_name`
- `tags`

Key outputs:

- `api_id`
- `api_endpoint`
- `lambda_function_name`

Security requirements:

- All protected routes require JWT authorizer.
- CORS restricted to known frontend origin(s).
- Log retention explicitly defined.

---

## 6) Module: `private_content_delivery`

Purpose:

- Store private files in S3.
- Serve private files only through CloudFront distribution.
- Support temporary access through signed URLs or signed cookies generated by backend.

Resources (minimum):

- `aws_s3_bucket` (private content)
- `aws_s3_bucket_public_access_block`
- `aws_cloudfront_origin_access_control`
- `aws_cloudfront_distribution` (private content)
- `aws_s3_bucket_policy`
- `aws_cloudfront_public_key` (if managed in Terraform)
- `aws_cloudfront_key_group` (if managed in Terraform)

Key inputs:

- `project_name`
- `environment`
- `private_content_domain_aliases` (optional)
- `acm_certificate_arn` (optional)
- `trusted_key_group_items` (optional if key group external)
- `tags`

Key outputs:

- `private_bucket_name`
- `private_distribution_id`
- `private_distribution_domain_name`
- `cloudfront_key_group_id` (if created)

Security requirements:

- No direct S3 public access.
- CloudFront distribution must require trusted signers/key groups for restricted paths.
- Signed URL/cookie expiration must be short-lived (configured in backend).

---

## Module Composition Order

The recommended dependency order in each environment is:

1. `data_access_dynamodb`
2. `private_content_delivery`
3. `auth_cognito`
4. `backend_iam`
5. `backend_api`
6. `frontend_delivery`

Dependency notes:

- `backend_iam` depends on DynamoDB and private content outputs.
- `backend_api` depends on Cognito, DynamoDB, private content, and IAM outputs.
- `frontend_delivery` may need API endpoint and Cognito client values via frontend configuration pipeline.

---

## Environment Contract

Each folder in `envs/` must:

- Pin Terraform and provider versions in `terraform.tf`.
- Configure backend state isolation per environment.
- Instantiate all required modules with explicit input wiring.
- Export minimal outputs needed by operations and frontend configuration.

Expected environment variables (example set):

- `aws_region`
- `project_name`
- `environment`
- `common_tags`

---

## Naming and Tagging Rules

- Use `snake_case` for Terraform variables, locals, and outputs.
- Use deterministic names derived from `project_name` and `environment`.
- Apply consistent tags to all taggable resources:
  - `Project`
  - `Environment`
  - `ManagedBy = Terraform`

---

## Validation Requirements

For every module and environment, the workflow must include:

1. `terraform fmt -check`
2. `terraform validate`
3. `terraform plan`

If a Makefile exists, prefer:

1. `make fmt`
2. `make validate`
3. `make plan`

No `apply` execution is part of this specification.

---

## MVP Decisions and Constraints

- Keep modules small and focused on a single responsibility.
- Avoid introducing unnecessary abstractions in MVP.
- Prefer explicit module inputs over hidden data lookups.
- Avoid public endpoints to private content except through signed CloudFront access.
- Keep IAM permissions service-scoped and least-privilege.

---

## Implementation Checklist

1. Create the six modules under `modules/`.
2. Define `variables.tf` and `outputs.tf` for each module.
3. Wire module dependencies in `envs/dev/main.tf` first.
4. Validate `dev` with fmt, validate, and plan.
5. Replicate environment composition for `stage` and `prod` with environment-specific values.

This checklist defines the minimum deliverable for Terraform module creation aligned with the architecture specification.