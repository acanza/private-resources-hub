# AWS IaC Security Review Report

**Date**: [YYYY-MM-DD]  
**Reviewed By**: [@user]  
**Files Reviewed**: [list files or provide PR link]  
**Environment**: [dev/stage/prod]  
**Approval Status**: ⏳ **Pending** / ✅ **Approved** / ❌ **Blocked**

---

## Executive Summary

**Risk Level**: 🔴 **CRITICAL** / 🟠 **HIGH** / 🟡 **MEDIUM** / 🟢 **LOW**

[1-2 sentence summary of findings and overall recommendation]

**Recommendation**: 
- [ ] Approve and merge
- [ ] Request changes and re-review
- [ ] Block pending security sign-off

---

## 1. IAM Over-Permissioning

### Findings

**CRITICAL Issues**:
- [ ] [Issue description, file location, code snippet]
  - **Why it matters**: [Impact if compromised]
  - **Fix**: [Recommended action]

**HIGH Issues**:
- [ ] [Issue description]
  - **Why it matters**: [Impact]
  - **Fix**: [Recommended action]

### Questions for Author

1. Does the service really need `[action]` permission?
2. Why is the Resource set to `*` instead of a specific ARN?
3. Is there a managed policy that covers this use case?

### IAM Review Checklist

- [ ] All Actions are specific (no `*` wildcards)
- [ ] All Resources are scoped (no unrestricted `*`)
- [ ] No `AdministratorAccess` unless for break-glass
- [ ] Assume policy (trust) is properly restricted
- [ ] Service assumes role, not human user (if applicable)
- [ ] Conditions restrict scope (IP, VPC, time) where appropriate

**Example of Required Fix**:

```hcl
# BEFORE (Over-permissioned)
policy = jsonencode({
  Action = ["s3:*"]
  Resource = "*"
})

# AFTER (Least privilege)
policy = jsonencode({
  Action = [
    "s3:GetObject",
    "s3:ListBucket"
  ]
  Resource = [
    "arn:aws:s3:::my-bucket",
    "arn:aws:s3:::my-bucket/data/*"
  ]
})
```

---

## 2. Public Exposure

### Findings

**CRITICAL Issues**:
- [ ] RDS database with `publicly_accessible = true`
  - **Why**: Exposes database to internet attacks, violates PCI/HIPAA
  - **Fix**: Set to `false`, place in private VPC

**HIGH Issues**:
- [ ] Security group with ingress from `0.0.0.0/0` on port 3306 (MySQL)
  - **Why**: Opens database to brute force attacks
  - **Fix**: Restrict to application security group or specific CIDR

**MEDIUM Issues**:
- [ ] Subnet with `map_public_ip_on_launch = true`
  - **Why**: Unintended public IPs on private resources
  - **Fix**: Should be `false` for private subnets

### Public Exposure Checklist

- [ ] No `publicly_accessible = true` on databases
- [ ] No `0.0.0.0/0` ingress on ports < 1024 (privileged)
- [ ] No `0.0.0.0/0` ingress on data services (RDS, DynamoDB, Redis)
- [ ] No `::/0` IPv6 rules on sensitive services
- [ ] S3 bucket policy does not allow public access (unless intentional static site)
- [ ] Load balancers are public, databases/caches are private
- [ ] Bastion/jump server SSH restricted to corporate IPs or VPN

**Services that SHOULD be public**:
- CloudFront distribution
- API Gateway endpoint
- Public-facing Application Load Balancer
- Static website S3 bucket

**Services that should NEVER be public**:
- RDS, Aurora
- ElastiCache, MemoryDB
- DynamoDB
- Secrets Manager
- Private subnets, NAT gateways
- Lambda functions handling secrets

---

## 3. Encryption

### Findings

**CRITICAL Issues**:
- [ ] RDS database without `storage_encrypted = true`
  - **Why**: Data at rest is exposed if storage is compromised
  - **Fix**: Enable storage encryption with customer-managed CMK

**HIGH Issues**:
- [ ] S3 bucket without server-side encryption
  - **Why**: Objects not encrypted at rest
  - **Fix**: Add `server_side_encryption_configuration` block

**MEDIUM Issues**:
- [ ] EBS volume not encrypted
  - **Why**: Snapshots and backups exposed
  - **Fix**: Set `encrypted = true`, use customer-managed KMS key

### Encryption Checklist

- [ ] RDS: `storage_encrypted = true` + customer-managed KMS key
- [ ] Aurora: `storage_encrypted = true` (default)
- [ ] EBS: `encrypted = true` + customer-managed KMS key
- [ ] S3: `server_side_encryption_configuration` with KMS key
- [ ] DynamoDB: `sse_specification.enabled = true` with KMS key
- [ ] ElastiCache: `at_rest_encryption_enabled = true`
- [ ] Secrets Manager: Always encrypted (auto)
- [ ] Backups: Encrypted same as primary resource
- [ ] In-transit: TLS 1.2+ enforced (ALB, API Gateway, databases)
- [ ] KMS Keys: Customer-managed (not AWS-managed) for sensitive data

**Example Encryption Setup**:

```hcl
# Customer-managed KMS key for RDS
resource "aws_kms_key" "rds" {
  description = "KMS key for RDS encryption"
  enable_key_rotation = true
}

resource "aws_db_instance" "main" {
  storage_encrypted = true
  kms_key_id = aws_kms_key.rds.arn
  # ... other config
}
```

---

## 4. Logging

### Findings

**CRITICAL Issues**:
- [ ] CloudTrail with `enable_logging = false`
  - **Why**: No audit trail of API calls
  - **Fix**: Set to `true`, configure S3 and CloudWatch destinations

**HIGH Issues**:
- [ ] RDS without `enabled_cloudwatch_logs_exports`
  - **Why**: No activity logs for compliance/debugging
  - **Fix**: Enable postgresql, upgrade, error logs

**MEDIUM Issues**:
- [ ] VPC without VPC Flow Logs
  - **Why**: No visibility into network traffic for prod environments
  - **Fix**: Enable VPC Flow Logs to CloudWatch Logs

### Logging Checklist

- [ ] CloudTrail enabled for all API calls
- [ ] RDS: CloudWatch logs enabled (postgresql, upgrade, error, slowquery)
- [ ] VPC: Flow Logs enabled (CloudWatch Logs + S3)
- [ ] ALB/NLB: Access logs sent to S3
- [ ] Lambda: CloudWatch Logs configured
- [ ] API Gateway: CloudWatch Logs enabled
- [ ] S3: Server access logging enabled
- [ ] Log retention policies appropriate (90+ days for compliance)
- [ ] Log groups encrypted if customer-managed KMS

**Example Logging Configuration**:

```hcl
resource "aws_db_instance" "main" {
  enabled_cloudwatch_logs_exports = [
    "postgresql",
    "upgrade",
    "error"
  ]
  # ... 
}

resource "aws_cloudwatch_log_group" "rds" {
  name              = "/aws/rds/postgres-main"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.logs.arn
}
```

---

## 5. Risky Resource Replacements

### Findings

**CRITICAL Issues**:
- [ ] RDS identifier will change on deploy (forces replacement)
  - **Why**: New database created, old one deleted → downtime + potential data loss
  - **Fix**: Use static identifier, configure `final_snapshot_identifier`

**HIGH Issues**:
- [ ] VPC CIDR range changed (forces replacement)
  - **Why**: VPC deletion requires all resources removed
  - **Fix**: Create new VPC if CIDR change needed, migrate carefully

**MEDIUM Issues**:
- [ ] S3 bucket with `force_destroy = true`
  - **Why**: Terraform destroy will delete all objects
  - **Fix**: Set to `false` for production buckets

### Replacement Risk Checklist

- [ ] RDS: Identifier is static (not variable or timestamp-based)
- [ ] RDS: `skip_final_snapshot = false`, `final_snapshot_identifier` set
- [ ] Aurora: Cluster identifier is stable
- [ ] S3: `force_destroy = false` for production buckets
- [ ] VPC: CIDR range not changing (recreate VPC if needed)
- [ ] Subnets: Availability zones are stable (use `availability_zones` not `availability_zone`)
- [ ] KMS Keys: `enable_key_rotation` only (never change key policy)
- [ ] RDS: `enable_deletion_protection = true` in production
- [ ] VPC: Verify no dependencies before changing
- [ ] Terraform: Run `terraform plan` and verify no unexpected replacements

**How to Check for Forced Replacements**:

```bash
cd modules/rds
terraform plan -out=tfplan

# Look for "forces new resource" in output
terraform show tfplan | grep -i "forces new\|replace"
```

**Safe vs. Risky Changes**:

| Change | Impact | Risk | Approval |
|--------|--------|------|----------|
| Security group rule | Immediate | Low | Team review |
| Security group delete | Immediate | High if attached | Lead approval |
| RDS parameter group | Rolling restart | Medium | Lead approval |
| RDS instance class | Downtime window | Medium | Lead + oncall |
| RDS identifier | Replacement (new DB) | **CRITICAL** | VP + DBE |
| VPC CIDR | Replacement (new VPC) | **CRITICAL** | VP + Network |
| Availability zone | Possible replacement | High | Lead approval |

---

## Summary Table

| Category | CRITICAL | HIGH | MEDIUM | INFO | Status |
|----------|----------|------|--------|------|--------|
| **IAM** | 0 | 0 | 0 | 0 | ✅ Pass |
| **Public Exposure** | 0 | 0 | 0 | 0 | ✅ Pass |
| **Encryption** | 0 | 0 | 0 | 0 | ✅ Pass |
| **Logging** | 0 | 0 | 0 | 0 | ✅ Pass |
| **Replacement Risk** | 0 | 0 | 0 | 0 | ✅ Pass |

---

## Additional Notes

- **Tested**: [e.g., "Ran terraform plan, no unexpected replacements"]
- **Compliance**: [e.g., "Meets SOC 2, HIPAA, PCI-DSS requirements"]
- **Performance Impact**: [e.g., "No performance regressions expected"]

---

## Approval Sign-Off

**Security Team**: 
- [ ] Reviewed and approved by [name]
- [ ] Approved at [timestamp]

**Engineering Lead**:
- [ ] Reviewed and approved by [name]
- [ ] Approved at [timestamp]

**Notes**:  
[Additional comments or conditions]

---

## Related Resources

- [AWS IaC Review Skill](../../SKILL.md)
- [IAM Permission Checklist](../iam-permission-checklist.md)
- [Best Practices](../best-practices.md)
