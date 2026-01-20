# ---------------------------------------------------------------------------------------------------------------------
# COMMON IAM ROLES CONFIGURATION
# Creates IAM roles for ECS tasks and other services using terraform-aws-iam module.
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  source = "${dirname(find_in_parent_folders("account.hcl"))}/modules/terraform-aws-iam//modules/iam-assumable-role"
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  account_name = local.account_vars.locals.account_name
  environment  = local.env_vars.locals.environment
  aws_region   = local.region_vars.locals.aws_region

  role_name_prefix = "${local.account_name}-${local.environment}"
}

inputs = {
  # Role configuration set in environment terragrunt.hcl
  # role_name = "${local.role_name_prefix}-<service>-role"

  create_role = true

  # Trusted services (override as needed)
  trusted_role_services = ["ecs-tasks.amazonaws.com"]

  # Tags
  tags = {
    Component   = "security"
    Environment = local.environment
    ManagedBy   = "Terragrunt"
  }
}
