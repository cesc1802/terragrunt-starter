# ---------------------------------------------------------------------------------------------------------------------
# COMMON VPC CONFIGURATION
# This file contains the common configuration for VPC that is shared across all environments.
# Environment-specific terragrunt.hcl files include this and can override specific values.
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  # Using terraform-aws-modules/vpc from Terraform Registry
  # Pin to specific version for reproducibility
  source = "tfr:///terraform-aws-modules/vpc/aws?version=5.13.0"
}

# ---------------------------------------------------------------------------------------------------------------------
# Load variables from hierarchy
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # Load environment and region variables
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment = local.env_vars.locals.environment
  aws_region  = local.region_vars.locals.aws_region
  azs         = local.region_vars.locals.azs

  # Determine sizing based on environment
  enable_multi_az = local.env_vars.locals.enable_multi_az

  # Calculate number of AZs to use
  az_count = local.enable_multi_az ? 3 : 2
}

# ---------------------------------------------------------------------------------------------------------------------
# Default inputs - can be overridden by environment-specific terragrunt.hcl
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  name = "vpc-${local.environment}"
  cidr = "10.0.0.0/16"

  azs = slice(local.azs, 0, local.az_count)

  # Subnet CIDR blocks
  private_subnets = local.enable_multi_az ? [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24"
    ] : [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]

  public_subnets = local.enable_multi_az ? [
    "10.0.101.0/24",
    "10.0.102.0/24",
    "10.0.103.0/24"
    ] : [
    "10.0.101.0/24",
    "10.0.102.0/24"
  ]

  database_subnets = local.enable_multi_az ? [
    "10.0.201.0/24",
    "10.0.202.0/24",
    "10.0.203.0/24"
    ] : [
    "10.0.201.0/24",
    "10.0.202.0/24"
  ]

  # NAT Gateway configuration
  enable_nat_gateway     = true
  single_nat_gateway     = !local.enable_multi_az # Cost optimization for non-prod
  one_nat_gateway_per_az = local.enable_multi_az  # HA for prod

  # DNS settings
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Database subnet group
  create_database_subnet_group       = true
  create_database_subnet_route_table = true

  # VPC Flow Logs (optional - enable for prod)
  enable_flow_log                      = local.environment == "prod"
  create_flow_log_cloudwatch_iam_role  = local.environment == "prod"
  create_flow_log_cloudwatch_log_group = local.environment == "prod"

  # Tags for subnet discovery (used by EKS, ECS, ALB)
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    "Tier"                   = "public"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "Tier"                            = "private"
  }

  database_subnet_tags = {
    "Tier" = "database"
  }

  tags = {
    Component = "networking"
  }
}
