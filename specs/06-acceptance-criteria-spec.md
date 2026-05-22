# 06 - Acceptance Criteria Specification

## Project Name

Private Resource Hub

## Purpose

This specification defines measurable acceptance criteria for the MVP, derived from:

- Product scope and functional requirements
- Target architecture
- Security requirements
- API contract
- Data model
- Terraform module strategy

The objective is to provide a single source of truth for validating that the MVP is complete, secure, and ready for review.

---

## Acceptance Principles

All criteria in this document must be:

- Observable: can be verified through tests, API calls, or infrastructure inspection.
- Binary: each criterion can be marked as Pass or Fail.
- Traceable: each criterion maps to at least one existing specification.
- MVP-aligned: no criterion introduces out-of-scope features.

---

## Traceability Matrix (High-Level)

- Product specification: user authentication, authorized resource listing, temporary access to private files.
- Architecture specification: Cognito + API Gateway JWT + Lambda + DynamoDB + CloudFront + S3 separation.
- Security specification: authenticated access, least privilege, private content isolation, short-lived temporary access.
- API contract: protected routes, response format, status behavior.
- Data model specification: single-table patterns and query/get access patterns without scans.
- Terraform modules specification: reusable modules, environment composition, validation workflow.

---

## Functional Acceptance Criteria

### AC-FR-001 - Cognito Authentication

Given a valid user in Cognito,
When the user completes login,
Then the frontend obtains a valid JWT token usable in the Authorization header for protected API routes.

Verification:

- Validate token structure and signature according to Cognito issuer.
- Call a protected API route with the token and receive a non-401 response.

### AC-FR-002 - Protected API Requires JWT

Given an API request to a protected route,
When the Authorization header is missing, malformed, or contains an invalid/expired token,
Then the API returns Unauthorized behavior (401-equivalent) and does not invoke business logic for resource access.

Verification:

- Send requests with missing/invalid token and assert unauthorized response.
- Confirm no resource data is returned.

### AC-FR-003 - Authorized Resource Listing Only

Given an authenticated user with explicit access to a subset of resources,
When the user calls the resource listing endpoint,
Then the response contains only resources assigned to that user and excludes all others.

Verification:

- Seed at least two users with different access edges.
- Assert each user only sees own authorized resources.

### AC-FR-004 - Resource Metadata Contract

Given an authorized resource returned by the listing endpoint,
When a resource object is inspected,
Then it includes exactly the required metadata fields for MVP usage:

- id
- title
- description
- content_prefix

Verification:

- Validate response schema.
- Ensure required fields are present and non-empty where applicable.

### AC-FR-005 - Temporary Access for Authorized Resource

Given an authenticated user authorized for a resource,
When the user requests private content access for that resource,
Then the backend returns temporary access material (signed URL or signed cookie flow) with a short expiration.

Verification:

- Confirm the access artifact expires after configured TTL.
- Confirm content is accessible before expiration and denied after expiration.

### AC-FR-006 - Access Denial for Unauthorized Resource

Given an authenticated user without access edge for a target resource,
When the user requests temporary access for that resource,
Then the API denies access (403-equivalent) and does not issue any signed artifact.

Verification:

- Request access for unauthorized resource and assert deny response.
- Confirm no signed URL/cookie is generated.

---

## Security Acceptance Criteria

### AC-SEC-001 - Private S3 Content Is Not Public

Given the private content bucket,
When public access settings and policy are inspected,
Then public read access is blocked and direct anonymous object retrieval fails.

Verification:

- Validate S3 Public Access Block settings are fully enabled.
- Attempt unauthenticated direct S3 object access and assert denial.

### AC-SEC-002 - Private Content Served Only Through CloudFront Restricted Access

Given private content distribution,
When content is requested without valid signed access,
Then CloudFront denies access.

Verification:

- Attempt CloudFront request without valid signature and assert denial.
- Attempt with valid signed access and assert success during validity window.

### AC-SEC-003 - Least-Privilege IAM for Backend

Given Lambda execution role and attached policies,
When IAM permissions are reviewed,
Then permissions are restricted to required service actions and scoped resources for MVP operations.

Verification:

- Confirm only required DynamoDB read and content-signing related permissions exist.
- Confirm no wildcard admin privileges (for example, Action="*" on Resource="*").

### AC-SEC-004 - No Secret Exposure in Frontend or Terraform Outputs

Given frontend build artifacts and Terraform outputs,
When inspected,
Then no secrets, private keys, or sensitive credential material are exposed.

Verification:

- Scan frontend configuration and output files for secret patterns.
- Confirm sensitive values are not exported in plain outputs.

---

## API Contract Acceptance Criteria

### AC-API-001 - Resource List Endpoint Contract

Given a successful authenticated request to list resources,
When the endpoint responds,
Then response status and payload structure match the API contract specification.

Verification:

- Validate HTTP status and JSON schema.
- Validate object fields and types for each resource.

### AC-API-002 - Temporary Access Endpoint Contract

Given an authenticated request for resource access,
When the resource is authorized,
Then the API response includes only the fields defined by contract for temporary access delivery.

Verification:

- Validate success and error response schemas.
- Validate that unauthorized or not found flows match defined status behavior.

### AC-API-003 - Auth Header Convention

Given any protected route request,
When authentication is provided,
Then it uses Authorization: Bearer <jwt> and is validated by JWT authorizer.

Verification:

- Confirm JWT authorizer is attached to protected routes in API Gateway configuration.

---

## Data Model Acceptance Criteria

### AC-DATA-001 - Single-Table Key Patterns Implemented

Given the DynamoDB table,
When items are inspected,
Then keys follow required patterns:

- Resource metadata: pk = RESOURCE#{resource_id}, sk = METADATA
- User-resource edge: pk = USER#{email}, sk = RESOURCE#{resource_id}

Verification:

- Insert and read sample items for both types.
- Confirm exact prefixes are used.

### AC-DATA-002 - User Resource Listing Without Scan

Given a user with assigned resources,
When listing authorized resources,
Then backend uses query pattern on pk = USER#{email} and does not rely on table scan.

Verification:

- Confirm implementation path uses Query with begins_with on sk.
- Confirm API behavior matches expected resources.

### AC-DATA-003 - Access Check by Composite Key

Given a user and a target resource,
When checking authorization,
Then backend uses direct key lookup for USER#{email} + RESOURCE#{resource_id} edge.

Verification:

- Confirm GetItem-based authorization check path.
- Confirm allow/deny behavior maps to edge existence.

---

## Architecture and Infrastructure Acceptance Criteria

### AC-ARCH-001 - Three-Tier Serverless Flow Is Implemented

Given deployed MVP infrastructure,
When architecture components are enumerated,
Then the required chain exists:

- Frontend delivery: S3 + CloudFront
- Identity: Cognito User Pool
- API layer: API Gateway HTTP API with JWT authorizer
- Compute: Lambda backend
- Data: DynamoDB table
- Private content delivery: CloudFront + private S3

Verification:

- Validate all components are provisioned and integrated.
- Validate end-to-end user flow from login to private content access.

### AC-IAC-001 - Required Terraform Modules Exist

Given repository modules directory,
When Terraform module inventory is checked,
Then all required modules are present:

- frontend_delivery
- auth_cognito
- data_access_dynamodb
- backend_iam
- backend_api
- private_content_delivery

Verification:

- Confirm each module contains at minimum main.tf, variables.tf, and outputs.tf.

### AC-IAC-002 - Environment Composition Contract

Given envs/dev (and replicated stage/prod structure),
When environment files are reviewed,
Then modules are wired with explicit inputs and dependencies in expected composition order.

Verification:

- Confirm Terraform/provider version pinning in terraform.tf.
- Confirm backend state isolation configuration per environment.

### AC-IAC-003 - Validation Workflow Passes

Given Terraform code for modules and environment,
When validation commands are executed,
Then they complete successfully:

- terraform fmt -check
- terraform validate
- terraform plan

If Makefile targets exist, equivalent acceptance commands are:

- make fmt
- make validate
- make plan

Verification:

- Capture command exit codes and plan output generation.
- No apply execution is required for acceptance.

---

## Non-Goals Validation

The MVP must be accepted only if none of the explicitly out-of-scope capabilities are required for completion, including:

- Admin dashboard
- Frontend resource creation
- Advanced RBAC
- Multi-tenant support
- Payment/subscription features
- Full-text search
- CI/CD implementation

Acceptance rule:

- Missing out-of-scope features must not block MVP acceptance.

---

## Acceptance Test Evidence Checklist

For handoff readiness, provide evidence for each criterion category:

- Functional API test results (authorized, unauthorized, expired access).
- Security checks (private bucket, restricted CloudFront, IAM least privilege).
- Data model checks (key patterns, query/get access paths, no scans for core reads).
- Terraform validation logs (fmt, validate, plan).
- End-to-end walkthrough: login -> list resources -> request temporary access -> access private content.

---

## Definition of Done for MVP Acceptance

The MVP is accepted when all mandatory criteria AC-FR, AC-SEC, AC-API, AC-DATA, AC-ARCH, and AC-IAC pass, and no blocking security issue is identified.
