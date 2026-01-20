# ---------------------------------------------------------------------------------------------------------------------
# REGION-LEVEL VARIABLES - US-EAST-1
# These variables apply to all resources in this region.
# ---------------------------------------------------------------------------------------------------------------------

locals {
  aws_region = "us-east-1"

  # Availability zones for this region
  azs = ["us-east-1a", "us-east-1b", "us-east-1c"]

  # VPC CIDR for this region (moved from env.hcl for region-specific allocation)
  vpc_cidr = "10.10.0.0/16"

  # Region-specific settings (optional)
  # ami_id = "ami-xxxxxxxxx"  # Region-specific AMI if needed
}
