# Backend configuration for Terraform state
# This file should be configured per environment

# Example for production:
# terraform {
#   backend "s3" {
#     bucket         = "ccs-terraform-state-prod"
#     key            = "terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "ccs-terraform-locks-prod"
#   }
# }

# For local development, comment out the backend block above
# State will be stored locally in terraform.tfstate

