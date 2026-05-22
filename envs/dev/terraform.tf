terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  # Remote state stored in S3 with DynamoDB locking.
  # Prerequisites before running terraform init:
  #   1. Create an S3 bucket for state storage (versioning and encryption recommended).
  #   2. Create a DynamoDB table with a string partition key named "LockID".
  #   3. Replace the placeholder values below with the actual bucket and table names.
  backend "s3" {
    bucket         = "REPLACE_WITH_STATE_BUCKET_NAME"
    key            = "envs/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "REPLACE_WITH_LOCK_TABLE_NAME"
  }
}

provider "aws" {
  region = var.aws_region

  # Default tags applied to every resource managed by this provider.
  # Individual modules may add resource-specific tags via their own tags variable.
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
