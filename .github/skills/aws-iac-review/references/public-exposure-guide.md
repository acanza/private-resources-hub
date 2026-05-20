# Public Exposure Risk Guide

Unintended public accessibility is one of the most common AWS security misconfigurations. This guide details which services should/can be public, exposure vectors, and how to fix them.

## Overview: Public vs. Private by Service

| Service | Typical Exposure | Configure As | If Public |
|---------|-----------------|--------------|-----------|
| **CloudFront** | Public | Public | ✅ Intended |
| **API Gateway** | Public API | Public | ✅ Intended |
| **ALB/NLB** | Public API | Public | ✅ Intended |
| **S3 (Static Site)** | Public web | Public | ✅ Intended |
| **RDS Database** | Private app | Private | ⚠️ Never public |
| **ElastiCache** | Private app | Private | ⚠️ Never public |
| **DynamoDB** | Private app | Private | ⚠️ Never public |
| **Lambda** | Invoked via API | Private | ⚠️ Direct access rare |
| **Bastion/Jump** | Ops only | Restricted | 🔴 High risk if full open |
| **Secrets Manager** | App lookup | Private | ⚠️ Application access only |

---

## Critical: Services That Should NEVER Be Public

### 1. Relational Databases (RDS, Aurora)

**Risk**: SQL injection, brute force, data exfiltration

❌ **WRONG**:
```hcl
resource "aws_db_instance" "main" {
  publicly_accessible = true  # ❌ CRITICAL!
}
```

✅ **CORRECT**:
```hcl
resource "aws_db_instance" "main" {
  publicly_accessible = false
  db_subnet_group_name = aws_db_subnet_group.private.name
  
  # Only allow from app security group
  vpc_security_group_ids = [aws_security_group.rds.id]
}

resource "aws_security_group" "rds" {
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]  # Only from app tier
  }
}
```

**Verification**:
```bash
# Confirm database is in private subnet with no public IP assigned
terraform show | grep -i publicly_accessible  # Should be false
terraform show | grep -i "db_subnet_group"    # Should reference private subnet
```

### 2. In-Memory Caches (ElastiCache, MemoryDB)

**Risk**: Session hijacking, credential theft, cache pollution

❌ **WRONG**:
```hcl
resource "aws_elasticache_cluster" "session" {
  # No security group specified = default VPC, potentially public route
  subnet_group_name = aws_elasticache_subnet_group.public.name  # ❌
}
```

✅ **CORRECT**:
```hcl
resource "aws_elasticache_cluster" "session" {
  subnet_group_name          = aws_elasticache_subnet_group.private.name
  security_group_ids         = [aws_security_group.redis.id]
  automatic_failover_enabled = true
  
  security_group {
    ingress {
      from_port       = 6379
      to_port         = 6379
      protocol        = "tcp"
      security_groups = [aws_security_group.app.id]
    }
  }
}
```

### 3. NoSQL Databases (DynamoDB, DocumentDB)

**Risk**: Data exfiltration, denial of service (throughput consumption)

❌ **WRONG**:
```hcl
resource "aws_dynamodb_table" "users" {
  # No VPC endpoint = public table (if global)
  stream_specification {
    stream_enabled   = true
    stream_view_type = "NEW_AND_OLD_IMAGES"
  }
}

# Global tables replicate to all regions = public internet traffic
resource "aws_dynamodb_global_table" "users" {
  name = "users"
}
```

✅ **CORRECT**:
```hcl
# Use VPC endpoints for private access
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.eu-west-3.dynamodb"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = aws_iam_role.app.arn
      }
      Action   = ["dynamodb:GetItem", "dynamodb:Query"]
      Resource = aws_dynamodb_table.users.arn
      Condition = {
        StringEquals = {
          "aws:SourceVpc" = aws_vpc.main.id
        }
      }
    }]
  })
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
      Action = ["dynamodb:GetItem"]
      Resource = aws_dynamodb_table.users.arn
    }]
  })
}
```

---

## High Risk: Restricted Public Access

### 1. Security Groups with 0.0.0.0/0

**Most Common Issue**: Database port (3306, 5432) open to internet

❌ **WRONG**:
```hcl
resource "aws_security_group" "database_sg" {
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # ❌ CRITICAL: Database open to internet!
  }
}
```

✅ **CORRECT**:
```hcl
resource "aws_security_group" "database_sg" {
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]  # Only from app tier
  }
}
```

**Allowed Ports (Justifiable, But Require Controls)**:

| Port | Service | When OK | Control |
|------|---------|---------|---------|
| 80 | HTTP | Load balancer for public API | WAF + rate limiting |
| 443 | HTTPS | API endpoint | Rate limiting + auth |
| 22 | SSH | Bastion/jump host | IP whitelist + MFA |
| 3389 | RDP | Windows jump host | IP whitelist + conditional access |

**SSH from 0.0.0.0/0 Example**:

❌ **WRONG**:
```hcl
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]  # ❌ Brute force attacks
}
```

✅ **CORRECT**:
```hcl
# Option 1: Office + VPN IPs
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = [
    "203.0.113.0/24",     # Office
    "198.51.100.0/24"     # VPN endpoint
  ]
}

# Option 2: Systems Manager Session Manager (better)
# → No SSH port needed if using EC2 Instance Connect or SSM Session Manager
# → Requires IAM role, no exposed ports

# Option 3: Security group ingress from somewhere restricted
ingress {
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"
  security_groups = [aws_security_group.vpn.id]  # VPN security group only
  description     = "SSH from VPN only"
}
```

### 2. IPv6 Exposure (::/0)

**Often Overlooked**: IPv6 rules not restricted the same as IPv4

❌ **WRONG**:
```hcl
resource "aws_security_group" "app" {
  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"]  # ❌ Allows all IPv6 addresses
  }
}
```

✅ **CORRECT**:
```hcl
ingress {
  from_port        = 443
  to_port          = 443
  protocol         = "tcp"
  ipv6_cidr_blocks = ["2600:1f13:e2c:ca00::/56"]  # Your corporate IPv6 range
}
```

### 3. S3 Public Access Configuration

**Risk**: Unintended data exposure (especially common in dev/test buckets promoted to prod)

❌ **WRONG**:
```hcl
resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id
  
  block_public_acls       = false  # ❌
  block_public_policy     = false  # ❌
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "data" {
  bucket = aws_s3_bucket.data.id
  
  policy = jsonencode({
    Statement = [{
      Effect    = "Allow"
      Principal = "*"  # ❌ Allow anyone
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.data.arn}/*"
    }]
  })
}
```

✅ **CORRECT (Private Bucket)**:
```hcl
resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id
  
  block_public_acls       = true  # ✅ Prevent any public ACLs
  block_public_policy     = true  # ✅ Prevent public bucket policies
  ignore_public_acls      = true  # ✅ Treat all ACLs as public
  restrict_public_buckets = true  # ✅ Restrict all public access
}

# No public bucket policy - use presigned URLs or CloudFront for sharing
```

✅ **CORRECT (Static Website via CloudFront)**:
```hcl
resource "aws_s3_bucket_public_access_block" "static" {
  bucket = aws_s3_bucket.static.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Access ONLY via CloudFront, not direct S3 URL
resource "aws_cloudfront_distribution" "static" {
  origin {
    domain_name = aws_s3_bucket.static.bucket_regional_domain_name
    origin_access_identity = aws_cloudfront_origin_access_identity.s3.cloudfront_access_identity_path
  }
  
  restrictions {
    geo_restriction {
      restriction_type = "none"  # Or whitelist countries
    }
  }
}
```

---

## Medium Risk: Networking Misconfigurations

### 1. Subnet with map_public_ip_on_launch

**Risk**: Instances in "private" subnets get public IPs unintentionally

❌ **WRONG**:
```hcl
resource "aws_subnet" "app" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  map_public_ip_on_launch = true  # ❌ Should be private
}
```

✅ **CORRECT**:
```hcl
resource "aws_subnet" "app_private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = false  # ✅ Keep private
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.10.0/24"
  map_public_ip_on_launch = true  # ✅ Only for actual public tier
}
```

### 2. NAT Gateway in Public Subnet (Required for Private Outbound)

✅ **CORRECT Architecture**:
```
Public Subnet (Internet-facing)
├── NAT Gateway (Elastic IP)
└── ALB (load balancer)

Private Subnet (App tier)
├── EC2 instances (route to NAT via main route table)
└── Outbound internet via NAT Gateway

Private Subnet (Database tier)
├── RDS instance (no internet access)
└── No routes to internet
```

### 3. Auto Scaling Group Public IP Assignment

❌ **WRONG**:
```hcl
resource "aws_autoscaling_group" "app" {
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
  
  # Implicit: Default VPC with map_public_ip_on_launch
  # Result: All instances get public IPs
}
```

✅ **CORRECT**:
```hcl
resource "aws_autoscaling_group" "app" {
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
  
  vpc_zone_identifier = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]
  # No public IPs assigned, only accessible via load balancer
}
```

---

## Checklist for Public Exposure Review

### For Every Resource in Review

- [ ] **Is this resource supposed to be public?**
  - Databases, caches, secrets: Almost never
  - APIs, static content, load balancers: Yes
  
- [ ] **If public, is access restricted?**
  - [ ] Security groups have specific ingress rules (not 0.0.0.0/0)
  - [ ] S3 buckets have public access blocks enabled + presigned URLs
  - [ ] API Gateway has authorization enabled
  - [ ] CloudFront has HTTPS enforced + WAF (if needed)

- [ ] **If private, is there a public path?**
  - [ ] RDS not in public subnet
  - [ ] Database not in default VPC
  - [ ] No public IPs on private instances
  - [ ] Security groups don't allow 0.0.0.0/0

- [ ] **Verify subnets correct**
  - [ ] Public subnets: map_public_ip_on_launch = true
  - [ ] Private subnets: map_public_ip_on_launch = false
  - [ ] Private subnets have NAT gateway for outbound internet

- [ ] **IPv6 rules match IPv4**
  - [ ] If IPv4 restricted to CIDR, IPv6 also restricted
  - [ ] No ::/0 rules unless intended

---

## By-Service Exposure Decision Tree

```
Resource Type?
├── Database (RDS, Aurora, DocumentDB)
│   └── Should be public? NO → Error if publicly_accessible = true
├── Cache (ElastiCache, MemoryDB)
│   └── Should be public? NO → Error if in public subnet
├── API (API Gateway, ALB, NLB, ECS)
│   └── Should be public? YES → Verify security group allows 80/443 only
├── Static Site (S3 + CloudFront)
│   └── Should be public? S3: NO, CloudFront: YES → Block public S3 ACL
├── Lambda
│   └── Direct invocation public? Rare → Use IAM + API Gateway
├── Bastion/Jump Host
│   └── Should be public? YES → Restrict SSH to corporate IPs + MFA
└── Private App (EC2, ECS in private subnet)
    └── Should be public? NO → Error if public IP assigned
```

---

## Testing Public Exposure

### Terraform Plan Review

```bash
terraform plan -out=tfplan
terraform show tfplan | grep -i "publicly_accessible\|map_public\|cidr_blocks.*0\.0\.0\.0"
```

### Network Testing (Post-Deployment)

```bash
# Test RDS accessibility (should FAIL)
nmap -p 5432 <rds-endpoint>  # Should be filtered/closed

# Test S3 bucket from public internet (should FAIL)
aws s3 ls s3://my-bucket --no-sign-request  # Should error: Access Denied

# Test ALB (should succeed)
curl https://api.example.com  # Should work
```

### IAM Check for Public Access

```bash
# Find bucket policies allowing public access
aws s3api get-bucket-policy --bucket <bucket-name> | grep '"Principal".*"*"'

# Find security groups allowing 0.0.0.0/0
aws ec2 describe-security-groups --query 'SecurityGroups[?IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]]'
```

---

## Common Misconfigurations by Use Case

### Dev/Test Environment Leaking to Production

**Scenario**: Dev bucket settings copied to prod template, now production data is public

**Prevention:**
- [ ] Different IAM principals for dev vs. prod
- [ ] Separate Terraform state files
- [ ] Code review enforces `block_public_acls = true` in prod
- [ ] Prevent `publicly_accessible = true` on any database via policy

### Multi-Account Exposure

**Scenario**: Cross-account role assumed by public principal

```hcl
# ❌ WRONG: Cross-account role from anywhere
resource "aws_iam_role" "cross_account" {
  assume_role_policy = jsonencode({
    Principal = { AWS = "*" }  # ❌ Anyone can assume
  })
}

# ✅ CORRECT: Cross-account role from specific account only
resource "aws_iam_role" "cross_account" {
  assume_role_policy = jsonencode({
    Principal = { AWS = "arn:aws:iam::123456789012:root" }
    Condition = {
      StringEquals = {
        "sts:ExternalId" = var.external_id  # Prevent confused deputy
      }
    }
  })
}
```
