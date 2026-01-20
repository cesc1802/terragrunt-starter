# ---------------------------------------------------------------------------------------------------------------------
# COMMON ECS CLUSTER CONFIGURATION
# Creates ECS cluster with Fargate support using terraform-aws-ecs module.
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  source = "${dirname(find_in_parent_folders("account.hcl"))}/modules/terraform-aws-ecs//modules/cluster"
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  account_name = local.account_vars.locals.account_name
  environment  = local.env_vars.locals.environment
  aws_region   = local.region_vars.locals.aws_region

  cluster_name = "${local.account_name}-${local.environment}-cluster"

  # Container Insights - enabled for prod only (cost optimization)
  enable_container_insights = local.environment == "prod"
}

inputs = {
  cluster_name = local.cluster_name

  # Fargate capacity providers
  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 50
        base   = 20
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 50
      }
    }
  }

  # Container Insights
  cluster_settings = [
    {
      name  = "containerInsights"
      value = local.enable_container_insights ? "enabled" : "disabled"
    }
  ]

  # Tags
  tags = {
    Component   = "compute"
    Environment = local.environment
    ManagedBy   = "Terragrunt"
  }
}
