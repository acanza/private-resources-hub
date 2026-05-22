---
name: aws-iac-review
description: 'Review AWS Infrastructure-as-Code changes for security risks: IAM over-permissioning, public exposure, encryption, logging, risky replacements. Use when: reviewing Terraform/CloudFormation PRs, conducting security audits, validating production infrastructure changes, preventing security regressions.'
argument-hint: 'File path to review (e.g., modules/rds/main.tf) or "all" for full audit'
---

# AWS IaC Security Review

## When to Use

- **Pull Request Review**: Before merging infrastructure changes
- **Security Audit**: Validating new or modified AWS resources
- **Change Control**: Verifying production infrastructure modifications
- **Onboarding**: Reviewing IaC from team members or contractors
- **Compliance Check**: Ensuring changes meet security standards
- **Post-Incident**: Understanding what configuration change introduced a vulnerability

## What This Skill Provides

A comprehensive security-focused code review workflow for AWS Infrastructure-as-Code that checks five critical risk categories:

1. **IAM Over-Permissioning** — Detect overly broad permissions, missing least-privilege constraints
2. **Public Exposure** — Flag unintended public accessibility and open security groups
3. **Encryption** — Ensure encryption at-rest and in-transit, encryption key management
4. **Logging** — Verify audit trail enablement, CloudWatch/VPC Flow Logs configuration
5. **Risky Resource Replacement** — Identify changes that could cause data loss or service disruption

## Procedure

### Step 1: Prepare Code and Context
Identify the Terraform/CloudFormation files to review:
- Specific module (e.g., `modules/rds/`)
- Changed files from a git diff
- Entire environment (e.g., `envs/prod/`)

Gather related information:
- Purpose of the changes
- Environment (dev/stage/prod)
- Expected blast radius
- Approval requirements

### Step 2: Run Automated Security Scan
Execute [iac-review.sh](./scripts/iac-review.sh) to perform pattern matching:
```bash
./scripts/iac-review.sh modules/rds
```

The script scans for:
- `"*"` in IAM effect statements and resources
- `publicly_accessible = true`, `map_public_ip_on_launch = true`
- Missing encryption flags on storage resources
- Disabled logging on auditable services
- Force destroy, delete protection disabled on critical resources
- Hardcoded security group open ingress rules

**Output**: Machine-readable findings with severity levels (CRITICAL, HIGH, MEDIUM, INFO)

### Step 3: Review IAM Permissions Manually
Use [iam-permission-checklist.md](./assets/iam-permission-checklist.md) to:
- Enumerate all IAM policies and roles in the change
- Verify each action is necessary for the intended function
- Check for wildcard actions (`s3:*`, `ec2:*`)
- Validate resource constraints (ARNs, conditions)
- Confirm service roles use specific assume policy conditions
- Review inline policies (prefer managed policies)

Example decision points:
- Does the function really need `s3:*` or can it be `s3:GetObject`?
- Is the resource wildcard `*` needed, or should it be `arn:aws:s3:::my-bucket/*`?
- Should conditions limit to specific IP ranges, VPC, or MFA?

### Step 4: Audit Public Exposure Points
Check for unintended public accessibility:

✅ **Resources that SHOULD be public**:
- CloudFront distribution
- API Gateway endpoint
- Load balancer for public API
- S3 bucket for static website

❌ **Resources that should NEVER be public**:
- RDS database
- ElastiCache cluster
- Bastion host SSH (unless restricted by CIDR)
- DynamoDB table
- Lambda functions handling secrets
- Private subnet instances

Review [public-exposure-guide.md](./references/public-exposure-guide.md) for patterns.

### Step 5: Validate Encryption Configuration
Verify all data protection in place:

| Service | At-Rest | In-Transit | KMS Key Management |
|---------|---------|------------|-------------------|
| RDS | `storage_encrypted = true` | Force SSL/TLS | Customer managed KMS |
| EBS | `encrypted = true` | N/A | Customer managed KMS |
| S3 | `server_side_encryption_configuration` | Enforce HTTPS via bucket policy | Customer managed KMS |
| DynamoDB | `sse_specification.enabled = true` | N/A | AWS managed or customer key |
| Secrets Manager | Always encrypted | HTTPS required | Customer managed KMS |

### Step 6: Check Logging Configuration
Ensure audit trails exist for compliance:

| Service | Logging Type | Configuration | Requirement |
|---------|--------------|---------------|------------|
| RDS | CloudWatch | `enabled_cloudwatch_logs_exports` | All log types |
| Lambda | CloudWatch | IAM role with logs:CreateLogGroup | Auto via default role |
| VPC | VPC Flow Logs | IAM role, CloudWatch Logs group | Enable for prod |
| S3 | Server access logging | Logging destination bucket | Audit trail for access |
| ALB/NLB | Access logs | S3 bucket | Production deployments |
| CloudTrail | API logging | S3 + CloudWatch | Account-wide recommended |

### Step 7: Identify Risky Resource Replacements
Check for changes that force replacement:

✅ **Safe Changes**:
- Updating security group description
- Adding new tags
- Enabling enhanced monitoring
- Modifying non-critical parameters

⚠️ **Risky Changes** (require approval):
- Changing database identifier (forces RDS replacement)
- Modifying VPC or subnet CIDR (forces re-recreation)
- Changing KMS key for encrypted resource
- Modifying instance type with delete protection
- Removing final snapshot configuration

**How to identify**:
- Run `terraform plan -out=tfplan` and look for `(forces new resource)` annotations
- Check [replacement-guide.md](./references/replacement-guide.md) for service-specific behaviors

### Step 8: Prepare Review Findings
Collect findings into categories:

**CRITICAL** (block merge):
- Hardcoded credentials
- Public database access
- Overly broad IAM (`*` on wildcard resources)
- Disabled encryption on sensitive data
- Missing logging on audit-required services

**HIGH** (requires discussion):
- Risky replacements without approval
- Missing backup configuration
- Insufficient logging granularity
- Over-permissioned service roles

**MEDIUM** (should fix):
- Inconsistent tagging
- Missing cost allocation tags
- Non-standard naming conventions
- Incomplete variable documentation

**INFO** (nice to have):
- Documentation improvements
- Optimization suggestions
- Code style consistency

### Step 9: Generate Review Report
Use the [security-review-template.md](./assets/security-review-template.md) to document findings in a standardized format suitable for pull request comments or security audit records.

## Quick Reference: The Five Checks

### 1. IAM — Principle of Least Privilege
```hcl
# ❌ WRONG: Wildcard actions and resources
policy_document = {
  Action   = ["s3:*"]
  Resource = "*"
}

# ✅ RIGHT: Specific action and resource
policy_document = {
  Action   = ["s3:GetObject"]
  Resource = "arn:aws:s3:::my-bucket/documents/*"
}
```

### 2. Public Exposure — Restrict by Default
```hcl
# ❌ WRONG: Public database
resource "aws_db_instance" "main" {
  publicly_accessible = true
}

# ✅ RIGHT: Private database in VPC
resource "aws_db_instance" "main" {
  publicly_accessible = false
  db_subnet_group_name = aws_db_subnet_group.private.name
}
```

### 3. Encryption — Always On
```hcl
# ❌ WRONG: No encryption
resource "aws_ebs_volume" "data" {
  # encrypted not specified, defaults to false
}

# ✅ RIGHT: Encrypted with customer key
resource "aws_ebs_volume" "data" {
  encrypted  = true
  kms_key_id = aws_kms_key.ebs.arn
}
```

### 4. Logging — Audit Everything
```hcl
# ❌ WRONG: No logging
resource "aws_rds_cluster" "main" {
  # No enabled_cloudwatch_logs_exports
}

# ✅ RIGHT: All logs enabled
resource "aws_rds_cluster" "main" {
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
}
```

### 5. Risky Replacement — Plan Review Required
```hcl
# ❌ WRONG: Identifies will change (forces new RDS)
resource "aws_db_instance" "main" {
  identifier = "db-${local.version}"  # Changes on every version update
}

# ✅ RIGHT: Stable identifier
resource "aws_db_instance" "main" {
  identifier = "production-db"
  skip_final_snapshot = false
  final_snapshot_identifier = "prod-db-snapshot-${timestamp()}"
}
```

## Example: Complete Review Workflow

```bash
# 1. Run automated scan
./scripts/iac-review.sh modules/rds

# 2. Review plan with attention to replacements
cd modules/rds && terraform plan -out=tfplan && terraform show tfplan

# 3. Manual checklist review using assets/iam-permission-checklist.md
# → Check RDS IAM role has only describe and modify permissions

# 4. Verify encryption
# → Check storage_encrypted = true, kms_key_id set

# 5. Verify logging
# → Check enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

# 6. Verify no public exposure
# → Check publicly_accessible = false, db_subnet_group set

# 7. Generate report
# → Use security-review-template.md for PR comment

# 8. Approval
# → Security team approves, merge with confidence
```

## Related Resources

- [IAM Permission Checklist](./assets/iac-permission-checklist.md) — Step-by-step IAM review
- [Public Exposure Guide](./references/public-exposure-guide.md) — Services, exposure vectors, fixes
- [Encryption Patterns](./references/encryption-patterns.md) — Service-by-service encryption validation
- [Logging Best Practices](./references/logging-best-practices.md) — Audit trail setup for each service
- [Replacement Risk Guide](./references/replacement-guide.md) — Identifying dangerous resource changes
- [Review Script](./scripts/iac-review.sh) — Automated pattern matching tool
- [Review Template](./assets/security-review-template.md) — Standardized report format

## Discovery Triggers

- "review Terraform security"
- "audit AWS IaC changes"
- "check for IAM over-permissions"
- "review public exposure"
- "validate encryption"
- "security code review"
- "terraform PR review"
