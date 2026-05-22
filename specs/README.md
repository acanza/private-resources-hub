# Specs Index

This file is the first stop for the agent before changing anything in this repository.

## Workflow

1. Read this file first.
2. Identify the task type.
3. Read only the specs that apply to that task.
4. Implement the change.
5. Validate the result against the acceptance criteria and the pre-plan approval checklist.

## Default Reading Order

When a task is not clearly scoped, use this order:

1. [00-product-spec.md](00-product-spec.md)
2. [01-architecture-spec.md](01-architecture-spec.md)
3. [02-security-spec.md](02-security-spec.md)
4. [05-terraform-modules-spec.md](05-terraform-modules-spec.md)
5. [06-acceptance-criteria-spec.md](06-acceptance-criteria-spec.md)
6. [07-pre-plan-approval-checklist-spec.md](07-pre-plan-approval-checklist-spec.md)

## Task Type Map

### Product or scope clarification

Read:

- [00-product-spec.md](00-product-spec.md)
- [01-architecture-spec.md](01-architecture-spec.md)

Use when the task is about business scope, MVP boundaries, or overall system intent.

### Architecture or component boundaries

Read:

- [01-architecture-spec.md](01-architecture-spec.md)
- [05-terraform-modules-spec.md](05-terraform-modules-spec.md)

Use when the task changes how the system is decomposed, connected, or deployed.

### Security, IAM, access control, or private delivery

Read:

- [02-security-spec.md](02-security-spec.md)
- [01-architecture-spec.md](01-architecture-spec.md)
- [05-terraform-modules-spec.md](05-terraform-modules-spec.md)

Use when the task touches IAM, encryption, authentication, network exposure, or private content controls.

### API contract or integration behavior

Read:

- [03-api-contract-spec.md](03-api-contract-spec.md)
- [01-architecture-spec.md](01-architecture-spec.md)
- [02-security-spec.md](02-security-spec.md)

Use when the task changes API endpoints, request or response shapes, auth expectations, or integration boundaries.

### Data model, persistence, or DynamoDB assumptions

Read:

- [04-data-model-spec.md](04-data-model-spec.md)
- [01-architecture-spec.md](01-architecture-spec.md)
- [02-security-spec.md](02-security-spec.md)

Use when the task changes table design, keys, access patterns, or storage-related assumptions.

### Terraform module design or module implementation

Read:

- [05-terraform-modules-spec.md](05-terraform-modules-spec.md)
- [01-architecture-spec.md](01-architecture-spec.md)
- [02-security-spec.md](02-security-spec.md)

Use when the task adds, updates, or wires reusable Terraform modules.

### Acceptance criteria or validation alignment

Read:

- [06-acceptance-criteria-spec.md](06-acceptance-criteria-spec.md)

Use when the task needs to confirm that the implementation can be verified and reviewed.

### Pre-plan approval or readiness to run Terraform

Read:

- [07-pre-plan-approval-checklist-spec.md](07-pre-plan-approval-checklist-spec.md)
- [06-acceptance-criteria-spec.md](06-acceptance-criteria-spec.md)

Use before `terraform plan` or `make plan` to ensure the change is safe to review.

## Spec Index

- [00-product-spec.md](00-product-spec.md): product purpose, scope, and MVP intent.
- [01-architecture-spec.md](01-architecture-spec.md): system architecture, boundaries, and deployment structure.
- [02-security-spec.md](02-security-spec.md): security posture, IAM, private delivery, and encryption expectations.
- [03-api-contract-spec.md](03-api-contract-spec.md): API surface, request and response contracts, and integration rules.
- [04-data-model-spec.md](04-data-model-spec.md): persistence model, keys, access patterns, and data assumptions.
- [05-terraform-modules-spec.md](05-terraform-modules-spec.md): Terraform module structure, composition, and implementation rules.
- [06-acceptance-criteria-spec.md](06-acceptance-criteria-spec.md): acceptance criteria, validation expectations, and reviewability checks.
- [07-pre-plan-approval-checklist-spec.md](07-pre-plan-approval-checklist-spec.md): pre-plan safety gate and approval checklist.

## Operating Rule

Do not guess which specs to apply. If the task touches more than one concern, read every matching spec before implementing.

When in doubt, prioritize safety and validation:

- confirm the change still fits the product and architecture specs,
- check security impact before implementation,
- verify acceptance criteria after implementation,
- and apply the pre-plan checklist before any plan command.