# ---------------------------------------------------------------------------------------------------------------------
# ENVIRONMENT-LEVEL VARIABLES - DEV
# These variables apply to all resources in the dev environment.
# ---------------------------------------------------------------------------------------------------------------------

locals {
  environment = "dev"

  # Environment-specific settings
  instance_size_default      = "small" # Cost optimization for dev
  enable_deletion_protection = false
  enable_multi_az            = false # Single AZ for dev (cost saving)

  # VPC settings
  vpc_cidr = "10.10.0.0/16"

  # NAT Gateway - disabled for dev (cost optimization, ~$32/mo savings)
  # Enable if private subnets need outbound internet access
  enable_nat_gateway = false

  # VPC Flow Logs - disabled for dev (enable for debugging if needed, ~$0.50/GB)
  enable_flow_log = false

  # Tagging
  cost_allocation_tag = "dev-workloads"
}
