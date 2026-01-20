# ---------------------------------------------------------------------------------------------------------------------
# IAM ROLES - DEV US-WEST-1
# Creates IAM roles for ECS tasks and other services.
# Configuration inherited from _envcommon/security/iam-roles.hcl.
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/security/iam-roles.hcl"
  expose = true
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  account_name = local.account_vars.locals.account_name
  environment  = local.env_vars.locals.environment
}

inputs = {
  role_name = "${local.account_name}-${local.environment}-usw1-ecs-task-role"

  trusted_role_services = ["ecs-tasks.amazonaws.com"]

  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
}
