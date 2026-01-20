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

  # VPC settings (CIDR now in region.hcl for region-specific allocation)
  enable_nat_gateway = false # Disabled for dev (cost optimization, ~$32/mo savings)
  enable_flow_log    = false # Disabled for dev (enable for debugging if needed, ~$0.50/GB)

  # Tagging
  cost_allocation_tag = "dev-workloads"
}
