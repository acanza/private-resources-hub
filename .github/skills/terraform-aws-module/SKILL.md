---
name: terraform-aws-module
description: 'Scaffold new Terraform AWS modules with version pinning, documented variables/outputs, secret safety checks, and automated validation. Use when: creating new infrastructure modules, enforcing Terraform best practices, setting up reusable AWS resource blocks.'
argument-hint: 'Module name (e.g., rds, lambda, s3-bucket)'
---

# Terraform AWS Module Scaffolding

## When to Use

- Creating a new reusable Terraform module in the `modules/` directory
- Enforcing consistent module structure and AWS best practices
- Setting up projects with version-pinned dependencies and documented interfaces
- Ensuring secrets are never hardcoded and validation runs before completion

## What This Skill Provides

A complete workflow to scaffold production-ready Terraform modules that:
- Generate boilerplate files (main.tf, variables.tf, outputs.tf, terraform.tf)
- Enforce provider and Terraform version pinning
- Create comprehensive variable and output documentation
- Validate no hardcoded secrets or sensitive data
- Run formatting, validation, and plan checks before finishing

## Procedure

### Step 1: Define Module Metadata
Provide the module name and AWS service it manages (e.g., "rds", "lambda", "alb"). The script validates the module does not already exist.

### Step 2: Generate Module Structure
Run [scaffold-module.sh](./scripts/scaffold-module.sh) to create the directory and core files:
- `terraform.tf` — Provider and version constraints
- `variables.tf` — Input variables with descriptions and type validation
- `outputs.tf` — Exported values with descriptions
- `main.tf` — Resource definitions (template)

### Step 3: Customize Resource Blocks
Open `modules/<module-name>/main.tf` and add AWS resource definitions. Reference the [module template](./assets/module-template.tf) and [best practices guide](./references/best-practices.md) for patterns.

### Step 4: Document Variables and Outputs
- Ensure every variable in `variables.tf` has `description`, `type`, and `default` (if optional)
- Ensure every output in `outputs.tf` has `description` and matches a resource attribute
- Use the [documentation template](./assets/variables-template.tf) as reference

### Step 5: Validate for Security
Run [validate-secrets.sh](./scripts/validate-secrets.sh) to scan for:
- Hardcoded values (API keys, passwords)
- Default AWS credentials patterns
- Unsafe file references
- Database passwords or connection strings

### Step 6: Run Terraform Checks
Execute validation workflow:
```bash
cd modules/<module-name>
terraform fmt -check        # Check formatting
terraform validate          # Validate configuration
terraform plan -out=tfplan  # Generate plan (review before apply)
```

### Step 7: Review and Complete
- Verify plan output matches intended resources
- Confirm no sensitive values in logs or plan
- Commit module to version control
- Document module in root `README.md` with usage example

## Example: Scaffolding an RDS Module

```bash
# Invoke skill with module name
# The scaffold-module.sh script creates:
modules/rds/
├── terraform.tf       (AWS provider 5.x, Terraform >= 1.5)
├── variables.tf       (db_engine, db_instance_class, ...)
├── outputs.tf         (endpoint, port, resource_id, ...)
└── main.tf            (aws_db_instance resource template)

# Then customize main.tf with RDS-specific configuration
# Run validation to ensure no hardcoded secrets
# Test with terraform plan
```

## Quick Reference

| Task | Command |
|------|---------|
| Scaffold module | `./scripts/scaffold-module.sh <module-name> <aws-service>` |
| Check secrets | `./scripts/validate-secrets.sh modules/<module-name>` |
| Format code | `terraform fmt modules/<module-name>` |
| Validate | `terraform -chdir=modules/<module-name> validate` |
| Plan | `terraform -chdir=modules/<module-name> plan` |

## Related Resources

- [Best Practices Guide](./references/best-practices.md) — AWS and Terraform conventions
- [Module Template](./assets/module-template.tf) — Resource boilerplate
- [Variables Template](./assets/variables-template.tf) — Input/output patterns
- [Scaffold Script](./scripts/scaffold-module.sh) — Automated module generation
