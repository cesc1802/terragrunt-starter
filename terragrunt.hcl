# ---------------------------------------------------------------------------------------------------------------------
# ROOT TERRAGRUNT CONFIGURATION
# This is the root configuration that all other terragrunt.hcl files include.
# It defines the remote state backend and provider configuration.
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  # Automatically load region-level variables
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Automatically load environment-level variables
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  # Extract commonly used variables for easy access
  account_id   = local.account_vars.locals.aws_account_id
  account_name = local.account_vars.locals.account_name
  aws_region   = local.region_vars.locals.aws_region
  environment  = local.env_vars.locals.environment
}

# ---------------------------------------------------------------------------------------------------------------------
# REMOTE STATE CONFIGURATION
# Configure S3 as the backend for storing Terraform state files.
# The state file path is automatically derived from the folder structure.
# ---------------------------------------------------------------------------------------------------------------------

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    # Naming aligned with Cloud Posse terraform-aws-tfstate-backend module output
    # Pattern: {namespace}-{stage}-{name}-{attributes} = {account_name}-{environment}-terraform-state
    bucket         = "${local.account_name}-${local.environment}-terraform-state"
    key            = "${local.aws_region}/${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1" # State bucket region (keep consistent)
    encrypt        = true
    dynamodb_table = "${local.account_name}-${local.environment}-terraform-state"

    # Prevent accidental deletion
    skip_bucket_versioning             = false
    skip_bucket_root_access            = false
    skip_bucket_enforced_tls           = false
    skip_bucket_public_access_blocking = false
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# PROVIDER CONFIGURATION
# Generate the AWS provider configuration with default tags.
# ---------------------------------------------------------------------------------------------------------------------

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<EOF
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "${local.aws_region}"

  default_tags {
    tags = {
      Environment = "${local.environment}"
      ManagedBy   = "Terragrunt"
      Project     = "${local.account_name}"
      Region      = "${local.aws_region}"
    }
  }
}
EOF
}

# ---------------------------------------------------------------------------------------------------------------------
# GLOBAL INPUTS
# These inputs are passed to all Terraform modules.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  aws_region   = local.aws_region
  environment  = local.environment
  account_id   = local.account_id
  account_name = local.account_name
}
