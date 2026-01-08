# ---------------------------------------------------------------------------------------------------------------------
# RDS POSTGRESQL - DEV ENVIRONMENT
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/data-stores/rds.hcl"
  expose = true
}

# ---------------------------------------------------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------------------------------------------------

dependency "vpc" {
  config_path = "../../networking/vpc"

  mock_outputs = {
    vpc_id                    = "vpc-mock-12345"
    database_subnet_group     = "mock-db-subnet-group"
    private_subnets           = ["subnet-mock-1", "subnet-mock-2"]
    database_subnets          = ["subnet-mock-db-1", "subnet-mock-db-2"]
    default_security_group_id = "sg-mock-12345"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# ---------------------------------------------------------------------------------------------------------------------
# Inputs with VPC outputs
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  # Network configuration from VPC
  db_subnet_group_name   = dependency.vpc.outputs.database_subnet_group_name
  vpc_security_group_ids = [dependency.vpc.outputs.default_security_group_id]

  # Dev-specific: smaller instance, less storage
  allocated_storage = 20
  instance_class    = "db.t3.micro"
}
