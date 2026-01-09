# Phase 02: Create Dev VPC Deployment

## Context Links

- [Parent Plan](./plan.md)
- [Phase 01: Common VPC Config](./phase-01-envcommon-vpc-config.md)
- [tfstate-backend reference](./../../../environments/dev/us-east-1/00-bootstrap/tfstate-backend/terragrunt.hcl)

## Overview

- **Priority:** P1 - Dev environment foundation
- **Status:** Pending
- **Description:** Create dev VPC deployment at `environments/dev/us-east-1/01-infra/network/vpc/`

## Key Insights

1. **Directory Structure**: Use `01-infra/network/vpc/` (not `networking/vpc/`) per user request
2. **Include Pattern**: root + envcommon includes (same as tfstate-backend)
3. **CIDR Planning**: 10.10.0.0/16 with /24 subnets for 3 AZs
4. **No NAT**: Cost optimization for dev - private subnets won't have outbound internet

## Requirements

### Functional
- Include root.hcl for backend/provider
- Include envcommon vpc.hcl for common config
- Configure dev-specific CIDR and subnets
- Disable NAT gateway (cost saving)

### Non-Functional
- Follow existing terragrunt.hcl patterns
- Align with project directory structure

## Architecture

### Subnet CIDR Layout

```
VPC: 10.10.0.0/16 (65,536 IPs)

Public Subnets (internet-facing):
├── 10.10.1.0/24  (us-east-1a) - 254 IPs
├── 10.10.2.0/24  (us-east-1b) - 254 IPs
└── 10.10.3.0/24  (us-east-1c) - 254 IPs

Private Subnets (application layer):
├── 10.10.11.0/24 (us-east-1a) - 254 IPs
├── 10.10.12.0/24 (us-east-1b) - 254 IPs
└── 10.10.13.0/24 (us-east-1c) - 254 IPs

Database Subnets (data layer):
├── 10.10.21.0/24 (us-east-1a) - 254 IPs
├── 10.10.22.0/24 (us-east-1b) - 254 IPs
└── 10.10.23.0/24 (us-east-1c) - 254 IPs
```

## Related Code Files

### To Create
- `environments/dev/us-east-1/01-infra/network/vpc/terragrunt.hcl`

### Reference Files
- `_envcommon/networking/vpc.hcl` - Common configuration (Phase 01)
- `environments/dev/us-east-1/00-bootstrap/tfstate-backend/terragrunt.hcl` - Pattern reference

## Implementation Steps

### Step 1: Create directory structure

```bash
mkdir -p environments/dev/us-east-1/01-infra/network/vpc
```

### Step 2: Create terragrunt.hcl

Create `environments/dev/us-east-1/01-infra/network/vpc/terragrunt.hcl`:

```hcl
# ---------------------------------------------------------------------------------------------------------------------
# DEV VPC - US-EAST-1
# Creates VPC with public, private, and database subnets for dev environment.
# NAT Gateway disabled for cost optimization.
# ---------------------------------------------------------------------------------------------------------------------

# Include root configuration (backend, provider)
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Include common VPC configuration
include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/networking/vpc.hcl"
  expose = true
}

# ---------------------------------------------------------------------------------------------------------------------
# Dev-specific VPC configuration
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  # VPC CIDR block
  cidr = "10.10.0.0/16"

  # Public subnets (one per AZ)
  public_subnets = [
    "10.10.1.0/24",   # us-east-1a
    "10.10.2.0/24",   # us-east-1b
    "10.10.3.0/24"    # us-east-1c
  ]

  # Private subnets (one per AZ)
  private_subnets = [
    "10.10.11.0/24",  # us-east-1a
    "10.10.12.0/24",  # us-east-1b
    "10.10.13.0/24"   # us-east-1c
  ]

  # Database subnets (one per AZ)
  database_subnets = [
    "10.10.21.0/24",  # us-east-1a
    "10.10.22.0/24",  # us-east-1b
    "10.10.23.0/24"   # us-east-1c
  ]

  # NAT Gateway - disabled for dev (cost optimization)
  # Private subnets won't have outbound internet access
  enable_nat_gateway = false

  # VPC Flow Logs - disabled for dev
  enable_flow_log = false

  # Additional dev-specific tags
  tags = {
    CostAllocation = "dev-workloads"
  }
}
```

## Todo List

- [ ] Create `environments/dev/us-east-1/01-infra/network/vpc/` directory
- [ ] Create `terragrunt.hcl` with dev-specific configuration
- [ ] Run `terragrunt validate` to verify configuration
- [ ] Run `terragrunt plan` to preview resources

## Success Criteria

1. Directory structure created: `environments/dev/us-east-1/01-infra/network/vpc/`
2. `terragrunt.hcl` includes root and envcommon correctly
3. CIDR: 10.10.0.0/16
4. 3 public subnets: 10.10.1-3.0/24
5. 3 private subnets: 10.10.11-13.0/24
6. 3 database subnets: 10.10.21-23.0/24
7. NAT gateway disabled
8. VPC Flow Logs disabled
9. `terragrunt validate` passes

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Include path incorrect | Low | High | Copy pattern from tfstate-backend |
| CIDR overlap with other envs | Low | Medium | Dev uses 10.10.x.x, others use different ranges |
| No NAT breaks workloads | Medium | Low | Dev only; workloads requiring outbound go in public |

## Security Considerations

- **No NAT Gateway**: Private subnet resources cannot reach internet
  - Acceptable for dev; use public subnet for resources needing internet
  - Consider NAT for staging/prod
- **Default SG locked**: No ingress/egress by default
- **Database subnets**: Isolated, no direct internet access

## Next Steps

After completing this phase:
1. Deploy bootstrap (if not already done): `make apply TARGET=dev/us-east-1/00-bootstrap/tfstate-backend`
2. Deploy VPC: `make apply TARGET=dev/us-east-1/01-infra/network/vpc`
3. Verify outputs: `terragrunt output`

## Deployment Commands

```bash
# Navigate to VPC module
cd environments/dev/us-east-1/01-infra/network/vpc

# Validate configuration
terragrunt validate

# Preview changes
terragrunt plan

# Apply (create VPC)
terragrunt apply

# View outputs
terragrunt output
```

## Expected Outputs

Key outputs after deployment:
- `vpc_id` - VPC identifier
- `vpc_cidr_block` - 10.10.0.0/16
- `public_subnets` - List of public subnet IDs
- `private_subnets` - List of private subnet IDs
- `database_subnets` - List of database subnet IDs
- `database_subnet_group` - RDS subnet group ID
- `igw_id` - Internet gateway ID
