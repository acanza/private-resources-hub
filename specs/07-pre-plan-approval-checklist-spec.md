# 07 - Pre-Plan Approval Checklist Specification

## Project Name

Private Resource Hub

## Purpose

This specification defines the approval checklist that must be completed before executing `terraform plan` for the Private Resource Hub repository.

Its objective is to create a safety gate between code changes and plan generation so that Terraform changes are:

- structurally correct,
- aligned with repository conventions,
- free from obvious hardcoded or unsafe values,
- reviewed for replacement risk,
- and validated with the required non-destructive checks.

This document is intended to prevent avoidable plan failures, reduce review churn, and surface infrastructure risk before plan output is generated.

---

## Scope

This specification applies to:

- all Terraform changes under `modules/`
- all Terraform changes under `envs/`
- new modules
- updates to existing modules
- environment composition changes
- variable, output, provider, backend, IAM, networking, storage, and data-layer changes

This specification must be used before running either:

- `terraform plan`
- `make plan`

Out of scope for this document:

- `terraform apply`
- `terraform destroy`
- CI/CD workflow design
- runtime application testing beyond infrastructure validation prerequisites

---

## Pre-Plan Approval Principles

All checklist items in this document must be:

- Observable: each item can be verified through file inspection, command output, or change review.
- Binary: each item must be marked as Pass, Fail, or Not Applicable.
- Actionable: a failed item must indicate what must be fixed before planning.
- Conservative: if a change introduces uncertain replacement or data-loss risk, approval is blocked until clarified.
- Traceable: each section maps to existing repository specifications and conventions.

---

## Traceability Matrix (High-Level)

- Product and architecture specifications: ensure infrastructure changes still support the MVP system boundaries.
- Security specification: ensure no public exposure, secret leakage, or over-permissioned IAM is introduced.
- Data model specification: ensure Terraform changes do not drift from required DynamoDB access patterns and key assumptions.
- Terraform modules specification: ensure module boundaries, environment composition, and reusable structure remain consistent.
- Acceptance criteria specification: ensure validation workflow and module inventory remain reviewable and testable.
- Repository conventions: ensure docs remain in English and standard validation flow is preserved as `make fmt`, `make validate`, `make plan`.

---

## Approval Outcomes

The pre-plan review must end in exactly one of the following states:

### APPROVED TO PLAN

Use this outcome only when all mandatory checklist items pass and no unresolved destructive-risk concern remains.

### BLOCKED

Use this outcome when any mandatory checklist item fails, when required validation commands fail, or when replacement/data-loss risk is not understood.

### APPROVED TO PLAN WITH REVIEW NOTES

Use this outcome only when all mandatory checks pass, but the reviewer wants explicit post-plan attention on specific areas such as replacement candidates, IAM scope, or backend changes.

This status is not allowed if there is any unresolved blocker.

---

## Mandatory Pre-Plan Checklist

### PPC-STR-001 - Change Is Placed in the Correct Repository Layer

Given a Terraform change under review,
When its file location and purpose are inspected,
Then the change belongs to the correct structural layer:

- reusable logic in `modules/`
- environment composition in `envs/<environment>/`

Verification:

- Confirm the change is not incorrectly implemented directly in an environment when it should be reusable.
- Confirm new shared behavior is not duplicated across environments without justification.

### PPC-STR-002 - Existing Patterns Are Reused

Given a Terraform change that introduces or modifies infrastructure behavior,
When nearby modules and environment wiring are reviewed,
Then the change follows the nearest existing repository pattern unless a documented reason requires deviation.

Verification:

- Compare against the closest existing module or environment composition.
- Confirm any new pattern is explicitly justified in code comments or review notes.

### PPC-VER-001 - Terraform and Provider Versions Are Explicitly Constrained

Given a module or environment targeted for planning,
When Terraform configuration files are inspected,
Then explicit version constraints exist for Terraform and required providers.

Verification:

- Confirm `required_version` is present.
- Confirm `required_providers` is present.
- Confirm the AWS provider source is explicit.
- Confirm version constraints are not left implicit.

### PPC-VER-002 - Backend Isolation Remains Clear for Environment Code

Given an environment configuration under `envs/`,
When backend and state-related configuration are reviewed,
Then the environment preserves isolated state configuration and does not introduce ambiguous or shared state behavior.

Verification:

- Confirm backend configuration is still environment-specific.
- Confirm the change does not accidentally point multiple environments at the same state location.

### PPC-NAM-001 - Naming Conventions Stay Consistent

Given changed variables, outputs, locals, and resource identifiers,
When naming is inspected,
Then repository naming conventions remain consistent and readable.

Verification:

- Confirm `snake_case` is used for variables, outputs, and locals.
- Confirm names are descriptive and aligned with nearby code.
- Confirm resource naming uses project/environment inputs rather than ad hoc literals.

### PPC-VAL-001 - No Hardcoded Secrets or Credentials Exist

Given the changed Terraform files,
When literal values are reviewed,
Then no secret, credential, private key, token, or password material is hardcoded.

Verification:

- Confirm sensitive values are provided through variables, Secrets Manager, Parameter Store, or equivalent approved inputs.
- Confirm no Terraform output exposes secret material in plain text.

### PPC-VAL-002 - No Hardcoded Account- or Environment-Specific Values Are Introduced Without Justification

Given the changed Terraform files,
When static values are reviewed,
Then account IDs, ARNs, regions, environment names, and resource identifiers are parameterized or derived unless an explicit repository convention requires otherwise.

Verification:

- Confirm AWS account IDs are not hardcoded when they can be derived.
- Confirm regions and environment names are not embedded into resource definitions as fixed literals.
- Confirm bucket names, identifiers, and ARNs follow variable-driven composition.

### PPC-SEC-001 - IAM Scope Remains Least-Privilege

Given any change affecting IAM roles, policies, or policy attachments,
When the permission set is reviewed,
Then access remains limited to required service actions and scoped resources for the MVP.

Verification:

- Confirm no wildcard administrative policy is introduced.
- Confirm permissions are grouped by service concern where practical.
- Confirm oversized or mixed-concern inline policies are not introduced when managed policies are more appropriate.

### PPC-SEC-002 - Sensitive or Private Delivery Controls Are Not Weakened

Given any change affecting S3, CloudFront, Cognito, API Gateway, Lambda, or DynamoDB,
When the security impact is reviewed,
Then the change does not weaken private-content controls, authentication enforcement, or encryption-related expectations defined for the MVP.

Verification:

- Confirm private content is not made directly public.
- Confirm JWT-protected API paths remain protected.
- Confirm security-sensitive defaults are not silently relaxed.

### PPC-RISK-001 - Replacement Risk Is Reviewed Before Planning

Given a Terraform change that may affect existing resources,
When resource attributes and identifiers are reviewed,
Then any change that can force replacement is identified before `terraform plan` is executed.

Verification:

- Review changes to names, identifiers, CIDR blocks, encryption attributes, availability zones, and similar replacement-sensitive fields.
- Record any resource likely to require replacement in the review notes.

### PPC-RISK-002 - Destructive or Data-Loss Risk Has a Review Note and Mitigation Path

Given a change with possible replacement or destructive impact,
When the change is prepared for planning,
Then the reviewer documents the risk and the mitigation path before approval.

Verification:

- Confirm review notes describe why the risk exists.
- Confirm backups, snapshots, migration path, or maintenance-window assumptions are stated when relevant.
- Block approval if the risk is not understood.

### PPC-DOC-001 - Non-Obvious Assumptions Are Explicitly Documented

Given a Terraform change whose intent is not obvious from the code alone,
When the diff is reviewed,
Then assumptions, constraints, or compatibility expectations are documented in the relevant Terraform files or review notes.

Verification:

- Confirm non-obvious choices are explained.
- Confirm reviewers do not need to infer critical safety assumptions from the diff alone.

### PPC-VAL-003 - Terraform Formatting Check Passes

Given the target Terraform code,
When the formatting gate is executed,
Then the code passes the repository formatting step before planning.

Verification:

- Preferred: `make fmt`
- Acceptable equivalent: `terraform fmt -check`

Approval rule:

- Approval is blocked if formatting fails or required formatting changes are still pending.

### PPC-VAL-004 - Terraform Validation Check Passes

Given the target Terraform code,
When the validation gate is executed,
Then the code passes Terraform validation before planning.

Verification:

- Preferred: `make validate`
- Acceptable equivalent: `terraform validate`

Approval rule:

- Approval is blocked if validation fails.

### PPC-DIFF-001 - The Change Set Is Reviewable and Focused

Given the Terraform diff prepared for plan generation,
When the scope of the change is reviewed,
Then the diff is narrow enough to be understood and approved without mixing unrelated infrastructure concerns.

Verification:

- Confirm the change is limited to the intended objective.
- Confirm unrelated refactors, renames, or formatting-only churn are not bundled without justification.

---

## Pre-Plan Approval Record Template

Each pre-plan review should produce a short record containing at least:

- Target scope: module path or environment path
- Reviewer
- Date
- Outcome: `APPROVED TO PLAN`, `BLOCKED`, or `APPROVED TO PLAN WITH REVIEW NOTES`
- Checklist results for all mandatory items
- Explicit notes for any replacement or security-sensitive review area
- Exact next command to run

Recommended template:

```md
## Pre-Plan Approval Record

Target: envs/dev
Reviewer: <name>
Date: YYYY-MM-DD
Outcome: APPROVED TO PLAN

Checklist:
- PPC-STR-001: PASS
- PPC-STR-002: PASS
- PPC-VER-001: PASS
- PPC-VER-002: PASS
- PPC-NAM-001: PASS
- PPC-VAL-001: PASS
- PPC-VAL-002: PASS
- PPC-SEC-001: PASS
- PPC-SEC-002: PASS
- PPC-RISK-001: PASS
- PPC-RISK-002: N/A
- PPC-DOC-001: PASS
- PPC-VAL-003: PASS
- PPC-VAL-004: PASS
- PPC-DIFF-001: PASS

Review notes:
- No replacement-sensitive fields changed.
- IAM scope unchanged.

Next command:
- make plan
```

---

## Blocking Conditions

`terraform plan` must not be executed if any of the following is true:

- a mandatory checklist item is marked Fail
- a mandatory checklist item cannot be assessed
- `make fmt` or equivalent formatting check fails
- `make validate` or equivalent validation check fails
- the change may force replacement and the impact is not documented
- the change introduces unclear backend/state behavior
- the change introduces suspected secret exposure or public access regression

---

## Minimum Evidence Required Before Plan

Before plan execution, the reviewer must have access to evidence for:

- the inspected Terraform diff
- the target module or environment path
- formatting result
- validation result
- any identified replacement-risk notes
- any security-sensitive review notes

Evidence may be captured through:

- reviewed files
- terminal command output
- pull request review notes
- implementation notes attached to the task or change request

---

## Definition of Done for Pre-Plan Approval

A Terraform change is approved for `terraform plan` only when all mandatory checklist items pass, required evidence exists, and no unresolved safety concern remains around secrets, permissions, state isolation, or replacement risk.