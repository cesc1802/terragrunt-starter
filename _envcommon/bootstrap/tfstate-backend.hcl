# ---------------------------------------------------------------------------------------------------------------------
# COMMON TFSTATE-BACKEND CONFIGURATION
# Creates S3 bucket and DynamoDB table for Terraform remote state.
# BOOTSTRAP MODULE: Run with local state first, then migrate to S3.
# Bootstrap procedure: See Phase 04 in plans/260108-1243-terragrunt-init/phase-04-bootstrap-migration.md
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  # Local module - Cloud Posse terraform-aws-tfstate-backend
  # Path resolves from: environments/{env}/{region}/bootstrap/tfstate-backend/
  source = "${dirname(find_in_parent_folders("account.hcl"))}/modules/terraform-aws-tfstate-backend"
}

# ---------------------------------------------------------------------------------------------------------------------
# Load variables from hierarchy
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # Load configuration from hierarchy
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Extract commonly used variables
  account_name = local.account_vars.locals.account_name
  environment  = local.env_vars.locals.environment
  aws_region   = local.region_vars.locals.aws_region

  # Environment-specific protection settings
  enable_deletion_protection = local.env_vars.locals.enable_deletion_protection

  # Determine if force_destroy should be enabled (only for dev)
  force_destroy = local.environment == "dev"
}

# ---------------------------------------------------------------------------------------------------------------------
# Default inputs - can be overridden by environment-specific terragrunt.hcl
# ---------------------------------------------------------------------------------------------------------------------
#
# NOTE: Future enhancements for production:
# - S3 access logging: Add `logging` input to environment terragrunt.hcl
# - Cross-region replication: Configure `s3_replication_enabled` and `s3_replica_bucket_arn`
# - KMS encryption: Change `sse_encryption` to "aws:kms" with `kms_master_key_id`
# - Lifecycle rules: Module uses S3 versioning; add lifecycle via AWS console/CLI if needed
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  # Cloud Posse Label inputs
  namespace  = local.account_name
  stage      = local.environment
  name       = "terraform"
  attributes = ["state"]

  # S3 Bucket settings
  force_destroy               = local.force_destroy
  prevent_unencrypted_uploads = true
  enable_public_access_block  = true
  block_public_acls           = true
  block_public_policy         = true
  ignore_public_acls          = true
  restrict_public_buckets     = true

  # DynamoDB settings
  billing_mode                  = "PAY_PER_REQUEST"
  enable_point_in_time_recovery = true
  deletion_protection_enabled   = local.enable_deletion_protection

  # Encryption
  sse_encryption = "AES256"

  # Tags (Region tag for resource identification)
  tags = {
    Component   = "bootstrap"
    Environment = local.environment
    Region      = local.aws_region
    ManagedBy   = "Terragrunt"
  }
}
