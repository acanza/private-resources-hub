# Variables and Outputs Template

This file documents the patterns for defining input variables and output values in Terraform modules.

## Variable Definition Best Practices

Every variable should include:
- `description` — Clear explanation of what the variable is for
- `type` — Data type (string, number, bool, list, map, object, any)
- `default` — Optional default value (if not provided, variable is required)
- `sensitive` — true for secrets, passwords, API keys
- `validation` — Input constraints to catch errors early

### Examples

```hcl
# Simple required variable
variable "instance_name" {
  description = "Name for the EC2 instance"
  type        = string
}

# Optional with default
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

# Sensitive variable (passwords, tokens)
variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.db_password) >= 12
    error_message = "Password must be at least 12 characters."
  }
}

# List of values
variable "availability_zones" {
  description = "List of AZs for multi-AZ deployment"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# Map of key-value pairs
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
  }
}

# Complex object
variable "database_config" {
  description = "Database configuration"
  type = object({
    engine         = string
    instance_class = string
    allocated_storage = number
  })
}

# Enum/Restricted values
variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Environment must be dev, stage, or prod."
  }
}

# Number with constraints
variable "replica_count" {
  description = "Number of read replicas"
  type        = number
  default     = 2
  validation {
    condition     = var.replica_count >= 0 && var.replica_count <= 10
    error_message = "Replica count must be 0-10."
  }
}

# Boolean flag
variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring"
  type        = bool
  default     = true
}

# Computed value (no default allowed)
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
}
```

## Output Definition Best Practices

Every output should include:
- `description` — Explain what the output provides
- `value` — Reference to resource attribute
- `sensitive` — true if output contains secrets
- `depends_on` — (optional) Explicit dependency if needed

### Examples

```hcl
# Simple output
output "instance_id" {
  description = "The EC2 instance ID"
  value       = aws_instance.main.id
}

# Output with sensitive data
output "db_password" {
  description = "Database master password (for initial setup only)"
  value       = aws_db_instance.main.password
  sensitive   = true
}

# Computed output
output "instance_public_ip" {
  description = "Public IP address of the instance"
  value       = aws_instance.main.public_ip
}

# Multiple values as map
output "endpoints" {
  description = "Service endpoints"
  value = {
    database = aws_db_instance.main.endpoint
    api      = aws_api_gateway_stage.main.invoke_url
    cache    = aws_elasticache_cluster.main.configuration_endpoint_address
  }
}

# List output
output "availability_zones" {
  description = "AZs where resources are deployed"
  value       = data.aws_availability_zones.available.names
}

# Output with processing
output "database_connection_string" {
  description = "PostgreSQL connection string"
  value       = "postgresql://${var.db_username}@${aws_db_instance.main.endpoint}/mydb"
  sensitive   = true
}

# ARN output
output "instance_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.main.arn
}
```

## Common Variable Patterns for AWS Resources

### Naming Convention
```hcl
variable "module_name" {
  description = "Base name for all resources (e.g., 'myapp', 'api-service')"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.module_name))
    error_message = "Module name must contain only lowercase letters, numbers, and hyphens."
  }
}

# Use in resources:
# aws_instance "main" {
#   tags = { Name = "${var.module_name}-instance" }
# }
```

### Region and Availability Zones
```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "Availability zones for redundancy"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
```

### Tags for Cost Allocation
```hcl
variable "default_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    ManagedBy   = "Terraform"
    Environment = "dev"
    Team        = "engineering"
    CostCenter  = "cloud-ops"
  }
}

# Used via provider:
# provider "aws" {
#   default_tags {
#     tags = var.default_tags
#   }
# }
```

### VPC and Network
```hcl
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 1))
    error_message = "Must be a valid CIDR block."
  }
}

variable "subnet_cidrs" {
  description = "CIDR blocks for subnets"
  type        = list(string)
  validation {
    condition = alltrue([
      for cidr in var.subnet_cidrs : can(cidrhost(cidr, 1))
    ])
    error_message = "All subnet CIDRs must be valid."
  }
}
```

### Security and Secrets
```hcl
variable "api_key" {
  description = "External API key for integrations"
  type        = string
  sensitive   = true
  # Should be provided via:
  # - terraform.tfvars (in .gitignore)
  # - Environment variables: TF_VAR_api_key
  # - AWS Secrets Manager
}

variable "tls_enabled" {
  description = "Enable TLS/SSL encryption"
  type        = bool
  default     = true
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access resources"
  type        = list(string)
  validation {
    condition = alltrue([
      for cidr in var.allowed_cidr_blocks : can(cidrhost(cidr, 1))
    ])
    error_message = "All CIDRs must be valid."
  }
}
```

## Anti-Patterns ❌

```hcl
# Wrong: Missing description
variable "foo" {
  type = string
}

# Wrong: No validation for sensitive data
variable "password" {
  type = string
}

# Wrong: Magic numbers without explanation
variable "count" {
  type    = number
  default = 3
}

# Wrong: Missing type
variable "config" {
  default = { key = "value" }
}

# Wrong: Hardcoded secrets in variable default
variable "api_key" {
  type    = string
  default = "sk_live_abc123xyz"
}
```

## Best Practices ✅

```hcl
# Right: Complete variable definition
variable "instance_count" {
  description = "Number of instances to create (1-10)"
  type        = number
  default     = 3
  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}

# Right: Sensitive flag for secrets
variable "db_password" {
  description = "Database password (must be 12+ chars)"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.db_password) >= 12
    error_message = "Password must be at least 12 characters."
  }
}

# Right: Output with full details
output "instance_endpoint" {
  description = "Endpoint to access the service"
  value       = aws_instance.main.public_dns
}
```
