# ---------------------------------------------------------------------------------------------------------------------
# VPC - PROD ENVIRONMENT (US-EAST-1)
# Production VPC with full high availability configuration
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/networking/vpc.hcl"
  expose = true
}

# ---------------------------------------------------------------------------------------------------------------------
# Production-specific configuration
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  cidr = "10.30.0.0/16"

  private_subnets = [
    "10.30.1.0/24",
    "10.30.2.0/24",
    "10.30.3.0/24"
  ]

  public_subnets = [
    "10.30.101.0/24",
    "10.30.102.0/24",
    "10.30.103.0/24"
  ]

  database_subnets = [
    "10.30.201.0/24",
    "10.30.202.0/24",
    "10.30.203.0/24"
  ]

  # Production: Enable VPC Flow Logs
  enable_flow_log = true
}
