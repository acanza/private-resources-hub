terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state stored in S3.
  # Prerequisite before running terraform init:
  #   Create an S3 bucket for state storage and replace the placeholder below.
  #   Versioning is recommended to allow recovery of previous states.
  backend "s3" {
    bucket  = "private-resources-hub-project-tfstate"
    key     = "envs/dev/terraform.tfstate"
    region  = "eu-west-3"
    encrypt = true
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
