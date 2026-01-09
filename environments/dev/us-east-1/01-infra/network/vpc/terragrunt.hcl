# ---------------------------------------------------------------------------------------------------------------------
# DEV VPC - US-EAST-1
# Creates VPC with public, private, and database subnets for dev environment.
# Configuration inherited from _envcommon/networking/vpc.hcl and env.hcl.
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
# All settings inherited from envcommon. Override here only if needed.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  # Additional dev-specific tags (merged with envcommon tags)
  tags = {
    CostAllocation = "dev-workloads"
  }
}
