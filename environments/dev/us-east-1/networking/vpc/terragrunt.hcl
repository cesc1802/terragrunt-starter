# ---------------------------------------------------------------------------------------------------------------------
# VPC - DEV ENVIRONMENT
# This file includes the common VPC configuration and can override specific values.
# ---------------------------------------------------------------------------------------------------------------------

# Include root terragrunt.hcl (backend, provider)
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Include common VPC configuration
include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/networking/vpc.hcl"
  expose = true
}

# ---------------------------------------------------------------------------------------------------------------------
# Environment-specific overrides (optional)
# Uncomment and modify as needed
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  # Override CIDR for dev environment
  cidr = "10.10.0.0/16"

  private_subnets = [
    "10.10.1.0/24",
    "10.10.2.0/24"
  ]

  public_subnets = [
    "10.10.101.0/24",
    "10.10.102.0/24"
  ]

  database_subnets = [
    "10.10.201.0/24",
    "10.10.202.0/24"
  ]
}
