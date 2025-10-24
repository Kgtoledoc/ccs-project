terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "CCS"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "Infrastructure Team"
    }
  }
}

# Provider for Lambda@Edge (must be in us-east-1)
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "CCS"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "Infrastructure Team"
    }
  }
}

