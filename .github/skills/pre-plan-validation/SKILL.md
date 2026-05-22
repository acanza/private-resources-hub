---
name: pre-plan-validation
description: 'Pre-plan validation for Terraform on AWS. Use when: before running terraform plan, preparing infrastructure changes, finalizing Terraform modifications, validating consistency and safety of IaC changes. Inspects repo structure, version constraints, naming conventions, hardcoded values, and replacement risks.'
argument-hint: 'Path to validate (e.g., modules/rds, envs/prod) or "." for current'
---

# Terraform Pre-Plan Validation

## When to Use

- **Before running `terraform plan`**: Catch issues early, before code review
- **Finalizing infrastructure changes**: Before committing or pushing to git
- **Consistency check**: Verify new code follows project conventions
- **Safety validation**: Identify possible destructive changes or risky configurations
- **Onboarding**: Validate that new team members' changes are project-aligned
- **CI/CD gate**: Pre-merge validation step to prevent bad plans

## What This Skill Provides

A structured **safety-first validation workflow** that runs before Terraform plan, ensuring:

1. **Structural Consistency** — Code follows repo patterns and conventions
2. **Version Safety** — Provider and Terraform versions explicitly pinned
3. **Naming Alignment** — Variables, outputs, locals match project style
4. **Value Parameterization** — No hardcoded secrets, region-specific IDs, or environment values
5. **Minimal Diffs** — Changes are small, focused, reversible
6. **Replacement Awareness** — Identifies destructive changes early
7. **Formatting & Validation** — Code passes checks before planning

## Procedure

### Step 1: Identify Repository Structure

Understand where your changes belong and verify existing conventions.

**Determine Structure Type**:
```bash
# Check if project uses Terraform directory layout
ls -la
# Expected:
# • modules/          (reusable infrastructure blocks)
# • envs/             (environment-specific configurations)
# • shared/           (cross-environment resources)
# • Makefile          (optional but preferred for command orchestration)
# • terraform.tf/.    (top-level or per-environment provider config)
```

**Locate your change**:

| Change type | Location | Scope |
|-------------|----------|-------|
| **New service/component** | `modules/<service>/` | Reusable across environments |
| **Environment-specific config** | `envs/<env>/` | Single environment only |
| **Shared infrastructure** | `shared/` or `modules/` | Cross-environment common |
| **Variable/provider defaults** | Root or `envs/` | Varies by structure |

**Questions to answer**:
- [ ] Does my change belong in `modules/` (reusable) or `envs/` (environment-specific)?
- [ ] Are there existing similar resources I should follow as pattern reference?
- [ ] Does this change affect multiple environments (if yes, likely `modules/`)?

**Understanding the repo structure** → Use [structure-detector.sh](./scripts/structure-detector.sh) to analyze:
```bash
./.github/skills/pre-plan-validation/scripts/structure-detector.sh .
# Output: Directory tree, identified pattern, recommendations
```

### Step 2: Verify Version Pinning

Ensure Terraform and AWS provider versions are EXPLICITLY constrained (not relying on defaults).

**Check for version constraints**:
```bash
# Look for terraform.tf or main.tf in your directory
cd modules/rds  # or envs/prod, etc.

# Required patterns:
grep -r "required_version" .
grep -r "required_providers" .
grep -r 'source.*=.*"hashicorp/aws"' .
```

**must-haves**:

✅ **CORRECT**: Explicit version constraints
```hcl
terraform {
  required_version = ">= 1.5, < 2.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

❌ **WRONG**: No version pinning (dangerous in CI/CD)
```hcl
terraform {
  # Missing required_version and required_providers!
}
```

**Questions to answer**:
- [ ] Does `terraform.tf` (or `main.tf`) include `required_version`?
- [ ] Does `required_version` have both min and max bounds?
- [ ] Does `required_providers` pin `aws` provider version?
- [ ] Is AWS provider version `~> 5.x` (or your org's standard)?
- [ ] If using other providers (postgresql, null, random), are they pinned?

**What to do if missing**:
```bash
# Add/update terraform.tf in your module or environment directory
cat > terraform.tf << 'EOF'
terraform {
  required_version = ">= 1.5, < 2.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
EOF
```

### Step 3: Check Naming and Variable Consistency

Verify your code aligns with project naming conventions and variable patterns.

**Inspect existing patterns**:
```bash
# List all variables across modules
find modules -name "variables.tf" | xargs grep "variable" | head -20

# List all outputs
find modules -name "outputs.tf" | xargs grep "output" | head -20

# Check naming style (snake_case, descriptive, etc.)
grep "variable \"" modules/*/variables.tf | cut -d'"' -f2 | sort | uniq
```

**Common conventions** (verify your project uses these):

| Element | Convention | Example |
|---------|-----------|---------|
| Variables | `snake_case`, descriptive | `db_instance_class`, `enable_encryption` |
| Outputs | `snake_case`, descriptive | `db_endpoint`, `instance_id` |
| Locals | `snake_case` | `common_tags`, `service_port` |
| Resources | `resource_name_short` | `aws_db_instance` → `.main` |
| Resource names | `module_name` prefix | `${var.module_name}-db` |

**Checklist**:
- [ ] Are my `variable` names consistent with existing variables?
- [ ] Do my variables have `description`, `type`, and `default` (if optional)?
- [ ] Are my outputs named clearly and described?
- [ ] Do I use `var.module_name` consistently for resource naming?
- [ ] Are locals used to avoid repetition (DRY principle)?
- [ ] Are tags consistent with existing `default_tags` pattern?

**Validation**: Use [naming-validator.sh](./scripts/naming-validator.sh):
```bash
./.github/skills/pre-plan-validation/scripts/naming-validator.sh modules/myservice
# Output: Naming consistency report, suggestions for fixes
```

### Step 4: Detect Hardcoded Values and Secrets

Find unparameterized values that should be variables, especially secrets, ARNs, and account-specific data.

**Scan for common patterns**:

❌ **Hardcoded Secrets**:
- Passwords: `password = "MyFixedPass"`
- API Keys: `api_key = "sk_live_abc123"`
- AWS credentials: `AKIA...` patterns

❌ **Hardcoded Environment-Specific Values**:
- Account IDs: `"123456789012"`
- Regions: `available_zone = "us-east-1a"`
- ARNs: `arn:aws:iam::123456789012:role/...`
- Environment names: `name = "prod-db"` (should be `${var.environment}-db`)

❌ **Over-Specific Names**:
- Instance identifiers: `db_identifier = "customer-prod-db"` (should parameterize)
- S3 bucket names: `bucket = "company-logs-2024"` (should be variable)

**Run automated detection**:
```bash
./.github/skills/pre-plan-validation/scripts/detect-hardcodes.sh modules/myservice
# Output: List of findings with severity (CRITICAL, HIGH, MEDIUM)
```

**Manual inspection checklist**:
- [ ] No `password = "..."` literals (use variables or AWS Secrets Manager)
- [ ] No AWS account IDs hard-coded (use `data.aws_caller_identity.current.account_id`)
- [ ] No region hard-coded (use `var.aws_region`)
- [ ] No environment names in resource IDs (use `var.environment`)
- [ ] No time-based identifiers like `timestamp()` in resource names (causes replacement)
- [ ] All resource names use `var.module_name` or appropriate variables

**Example fixes**:

❌ **WRONG**:
```hcl
resource "aws_db_instance" "main" {
  identifier = "prod-customer-db"
  password   = "MyFixedPassword123"
  
  tags = {
    Environment = "production"
  }
}
```

✅ **CORRECT**:
```hcl
variable "environment" {
  type = string
}

variable "module_name" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

resource "aws_db_instance" "main" {
  identifier = "${var.module_name}-db"
  password   = var.db_password
  
  tags = {
    Environment = var.environment
  }
}
```

### Step 5: Identify Possible Resource Replacements

Scan for changes that will cause Terraform to destroy and recreate resources (potentially destructive).

**Risk indicators**:

🔴 **CRITICAL — Will Force Replacement**:
- RDS `identifier` changed
- VPC `cidr_block` changed
- S3 `bucket` name changed
- DynamoDB table `name` changed
- Subnet `availability_zone` changed

🟡 **MEDIUM — May Force Replacement**:
- Security group `name` changed (use name_prefix instead)
- KMS key attributes modified
- Engine version changes on databases

**Detection**:
```bash
# Method 1: Use terraform plan (if safe to run)
cd modules/myservice
terraform plan -out=tfplan
terraform show tfplan | grep "forces new resource"

# Method 2: Automated check
./.github/skills/pre-plan-validation/scripts/replacement-detector.sh modules/myservice
```

**Checklist — Red flags to investigate**:
- [ ] Did I change a resource `name` or `identifier`? (likely replacement)
- [ ] Did I change a network-related attribute (CIDR, AZ)? (replacement risk)
- [ ] Did I change a KMS key ID for encrypted resource? (replacement risk)
- [ ] Did I change engine version? (may cause replacement)
- [ ] Did I enable/disable encryption on existing resource? (replacement)

**If replacement detected**:
1. Document why replacement is necessary
2. Get approval before proceeding (see [replacement-guide.md](../references/replacement-guide.md) from aws-iac-review skill)
3. Ensure backups exist (for databases, snapshots configured)
4. Plan maintenance window with team notification

### Step 6: Run Formatting and Validation

Execute checks to ensure code is syntactically correct and consistently formatted.

**Recommended sequence** (check if Makefile exists for shortcuts):

```bash
# Option 1: Using Makefile (preferred if available)
make fmt      # or make format
make validate
make lint     # if tflint available

# Option 2: Manual Terraform commands
cd modules/myservice

# 1. Format code
terraform fmt -check
terraform fmt  # Fix formatting in-place

# 2. Validate syntax
terraform validate

# 3. Lint (if available, improves code quality)
tflint
```

**Interpretation**:

| Command | Success | Failure | What to do |
|---------|---------|---------|-----------|
| `terraform fmt -check` | No changes needed | Files need formatting | Run `terraform fmt` |
| `terraform validate` | Valid syntax | Syntax errors | Fix errors shown |
| `tflint` | All checks pass | Violations found | Review and fix (optional but recommended) |

**Questions to answer**:
- [ ] Does `terraform fmt -check` pass (or would `terraform fmt` make changes)?
- [ ] Does `terraform validate` pass without errors?
- [ ] Does `tflint` pass (if you use it)?
- [ ] Are there any deprecation warnings?

### Step 7: Prepare Plan Output and Summarize Findings

Document your pre-validation assessment and indicate if `terraform plan` is safe to run.

**Create a summary report** using the [validation-summary-template.md](./assets/validation-summary-template.md):

```
## Pre-Plan Validation Summary

**Module/Environment**: modules/rds  
**Validator**: @username  
**Date**: 2024-03-30  

### 1. Structural Issues
- ✅ Correctly placed in modules/ (reusable)
- ✅ Follows existing module patterns
- ⚠️ Missing terraform.tf (added in validation)

### 2. Safety Issues  
- ✅ No hardcoded secrets
- ✅ No account IDs hard-coded
- ⚠️ Environment name hard-coded (should use var.environment)

### 3. Validation Status
- ✅ terraform fmt: PASS
- ✅ terraform validate: PASS
- ✅ tflint: PASS (3 info messages)

### 4. Possible Plan Risks
- ✅ No detected resource replacements
- ✅ No breaking changes
- ✅ Small, focused diff

### 5. Next Recommended Action
**Status**: ✅ **SAFE TO PLAN**

Run: `terraform -chdir=modules/rds plan`

Approval needed for: None  
Post-plan review focus: Variable defaults, security group rules
```

**What to include**:
- [ ] Structural assessment (where code should be, existing patterns)
- [ ] Safety findings (hardcodes, secrets, risky values)
- [ ] Validation status (fmt, validate, lint results)
- [ ] Replacement risks (forces new resource detection)
- [ ] Clear recommendation (SAFE TO PLAN vs. NEEDS FIXES)
- [ ] Specific next steps (exact terraform command or fixes needed)

## Quick Reference: Pre-Plan Checklist

Run this before requesting `terraform plan`:

- [ ] **Structure**: Change in appropriate directory (modules/ for reusable, envs/ for environment-specific)
- [ ] **Versions**: terraform.tf includes `required_version` and `required_providers` with pinned versions
- [ ] **Naming**: Variable/output names follow snake_case and project conventions
- [ ] **Parameterization**: No hardcoded secrets, account IDs, regions, or environment names
- [ ] **Replacements**: No detected forced resource replacements
- [ ] **Formatting**: `terraform fmt -check` passes
- [ ] **Validation**: `terraform validate` passes
- [ ] **Linting**: No critical tflint errors
- [ ] **Documentation**: Variables, outputs have descriptions
- [ ] **Summary**: Pre-plan validation report completed

## Example: Full Validation Workflow

```bash
# 1. Detect repo structure and conventions
./.github/skills/pre-plan-validation/scripts/structure-detector.sh .

# 2. Add version constraints if missing
cd modules/myservice
# (add terraform.tf if needed)

# 3. Check naming consistency
../../scripts/naming-validator.sh .

# 4. Scan for hardcoded values
../../scripts/detect-hardcodes.sh .

# 5. Check for replacements
../../scripts/replacement-detector.sh .

# 6. Format, validate, lint
terraform fmt
terraform validate

# 7. Create validation summary
# (use template from assets/validation-summary-template.md)

# 8. Safe to plan!
terraform plan -out=tfplan
terraform show tfplan
```

## Related Resources

- [Structure-Detector Script](./scripts/structure-detector.sh) — Analyze repo layout
- [Naming-Validator Script](./scripts/naming-validator.sh) — Check naming consistency
- [Hardcode Detection Script](./scripts/detect-hardcodes.sh) — Find parameterization issues
- [Replacement-Detector Script](./scripts/replacement-detector.sh) — Identify destructive changes
- [Validation Summary Template](./assets/validation-summary-template.md) — Report format
- [Makefile Commands Reference](./references/makefile-commands.md) — Project build orchestration
- [AWS IaC Review Skill](../../aws-iac-review) — Deep security validation (after plan)
- [Terraform Module Skill](../../terraform-aws-module) — Scaffolding new modules

## Discovery Triggers

- "validating terraform changes"
- "before terraform plan"
- "check terraform consistency"
- "terraform pre-flight checklist"
- "safety validation"
- "naming conventions"
- "hardcoded values"
- "resource replacement risk"
- "version pinning"
