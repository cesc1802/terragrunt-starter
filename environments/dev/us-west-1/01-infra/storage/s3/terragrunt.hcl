# ---------------------------------------------------------------------------------------------------------------------
# S3 BUCKET - DEV US-WEST-1
# Application data bucket for us-west-1 region.
# Configuration inherited from _envcommon/storage/s3.hcl.
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/storage/s3.hcl"
  expose = true
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  account_name = local.account_vars.locals.account_name
  environment  = local.env_vars.locals.environment
}

inputs = {
  bucket = "${local.account_name}-${local.environment}-usw1-app-data"
}
