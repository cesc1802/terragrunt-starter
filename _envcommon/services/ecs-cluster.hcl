# ---------------------------------------------------------------------------------------------------------------------
# COMMON ECS CLUSTER CONFIGURATION
# This file contains the common configuration for ECS Cluster shared across all environments.
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  source = "tfr:///terraform-aws-modules/ecs/aws?version=5.11.0"
}

# ---------------------------------------------------------------------------------------------------------------------
# Load variables from hierarchy
# ---------------------------------------------------------------------------------------------------------------------

locals {
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  environment  = local.env_vars.locals.environment
  account_name = local.account_vars.locals.account_name
}

# ---------------------------------------------------------------------------------------------------------------------
# Default inputs
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  cluster_name = "${local.account_name}-${local.environment}"

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
  cluster_settings = {
    name  = "containerInsights"
    value = local.environment == "prod" ? "enabled" : "disabled"
  }

  tags = {
    Component = "ecs"
  }
}
