# ---------------------------------------------------------------------------------------------------------------------
# COMMON S3 BUCKET CONFIGURATION
# Creates S3 bucket with versioning and encryption using terraform-aws-s3-bucket module.
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  source = "${dirname(find_in_parent_folders("account.hcl"))}/modules/terraform-aws-s3-bucket"
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  account_name = local.account_vars.locals.account_name
  environment  = local.env_vars.locals.environment
  aws_region   = local.region_vars.locals.aws_region

  # Allow force_destroy in non-prod environments
  force_destroy = local.environment != "prod"
}

inputs = {
  # Bucket name set in environment terragrunt.hcl
  # bucket = "${local.account_name}-${local.environment}-<purpose>"

  # Versioning
  versioning = {
    enabled = true
  }

  # Encryption
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  # Block public access
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  # Lifecycle
  force_destroy = local.force_destroy

  # Tags
  tags = {
    Component   = "storage"
    Environment = local.environment
    ManagedBy   = "Terragrunt"
  }
}
