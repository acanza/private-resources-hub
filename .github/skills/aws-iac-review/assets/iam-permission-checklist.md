# IAM Permission Checklist

Use this checklist to manually review IAM policies and roles in your infrastructure changes. Every IAM resource created or modified should pass this review.

## Pre-Review Preparation

Before diving into specific policies, understand the context:

- [ ] What service/application will assume this role?
- [ ] What specific operations does it need to perform?
- [ ] What blast radius if credentials are compromised?
- [ ] Is this for automated (service) or human (user) access?
- [ ] Are there existing managed policies that cover this use case?

## IAM Role Definition Checklist

### 1. Assume Policy (Trust Relationship)

```hcl
resource "aws_iam_role" "lambda_execution" {
  name = "lambda-execution"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"  # Specific service, not "*"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id  # Limit to account
        }
      }
    }]
  })
}
```

**Checklist for Assume Policy**:

- [ ] `Principal` is **NOT** a wildcard (`"*"`)
- [ ] `Principal` specifies the exact service (e.g., `lambda.amazonaws.com`) not `"principals": "*"`
- [ ] If cross-account access: `Condition` limits to specific account(s)
- [ ] If cross-account access: Includes `ExternalId` for added security
- [ ] `Action` is `sts:AssumeRole` OR `sts:AssumeRoleWithWebIdentity` for OIDC
- [ ] For time-limited credentials: `Condition.DateGreaterThan` and `DateLessThan` set if needed
- [ ] For MFA: `Condition.Bool` for `"aws:MultiFactorAuthPresent" = "true"` on human access

### 2. Permission Policy (Inline or Managed)

**Decision: Use Managed Policy?**

| Use Case | Recommendation |
|---------|-----------------|
| **Single-use custom policy** | Inline (simpler, tighter coupling) |
| **Reusable across services** | Managed policy (maintainable, auditable) |
| **AWS managed policy covers it** | Attach AWS managed policy (vetted, updated by AWS) |
| **Sensitive permissions** | Managed policy (versioning, rollback capability) |

**Review Template**:

```hcl
resource "aws_iam_role_policy" "s3_readonly" {
  name = "s3-readonly"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBuckets"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",              # ✅ Specific action
          "s3:GetBucketLocation"
        ]
        Resource = "arn:aws:s3:::my-bucket"  # ✅ Specific resource, not "*"
      },
      {
        Sid    = "ReadObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject"                # ✅ Read-only (no Put/Delete)
        ]
        Resource = "arn:aws:s3:::my-bucket/data/*"  # ✅ Path limited
      }
    ]
  })
}
```

## Action-Level Review Checklist

For each `Action` in the policy:

- [ ] **Is it necessary?** Does the service actually need this permission?
- [ ] **Is it specific?** Avoid wildcards (`s3:*`, `ec2:*`, `logs:*`)
- [ ] **Is it scoped?** Minimum required - not `DescribeInstances` if only `GetConsoleOutput` needed
- [ ] **Is the mode correct?** Read-only (Get/Describe/List) vs. Write (Put/Create/Delete)

### Common Overly-Broad Patterns ❌

```hcl
# WRONG: Action wildcard
Action = ["s3:*"]

# WRONG: Resource wildcard for everything
Action = ["s3:*"]
Resource = "*"

# WRONG: Overqualified permissions
Action = ["ec2:*"]  # when only ec2:DescribeInstances needed

# WRONG: Write access when read-only needed
Action = ["s3:*"]  # when only s3:GetObject required
```

### Correct Patterns ✅

```hcl
# RIGHT: Specific actions
Action = [
  "s3:GetObject",
  "s3:ListBucket"
]

# RIGHT: Scoped to specific resources
Resource = [
  "arn:aws:s3:::my-bucket/documents/*",
  "arn:aws:s3:::my-bucket"
]

# RIGHT: Least privilege for use case
Action = [
  "logs:CreateLogGroup",
  "logs:CreateLogStream",
  "logs:PutLogEvents"
]
```

## Resource-Level Review Checklist

For each `Resource` ARN in the policy:

- [ ] **Is it specific?** Avoid wildcards (`*`, `/*`)
- [ ] **Is it scoped correctly?** Path-level constraints where applicable
- [ ] **Are account IDs hardcoded or variable?** Use `data.aws_caller_identity.current.account_id`
- [ ] **Is the resource type correct?** Match the action (S3 objects vs. bucket vs. access point)

### ARN Format Reference

```hcl
# S3 Bucket (for ListBucket, GetBucketLocation)
"arn:aws:s3:::my-bucket"

# S3 Objects (for GetObject, PutObject)
"arn:aws:s3:::my-bucket/*"
"arn:aws:s3:::my-bucket/specific/path/*"

# EC2 Instances
"arn:aws:ec2:eu-west-3:123456789012:instance/i-*"

# Lambda Functions
"arn:aws:lambda:eu-west-3:123456789012:function:MyFunction"

# RDS Database
"arn:aws:rds:eu-west-3:123456789012:db:mydb"

# DynamoDB Table
"arn:aws:dynamodb:eu-west-3:123456789012:table/my-table"

# SNS Topic
"arn:aws:sns:eu-west-3:123456789012:my-topic"
```

### Dynamic ARNs (Never Hardcode Account ID) ✅

```hcl
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

policy = jsonencode({
  Version = "2012-10-17"
  Statement = [{
    Action = "logs:PutLogEvents"
    Resource = "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/*"
  }]
})
```

## Condition-Based Restrictions Checklist

Advanced: Use conditions to further limit permissions.

- [ ] **IP restrictions**: Limit to specific CIDR blocks
- [ ] **VPC restrictions**: Limit to specific VPC/subnets (for data access)
- [ ] **Time-based**: Restrict to business hours or emergency maintenance windows
- [ ] **Source account**: Cross-account access limited to specific source
- [ ] **RequesterPaid**: For bucket operations requiring requester to pay
- [ ] **Principal restrictions**: For resource-based policies, verify principal scope

### Condition Examples

```hcl
# Restrict to specific VPC
Condition = {
  StringEquals = {
    "aws:SourceVpc" = aws_vpc.main.id
  }
}

# Restrict to specific IPs
Condition = {
  IpAddress = {
    "aws:SourceIp" = [
      "203.0.113.0/24",    # Corporate office
      "198.51.100.0/24"    # VPN gateway
    ]
  }
}

# Restrict to specific AWS account
Condition = {
  StringEquals = {
    "aws:SourceAccount" = "123456789012"
  }
}

# Restrict based on MFA
Condition = {
  Bool = {
    "aws:MultiFactorAuthPresent" = "true"
  }
}

# Time-based (maintenance window)
Condition = {
  DateGreaterThan = {
    "aws:CurrentTime" = "2024-01-01T00:00:00Z"
  }
  DateLessThan = {
    "aws:CurrentTime" = "2024-12-31T23:59:59Z"
  }
}
```

## Service-Specific Reviews

### Lambda Execution Role

Typical needs: CloudWatch Logs, VPC (if ENI access), X-Ray (if tracing)

```hcl
# ✅ Correct Lambda Execution Role
Statement = [
  {
    Sid    = "CloudWatchLogs"
    Effect = "Allow"
    Action = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    Resource = "arn:aws:logs:eu-west-3:${var.account_id}:log-group:/aws/lambda/*"
  },
  {
    Sid    = "VPCAccess"
    Effect = "Allow"
    Action = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface"
    ]
    Resource = "arn:aws:ec2:eu-west-3:${var.account_id}:network-interface/*"
    Condition = {
      StringEquals = {
        "ec2:Vpc" = aws_vpc.main.arn
      }
    }
  }
]
```

### ECS Task Execution Role

Needs: ECR pull, CloudWatch Logs, Secrets Manager (if secrets)

```hcl
# ✅ Correct ECS Task Execution Role
Statement = [
  {
    Sid    = "ECRPull"
    Effect = "Allow"
    Action = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]
    Resource = "*"  # ECR endpoint is regional, authorization is global
  },
  {
    Sid    = "CloudWatchLogs"
    Effect = "Allow"
    Action = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    Resource = "arn:aws:logs:${var.region}:${var.account_id}:log-group:/ecs/*"
  }
]
```

### Application Role (Service-to-Service Access)

Example: App needs to read from specific S3 bucket and write to SQS

```hcl
# ✅ Correct Application Role
Statement = [
  {
    Sid    = "S3ReadData"
    Effect = "Allow"
    Action = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    Resource = [
      "arn:aws:s3:::app-data",
      "arn:aws:s3:::app-data/inputs/*"
    ]
  },
  {
    Sid    = "SQSSendMessage"
    Effect = "Allow"
    Action = ["sqs:SendMessage"]
    Resource = aws_sqs_queue.notifications.arn
  }
]
```

## Red Flags & Questions to Ask

| Finding | Question | Expected Answer |
|---------|----------|-----------------|
| Action: `*` | Does the service really need all permissions? | No, should be specific actions |
| Resource: `*` | Will it access all resources? | No, should constrain to specific ARN |
| `inline_policy` | Why not use a managed policy? | Valid for one-off, tight coupling acceptable |
| `AdministratorAccess` | Is this for break-glass only? | Yes, or suggest least privilege |
| Cross-account role | Is there ExternalId? | Yes, prevents confused deputy |
| No conditions | Should access be restricted by IP/VPC? | Depends on use case |
| Wildcard in ARN | Can this be path-limited? | Usually yes, e.g., `/env/prod/*` |

## Sign-Off Checklist

Before approving IAM changes:

- [ ] Every Action is necessary and specific
- [ ] Every Resource is specific (not wildcards)
- [ ] No wildcard principals in resource policies
- [ ] Conditions restrict scope where appropriate
- [ ] No hardcoded credentials in policies (use Secrets Manager)
- [ ] Assume policy (trust relationship) is restrictive
- [ ] Managed policies preferred over inline for reusability
- [ ] Service-specific permissions follow AWS best practices
- [ ] Cross-account access (if any) has ExternalId
- [ ] Approval collected from security team before deploying to prod
