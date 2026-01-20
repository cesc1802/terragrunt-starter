# Phase 04: Create us-west-1 Deployment Structure

## Context

Create the `environments/dev/us-west-1/` directory structure manually (or via scaffold script from Phase 03) and deploy infrastructure.

## Overview

If scaffold script not ready, manually create:
- `region.hcl` with us-west-1 config
- Directory structure for all modules
- `terragrunt.hcl` files for each module
- Deploy in correct dependency order

## Requirements

- [ ] Create us-west-1 region.hcl with CIDR 10.11.0.0/16
- [ ] Create directory structure for all modules
- [ ] Create terragrunt.hcl files with dependencies
- [ ] Deploy VPC first
- [ ] Deploy remaining modules in order
- [ ] Verify all resources created

## Implementation Steps

### Step 1: Create Directory Structure

```bash
cd /Users/thuocnguyen/Documents/personal-workspace/terragrunt-starter

# Create directories
mkdir -p environments/dev/us-west-1/00-bootstrap/tfstate-backend
mkdir -p environments/dev/us-west-1/01-infra/network/vpc
mkdir -p environments/dev/us-west-1/01-infra/security/iam-roles
mkdir -p environments/dev/us-west-1/01-infra/storage/s3
mkdir -p environments/dev/us-west-1/01-infra/data-stores/rds
mkdir -p environments/dev/us-west-1/01-infra/services/ecs-cluster
```

### Step 2: Create region.hcl

**File:** `environments/dev/us-west-1/region.hcl`

```hcl
# ---------------------------------------------------------------------------------------------------------------------
# REGION-LEVEL VARIABLES - US-WEST-1
# These variables apply to all resources in this region.
# ---------------------------------------------------------------------------------------------------------------------

locals {
  aws_region = "us-west-1"
  azs        = ["us-west-1a", "us-west-1b"]

  # VPC CIDR for this region
  vpc_cidr = "10.11.0.0/16"
}
```

### Step 3: Create Bootstrap Module

**File:** `environments/dev/us-west-1/00-bootstrap/tfstate-backend/terragrunt.hcl`

```hcl
# ---------------------------------------------------------------------------------------------------------------------
# TERRAFORM STATE BACKEND - DEV US-WEST-1
# Note: Uses shared state bucket in us-east-1, path-isolated by region
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/bootstrap/tfstate-backend.hcl"
  expose = true
}

# Dev-specific overrides
inputs = {}
```

**Note:** tfstate-backend not needed for us-west-1 since we share state bucket in us-east-1. This is kept for reference/future use.

### Step 4: Create VPC Module

**File:** `environments/dev/us-west-1/01-infra/network/vpc/terragrunt.hcl`

```hcl
# ---------------------------------------------------------------------------------------------------------------------
# DEV VPC - US-WEST-1
# Creates VPC with CIDR 10.11.0.0/16
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/networking/vpc.hcl"
  expose = true
}

inputs = {
  tags = {
    CostAllocation = "dev-workloads"
  }
}
```

### Step 5: Create IAM Roles Module

**File:** `environments/dev/us-west-1/01-infra/security/iam-roles/terragrunt.hcl`

```hcl
# ---------------------------------------------------------------------------------------------------------------------
# IAM ROLES - DEV US-WEST-1
# Creates IAM roles for ECS tasks and other services
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/security/iam-roles.hcl"
  expose = true
}

inputs = {
  role_name = "mycompany-dev-usw1-ecs-task-role"

  trusted_role_services = ["ecs-tasks.amazonaws.com"]

  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
}
```

### Step 6: Create S3 Module

**File:** `environments/dev/us-west-1/01-infra/storage/s3/terragrunt.hcl`

```hcl
# ---------------------------------------------------------------------------------------------------------------------
# S3 BUCKET - DEV US-WEST-1
# Application data bucket for us-west-1
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/storage/s3.hcl"
  expose = true
}

inputs = {
  bucket = "mycompany-dev-usw1-app-data"
}
```

### Step 7: Create RDS Module

**File:** `environments/dev/us-west-1/01-infra/data-stores/rds/terragrunt.hcl`

```hcl
# ---------------------------------------------------------------------------------------------------------------------
# RDS - DEV US-WEST-1
# PostgreSQL database for us-west-1
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/data-stores/rds.hcl"
  expose = true
}

dependency "vpc" {
  config_path = "../../network/vpc"
}

inputs = {
  identifier = "mycompany-dev-usw1-db"

  # Network from VPC dependency
  db_subnet_group_name   = dependency.vpc.outputs.database_subnet_group_name
  vpc_security_group_ids = [dependency.vpc.outputs.default_security_group_id]

  # Dev settings
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  # Credentials (use Secrets Manager in production)
  username = "dbadmin"
  # password managed via Secrets Manager or parameter store
}
```

### Step 8: Create ECS Cluster Module

**File:** `environments/dev/us-west-1/01-infra/services/ecs-cluster/terragrunt.hcl`

```hcl
# ---------------------------------------------------------------------------------------------------------------------
# ECS CLUSTER - DEV US-WEST-1
# Fargate cluster for container workloads
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/services/ecs-cluster.hcl"
  expose = true
}

dependency "vpc" {
  config_path = "../../network/vpc"
}

dependency "iam" {
  config_path = "../../security/iam-roles"
}

inputs = {
  cluster_name = "mycompany-dev-usw1-cluster"
}
```

### Step 9: Deploy Infrastructure

```bash
# 1. Deploy VPC first (foundation)
cd environments/dev/us-west-1/01-infra/network/vpc
terragrunt plan
terragrunt apply

# 2. Deploy IAM roles (standalone)
cd ../security/iam-roles
terragrunt plan
terragrunt apply

# 3. Deploy S3 (standalone)
cd ../../storage/s3
terragrunt plan
terragrunt apply

# 4. Deploy RDS (depends on VPC)
cd ../../data-stores/rds
terragrunt plan
terragrunt apply

# 5. Deploy ECS (depends on VPC, IAM)
cd ../../services/ecs-cluster
terragrunt plan
terragrunt apply
```

**Or use run-all:**

```bash
cd environments/dev/us-west-1/01-infra
terragrunt run-all apply
```

## Success Criteria

- [ ] All directories created
- [ ] All terragrunt.hcl files valid syntax
- [ ] VPC deployed with CIDR 10.11.0.0/16
- [ ] VPC has 2 AZs (us-west-1a, us-west-1b)
- [ ] IAM roles created
- [ ] S3 bucket created
- [ ] RDS instance created (if deployed)
- [ ] ECS cluster created
- [ ] State files stored in S3 under correct path

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Dependency not ready | Medium | Use mock_outputs for plan |
| Module version mismatch | Medium | Verify _envcommon source paths |
| CIDR conflict | High | Verify 10.11.0.0/16 not used elsewhere |
| Cost overrun | Medium | Use t3.micro, disable unused modules |

## Verification Commands

```bash
# Verify directory structure
tree environments/dev/us-west-1/

# Validate all configs
cd environments/dev/us-west-1
terragrunt run-all validate

# Check state location
aws s3 ls s3://mycompany-dev-terraform-state/ --recursive | grep us-west-1

# Verify VPC CIDR
aws ec2 describe-vpcs --region us-west-1 --filters "Name=tag:Environment,Values=dev" \
  --query 'Vpcs[*].{Id:VpcId,CIDR:CidrBlock}'
```

## Deployment Order Summary

```
┌─────────────────┐
│   IAM Roles     │ (standalone)
└────────┬────────┘
         │
┌────────▼────────┐     ┌─────────────┐
│      VPC        │     │     S3      │ (standalone)
└────────┬────────┘     └─────────────┘
         │
    ┌────┴────┐
    │         │
┌───▼───┐ ┌───▼───┐
│  RDS  │ │  ECS  │
└───────┘ └───────┘
```
