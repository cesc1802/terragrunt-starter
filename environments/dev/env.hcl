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

  # Tagging
  cost_allocation_tag = "dev-workloads"
}
