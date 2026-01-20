# ---------------------------------------------------------------------------------------------------------------------
# RDS - DEV US-WEST-1
# PostgreSQL database for us-west-1 region.
# Configuration inherited from _envcommon/compute/rds.hcl.
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/compute/rds.hcl"
  expose = true
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  account_name = local.account_vars.locals.account_name
  environment  = local.env_vars.locals.environment
}

dependency "vpc" {
  config_path = "../../01-infra/network/vpc"

  mock_outputs = {
    database_subnet_group_name = "mock-db-subnet-group"
    default_security_group_id  = "sg-mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  identifier = "${local.account_name}-${local.environment}-usw1-db"

  # Network from VPC dependency
  db_subnet_group_name   = dependency.vpc.outputs.database_subnet_group_name
  vpc_security_group_ids = [dependency.vpc.outputs.default_security_group_id]

  # Dev settings
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  # Credentials - RDS manages the master user password via AWS Secrets Manager
  username                    = "dbadmin"
  manage_master_user_password = true
}
