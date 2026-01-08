# ---------------------------------------------------------------------------------------------------------------------
# RDS POSTGRESQL - PROD ENVIRONMENT
# Production database with high availability and enhanced monitoring
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
    vpc_id                     = "vpc-mock-12345"
    database_subnet_group_name = "mock-db-subnet-group"
    private_subnets            = ["subnet-mock-1", "subnet-mock-2", "subnet-mock-3"]
    database_subnets           = ["subnet-mock-db-1", "subnet-mock-db-2", "subnet-mock-db-3"]
    default_security_group_id  = "sg-mock-12345"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# ---------------------------------------------------------------------------------------------------------------------
# Production-specific configuration
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  # Network
  db_subnet_group_name   = dependency.vpc.outputs.database_subnet_group_name
  vpc_security_group_ids = [dependency.vpc.outputs.default_security_group_id]

  # Production sizing
  instance_class        = "db.r6g.large"
  allocated_storage     = 100
  max_allocated_storage = 500

  # High availability
  multi_az = true

  # Enhanced monitoring
  monitoring_interval    = 60
  monitoring_role_name   = "rds-monitoring-role"
  create_monitoring_role = true

  # Longer backup retention
  backup_retention_period = 30

  # Read replica (optional - uncomment if needed)
  # create_db_instance_replica = true
}
