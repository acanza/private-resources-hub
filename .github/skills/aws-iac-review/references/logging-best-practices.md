# Logging Best Practices for AWS Services

Complete audit trails enable security investigations, compliance verification, and troubleshooting. This guide covers logging configuration for each major AWS service.

## Quick Reference: Logging Checklist

| Service | Log Type | Destination | Configuration | Production |
|---------|----------|------------|---------------|----|
| **RDS** | Database logs | CloudWatch | `enabled_cloudwatch_logs_exports` | ✅ Required |
| **Aurora** | Database logs | CloudWatch | `enabled_cloudwatch_logs_exports` | ✅ Required |
| **DynamoDB** | Stream records | DynamoDB Streams | `stream_specification` | ✅ Recommended |
| **S3** | Access logs | S3 bucket | `logging` block | ✅ Required |
| **CloudTrail** | API calls | S3 + CloudWatch | `enable_logging = true` | ✅ Required |
| **VPC Flow Logs** | Network traffic | CloudWatch + S3 | `flow_logs_` resources | ✅ Required (prod) |
| **ALB/NLB** | Access logs | S3 bucket | `access_logs` block | ✅ Required |
| **API Gateway** | Request logs | CloudWatch | `CloudWatch` stage variable | ✅ Recommended |
| **Lambda** | Function logs | CloudWatch | Automatic (via execution role) | ✅ Automatic |
| **WAF** | Web access | CloudWatch + S3 | `logging_configuration` | ✅ Recommended |

---

## RDS / Aurora: Database Activity Logging

### Enable CloudWatch Logs

Capture database activity for compliance and troubleshooting:

❌ **WRONG**: No logs enabled
```hcl
resource "aws_db_instance" "main" {
  engine = "postgres"
  # No enabled_cloudwatch_logs_exports = limited visibility
}
```

✅ **CORRECT**: All relevant logs enabled
```hcl
# Create log group with encryption and retention
resource "aws_cloudwatch_log_group" "rds_postgres" {
  name              = "/aws/rds/postgres-main"
  retention_in_days = 30  # Adjust per compliance requirements
  kms_key_id        = aws_kms_key.logs.arn
}

resource "aws_db_instance" "main" {
  identifier = "production-db"
  engine     = "postgres"
  
  # Enable all available logs
  enabled_cloudwatch_logs_exports = [
    "postgresql",     # SQL queries and activity
    "upgrade",        # Database upgrade progress
    "error",         # Errors and exceptions
    "slowquery"      # Slow queries (if enabled in parameter group)
  ]
  
  # Set slow query threshold
  parameter_group_name = aws_db_parameter_group.postgres.name
  
  backup_retention_period = 35  # Keep backups & logs for audit trail
  copy_tags_to_snapshot   = true
}

resource "aws_db_parameter_group" "postgres" {
  family = "postgres15"
  name   = "postgres-logging"
  
  parameter {
    name  = "log_statement"
    value = "all"  # or "ddl" for schema changes only
  }
  
  parameter {
    name  = "log_duration"
    value = "1"
  }
  
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"  # Log queries > 1 second
  }
}

# Aurora (cluster)
resource "aws_rds_cluster" "main" {
  cluster_identifier = "production-cluster"
  engine             = "aurora-postgresql"
  
  enabled_cloudwatch_logs_exports = [
    "postgresql",
    "upgrade",
    "error"
  ]
  
  backup_retention_period = 35
  copy_tags_to_snapshot   = true
  
  # Enable audit logging (available in Enterprise Edition)
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.audit.name
}

resource "aws_rds_cluster_parameter_group" "audit" {
  family = "aurora-postgresql15"
  name   = "aurora-audit"
  
  parameter {
    name  = "pgaudit.log"
    value = "ALL"
  }
}
```

### Log Group Retention and Encryption

```hcl
# Secure log storage
resource "aws_cloudwatch_log_group" "rds" {
  name              = "/aws/rds/main"
  retention_in_days = 90  # 90+ days for PCI/SOC 2
  kms_key_id        = aws_kms_key.logs.arn
}

# Create metric filter for failures
resource "aws_cloudwatch_log_group_metric_filter" "errors" {
  log_group_name = aws_cloudwatch_log_group.rds.name
  filter_pattern = "[...]ERROR[...]"
  metric_transformation {
    name      = "DBErrorCount"
    namespace = "RDS"
    value     = "1"
  }
}

# Alert on errors
resource "aws_cloudwatch_metric_alarm" "db_errors" {
  alarm_name          = "rds-errors-detected"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "DBErrorCount"
  namespace           = "RDS"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
```

---

## S3: Object Access Logging

### Enable Server Access Logging

Log all S3 API calls for compliance:

❌ **WRONG**: No S3 logging configured
```hcl
resource "aws_s3_bucket" "data" {
  bucket = "my-company-data"
  # No logging = no audit trail of who accessed what
}
```

✅ **CORRECT**: Logging enabled to separate bucket
```hcl
# Create dedicated logging bucket
resource "aws_s3_bucket" "logs" {
  bucket = "my-company-data-logs"
}

# Prevent public access to logs
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforce encryption on logging bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Enable logging on main bucket
resource "aws_s3_bucket_logging" "data" {
  bucket = aws_s3_bucket.data.id
  
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-access-logs/"
}

# Lifecycle rule to delete old logs
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  
  rule {
    id     = "archive-old-logs"
    status = "Enabled"
    
    transitions {
      days          = 30
      storage_class = "GLACIER"
    }
    
    expiration {
      days = 90  # Delete after 90 days (adjust per compliance)
    }
  }
}

# Grant S3 log delivery permission
resource "aws_s3_bucket_policy" "allow_logging" {
  bucket = aws_s3_bucket.logs.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "logging.s3.amazonaws.com"
      }
      Action   = "s3:PutObject"
      Resource = "${aws_s3_bucket.logs.arn}/*"
    }]
  })
}
```

---

## CloudTrail: API Activity Logging

### Account-Wide API Logging

Track all API calls for compliance and forensics:

✅ **CORRECT**: CloudTrail enabled account-wide
```hcl
# Create S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "company-cloudtrail-logs"
}

# Prevent object deletion (protect logs from tampering)
resource "aws_s3_bucket_versioning" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Enforce encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# CloudTrail S3 bucket policy
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# CloudWatch Logs group for CloudTrail
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/api-activity"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.logs.arn
}

# IAM role for CloudTrail logs
resource "aws_iam_role" "cloudtrail_logs" {
  name = "cloudtrail-cloudwatch-logs-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "cloudtrail_logs" {
  name = "cloudtrail-cloudwatch-logs-policy"
  role = aws_iam_role.cloudtrail_logs.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
    }]
  })
}

# Enable CloudTrail
resource "aws_cloudtrail" "main" {
  name                          = "organization-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true  # Prevent tampering
  
  # Send to CloudWatch Logs
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_logs.arn
  
  depends_on = [aws_s3_bucket_policy.cloudtrail]
}
```

---

## VPC Flow Logs: Network Traffic Logging

### Enable Flow Logs to CloudWatch and S3

Monitor network traffic for security analysis:

```hcl
# CloudWatch Logs group
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn
}

# IAM role for VPC Flow Logs
resource "aws_iam_role" "vpc_flow_logs" {
  name = "vpc-flow-logs-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
    }]
  })
}

# S3 bucket for long-term storage
resource "aws_s3_bucket" "vpc_flow_logs" {
  bucket = "company-vpc-flow-logs"
}

# Enable Flow Logs
resource "aws_flow_log" "vpc" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
  traffic_type    = "ALL"  # REJECT, ACCEPT, or ALL for both
  vpc_id          = aws_vpc.main.id
  
  log_format = "${local.flow_log_fields}"
  
  tags = { Name = "vpc-flow-logs" }
}

locals {
  flow_log_fields = "\${version} \${account-id} \${interface-id} \${srcaddr} \${dstaddr} \${srcport} \${dstport} \${protocol} \${packets} \${bytes} \${windowstart} \${windowend} \${action} \${tcpflags} \${type} \${pkt-srcaddr} \${pkt-dstaddr} \${region} \${sublocation-type} \${sublocation-id}"
}
```

---

## ALB / NLB: Load Balancer Access Logs

### Enable Access Logs

Track all requests to your load balancers:

```hcl
# S3 bucket for logs
resource "aws_s3_bucket" "alb_logs" {
  bucket = "company-alb-logs"
}

# Get ELB account ID for the region
data "aws_canonical_user_id" "elb" {
  provider = aws
}

# Grant ELB write permission
resource "aws_s3_bucket_acl" "alb_logs" {
  bucket      = aws_s3_bucket.alb_logs.id
  acl         = "log-delivery-write"
  depends_on  = [aws_s3_bucket.alb_logs]
}

# Enable ALB access logs
resource "aws_lb" "main" {
  name               = "production-alb"
  load_balancer_type = "application"
  
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "alb-logs"
    enabled = true
  }
}

# Lifecycle rule for old logs
resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  
  rule {
    id     = "archive-logs"
    status = "Enabled"
    
    expiration {
      days = 90
    }
  }
}
```

---

## API Gateway: Request Logging

### Enable CloudWatch Logs

Log all API requests for monitoring and debugging:

```hcl
# CloudWatch Logs group
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/api-requests"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn
}

# IAM role for API Gateway logging
resource "aws_iam_role" "api_gateway_logs" {
  name = "api-gateway-logs-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "api_gateway_logs" {
  name = "api-gateway-logs-policy"
  role = aws_iam_role.api_gateway_logs.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogDelivery",
        "logs:GetLogDelivery",
        "logs:UpdateLogDelivery",
        "logs:DeleteLogDelivery",
        "logs:ListLogDeliveries",
        "logs:PutResourcePolicy",
        "logs:DescribeResourcePolicies",
        "logs:DescribeLogGroups"
      ]
      Resource = "*"
    }]
  })
}

# API Gateway stage with logging
resource "aws_apigatewayv2_stage" "prod" {
  api_id= aws_apigatewayv2_api.main.id
  name  = "prod"
  
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      error          = "$context.error.message"
    })
  }
}
```

---

## Lambda: Automatic CloudWatch Logging

Lambda automatically sends logs to CloudWatch when execution role has permissions:

✅ **CORRECT**: Default execution role permissions
```hcl
data "aws_iam_policy_document" "lambda_logs" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role" "lambda_execution" {
  name               = "lambda-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_logs" {
  name   = "lambda-logs-policy"
  role   = aws_iam_role.lambda_execution.id
  policy = data.aws_iam_policy_document.lambda_logs.json
}

resource "aws_lambda_function" "main" {
  role = aws_iam_role.lambda_execution.arn
  # Logs automatically sent to /aws/lambda/function-name
}

# Optional: Custom log group with retention
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.main.function_name}"
  retention_in_days = 30
}
```

---

## Logging Verification Checklist

Before deploying to production:

- [ ] CloudTrail enabled account-wide with S3 + CloudWatch targets
- [ ] VPC Flow Logs enabled for all VPCs (prod) to CloudWatch + S3
- [ ] RDS has `enabled_cloudwatch_logs_exports` configured
- [ ] S3 buckets have server access logging enabled
- [ ] ALB/NLB have access logs to S3
- [ ] API Gateway has request logging to CloudWatch
- [ ] All log groups encrypted with customer-managed KMS
- [ ] Appropriate retention periods set (90+ days for compliance)
- [ ] Log archives in S3 with lifecycle policies (transition to Glacier)
- [ ] CloudTrail log file validation enabled
- [ ] CloudWatch Logs Insights queries tested for common investigations

```bash
# CloudTrail validation
aws cloudtrail describe-trails --trail-name main-trail \
  --query 'trailList[0].LogFileValidationEnabled'

# Flow Logs check
aws ec2 describe-flow-logs --query 'FlowLogs[?ResourceId==`vpc-xxx`]'

# RDS logs
aws rds describe-db-instances --db-instance-identifier main \
  --query 'DBInstances[0].EnabledCloudwatchLogsExports'
```
