# Encryption Patterns for AWS Services

Encryption at-rest and in-transit should be enabled by default for all sensitive data. This guide shows encryption configuration for each major AWS service.

## Quick Reference: Encryption Checklist

| Service | At-Rest | In-Transit | KMS Key | Default OK? |
|---------|---------|-----------|---------|------------|
| **RDS** | `storage_encrypted = true` | Force SSL | Customer-managed | ❌ No |
| **Aurora** | `storage_encrypted = true` | Force SSL | Customer-managed | ❌ No |
| **DynamoDB** | `sse_specification.enabled = true` | N/A (VPC only) | Customer-managed | ❌ No |
| **S3** | `server_side_encryption_configuration` | Enforce HTTPS | Customer-managed | ❌ No |
| **EBS** | `encrypted = true` | N/A (internal) | Customer-managed | ❌ No |
| **ElastiCache** | `at_rest_encryption_enabled = true` | `transit_encryption_enabled = true` | Customer-managed | ❌ No |
| **Secrets Manager** | Always encrypted | Always encrypted | AWS-managed OK | ✅ Yes |
| **CloudWatch Logs** | `kms_key_id = ...` | N/A (agency model) | Customer-managed | ❌ No |

---

## RDS / Aurora: Relational Databases

### Storage Encryption (At-Rest)

❌ **WRONG**: Relying on default encryption
```hcl
resource "aws_db_instance" "main" {
  engine = "postgres"
  # storage_encrypted not specified, defaults to false
}
```

✅ **CORRECT**: Encrypted with customer-managed KMS key
```hcl
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_kms_alias" "rds" {
  name          = "alias/rds-main"
  target_key_id = aws_kms_key.rds.key_id
}

resource "aws_db_instance" "main" {
  identifier         = "production-db"
  engine             = "postgres"
  storage_encrypted  = true
  kms_key_id         = aws_kms_key.rds.arn
  
  # Enable encryption for backups
  copy_tags_to_snapshot = true
  
  tags = { Name = "production-db" }
}

# Verify backup encryption
resource "aws_db_snapshot" "backup" {
  db_instance_identifier = aws_db_instance.main.id
  db_snapshot_identifier = "snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  storage_encrypted      = true  # Inherited from db_instance
}
```

### Connection Encryption (In-Transit)

Force SSL/TLS for all client connections:

```hcl
resource "aws_db_parameter_group" "postgres" {
  family = "postgres15"
  name   = "postgres-enforced-ssl"
  
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
}

resource "aws_db_instance" "main" {
  parameter_group_name = aws_db_parameter_group.postgres.name
  
  # Clients must use SSL
  # Connection string: postgres://user:pass@endpoint.rds.amazonaws.com:5432/db?sslmode=require
}
```

### Aurora (Cluster)

```hcl
resource "aws_rds_cluster" "main" {
  cluster_identifier = "production-cluster"
  engine             = "aurora-postgresql"
  
  storage_encrypted  = true
  kms_key_id         = aws_kms_key.rds.arn
  
  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  backup_retention_period = 35  # >30 days for compliance
  copy_tags_to_snapshot   = true
  
  # Enable IAM authentication (certificate-based)
  iam_database_authentication_enabled = true
}
```

---

## DynamoDB: NoSQL Database

### Encryption at-Rest

❌ **WRONG**: Default AWS-managed encryption
```hcl
resource "aws_dynamodb_table" "users" {
  name           = "Users"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "UserId"
  
  # No sse_specification = uses AWS-managed KMS (limited control)
}
```

✅ **CORRECT**: Customer-managed KMS key
```hcl
resource "aws_kms_key" "dynamodb" {
  description             = "KMS key for DynamoDB encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_dynamodb_table" "users" {
  name           = "Users"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "UserId"
  
  sse_specification {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }
  
  # Encrypt backups (point-in-time recovery)
  point_in_time_recovery_specification {
    point_in_time_recovery_enabled = true
  }
  
  tags = { Name = "Users" }
}

# Restrict table access via IAM
resource "aws_dynamodb_table_policy" "users" {
  table_name = aws_dynamodb_table.users.name
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = aws_iam_role.app.arn
      }
      Action   = ["dynamodb:GetItem", "dynamodb:Query"]
      Resource = aws_dynamodb_table.users.arn
    }]
  })
}
```

### VPC Endpoint for Private Access

Prevent data from exiting your VPC:

```hcl
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.eu-west-3.dynamodb"
  vpc_endpoint_type   = "Gateway"
  route_table_ids     = [aws_route_table.private.id]
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = "*"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:BatchGetItem"
      ]
      Resource = aws_dynamodb_table.users.arn
      Condition = {
        StringEquals = {
          "aws:SourceVpc" = aws_vpc.main.id
        }
      }
    }]
  })
}
```

---

## S3: Object Storage

### Server-Side Encryption

❌ **WRONG**: No encryption configuration
```hcl
resource "aws_s3_bucket" "data" {
  bucket = "my-company-data"
  # No server_side_encryption_configuration = unencrypted objects
}
```

✅ **CORRECT**: Customer-managed KMS encryption
```hcl
resource "aws_kms_key" "s3" {
  description             = "KMS key for S3 encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_s3_bucket" "data" {
  bucket = "my-company-data"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true  # Faster encryption, lower KMS costs
  }
}

# Enforce encryption on object uploads
resource "aws_s3_bucket_policy" "enforce_kms" {
  bucket = aws_s3_bucket.data.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyUnencryptedUploads"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.data.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid    = "DenyWrongKmsKey"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.data.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption-aws-kms-key-id" = aws_kms_key.s3.arn
          }
        }
      }
    ]
  })
}

# Block public access + block unencrypted uploads
resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

### HTTPS Enforcement

Force SSL/TLS for all object transfers:

```hcl
resource "aws_s3_bucket_policy" "enforce_https" {
  bucket = aws_s3_bucket.data.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DenyUnencryptedTransport"
      Effect = "Deny"
      Principal = "*"
      Action = "s3:*"
      Resource = [
        aws_s3_bucket.data.arn,
        "${aws_s3_bucket.data.arn}/*"
      ]
      Condition = {
        Bool = {
          "aws:SecureTransport" = "false"
        }
      }
    }]
  })
}
```

---

## EBS: Block Storage

### Encryption by Default

❌ **WRONG**: Unencrypted volumes
```hcl
resource "aws_ebs_volume" "data" {
  availability_zone = "eu-west-3a"
  size              = 100
  # encrypted not specified, defaults to false
}

resource "aws_instance" "web" {
  root_block_device {
    # Not encrypted by default
  }
}
```

✅ **CORRECT**: Encrypted with customer-managed key
```hcl
# Enable encryption by default for your account (AWS Console or API)
# Or explicitly in code:

resource "aws_ebs_encryption_by_default" "main" {
  enabled = true
}

resource "aws_ebs_default_kms_key" "main" {
  key_arn = aws_kms_key.ebs.arn
}

resource "aws_ebs_volume" "data" {
  availability_zone = "eu-west-3a"
  size              = 100
  
  encrypted  = true
  kms_key_id = aws_kms_key.ebs.arn
  
  tags = { Name = "data-volume" }
}

resource "aws_instance" "web" {
  root_block_device {
    encrypted  = true
    kms_key_id = aws_kms_key.ebs.arn
  }
  
  ebs_block_device {
    device_name = "/dev/sdf"
    encrypted   = true
    kms_key_id  = aws_kms_key.ebs.arn
  }
}

resource "aws_ebs_snapshot" "backup" {
  volume_id = aws_ebs_volume.data.id
  
  tags = { Name = "backup" }
  # Inherits encryption from source volume
}

# Restrict snapshot copying to prevent key escape
resource "aws_ec2_snapshot_copy_default_kms_key_id" "main" {
  key_id = aws_kms_key.ebs.id
}
```

---

## ElastiCache: In-Memory Cache

### Encryption At-Rest and In-Transit

❌ **WRONG**: No encryption
```hcl
resource "aws_elasticache_cluster" "session" {
  engine               = "redis"
  engine_version       = "7.0"
  parameter_group_name = "default.redis7"
  # No encryption settings
}
```

✅ **CORRECT**: Encrypted at-rest and in-transit
```hcl
resource "aws_elasticache_cluster" "session" {
  cluster_id           = "session-cache"
  engine               = "redis"
  engine_version       = "7.0"
  cache_node_type      = "cache.t4g.small"
  
  # Encryption at-rest
  at_rest_encryption_enabled = true
  auth_token_enabled         = true
  auth_token                 = random_password.redis.result
  
  # Encryption in-transit
  transit_encryption_enabled = true
  transit_encryption_mode    = "preferred"
  
  tags = { Name = "session-cache" }
}

resource "random_password" "redis" {
  length  = 32
  special = true
}

# Store auth token in Secrets Manager
resource "aws_secretsmanager_secret" "redis" {
  name = "redis-auth-token"
}

resource "aws_secretsmanager_secret_version" "redis" {
  secret_id      = aws_secretsmanager_secret.redis.id
  secret_string  = random_password.redis.result
}
```

---

## CloudWatch Logs: Logging Destination

### Log Group Encryption

❌ **WRONG**: Logs encrypted with AWS-managed key
```hcl
resource "aws_cloudwatch_log_group" "app" {
  name = "/aws/lambda/my-function"
  # Uses AWS-managed encryption by default
}
```

✅ **CORRECT**: Logs encrypted with customer-managed key
```hcl
resource "aws_kms_key" "logs" {
  description             = "KMS key for CloudWatch Logs"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "logs.${var.region}.amazonaws.com"
      }
      Action = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:CreateGrant",
        "kms:DescribeKey"
      ]
      Resource = "*"
      Condition = {
        ArnLike = {
          "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.region}:${var.account_id}:*"
        }
      }
    }]
  })
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/lambda/my-function"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn
}
```

---

## Encryption Key Management Best Practices

### 1. Always Use Customer-Managed KMS Keys for Production

```hcl
# ❌ WRONG: AWS-managed encryption
storage_encrypted = true
# Uses AWS-managed key, limited audit trail

# ✅ CORRECT: Customer-managed key
kms_key_id = aws_kms_key.main.arn
```

### 2. Enable Key Rotation

```hcl
resource "aws_kms_key" "main" {
  enable_key_rotation = true  # Automatic annual rotation
}

# Verify rotation
# aws kms describe-key --key-id <key-id>
# → KeyRotationEnabled: true
```

### 3. Use Separate Keys by Service (Blast Radius)

```hcl
# Separate keys = compromise doesn't affect all data
resource "aws_kms_key" "rds" { ... }
resource "aws_kms_key" "s3" { ... }
resource "aws_kms_key" "logs" { ... }

# Each service assumes role with permissions to its key only
```

### 4. Prevent Key Deletion

```hcl
resource "aws_kms_key" "main" {
  is_enabled              = true
  deletion_window_in_days = 30  # Minimum, prevents accidental deletion
}

# Enable CloudTrail logging for key usage
```

---

## Encryption Verification Checklist

Run before deploying:

```bash
# Check RDS encryption
aws rds describe-db-instances --db-instance-identifier <id> \
  --query 'DBInstances[0].[StorageEncrypted, KmsKeyId]'

# Check S3 encryption
aws s3api get-bucket-encryption --bucket <bucket-name>

# Check EBS encryption
aws ec2 describe-volumes --volume-ids <vol-id> \
  --query 'Volumes[0].[Encrypted, KmsKeyId]'

# Check DynamoDB encryption
aws dynamodb describe-table --table-name <table> \
  --query 'Table.[SSEDescription]'

# Verify all keys have rotation enabled
aws kms describe-key --key-id <key-id> \
  --query 'KeyMetadata.KeyRotationEnabled'
```
