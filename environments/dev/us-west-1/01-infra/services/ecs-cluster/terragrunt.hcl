# ---------------------------------------------------------------------------------------------------------------------
# ECS CLUSTER - DEV US-WEST-1
# Fargate cluster for container workloads in us-west-1.
# Configuration inherited from _envcommon/services/ecs-cluster.hcl.
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/services/ecs-cluster.hcl"
  expose = true
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  account_name = local.account_vars.locals.account_name
  environment  = local.env_vars.locals.environment
}

dependency "vpc" {
  config_path = "../../network/vpc"

  mock_outputs = {
    vpc_id = "vpc-mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "iam" {
  config_path = "../../security/iam-roles"

  mock_outputs = {
    iam_role_arn = "arn:aws:iam::123456789012:role/mock-role"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  cluster_name = "${local.account_name}-${local.environment}-usw1-cluster"
}
