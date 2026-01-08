# ---------------------------------------------------------------------------------------------------------------------
# COMMON RDS CONFIGURATION
# This file contains the common configuration for RDS PostgreSQL shared across all environments.
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  source = "tfr:///terraform-aws-modules/rds/aws?version=6.7.0"
}

# ---------------------------------------------------------------------------------------------------------------------
# Load variables from hierarchy
# ---------------------------------------------------------------------------------------------------------------------

locals {
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  environment                = local.env_vars.locals.environment
  account_name               = local.account_vars.locals.account_name
  enable_multi_az            = local.env_vars.locals.enable_multi_az
  enable_deletion_protection = local.env_vars.locals.enable_deletion_protection

  # Instance size mapping
  instance_class_map = {
    small  = "db.t3.micro"
    medium = "db.t3.small"
    large  = "db.r6g.large"
  }
  instance_size = local.env_vars.locals.instance_size_default
}

# ---------------------------------------------------------------------------------------------------------------------
# Default inputs
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  identifier = "${local.account_name}-${local.environment}-postgres"

  # Engine configuration
  engine               = "postgres"
  engine_version       = "15.7"
  family               = "postgres15"
  major_engine_version = "15"
  instance_class       = local.instance_class_map[local.instance_size]

  # Storage
  allocated_storage     = local.environment == "prod" ? 100 : 20
  max_allocated_storage = local.environment == "prod" ? 500 : 100
  storage_type          = "gp3"
  storage_encrypted     = true

  # Database settings
  db_name  = "app"
  username = "dbadmin"
  port     = 5432

  # High availability
  multi_az = local.enable_multi_az

  # Backup & maintenance
  backup_retention_period = local.environment == "prod" ? 30 : 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Security
  deletion_protection              = local.enable_deletion_protection
  skip_final_snapshot              = local.environment != "prod"
  final_snapshot_identifier_prefix = "${local.account_name}-${local.environment}-final"

  # Performance Insights (prod only)
  performance_insights_enabled          = local.environment == "prod"
  performance_insights_retention_period = local.environment == "prod" ? 7 : 0

  # CloudWatch Logs
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # Parameter group
  parameters = [
    {
      name  = "log_statement"
      value = "all"
    },
    {
      name  = "log_min_duration_statement"
      value = local.environment == "prod" ? "1000" : "100"
    }
  ]

  tags = {
    Component = "database"
  }
}
