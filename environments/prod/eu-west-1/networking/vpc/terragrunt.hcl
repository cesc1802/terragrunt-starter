# ---------------------------------------------------------------------------------------------------------------------
# VPC - PROD ENVIRONMENT (EU-WEST-1)
# Production VPC in EU region for multi-region deployment
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/networking/vpc.hcl"
  expose = true
}

# ---------------------------------------------------------------------------------------------------------------------
# EU Region-specific configuration (different CIDR to allow peering)
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  name = "vpc-prod-eu"
  cidr = "10.40.0.0/16" # Different CIDR from us-east-1 for VPC peering

  private_subnets = [
    "10.40.1.0/24",
    "10.40.2.0/24",
    "10.40.3.0/24"
  ]

  public_subnets = [
    "10.40.101.0/24",
    "10.40.102.0/24",
    "10.40.103.0/24"
  ]

  database_subnets = [
    "10.40.201.0/24",
    "10.40.202.0/24",
    "10.40.203.0/24"
  ]

  enable_flow_log = true
}
