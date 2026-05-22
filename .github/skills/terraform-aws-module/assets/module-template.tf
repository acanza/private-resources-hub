# Terraform Module Structure Template

This file shows the recommended structure and patterns for AWS resource definitions in Terraform modules.

## Core Principles

1. **Version Pinning**: Always pin provider and Terraform versions to prevent breaking changes
2. **Variable Validation**: Use type constraints and validation blocks to catch configuration errors early
3. **Output Documentation**: Export all public resource attributes with clear descriptions
4. **Default Tags**: Apply consistent tags via provider default_tags for cost allocation
5. **Security**: Never hardcode credentials; use variables with `sensitive = true` for secrets
6. **Modular Resources**: Keep resource blocks focused and reusable

## Sample Module: RDS Database

```hcl
# terraform.tf - Version constraints
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
  default_tags {
    tags = var.default_tags
  }
}

# variables.tf - Input interface
variable "aws_region" {
  type        = string
  default     = "eu-west-3"
  description = "AWS region for resource deployment"
}

variable "db_instance_class" {
  type        = string
  description = "RDS instance class (e.g., db.t3.micro, db.r5.large)"
  validation {
    condition     = startswith(var.db_instance_class, "db.")
    error_message = "Instance class must start with 'db.'"
  }
}

variable "db_username" {
  type        = string
  description = "Master database username"
  sensitive   = true
  validation {
    condition     = length(var.db_username) >= 1 && length(var.db_username) <= 16
    error_message = "Username must be 1-16 characters."
  }
}

variable "db_password" {
  type        = string
  description = "Master database password (use AWS Secrets Manager in production)"
  sensitive   = true
  validation {
    condition     = length(var.db_password) >= 12
    error_message = "Password must be at least 12 characters."
  }
}

# main.tf - Resource definitions
resource "aws_db_instance" "main" {
  identifier     = "${var.module_name}-postgres"
  allocated_storage = 20
  storage_type   = "gp3"
  engine         = "postgres"
  engine_version = "15.3"
  instance_class = var.db_instance_class

  username = var.db_username
  password = var.db_password

  storage_encrypted = true  # IMPORTANT: Always encrypt
  skip_final_snapshot = false
  final_snapshot_identifier = "${var.module_name}-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = merge(var.default_tags, {
    Name = "${var.module_name}-db"
  })
}

# outputs.tf - Export resource attributes
output "db_endpoint" {
  description = "RDS instance endpoint for client connections"
  value       = aws_db_instance.main.endpoint
}

output "db_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "db_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.main.arn
}
```

## Important Patterns

### Password Handling ❌ DON'T DO THIS
```hcl
# WRONG: Hardcoded password
password = "MyFixedPassword123"
password = "admin"
```

### Correct: Use Variables or AWS Secrets Manager ✅ DO THIS
```hcl
# Option 1: Pass via variable (tfvars file, terraform.tfvars.json)
password = var.db_password

# Option 2: Generate random password
resource "random_password" "db" {
  length  = 16
  special = true
}
password = random_password.db.result

# Option 3: Use AWS Secrets Manager (best for production)
password = aws_secretsmanager_secret_version.db.secret_string
```

### Variable Sensitivity
```hcl
variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true  # Prevents value from printing in logs
}
```

### Default Tags Pattern
```hcl
provider "aws" {
  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = "prod"
      CostCenter  = "engineering"
    }
  }
}

# All resources automatically get these tags
resource "aws_instance" "web" {
  # ... configuration ...
  # tags already applied from default_tags
}
```

## File Organization

```
modules/rds/
├── terraform.tf         # Provider and version constraints
├── variables.tf         # Input variables with validation
├── outputs.tf          # Exported resource attributes
├── main.tf             # Resource definitions
├── README.md           # Usage documentation
├── .gitignore          # Exclude sensitive files from git
└── examples/           # (Optional) Real usage examples
    └── basic.tfvars
```

## Common Validation Patterns

```hcl
# String length
variable "name" {
  type = string
  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 64
    error_message = "Name must be 1-64 characters."
  }
}

# Allowed values
variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Environment must be dev, stage, or prod."
  }
}

# Pattern matching
variable "email" {
  type = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.email))
    error_message = "Must be a valid email address."
  }
}

# Tag validation
variable "tags" {
  type = map(string)
  validation {
    condition = alltrue([
      for key in keys(var.tags) : length(key) > 0 && length(key) <= 128
    ])
    error_message = "Tag keys must be 1-128 characters."
  }
}
```

## Security Checklist

- [ ] No hardcoded credentials (passwords, API keys, tokens)
- [ ] All sensitive variables use `sensitive = true`
- [ ] Encryption enabled on storage and data services
- [ ] Security groups/NACLs restrict inbound traffic
- [ ] Database backups enabled with retention policy
- [ ] Logging enabled for audit trails
- [ ] No public accessibility unless explicitly needed
- [ ] IAM roles follow least privilege
- [ ] Validated all variable inputs with constraints
