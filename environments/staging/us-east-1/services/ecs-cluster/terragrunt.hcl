# ---------------------------------------------------------------------------------------------------------------------
# ECS CLUSTER - DEV ENVIRONMENT
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/services/ecs-cluster.hcl"
  expose = true
}

# ---------------------------------------------------------------------------------------------------------------------
# Dependencies
# Terragrunt will ensure VPC is created before ECS cluster
# ---------------------------------------------------------------------------------------------------------------------

dependency "vpc" {
  config_path = "../../networking/vpc"

  # Mock outputs for `terragrunt plan` when VPC doesn't exist yet
  mock_outputs = {
    vpc_id          = "vpc-mock-12345"
    private_subnets = ["subnet-mock-1", "subnet-mock-2"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# ---------------------------------------------------------------------------------------------------------------------
# Inputs with dependency outputs
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  # Pass VPC info to ECS if needed by services
  # vpc_id          = dependency.vpc.outputs.vpc_id
  # private_subnets = dependency.vpc.outputs.private_subnets
}
