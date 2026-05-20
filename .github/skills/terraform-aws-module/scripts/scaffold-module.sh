#!/usr/bin/env bash
# scaffold-module.sh: Generate a new Terraform AWS module with best practices
# Usage: ./scaffold-module.sh <module-name> <aws-service-description>
# Example: ./scaffold-module.sh rds "AWS Relational Database Service"

set -euo pipefail

MODULE_NAME="${1:-}"
AWS_SERVICE="${2:-}"

# Validation
if [[ -z "$MODULE_NAME" ]]; then
    echo "❌ Error: Module name required"
    echo "Usage: $0 <module-name> <aws-service-description>"
    echo "Example: $0 rds 'AWS Relational Database Service'"
    exit 1
fi

# Check if module already exists
MODULE_PATH="modules/$MODULE_NAME"
if [[ -d "$MODULE_PATH" ]]; then
    echo "❌ Error: Module '$MODULE_NAME' already exists at $MODULE_PATH"
    exit 1
fi

# Create module directory
mkdir -p "$MODULE_PATH"
echo "✓ Created module directory: $MODULE_PATH"

# Create terraform.tf with version constraints
cat > "$MODULE_PATH/terraform.tf" << 'TERRAFORM_EOF'
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
TERRAFORM_EOF
echo "✓ Created terraform.tf with version pinning"

# Create variables.tf
cat > "$MODULE_PATH/variables.tf" << 'VARIABLES_EOF'
variable "aws_region" {
  description = "AWS region where resources will be deployed"
  type        = string
  default     = "eu-west-3"
}

variable "default_tags" {
  description = "Default tags applied to all resources for cost allocation and organization"
  type        = map(string)
  default = {
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}

variable "module_name" {
  description = "Name prefix for this module's resources"
  type        = string
  validation {
    condition     = length(var.module_name) > 0 && length(var.module_name) <= 64
    error_message = "module_name must be between 1 and 64 characters."
  }
}

# Add service-specific variables below
# Example:
# variable "instance_type" {
#   description = "Instance type for compute resources"
#   type        = string
#   sensitive   = false
# }
VARIABLES_EOF
echo "✓ Created variables.tf with common base variables"

# Create outputs.tf
cat > "$MODULE_PATH/outputs.tf" << 'OUTPUTS_EOF'
output "module_name" {
  description = "The name prefix of this module"
  value       = var.module_name
}

output "region" {
  description = "The AWS region where resources were deployed"
  value       = var.aws_region
}

# Add service-specific outputs below
# Example:
# output "instance_id" {
#   description = "The ID of the created instance"
#   value       = aws_instance.main.id
# }
# 
# output "endpoint" {
#   description = "The endpoint URL for client connections"
#   value       = aws_db_instance.main.endpoint
#   sensitive   = false
# }
OUTPUTS_EOF
echo "✓ Created outputs.tf with output conventions"

# Create main.tf template
cat > "$MODULE_PATH/main.tf" << 'MAIN_EOF'
# Resource definitions for this module
# 
# Security checklist:
# - [ ] No hardcoded credentials, API keys, or passwords
# - [ ] All sensitive values (secrets, passwords) use variables with sensitive=true
# - [ ] Database passwords use random_password or AWS Secrets Manager
# - [ ] No plaintext DB passwords in configuration
# - [ ] Security groups restrict inbound to needed ports only
# - [ ] Enable encryption at rest and in transit
#
# Best practices:
# - Use var.module_name as resource name prefix
# - Apply var.default_tags to all resources
# - Use descriptive names and add comments
# - Keep resources modular and focused
#
# Example (RDS):
# resource "aws_db_instance" "main" {
#   identifier     = "${var.module_name}-db"
#   engine         = "postgres"
#   instance_class = var.db_instance_class
#   allocated_storage = 20
#   
#   username = var.db_username
#   password = random_password.db_password.result  # Never hardcode!
#   
#   skip_final_snapshot = false
#   final_snapshot_identifier = "${var.module_name}-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
#   
#   tags = merge(var.default_tags, { Name = "${var.module_name}-db" })
# }

# TODO: Add resource definitions below
MAIN_EOF
echo "✓ Created main.tf with security checklist template"

# Create .gitignore for Terraform state and sensitive files
cat > "$MODULE_PATH/.gitignore" << 'GITIGNORE_EOF'
# Terraform files
.terraform/
.terraform.lock.hcl
*.tfstate
*.tfstate.*
*.tfvars
*.tfvars.json
crash.log
crash*.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# IDE
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store

# Plans
*.tfplan
tfplan
GITIGNORE_EOF
echo "✓ Created .gitignore for module"

# Create README for module
cat > "$MODULE_PATH/README.md" << 'README_EOF'
# Module: Service Name Here

[Add module description]

## Usage

```hcl
module "service_name" {
  source = "./modules/service_name"
  
  aws_region = "eu-west-3"
  module_name = "my-service"
  
  # Add service-specific variables
  # db_instance_class = "db.t3.micro"
}
```

## Variables

See [variables.tf](./variables.tf) for detailed variable descriptions and types.

## Outputs

See [outputs.tf](./outputs.tf) for output descriptions.

## Security Notes

- No hardcoded credentials in this module
- Sensitive values (passwords, API keys) use `sensitive = true` in variable definitions
- All resources encrypted at rest and in transit
- Security groups follow principle of least privilege

## Examples

[Add specific usage examples for your service]
README_EOF
echo "✓ Created README.md template"

echo ""
echo "✅ Module scaffolding complete!"
echo ""
echo "Next steps:"
echo "1. Edit $MODULE_PATH/variables.tf to add service-specific variables"
echo "2. Edit $MODULE_PATH/main.tf to add AWS resource definitions"
echo "3. Edit $MODULE_PATH/outputs.tf to export resource attributes"
echo "4. Edit $MODULE_PATH/README.md with usage documentation"
echo "5. Run: cd $MODULE_PATH && terraform fmt && terraform validate"
echo "6. Run: validate-secrets.sh $MODULE_PATH to check for hardcoded secrets"
echo ""
