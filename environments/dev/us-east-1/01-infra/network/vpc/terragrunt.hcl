# ---------------------------------------------------------------------------------------------------------------------
# DEV VPC - US-EAST-1
# Creates VPC with public, private, and database subnets for dev environment.
# NAT Gateway disabled for cost optimization.
# ---------------------------------------------------------------------------------------------------------------------

# Include root configuration (backend, provider)
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Include common VPC configuration
include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/networking/vpc.hcl"
  expose = true
}

# ---------------------------------------------------------------------------------------------------------------------
# Dev-specific VPC configuration
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  # VPC CIDR block
  cidr = "10.10.0.0/16"

  # Public subnets (one per AZ)
  public_subnets = [
    "10.10.1.0/24",   # us-east-1a
    "10.10.2.0/24",   # us-east-1b
    "10.10.3.0/24"    # us-east-1c
  ]

  # Private subnets (one per AZ)
  private_subnets = [
    "10.10.11.0/24",  # us-east-1a
    "10.10.12.0/24",  # us-east-1b
    "10.10.13.0/24"   # us-east-1c
  ]

  # Database subnets (one per AZ)
  database_subnets = [
    "10.10.21.0/24",  # us-east-1a
    "10.10.22.0/24",  # us-east-1b
    "10.10.23.0/24"   # us-east-1c
  ]

  # NAT Gateway - disabled for dev (cost optimization)
  # Private subnets won't have outbound internet access
  enable_nat_gateway = false

  # VPC Flow Logs - disabled for dev
  enable_flow_log = false

  # Additional dev-specific tags
  tags = {
    CostAllocation = "dev-workloads"
  }
}
