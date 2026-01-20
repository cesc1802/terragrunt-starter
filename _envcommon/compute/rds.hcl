# ---------------------------------------------------------------------------------------------------------------------
# COMMON RDS CONFIGURATION
# Creates PostgreSQL or MySQL database using terraform-aws-rds module.
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  source = "${dirname(find_in_parent_folders("account.hcl"))}/modules/terraform-aws-rds"
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  account_name = local.account_vars.locals.account_name
  environment  = local.env_vars.locals.environment
  aws_region   = local.region_vars.locals.aws_region

  # DB naming
  db_identifier = "${local.account_name}-${local.environment}-db"

  # Environment-specific settings
  enable_multi_az            = try(local.env_vars.locals.enable_multi_az, false)
  enable_deletion_protection = try(local.env_vars.locals.enable_deletion_protection, false)
  instance_class             = local.environment == "prod" ? "db.r6g.large" : "db.t3.micro"
}

inputs = {
  identifier = local.db_identifier

  # Engine defaults (override in terragrunt.hcl)
  engine               = "postgres"
  engine_version       = "15"
  family               = "postgres15"
  major_engine_version = "15"
  instance_class       = local.instance_class

  # Storage
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_encrypted     = true

  # Network (from dependency)
  # db_subnet_group_name   = dependency.vpc.outputs.database_subnet_group_name
  # vpc_security_group_ids = [dependency.vpc.outputs.default_security_group_id]

  # HA settings
  multi_az = local.enable_multi_az

  # Backup
  backup_retention_period = local.environment == "prod" ? 7 : 1
  skip_final_snapshot     = local.environment != "prod"

  # Protection
  deletion_protection = local.enable_deletion_protection

  # Tags
  tags = {
    Component   = "compute"
    Environment = local.environment
    ManagedBy   = "Terragrunt"
  }
}
