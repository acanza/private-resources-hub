# Makefile Commands Reference

This guide explains the Makefile commands available in this Terraform project and how they integrate with `pre-plan-validation` skill.

## Overview

The project Makefile provides standardized commands for Terraform operations across development, staging, and production environments.

### Why Use Makefile Over Raw Terraform?

1. **Consistency**: Same commands work for all environments
2. **Standardization**: Enforces version pinning and validation sequences
3. **Safety Gates**: Can enforce pre-plan validation before plan
4. **Documentation**: Self-documenting command targets
5. **Integration**: Easy to wire into CI/CD pipelines

---

## Common Makefile Targets

### Initialization & Setup

#### `make init` or `make init-DEV`
Initializes Terraform backend and downloads providers.

```bash
make init           # Initialize current environment (from ENV var)
make init-dev       # Initialize development
make init-stage     # Initialize staging
make init-prod      # Initialize production
```

**Pre-plan-validation integration**:
- Run after provider version changes
- Verify backend configuration exists
- Backend lock must not be held by other users

**Equivalent terraform command**:
```bash
terraform -chdir=envs/dev init
```

---

### Formatting & Validation

#### `make fmt` or `make fmt-check`
Formats Terraform code to canonical format.

```bash
make fmt            # Format all terraform files in current env
make fmt-check      # Check if formatting is needed (no changes)
```

**Pre-plan-validation integration**:
- **SHOULD** run before committing
- Ensures consistent code style
- Required by most CI/CD linters

**Equivalent terraform command**:
```bash
terraform fmt ./envs/dev
terraform fmt -check ./envs/dev
```

---

#### `make validate`
Validates Terraform configuration syntax and consistency.

```bash
make validate       # Validate configuration
```

**Pre-plan-validation integration**:
- **MUST** pass before running plan
- Catches syntax errors, variable mismatches, resource conflicts
- Fast check (doesn't hit AWS API)

**Equivalent terraform command**:
```bash
terraform -chdir=envs/dev validate
```

---

#### `make lint`
Runs tflint static analysis checks.

```bash
make lint           # Run tflint on current environment
```

**Pre-plan-validation integration**:
- Optional but recommended (depends on tflint availability)
- Catches best practice violations
- Can identify security issues

**Equivalent terraform command**:
```bash
tflint --init                          # First run only
tflint ./envs/dev
```

---

### Planning & Inspection

#### `make plan` or `make plan-dev`
Generates and displays execution plan without applying.

```bash
make plan           # Plan current environment (requires ENV)
make plan-dev       # Plan development
make plan-stage     # Plan staging
make plan-prod      # Plan production
```

**Pre-plan-validation integration**:
- **RUN** pre-plan-validation first to catch issues early
- Use this to verify actual replacement risks
- Save output: `make plan > plan.txt`

**Typical workflow**:
```bash
./scripts/structure-detector.sh envs/prod
./scripts/detect-hardcodes.sh envs/prod
./scripts/replacement-detector.sh envs/prod
# Review output...
make plan-prod
# Review plan for "must replace" messages
```

**Equivalent terraform command**:
```bash
terraform -chdir=envs/prod plan
```

---

#### `make plan-json`
Outputs plan in machine-readable JSON format (useful for automation).

```bash
make plan-json > plan.json
```

**Pre-plan-validation integration**:
- Enables automated analysis of replacements
- Can parse with jq to find resource changes
- Useful for CI/CD automation

---

### Applying Changes

#### `make apply` or `make apply-PROD`
Applies Terraform plan to infrastructure.

```bash
make apply          # Apply current environment (requires ENV)
make apply-dev      # Apply development
make apply-stage    # Apply staging
make apply-prod     # Apply production (may have approval gates)
```

**Pre-plan-validation integration**:
- **PRE-REQUISITE**: Run pre-plan-validation before this
- Production often requires human approval
- May have additional safety gates

**Safe apply workflow**:
```bash
# 1. Run all pre-plan checks
make fmt            # Format check
make validate       # Syntax check
./scripts/structure-detector.sh envs/prod
./scripts/detect-hardcodes.sh envs/prod
./scripts/replacement-detector.sh envs/prod

# 2. Review terraform plan
make plan-prod

# 3. Search for destructive changes
make plan-prod | grep "must replace"

# 4. If safe, apply
make apply-prod
```

---

### Destruction & Cleanup

#### `make destroy` or `make destroy-PROD`
Destroys all Terraform-managed infrastructure. **USE WITH CAUTION**.

```bash
make destroy        # Destroy current environment (requires ENV)
make destroy-dev    # Destroy development
# Production likely has fail-safes
```

**Pre-plan-validation integration**:
- Validates before destroy in safe environments
- Production should use `prevent_destroy = true` on critical resources
- Requires explicit confirmation

---

### Environment-Specific Targets

#### Format by Environment
```bash
make fmt-dev
make fmt-stage
make fmt-prod

make validate-dev
make validate-stage
make validate-prod

make lint-dev
make lint-stage
make lint-prod
```

---

## Makefile Variables

Key variables that control behavior:

### `ENV` (Environment Variable)
Specifies target environment (dev, stage, prod).

```bash
ENV=dev make plan           # Plan development
ENV=stage terraform init    # Initialize chdir uses ENV
ENV=prod make apply         # Apply production
```

### `TERRAFORM_VARS` or `TF_VARS`
Additional Terraform variables (if defined in Makefile).

```bash
make plan-dev TF_VARS="-var=instance_count=5"
```

### `TARGETS` (Selective Apply)
Some Makefiles support targeting specific resources.

```bash
make plan-dev TARGETS="-target=aws_rds_instance.main"
```

Check your project's Makefile for supported variables.

---

## Pre-Plan-Validation Workflow

### Recommended Command Sequence

**Before Running `terraform plan`**:

1. **Format Check** (ensures consistency)
   ```bash
   make fmt-check
   ```
   If fails: `make fmt` to auto-fix

2. **Syntax Validation** (quick safety check)
   ```bash
   make validate
   ```
   Must pass

3. **Structural Analysis** (repository organization)
   ```bash
   ./scripts/structure-detector.sh envs/prod
   ```
   Review recommendations

4. **Hardcode Detection** (security check)
   ```bash
   ./scripts/detect-hardcodes.sh envs/prod
   ```
   Fix CRITICAL issues before proceeding

5. **Replacement Risk Detection** (downtime assessment)
   ```bash
   ./scripts/replacement-detector.sh envs/prod
   ```
   Review HIGH/MEDIUM risks

6. **Linting** (optional, best practices)
   ```bash
   make lint
   ```

7. **Terraform Plan** (actual AWS diff)
   ```bash
   make plan > tfplan.txt
   grep "must replace" tfplan.txt  # Check for destructive changes
   ```

8. **Review & Approval**
   - Check for "must replace" on critical resources
   - Verify destruction prevention is active
   - Get infrastructure team sign-off

9. **Apply** (if approved)
   ```bash
   make apply
   ```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Terraform Validation

on: [pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Terraform
        uses: hashicorp/setup-terraform@v2
      
      - name: Format Check
        run: make fmt-check ENV=prod
      
      - name: Validate
        run: make validate ENV=prod
      
      - name: Pre-plan Validation
        run: |
          ./scripts/structure-detector.sh envs/prod
          ./scripts/detect-hardcodes.sh envs/prod
          ./scripts/replacement-detector.sh envs/prod
      
      - name: Plan
        run: make plan-prod
```

### GitLab CI Example

```yaml
terraform_plan:
  stage: plan
  script:
    - make fmt-check ENV=prod
    - make validate ENV=prod
    - ./scripts/structure-detector.sh envs/prod
    - ./scripts/detect-hardcodes.sh envs/prod
    - ./scripts/replacement-detector.sh envs/prod
    - make plan-prod
```

---

## Makefile Template

If your project doesn't have a Makefile, use this template:

```makefile
.PHONY: init validate fmt lint plan apply destroy

# Default environment
ENV ?= dev

# Targets by environment
init:
	terraform -chdir=envs/$(ENV) init

validate:
	terraform -chdir=envs/$(ENV) validate

fmt:
	terraform fmt -recursive ./envs/$(ENV)

fmt-check:
	terraform fmt -recursive -check ./envs/$(ENV)

lint:
	tflint ./envs/$(ENV)

plan:
	terraform -chdir=envs/$(ENV) plan -out=tfplan

plan-json:
	terraform -chdir=envs/$(ENV) plan -json

apply:
	terraform -chdir=envs/$(ENV) apply tfplan

destroy:
	terraform -chdir=envs/$(ENV) destroy

# Environment-specific shortcuts
init-dev: ENV=dev
init-dev: init

init-stage: ENV=stage
init-stage: init

init-prod: ENV=prod
init-prod: init

plan-dev: ENV=dev
plan-dev: plan

plan-stage: ENV=stage
plan-stage: plan

plan-prod: ENV=prod
plan-prod: plan

apply-dev: ENV=dev
apply-dev: apply

apply-stage: ENV=stage
apply-stage: apply

apply-prod: ENV=prod
apply-prod: apply
```

---

## Troubleshooting

### "make: command not found"
Make is not installed. On macOS:
```bash
brew install make
# or use: gmake (GNU make)
```

### "Makefile not found"
Current directory doesn't have Makefile. Navigate to project root:
```bash
cd /Volumes/STOREROOM/☁️\ AWS\ .../aws-terraform-simple-ecommerce
make plan
```

### "ENV variable not found"
Makefile expects to find terraform in envs/{ENV}. Check structure:
```bash
ls -la envs/      # Should show dev/, stage/, prod/
make plan ENV=dev
```

### Backend Lock Error
Another user or process holds the state lock:
```bash
# Check lock status
terraform -chdir=envs/prod force-unlock <LOCK_ID>  # Use with caution
```

---

## Best Practices

1. **Always run validation sequence before plan**: Catches issues early
2. **Use Makefile targets**: Ensures consistent command format
3. **Review plan output**: Look for "must replace" or "destroy"
4. **Test in non-prod first**: dev → stage → prod progression
5. **Keep Makefile in version control**: Team consistency
6. **Document custom targets**: Add comments to Makefile
7. **Use environment variables**: Don't hardcode paths/regions

---

## See Also

- [SKILL.md](../SKILL.md) - Pre-plan-validation workflow
- [terraform-aws-module skill](../../terraform-aws-module/) - Creating compliant modules
- [aws-iac-review skill](../../aws-iac-review/) - Security-focused code review
