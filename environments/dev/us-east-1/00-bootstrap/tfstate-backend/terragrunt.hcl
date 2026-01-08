# ---------------------------------------------------------------------------------------------------------------------
# TERRAFORM STATE BACKEND - DEV
# BOOTSTRAP MODULE: Creates S3 bucket and DynamoDB table for Terraform state storage.
#
# BOOTSTRAP PROCEDURE:
# 1. First run: terragrunt apply (uses local state)
# 2. After success: uncomment "root" include, run terragrunt init -migrate-state
# ---------------------------------------------------------------------------------------------------------------------

# UNCOMMENT AFTER BOOTSTRAP IS COMPLETE:
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Include common tfstate-backend configuration
include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/bootstrap/tfstate-backend.hcl"
  expose = true
}

# Generate local backend for bootstrap (remove after migration)
# generate "backend" {
#   path      = "backend.tf"
#   if_exists = "overwrite_terragrunt"
#   contents  = <<EOF
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }
# EOF
# }

# Generate provider (module has versions.tf with required_providers) (remove after migration)
# generate "provider" {
#   path      = "provider.tf"
#   if_exists = "overwrite_terragrunt"
#   contents  = <<EOF
# provider "aws" {
#   region = "us-east-1"
#   default_tags {
#     tags = {
#       Environment = "dev"
#       ManagedBy   = "Terragrunt"
#       Component   = "bootstrap"
#     }
#   }
# }
# EOF
# }

# Dev-specific overrides (if any needed beyond envcommon defaults)
inputs = {
  # Dev can have force_destroy for easy cleanup (already set in envcommon)
  # Add any dev-specific overrides here
}
