# Repository Copilot Instructions

## Repository Purpose & Priorities

This repository contains **AWS Infrastructure as Code** using Terraform. All work prioritizes:

1. **Safety**: Never risk unintended infrastructure destruction or data loss
2. **Clarity**: Code must be understandable to future maintainers (often under pressure)
3. **Consistency**: Naming, structure, and patterns must match existing conventions
4. **Reviewability**: Changes must be auditable; small reversible diffs preferred over large refactors
5. **Traceability**: Decisions and assumptions must be documented when non-obvious

---

## Global Repository Rules

Apply these rules to ALL Copilot interactions in this repository, regardless of context:

### 1. Never Hardcode Sensitive Information

**Absolute restriction**:
- ❌ Hardcoded passwords, API keys, private keys, certificates
- ❌ AWS access key IDs (AKIA*) or secret access keys
- ❌ Database master passwords or authentication tokens
- ❌ Private account IDs unless already established as project convention
- ❌ Private TLS certificates or SSH keys

**Always use**:
- AWS Secrets Manager for runtime secrets
- AWS Systems Manager Parameter Store for configuration
- IAM roles and policies instead of credentials
- `sensitive = true` in variable outputs
- `.gitignore` for local `.tfvars` files with secrets

### 2. Preserve Existing Structure & Conventions

**Must respect**:
- Directory organization: `modules/` for reusable components, `envs/` for environment-specific configs
- Naming pattern: `snake_case` for variables, outputs, local values, resource names
- File organization: `terraform.tf` (version constraints), `main.tf` (resources), `variables.tf` (inputs), `outputs.tf` (exports), `locals.tf` (computed values)
- Tagging and metadata patterns established in existing resources
- Backend and remote state configurations
- Write all documentation in English for consistency

**When uncertain**:
- Match the nearest existing module or resource for pattern consistency
- Ask for clarification rather than inventing alternative patterns

### 3. Prefer Small, Auditable, Reversible Changes

**Always**:
- Make incremental edits rather than wholesale rewrites
- Keep diffs concise and focused on single concerns
- Explain why changes are made, not just what changed
- Design changes that can be rolled back without data loss

**Never**:
- Restructure modules or refactor variables without strong justification
- Combine multiple unrelated changes in a single diff
- Remove or rename resources without explicit planning for state migration

### 4. Reuse Existing Modules, Patterns & Scripts

**Before creating anything new**:
1. Check `modules/` for existing reusable patterns
2. Check `.github/skills/` for domain-specific validation and scaffolding tools
3. Examine similar resources in `envs/` for established patterns
4. Look for existing shell scripts or Makefile targets

**If new abstractions are needed**:
- Justify clearly why existing patterns don't fit
- Document the new pattern immediately
- Make it reusable for future similar needs

### 5. Document Assumptions Explicitly

**When context is missing or ambiguous**:
- State assumptions about environment, requirements, or constraints
- Ask clarifying questions rather than guessing
- Add comments explaining non-obvious decisions
- Link to external documentation if referenced

**Example**:
```hcl
# Assumes: RDS multi-AZ failover enabled (required for prod)
# See: envs/prod for HA configuration
# Migration path: If changing to single-AZ, plan requires data retention window
resource "aws_db_instance" "main" {
  multi_az = var.enable_multi_az
  ...
}
```

---

## Documentation file policy

- Never create `.md` files in the repository root.
- Store all non-essential documentation under `/docs`.
- Write documentation in English for consistency.
- Create new documentation files only when explicitly requested or when the information has clear long-term value.
- Do not generate one documentation file per module by default.
- Prefer updating existing files in `/docs` rather than creating new ones.
- Temporary analysis, implementation notes, or risk summaries should be returned in chat, not saved as files.
- Avoid generic, repetitive, or low-value documentation.

## Validation & Execution Pattern

When making changes, prefer the established validation flow already present in this repository:

### Preferred Command Sequence
```bash
make fmt        # Format code to canonical style (idempotent)
make validate   # Check configuration syntax/consistency (no AWS calls)
make plan       # Show intended changes (read-only, informational)
```

**Why Makefile targets**:
- Standardized across team
- Enforces consistent command format
- Can embed safety checks or environment validation
- Documents standard operations

### Never Apply or Deploy Without Explicit Request

- ❌ Do **not** run `make apply` or `terraform apply` unless explicitly requested
- ❌ Do **not** run `terraform destroy` under any circumstances without clear confirmation
- ✅ Only plan, format, validate, or generate code

**If deployment is requested**:
- Summarize what will change
- Clearly warn about destructive operations (resource replacement, deletion, data loss)
- Recommend review of `terraform plan` output before execution

---

## When to Use the Specialized Terraform/IaC Agent

This repository includes a specialized agent at `.github/agents/terraform-iac.agent.md` for deep Terraform/AWS workflows.

**Use the specialized agent when**:
- Scaffolding new modules (VPC, RDS, IAM, ECS, etc.)
- Building multi-environment deployments from scratch
- Implementing complex AWS resource interactions
- Migrating infrastructure or refactoring large module structures
- Designing state management or backend configurations

**Use general Copilot with these instructions when**:
- Adding a single resource to an existing module
- Fixing a specific bug or configuration error
- Adding documentation or comments
- Understanding existing code structure
- Updating variable values or descriptions
- Creating or modifying Makefile targets, shell scripts, or documentation

**The specialized agent** focuses on Terraform architecture, scaffolding, and AWS provisioning best practices.  
**These instructions** provide the always-on behavioral baseline and safety guardrails.

---

## Code Quality & Style Expectations

### Readability Over Cleverness
- Prefer explicit, obvious code over abbreviated or clever constructs
- Use meaningful variable and resource names
- Break complex expressions into readable locals
- Comment non-obvious logic or business rules

### Risk & Impact Awareness
- Always summarize the scope of changes
- Highlight potentially destructive operations with clear warnings
- Explain replacement-causing changes (e.g., "changing `engine` forces database replacement")
- Identify dependencies that might break

### Maintainability
- Follow the pattern: "Would a tired engineer at 2am understand this six months from now?"
- Avoid one-liners or dense constructs
- Document assumptions and decisions
- Create examples for non-obvious patterns

---

## Key Resources

- **Makefile**: Standard targets for `fmt`, `validate`, `plan`, `apply`, `destroy`
- **Skills**: `.github/skills/` contains domain-specific validation tools
  - `terraform-aws-module/` — Module scaffolding best practices
  - `aws-iac-review/` — Security and architectural review
  - `pre-plan-validation/` — Pre-plan safety checks
- **Specialized Agent**: `.github/agents/terraform-iac.agent.md` — Deep Terraform/AWS expertise
- **Structure**: `modules/` (reusable), `envs/` (environment-specific)

---

## Quick Reference: What NOT to Do

| ❌ Don't | ✅ Do |
|---------|-----|
| Hardcode passwords, keys, or secrets | Use AWS Secrets Manager, IAM roles |
| Restructure modules without justification | Make focused, incremental changes |
| Create new patterns without documenting | Reference or enhance existing patterns |
| Apply/destroy without confirmation | Only plan, format, validate by default |
| Ignore existing naming/structure conventions | Ask for clarification when uncertain |
| Combine unrelated changes in one diff | Keep changes focused and reviewable |
| Leave non-obvious decisions unexplained | Document assumptions and "why" |
| Write clever or dense code | Optimize for readability and maintainability |

---

## Summary

This repository is a **shared infrastructure asset** that requires:
- **Conservative defaults**: Never destructive without explicit request
- **Clear communication**: Explain decisions and risks
- **Consistency**: Match existing patterns and conventions
- **Reviewability**: Small, auditable, reversible changes

The specialized Terraform/IaC agent handles deep scaffolding and architecture. These instructions provide the always-on safety and consistency baseline for all other interactions.

When in doubt, **prefer small changes, explicit permissions, and clear communication**.
