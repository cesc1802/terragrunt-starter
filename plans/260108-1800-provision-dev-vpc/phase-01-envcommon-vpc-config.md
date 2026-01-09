# Phase 01: Create Common VPC Configuration

## Context Links

- [Parent Plan](./plan.md)
- [tfstate-backend reference](./../../../_envcommon/bootstrap/tfstate-backend.hcl)
- [VPC module variables](./../../../modules/terraform-aws-vpc/variables.tf)

## Overview

- **Priority:** P1 - Foundation for all networking
- **Status:** Done (2026-01-09 13:59)
- **Description:** Create shared VPC configuration in `_envcommon/networking/vpc.hcl`

## Key Insights

1. **Local Module Source**: Use `${dirname(find_in_parent_folders("account.hcl"))}/modules/terraform-aws-vpc`
2. **Configuration Inheritance**: Follow tfstate-backend pattern (load account, env, region vars)
3. **EKS/ELB Tags**: Include subnet tags for future Kubernetes readiness
4. **Environment Flexibility**: Use locals for environment-specific settings (NAT, flow logs)

## Requirements

### Functional
- Source local terraform-aws-vpc module
- Load variables from hierarchy (account, env, region)
- Configure 3-tier subnet architecture
- Support EKS/ELB subnet tagging

### Non-Functional
- Follow existing DRY patterns
- Align with codebase naming conventions
- Enable easy environment-specific overrides

## Architecture

```
root.hcl (backend, provider)
    ↓
env.hcl (environment: dev/staging/uat/prod)
    ↓
region.hcl (aws_region, azs)
    ↓
_envcommon/networking/vpc.hcl (module source, defaults)
    ↓
environments/{env}/{region}/01-infra/network/vpc/terragrunt.hcl (overrides)
```

## Related Code Files

### To Create
- `_envcommon/networking/vpc.hcl`

### Reference Files
- `_envcommon/bootstrap/tfstate-backend.hcl` - Pattern reference
- `modules/terraform-aws-vpc/variables.tf` - Available inputs
- `modules/terraform-aws-vpc/outputs.tf` - Available outputs

## Implementation Steps

### Step 1: Create directory structure

```bash
mkdir -p _envcommon/networking
```

### Step 2: Create vpc.hcl

Create `_envcommon/networking/vpc.hcl` with:

```hcl
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
```

## Completed Work

- [x] Create `_envcommon/networking/` directory
- [x] Create `_envcommon/networking/vpc.hcl` with common configuration (75 lines)
- [x] Verify module source path resolves correctly
- [x] Test configuration loads hierarchy variables

## Success Criteria

1. `_envcommon/networking/vpc.hcl` created
2. Module source points to local `modules/terraform-aws-vpc`
3. Loads variables from account, env, region hierarchy
4. Includes EKS/ELB subnet tags
5. Default security group locked down (empty rules)
6. NAT gateway disabled by default (cost optimization)

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Module source path incorrect | Low | High | Test with `terragrunt validate` |
| Variable loading fails | Low | Medium | Follow existing tfstate-backend pattern |

## Security Considerations

- Default security group: No ingress/egress rules (locked down)
- VPC Flow Logs: Disabled for dev (enable for prod)
- Public subnets: Only for resources requiring internet access

## Next Steps

After completing this phase:
1. Proceed to Phase 02: Create dev VPC deployment
2. Run `terragrunt validate` to verify configuration
