# ---------------------------------------------------------------------------------------------------------------------
# ENVIRONMENT-LEVEL VARIABLES - UAT
# These variables apply to all resources in the uat environment.
# ---------------------------------------------------------------------------------------------------------------------

locals {
  environment = "uat"

  # Environment-specific settings
  instance_size_default      = "medium" # Same as staging, moderate capacity
  enable_deletion_protection = true     # Protect UAT resources
  enable_multi_az            = false    # Single AZ for UAT (cost saving)

  # Tagging
  cost_allocation_tag = "uat-workloads"
}
