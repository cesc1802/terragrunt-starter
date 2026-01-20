# ---------------------------------------------------------------------------------------------------------------------
# REGION-LEVEL VARIABLES - US_WEST_1
# These variables apply to all resources in this region.
# ---------------------------------------------------------------------------------------------------------------------

locals {
  aws_region = "us-west-1"

  # Availability zones for this region
  azs = ["us-west-1a", "us-west-1b"]

  # VPC CIDR for this region (moved from env.hcl for region-specific allocation)
  vpc_cidr = "10.11.0.0/16"

  # Region-specific settings (optional)
  # ami_id = "ami-xxxxxxxxx"  # Region-specific AMI if needed
}
