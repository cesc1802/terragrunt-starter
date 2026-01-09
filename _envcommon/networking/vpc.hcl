# ---------------------------------------------------------------------------------------------------------------------
# COMMON VPC CONFIGURATION
# Creates VPC with public, private, and database subnets using terraform-aws-vpc module.
# Provides foundation networking for all environments.
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  # Official Terraform AWS VPC module from registry
  # https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws
  source = "tfr:///terraform-aws-modules/vpc/aws?version=5.17.0"
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

  # Load from env.hcl with sensible defaults
  vpc_cidr           = try(local.env_vars.locals.vpc_cidr, "10.0.0.0/16")
  enable_nat_gateway = try(local.env_vars.locals.enable_nat_gateway, false)
  enable_flow_log    = try(local.env_vars.locals.enable_flow_log, false)

  # Calculate subnet CIDRs using cidrsubnet()
  # Public:   /24 subnets starting at .1, .2, .3
  # Private:  /24 subnets starting at .11, .12, .13
  # Database: /24 subnets starting at .21, .22, .23
  public_subnets   = [for i, az in local.azs : cidrsubnet(local.vpc_cidr, 8, i + 1)]
  private_subnets  = [for i, az in local.azs : cidrsubnet(local.vpc_cidr, 8, i + 11)]
  database_subnets = [for i, az in local.azs : cidrsubnet(local.vpc_cidr, 8, i + 21)]
}

# ---------------------------------------------------------------------------------------------------------------------
# Default inputs - Override in environment-specific terragrunt.hcl
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  name = local.vpc_name
  cidr = local.vpc_cidr
  azs  = local.azs

  # Subnet CIDRs calculated from vpc_cidr
  public_subnets   = local.public_subnets
  private_subnets  = local.private_subnets
  database_subnets = local.database_subnets

  # DNS settings
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Internet Gateway (required for public subnets)
  create_igw = true

  # NAT Gateway - loaded from env.hcl, single NAT for cost optimization
  enable_nat_gateway = local.enable_nat_gateway
  single_nat_gateway = true

  # VPC Flow Logs - loaded from env.hcl
  enable_flow_log = local.enable_flow_log

  # Database subnet group
  create_database_subnet_group = true

  # Default security group management - locked down
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  # Tags
  tags = {
    Component   = "networking"
    Environment = local.environment
    ManagedBy   = "Terragrunt"
  }
}
