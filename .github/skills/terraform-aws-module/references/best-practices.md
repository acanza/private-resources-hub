# Terraform AWS Module Best Practices

This reference guide documents conventions, patterns, and best practices for creating production-ready Terraform modules on AWS.

## Table of Contents

1. [Module Structure](#module-structure)
2. [Version Pinning](#version-pinning)
3. [Variable Design](#variable-design)
4. [Resource Configuration](#resource-configuration)
5. [Output Documentation](#output-documentation)
6. [Security](#security)
7. [Testing and Validation](#testing-and-validation)
8. [Documentation](#documentation)

## Module Structure

```
modules/<service-name>/
├── terraform.tf       # Provider, version, required_providers
├── variables.tf       # Input variables with validation
├── outputs.tf        # Output values with descriptions
├── main.tf           # Resource definitions
├── data.tf           # (optional) Data source queries
├── locals.tf         # (optional) Local values computed from inputs
├── README.md         # Usage documentation and examples
└── .gitignore        # Exclude state files and secrets
```

### File Responsibilities

| File | Purpose |
|------|---------|
| `terraform.tf` | Declare required Terraform version, providers, and their versions |
| `variables.tf` | Define all input variables with type, default, description |
| `main.tf` | Create AWS resources with variables and tags |
| `data.tf` | Query existing AWS resources (VPCs, AMIs, availability zones) |
| `outputs.tf` | Export resource attributes for other modules to reference |
| `locals.tf` | Compute derived values used across resources |
| `README.md` | Document usage, required variables, outputs, and examples |

## Version Pinning

**Why**: Without version pinning, future Terraform/provider updates could break your infrastructure code.

### terraform.tf Example

```hcl
terraform {
  required_version = ">= 1.5, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # If using multiple providers:
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = var.default_tags
  }
}
```

### Version Constraint Operators

| Operator | Meaning | Example |
|----------|---------|---------|
| `=` | Exact version | `version = "5.3.0"` |
| `~>` | Minor patch allowed | `version = "~> 5.0"` → allows 5.0.0 to 5.9.9 |
| `>=` | Greater than or equal | `version = ">= 1.5"` |
| `<=` | Less than or equal | `version = "<= 2.0"` |
| `!=` | Not equal | `version = "!= 4.0"` |
| Multiple | Combine constraints | `version = ">= 1.5, < 2.0"` |

### Pin Both Terraform and Providers

```hcl
# Lock Terraform to stable minor versions
required_version = ">= 1.5, < 2.0"

# Lock AWS provider to major version
version = "~> 5.0"      # Allows 5.0.0-5.999.999
version = "~> 5.3"      # Allows 5.3.0-5.9999.999
version = "~> 5.3.0"    # Allows 5.3.0-5.3.9999
```

## Variable Design

### Input Variable Checklist

- [ ] Every variable has `description`
- [ ] Every variable has explicit `type`
- [ ] Sensitive variables use `sensitive = true`
- [ ] Complex inputs have validation blocks
- [ ] Defaults are sensible (dev values, not prod)
- [ ] Names are descriptive without abbreviations

### Example: Comprehensive Variables

```hcl
variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "eu-west-3"
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Must be dev, stage, or prod."
  }
}

variable "instance_config" {
  description = "Configuration for compute instances"
  type = object({
    count          = number
    instance_type  = string
    enable_ebs_optimization = bool
  })
  validation {
    condition     = var.instance_config.count > 0
    error_message = "Instance count must be at least 1."
  }
}

variable "database_password" {
  description = "Master database password"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.database_password) >= 12
    error_message = "Password must be minimum 12 characters."
  }
}
```

## Resource Configuration

### Use Variables Consistently

```hcl
# Define a base module name
variable "module_name" {
  type        = string
  description = "Base name for all resources"
}

# Use it in resource naming
resource "aws_instance" "main" {
  tags = {
    Name = "${var.module_name}-instance"
  }
}

resource "aws_security_group" "main" {
  name        = "${var.module_name}-sg"
  description = "Security group for ${var.module_name}"
}
```

### Apply Tags Universally

```hcl
# Define standard tags at the provider level
provider "aws" {
  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = var.environment
      Module      = var.module_name
      Team        = "platform"
    }
  }
}

# Merge with resource-specific tags
resource "aws_instance" "web" {
  tags = merge(
    var.default_tags,
    {
      Name = "${var.module_name}-web"
    }
  )
}
```

### Enable Logging and Monitoring

```hcl
# RDS: Enable CloudWatch logs
resource "aws_db_instance" "main" {
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
}

# ECS: Enable CloudWatch logging for container tasks
resource "aws_ecs_task_definition" "main" {
  container_definitions = jsonencode([{
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}
```

### Enable Encryption

```hcl
# EBS volumes
root_block_device {
  encrypted = true
  kms_key_id = aws_kms_key.ebs.arn
}

# RDS storage
storage_encrypted = true
kms_key_id        = aws_kms_key.rds.arn

# S3 bucket
server_side_encryption_configuration {
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
  }
}
```

## Output Documentation

### Output Checklist

- [ ] Every output has `description`
- [ ] Output values reference actual resource attributes
- [ ] Sensitive outputs use `sensitive = true`
- [ ] Related outputs are grouped logically
- [ ] Output names are descriptive

### Example: Complete Outputs

```hcl
# Identifiers
output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.main.id
}

# Endpoints
output "rds_endpoint" {
  description = "RDS database endpoint for client connections"
  value       = aws_db_instance.main.endpoint
}

# ARNs
output "role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.lambda.arn
}

# Credentials (sensitive)
output "database_password" {
  description = "Database master password (store securely!)"
  value       = random_password.db.result
  sensitive   = true
}

# Computed URLs
output "api_endpoint" {
  description = "API Gateway invoke URL"
  value       = aws_api_gateway_stage.prod.invoke_url
}

# Composite outputs
output "connection_details" {
  description = "Database connection details for application"
  value = {
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    username = aws_db_instance.main.username
    database = aws_db_instance.main.db_name
  }
  sensitive = false  # Password should come from Secrets Manager
}
```

## Security

### Secrets Management

❌ **Never** hardcode secrets in Terraform files:
```hcl
# WRONG
password = "MyPassword123"
api_key  = "sk_live_abc123xyz"
```

✅ **Do** use these approaches:

#### Option 1: Variables (via tfvars)
```hcl
# main.tf
variable "db_password" {
  type      = string
  sensitive = true
}

# terraform.tfvars (add to .gitignore!)
db_password = "SecurePassword123!"
```

#### Option 2: Environment Variables
```bash
# Set before running terraform
export TF_VAR_db_password="SecurePassword123!"
terraform plan
```

#### Option 3: AWS Secrets Manager (Recommended for production)
```hcl
data "aws_secretsmanager_secret_version" "db" {
  secret_id = "prod/rds/password"
}

resource "aws_db_instance" "main" {
  password = jsondecode(data.aws_secretsmanager_secret_version.db.secret_string).password
}
```

#### Option 4: Generate Passwords Dynamically
```hcl
resource "random_password" "db" {
  length  = 16
  special = true
}

resource "aws_db_instance" "main" {
  password = random_password.db.result
}

# Store the generated password in Secrets Manager
resource "aws_secretsmanager_secret" "db" {
  name = "${var.module_name}-db-password"
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id      = aws_secretsmanager_secret.db.id
  secret_string  = random_password.db.result
}
```

### Network Security

```hcl
# Restrict security group ingress
resource "aws_security_group" "db" {
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Only if necessary
  }

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]  # Limit to app tier
  }
}

# RDS: Disable public accessibility by default
resource "aws_db_instance" "main" {
  publicly_accessible = false  # Default to private
  
  db_subnet_group_name = aws_db_subnet_group.main.name
}
```

### IAM Principle of Least Privilege

```hcl
# Grant only necessary permissions
resource "aws_iam_role_policy" "lambda" {
  name = "${var.module_name}-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]  # Specific action
        Resource = "${aws_s3_bucket.data.arn}/*"  # Specific resource
      }
    ]
  })
}
```

## Testing and Validation

### Run Before Committing

```bash
# Check formatting
terraform fmt -check modules/<name>

# Validate syntax
terraform validate -chdir=modules/<name>

# Generate plan (review carefully!)
terraform plan -chdir=modules/<name> -out=tfplan

# Check for secrets
./scripts/validate-secrets.sh modules/<name>

# Lint with TFLint (if available)
tflint modules/<name>
```

### Terraform Validation Example

```hcl
# Add validation blocks to catch errors early
variable "instance_count" {
  type = number
  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 100
    error_message = "Instance count must be 1-100."
  }
}

# Terraform will fail immediately on invalid input
```

## Documentation

### README.md Template

```markdown
# Module: Service Name

Brief description of what this module provides.

## Usage

### Basic Example
\`\`\`hcl
module "service" {
  source = "./modules/service"
  
  aws_region  = "eu-west-3"
  environment = "prod"
  instance_count = 3
}
```

## Variables

| Name | Type | Default | Required | Description |
|------|------|---------|----------|-------------|
| aws_region | string | "eu-west-3" | No | AWS region |
| environment | string | - | Yes | Environment (dev/stage/prod) |

## Outputs

| Name | Description |
|------|-------------|
| instance_ids | IDs of created instances |
| endpoint | Service endpoint URL |

## Security

- All data encrypted at rest and in transit
- No hardcoded credentials
- Database publicly_accessible = false
- Minimum IAM permissions per resource

## Dependencies

- AWS provider >= 5.0
- Terraform >= 1.5
```

### Document Assumptions

```markdown
## Assumptions

- AWS account already configured with default VPC
- IAM user has permissions to create EC2, RDS, security groups
- SSH keys already exist in the region
- Default tags will be applied to all resources

## Limitations

- Single region only (update code for multi-region)
- Does not create database backups policy
- Does not configure CloudFront CDN
```

## Common Patterns

### Count for Conditional Resources

```hcl
variable "enable_database" {
  type    = bool
  default = false
}

resource "aws_db_instance" "main" {
  count = var.enable_database ? 1 : 0
  # ...
}

output "db_endpoint" {
  value = var.enable_database ? aws_db_instance.main[0].endpoint : null
}
```

### For-Each for Multiple Similar Resources

```hcl
variable "subnets" {
  type = map(string)
  default = {
    "private-1" = "10.0.1.0/24"
    "private-2" = "10.0.2.0/24"
  }
}

resource "aws_subnet" "main" {
  for_each = var.subnets
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = data.aws_availability_zones.available.names[index(keys(var.subnets), each.key)]
  
  tags = {
    Name = each.key
  }
}
```

### DRY: Using Locals for Common Values

```hcl
locals {
  common_tags = {
    ManagedBy  = "Terraform"
    Module     = var.module_name
    CreatedAt  = timestamp()
  }
  
  service_port = var.environment == "prod" ? 443 : 8080
}

resource "aws_security_group" "main" {
  tags = local.common_tags
  
  ingress {
    from_port = local.service_port
    to_port   = local.service_port
    protocol  = "tcp"
  }
}
```

---

## Additional Resources

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Module Registry](https://registry.terraform.io/browse/modules?provider=aws)
- [AWS Best Practices](https://docs.aws.amazon.com/index.html)
