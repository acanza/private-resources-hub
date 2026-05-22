# Resource Replacement Risk Guide

When Terraform detects changes to certain resource attributes, it destroys the old resource and creates a new one. This guide identifies which changes trigger forced replacements and how to safely manage them.

## Quick Reference: Replacement Risk by Service

| Service | High-Risk Attributes | Impact | Approval Required |
|---------|---------------------|--------|------------------|
| **RDS** | `identifier`, KMS key changes | New database, data loss risk | VP + DBE |
| **Aurora** | Cluster `identifier`, engine | New cluster, data loss | VP + DBE |
| **S3** | `bucket` name | New bucket, data loss | Lead |
| **VPC** | `cidr_block` | Recreate entire VPC | VP + Network |
| **Subnet** | `availability_zone`, `cidr_block` | Recreate subnet | Lead |
| **EBS** | `availability_zone` | Recreate volume, potential data loss | Lead |
| **KMS** | Most attributes | Key replacement, if in use by other resources | VP + Security |
| **DynamoDB** | `name` (table name) | New table, data loss | Lead + DBE |
| **ALB** | Multiple attributes | New load balancer, requires DNS update | Lead |

---

## How to Identify Forced Replacements

### 1. Use `terraform plan`

```bash
cd modules/rds
terraform plan -out=tfplan

# Look for "forces new resource"
terraform show tfplan | grep -i "forces new\|will be replaced"

# Example output:
# aws_db_instance.main will be replaced, as requested (forces new resource)
# aws_vpc.main will be replaced (forces new resource)
```

### 2. Check Terraform Documentation

Visit [registry.terraform.io](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) for each resource type and look for "Forces New Resource" markers next to attributes.

### 3. Manual Inspection

Review changed attributes in code review:
- Identifier-like fields (names, IDs) often force replacement
- CIDR blocks and network settings often force replacement
- Engine/version changes may force replacement
- Security group names (vs. security group IDs) may force replacement

---

## CRITICAL Risk: Database Replacement

### RDS Instance Identifier Change

**Risk**: Destroys RDS instance, recreates new one → data loss

❌ **WRONG**: Dynamic identifier
```hcl
locals {
  db_version = "15.2"
}

resource "aws_db_instance" "main" {
  identifier = "prod-db-${local.db_version}"  # Changes on version update!
}
# Result: When db_version changes, RDS is replaced
# Data Loss: Old database is deleted (unless final snapshot configured)
```

✅ **CORRECT**: Static identifier with snapshot protection
```hcl
resource "aws_db_instance" "main" {
  identifier = "prod-db"  # Static, never changes
  
  # If deletion is forced, capture snapshot
  skip_final_snapshot       = false
  final_snapshot_identifier = "prod-db-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  
  # Prevent accidental deletion
  deletion_protection = true
}

# If upgrade needed: Change in parameter group, not identifier
resource "aws_db_parameter_group" "main" {
  family = "postgres15"
  name   = "prod-parameters"
  
  parameter {
    name  = "max_connections"
    value = "200"
  }
}
```

### Aurora Cluster Identifier Change

```hcl
# ❌ WRONG
resource "aws_rds_cluster" "main" {
  cluster_identifier = "prod-cluster-${local.version}"  # Changes = replacement
}

# ✅ CORRECT
resource "aws_rds_cluster" "main" {
  cluster_identifier = "prod-cluster"  # Static
  
  backup_retention_period = 35
  copy_tags_to_snapshot   = true
  
  # Safely upgrade via parameter group
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.main.name
}

# Perform rolling restarts via maintenance window instead
resource "aws_rds_cluster_parameter_group" "main" {
  family = "aurora-postgresql15"
  name   = "prod-params"
  
  apply_immediately = false  # Changes apply during maintenance window
}
```

---

## HIGH Risk: Network Infrastructure

### VPC CIDR Block Change

**Risk**: VPC must be destroyed and recreated → all resources deleted

❌ **WRONG**: Changing CIDR
```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Later: Change to "10.1.0.0/16" for expansion
# Result: Terraform wants to replace the VPC (impossible without manual teardown)
```

✅ **CORRECT**: Create new VPC if CIDR expansion needed
```hcl
# Don't change existing VPC CIDR
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# If expansion needed:
# 1. Create secondary CIDR via AWS console (VPC can have multiple CIDR blocks)
resource "aws_vpc_ipv4_cidr_block_association" "secondary" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.0.0/16"
}

# 2. Or plan migration to new VPC + data transfer
# Never try to replace a VPC in production
```

### Subnet Availability Zone Change

**Risk**: Subnet locked to AZ; changing AZ forces replacement

❌ **WRONG**: Specifying fixed AZ
```hcl
resource "aws_subnet" "app" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-3a"  # Hard-coded!
}

# Later: eu-west-3a becomes unavailable or deprecated
# Result: Terraform must replace the subnet (cascades to instances, ENIs, etc.)
```

✅ **CORRECT**: Use data source for AZ selection
```hcl
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "app" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  
  # Don't specify availability_zone - let AWS assign it
  # Or use AZ from data source
  availability_zone = data.aws_availability_zones.available.names[0]
}

# For multi-AZ: Use for_each
resource "aws_subnet" "multi_az" {
  for_each = toset(slice(data.aws_availability_zones.available.names, 0, 3))
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${index(data.aws_availability_zones.available.names, each.value)}.0/24"
  availability_zone = each.value
}
```

---

## MEDIUM Risk: Storage Replacement

### S3 Bucket Name Change

**Risk**: Bucket names are globally unique; bucket must be deleted

❌ **WRONG**: Dynamic bucket name
```hcl
resource "aws_s3_bucket" "data" {
  bucket = "company-data-${local.deployment_id}"  # Changes per deployment
}
# Result: old bucketgets deleted with all data
```

✅ **CORRECT**: Static, unique bucket name
```hcl
resource "aws_s3_bucket" "data" {
  bucket = "company-data-prod-eu-west-3"  # Static across deployments
  
  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }
}

# Versioning protects against accidental deletes
resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  
  versioning_configuration {
    status = "Enabled"
  }
}
```

### EBS Volume Availability Zone Change

**Risk**: Volumes are AZ-specific; changing AZ forces replacement

```hcl
# ❌ WRONG: Hard-coded AZ
resource "aws_ebs_volume" "data" {
  availability_zone = "eu-west-3a"  # Locked to this AZ
  size              = 1000
}

# ✅ CORRECT: Dynamic AZ assignment
resource "aws_ebs_volume" "data" {
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = 1000
  
  encrypted  = true
  kms_key_id = aws_kms_key.ebs.arn
  
  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }
}
```

### DynamoDB Table Name Change

**Risk**: Table name change forces reconstruction

```hcl
# ❌ WRONG
resource "aws_dynamodb_table" "users" {
  name = "Users-${local.version}"  # Changes = table replaced
}

# ✅ CORRECT
resource "aws_dynamodb_table" "users" {
  name = "Users"  # Static name
  
  backup_retention_period = 35
  
  point_in_time_recovery_specification {
    point_in_time_recovery_enabled = true
  }
  
  lifecycle {
    prevent_destroy = true
  }
}
```

---

## Detecting and Approving Replacements

### Step 1: Identify Risky Changes

In pull request, add checklist:

```markdown
## Risk Assessment

- [ ] No database identifiers changed
- [ ] No VPC/subnet CIDR blocks changed
- [ ] No S3 bucket names changed
- [ ] No KMS key attributes modified
- [ ] No AZ-specific attributes changed
- [ ] Terraform plan shows no forced replacements
```

### Step 2: Review `terraform plan` Output

Before merge, require:

```bash
terraform plan -out=tfplan
terraform show tfplan > plan.txt

# Scan for replacements
grep -i "forces new\|will be replaced\|replacement required" plan.txt
```

### Step 3: Risk-Based Approvals

| Replacement | Dev | Stage | Prod |
|------------|-----|-------|------|
| Security group rule | Self | Self | Lead |
| Security group | Self | Lead | VP + Lead |
| RDS identifier | **BLOCKED** | **BLOCKED** | **BLOCKED** |
| VPC CIDR | **BLOCKED** | **BLOCKED** | **BLOCKED** |
| Subnet AZ | Lead | VP | **BLOCKED** |
| S3 bucket name | Self | Lead | **BLOCKED** |
| DynamoDB table | Self | Lead | VP + DBE |

### Step 4: Mitigation Before Applying

For unavoidable replacements:

1. **Backup critical data**
   ```bash
   # RDS: Take manual snapshot
   aws rds create-db-snapshot --db-instance-identifier main \
     --db-snapshot-identifier pre-replacement-snapshot
   
   # DynamoDB: Enable point-in-time recovery
   ```

2. **Plan maintenance window**
   - Schedule during low-traffic periods
   - Notify stakeholders in advance
   - Have rollback plan ready

3. **Update dependent resources**
   - Update DNS records
   - Update application connection strings
   - Verify load balancer targets

4. **Test in staging first**
   - Apply replacement in staging environment
   - Verify failover behavior
   - Confirm recovery from backups

---

## Preventing Accidental Replacements

### Lifecycle Rules

```hcl
# Prevent destroy on critical resources
resource "aws_db_instance" "main" {
  identifier = "prod-db"
  
  lifecycle {
    prevent_destroy = true  # Terraform errors if you try to destroy
  }
}

resource "aws_rds_cluster" "main" {
  cluster_identifier = "prod-cluster"
  
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_dynamodb_table" "users" {
  name = "Users"
  
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket" "data" {
  bucket = "company-data-prod"
  
  lifecycle {
    prevent_destroy = true
  }
}
```

### Deletion Protection

Enable AWS-native deletion protection:

```hcl
resource "aws_db_instance" "main" {
  deletion_protection = true  # Can't delete via console/API
}

resource "aws_rds_cluster" "main" {
  deletion_protection = true
}
```

### Immutable Resource Names

Use Terraform validation to catch attempts to change identifiers:

```hcl
variable "db_identifier" {
  type = string
  
  validation {
    condition     = var.db_identifier == "prod-db"
    error_message = "Database identifier must always be 'prod-db' (cannot be changed)."
  }
}

resource "aws_db_instance" "main" {
  identifier = var.db_identifier
}
```

---

## Safe Resource Changes

### What Can Change WITHOUT Replacement

✅ **Safe**:
- Security group rules (add/remove/modify)
- IAM policy content (keeping role name same)
- Tags on any resource
- Parameter group values (RDS)
- Cluster parameter group values
- Environment variables for Lambda
- CloudWatch alarm thresholds
- KMS key rotation settings
- VPC Flow Logs settings

### Example: Safe RDS Upgrade

```hcl
# SAFE: Parameter group change (rolling restart during maintenance window)
resource "aws_db_parameter_group" "main" {
  family = "postgres15"
  
  parameter {
    name  = "max_connections"
    value = "300"  # Change this - no replacement
  }
}

# SAFE: Enhanced monitoring (no downtime)
resource "aws_db_instance" "main" {
  monitoring_interval = 60  # Enable detailed monitoring
}

# SAFE: Backup settings (no downtime)
resource "aws_db_instance" "main" {
  backup_retention_period = 35  # Increase from 7 to 35
  backup_window           = "03:00-04:00"
}

# NOT SAFE: Engine upgrade (may need testing)
# Use blue/green deployment or aurora-style single-AZ upgrade
```

---

## Replacement Approval Template

For code reviews, require this sign-off:

```markdown
## Replacement Risk Review

**Resources that will be replaced:**
- [ ] None (safest)
- [ ] [List resources and reason]

**Risk Level**: 🟢 Low / 🟡 Medium / 🔴 High / 🔴 CRITICAL

**Mitigation Steps**:
- [ ] Backup taken (for databases/storage)
- [ ] Maintenance window scheduled
- [ ] Stakeholders notified
- [ ] Rollback plan documented
- [ ] Staging environment tested

**Approvals**:
- [ ] Engineering lead reviewed
- [ ] Database engineer approved (if DB replacement)
- [ ] VP approval (if production CRITICAL risk)
- [ ] Security approval (if KMS/encryption changes)

**Sign-off**:
Approved by [name] on [date] for merge.
Applying to: [environment]
Expected duration: [time]
Rollback capability: [procedure]
```

---

## Common Gotchas

### 1. Security Group Name vs. ID

```hcl
# This can cause issues:
resource "aws_security_group" "app" {
  name = "app-sg"  # Name-based (can be problematic in resource policies)
  vpc_id = aws_vpc.main.id
}

# Better:
resource "aws_security_group" "app" {
  name_prefix = "app-"  # Avoid hard-coded names
  vpc_id = aws_vpc.main.id
}

# Always reference by ID, not name:
resource "aws_security_group_rule" "app_ingress" {
  security_group_id = aws_security_group.app.id  # Use ID
  # NOT: security_group_id = aws_security_group.app.name
}
```

### 2. Key Policy Changes on In-Use KMS Keys

```hcl
# ❌ RISKY: Modifying key policy might force key replacement
resource "aws_kms_key" "rds" {
  policy = jsonencode(...)  # If policy changes, entire key might be replaced
}

# ✅ SAFER: Only enable/disable key rotation
resource "aws_kms_key" "rds" {
  enable_key_rotation = true  # Safe to change
}
```

### 3. Lambda Replacement Surprise

```hcl
# ❌ Can cause replacement
resource "aws_lambda_function" "main" {
  filename = "function.zip"  # If file changes, function replaced
}

# ✅ Better: Use explicit versioning
resource "aws_lambda_function" "main" {
  filename = "build/lambda-${var.version}.zip"
  # Version control prevents constant replacements
}
```

---

## Testing Replacements Safely

### Use `terraform import` + Testing Account

1. **Create test environment** with same resources
2. **Apply the change** and observe behavior
3. **Verify failover** and recovery
4. **Document timing and impact**
5. **Validate monitoring/alerts** worked
6. **Then apply to staging, then production**

```bash
# Example: Test RDS replacement in dev first
cd terraform/dev
terraform plan -target=aws_db_instance.main
terraform apply -target=aws_db_instance.main

# Monitor:
watch -n 5 'aws rds describe-db-instances --db-instance-identifier main \
  --query "DBInstances[0].[DBInstanceStatus,DBInstancePort]"'

# Test application connection after replacement
curl https://api.dev.example.com/health  # Should be ready
```
