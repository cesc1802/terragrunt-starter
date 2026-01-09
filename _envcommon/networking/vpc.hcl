# ---------------------------------------------------------------------------------------------------------------------
# COMMON VPC CONFIGURATION
# Creates VPC with public, private, and database subnets using local terraform-aws-vpc module.
# Provides foundation networking for all environments.
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  # Local module - terraform-aws-vpc (forked/vendored)
  # Path resolves from: environments/{env}/{region}/01-infra/network/vpc/
  source = "${dirname(find_in_parent_folders("account.hcl"))}/modules/terraform-aws-vpc"
}

# ---------------------------------------------------------------------------------------------------------------------
# Load variables from hierarchy
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # Load configuration from hierarchy
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Extract commonly used variables
  account_name = local.account_vars.locals.account_name
  environment  = local.env_vars.locals.environment
  aws_region   = local.region_vars.locals.aws_region
  azs          = local.region_vars.locals.azs

  # VPC naming
  vpc_name = "${local.account_name}-${local.environment}-vpc"

  # Environment-specific settings (can be overridden)
  enable_multi_az = try(local.env_vars.locals.enable_multi_az, false)
}

# ---------------------------------------------------------------------------------------------------------------------
# Default inputs - Override in environment-specific terragrunt.hcl
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  name = local.vpc_name
  azs  = local.azs

  # DNS settings
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Internet Gateway (required for public subnets)
  create_igw = true

  # NAT Gateway - disabled by default, enable per environment
  enable_nat_gateway = false
  single_nat_gateway = true

  # VPC Flow Logs - disabled by default, enable for prod
  enable_flow_log = false

  # Database subnet group
  create_database_subnet_group = true

  # Default security group management
  manage_default_security_group = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  # Tags
  tags = {
    Component   = "networking"
    Environment = local.environment
    ManagedBy   = "Terragrunt"
  }

  # EKS/ELB subnet tags (for future Kubernetes readiness)
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}
