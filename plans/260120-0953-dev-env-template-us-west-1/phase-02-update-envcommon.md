# Phase 02: Update _envcommon and Move CIDR to region.hcl

## Context

Create new `_envcommon` files for RDS, ECS, S3, and IAM modules. Move `vpc_cidr` from `env.hcl` to `region.hcl` to support region-specific CIDR allocation.

## Overview

- Update VPC config to read `vpc_cidr` from `region.hcl`
- Create 4 new `_envcommon` files with sensible defaults
- Update existing `env.hcl` and `region.hcl` files

## Requirements

- [x] Move vpc_cidr from env.hcl to region.hcl (us-east-1)
- [x] Update _envcommon/networking/vpc.hcl to read from region.hcl
- [x] Create _envcommon/data-stores/rds.hcl
- [x] Create _envcommon/services/ecs-cluster.hcl
- [x] Create _envcommon/storage/s3.hcl
- [x] Create _envcommon/security/iam-roles.hcl

## Implementation Steps

### Step 1: Update us-east-1 region.hcl

**File:** `environments/dev/us-east-1/region.hcl`

```hcl
# ---------------------------------------------------------------------------------------------------------------------
# REGION-LEVEL VARIABLES - US-EAST-1
# These variables apply to all resources in this region.
# ---------------------------------------------------------------------------------------------------------------------

locals {
  aws_region = "us-east-1"
  azs        = ["us-east-1a", "us-east-1b", "us-east-1c"]

  # VPC CIDR for this region (moved from env.hcl)
  vpc_cidr = "10.10.0.0/16"
}
```

### Step 2: Update env.hcl (Remove vpc_cidr)

**File:** `environments/dev/env.hcl`

Remove the `vpc_cidr` line. Keep other settings:

```hcl
locals {
  environment = "dev"
  instance_size_default      = "small"
  enable_deletion_protection = false
  enable_multi_az            = false

  # VPC settings (CIDR now in region.hcl)
  enable_nat_gateway = false
  enable_flow_log    = false

  cost_allocation_tag = "dev-workloads"
}
```

### Step 3: Update _envcommon/networking/vpc.hcl

Change `vpc_cidr` source from `env_vars` to `region_vars`:

```hcl
# Line ~33 - Change from:
vpc_cidr = try(local.env_vars.locals.vpc_cidr, "10.0.0.0/16")

# To:
vpc_cidr = try(local.region_vars.locals.vpc_cidr, "10.0.0.0/16")
```

### Step 4: Create _envcommon/data-stores/rds.hcl

```hcl
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
    Component   = "data-stores"
    Environment = local.environment
    ManagedBy   = "Terragrunt"
  }
}
```

### Step 5: Create _envcommon/services/ecs-cluster.hcl

```hcl
# ---------------------------------------------------------------------------------------------------------------------
# COMMON ECS CLUSTER CONFIGURATION
# Creates ECS cluster with Fargate support using terraform-aws-ecs module.
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  source = "${dirname(find_in_parent_folders("account.hcl"))}/modules/terraform-aws-ecs//modules/cluster"
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  account_name = local.account_vars.locals.account_name
  environment  = local.env_vars.locals.environment
  aws_region   = local.region_vars.locals.aws_region

  cluster_name = "${local.account_name}-${local.environment}-cluster"

  # Container Insights - enabled for prod only (cost optimization)
  enable_container_insights = local.environment == "prod"
}

inputs = {
  cluster_name = local.cluster_name

  # Fargate capacity providers
  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 50
        base   = 20
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 50
      }
    }
  }

  # Container Insights
  cluster_settings = {
    name  = "containerInsights"
    value = local.enable_container_insights ? "enabled" : "disabled"
  }

  # Tags
  tags = {
    Component   = "services"
    Environment = local.environment
    ManagedBy   = "Terragrunt"
  }
}
```

### Step 6: Create _envcommon/storage/s3.hcl

```hcl
# ---------------------------------------------------------------------------------------------------------------------
# COMMON S3 BUCKET CONFIGURATION
# Creates S3 bucket with versioning and encryption using terraform-aws-s3-bucket module.
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  source = "${dirname(find_in_parent_folders("account.hcl"))}/modules/terraform-aws-s3-bucket"
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  account_name = local.account_vars.locals.account_name
  environment  = local.env_vars.locals.environment
  aws_region   = local.region_vars.locals.aws_region

  # Allow force_destroy in non-prod environments
  force_destroy = local.environment != "prod"
}

inputs = {
  # Bucket name set in environment terragrunt.hcl
  # bucket = "${local.account_name}-${local.environment}-<purpose>"

  # Versioning
  versioning = {
    enabled = true
  }

  # Encryption
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  # Block public access
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  # Lifecycle
  force_destroy = local.force_destroy

  # Tags
  tags = {
    Component   = "storage"
    Environment = local.environment
    ManagedBy   = "Terragrunt"
  }
}
```

### Step 7: Create _envcommon/security/iam-roles.hcl

```hcl
# ---------------------------------------------------------------------------------------------------------------------
# COMMON IAM ROLES CONFIGURATION
# Creates IAM roles for ECS tasks and other services using terraform-aws-iam module.
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  source = "${dirname(find_in_parent_folders("account.hcl"))}/modules/terraform-aws-iam//modules/iam-assumable-role"
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  account_name = local.account_vars.locals.account_name
  environment  = local.env_vars.locals.environment
  aws_region   = local.region_vars.locals.aws_region

  role_name_prefix = "${local.account_name}-${local.environment}"
}

inputs = {
  # Role configuration set in environment terragrunt.hcl
  # role_name = "${local.role_name_prefix}-<service>-role"

  create_role = true

  # Trusted services (override as needed)
  trusted_role_services = ["ecs-tasks.amazonaws.com"]

  # Tags
  tags = {
    Component   = "security"
    Environment = local.environment
    ManagedBy   = "Terragrunt"
  }
}
```

### Step 8: Create Directory Structure

```bash
mkdir -p _envcommon/data-stores
mkdir -p _envcommon/services
mkdir -p _envcommon/storage
mkdir -p _envcommon/security
```

## Success Criteria

- [x] `vpc_cidr` removed from `env.hcl`
- [x] `vpc_cidr` added to `region.hcl` for us-east-1
- [x] `_envcommon/networking/vpc.hcl` reads CIDR from `region_vars`
- [x] All 4 new `_envcommon` files created
- [x] Existing VPC still deploys correctly (`terragrunt plan` shows no changes)

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking existing VPC | High | Run plan before/after to verify no changes |
| Module subpath errors | Medium | Test each _envcommon file with plan |
| Missing dependencies | Medium | Document required dependencies in each file |

## Verification Commands

```bash
# Verify directory structure
ls -la _envcommon/*/

# Test VPC still works (no changes expected)
cd environments/dev/us-east-1/01-infra/network/vpc
terragrunt plan
# Should show: No changes

# Test _envcommon syntax
cd environments/dev/us-east-1
terragrunt run-all validate
```
