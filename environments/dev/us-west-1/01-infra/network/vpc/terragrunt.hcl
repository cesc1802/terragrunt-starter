# ---------------------------------------------------------------------------------------------------------------------
# DEV VPC - US-WEST-1
# Creates VPC with CIDR 10.11.0.0/16 for dev environment in us-west-1.
# Configuration inherited from _envcommon/networking/vpc.hcl.
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/networking/vpc.hcl"
  expose = true
}

inputs = {
  tags = {
    CostAllocation = "dev-workloads"
  }
}
