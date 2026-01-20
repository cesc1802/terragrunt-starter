# ---------------------------------------------------------------------------------------------------------------------
# TERRAFORM STATE BACKEND - DEV US-WEST-1
# Note: Uses shared state bucket in us-east-1, path-isolated by region.
# This module is optional since us-west-1 shares state backend with us-east-1.
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/bootstrap/tfstate-backend.hcl"
  expose = true
}

inputs = {}
