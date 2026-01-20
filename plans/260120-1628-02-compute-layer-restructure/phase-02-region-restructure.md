---
parent: plan.md
phase: 02
status: pending
depends_on: [phase-01]
---

# Phase 02: Region Directory Restructure

## Context
- Parent: [plan.md](plan.md)
- Dependencies: [Phase 01](phase-01-envcommon-restructure.md)

## Overview

| Field | Value |
|-------|-------|
| Date | 2026-01-20 |
| Priority | P2 |
| Implementation | PENDING |
| Review | PENDING |

Move RDS and ECS from `01-infra/` to new `02-compute/` in both us-west-1 and us-east-1.

## Key Insights

- us-west-1: Has both RDS and ECS
- us-east-1: Only has VPC in 01-infra (no RDS/ECS to move)
- FLAT structure under 02-compute (no subcategories)
- Dependency paths must be updated (now relative from 02-compute)

## Regions Affected

| Region | RDS | ECS | Action |
|--------|-----|-----|--------|
| us-west-1 | ✓ | ✓ | Move both |
| us-east-1 | ✗ | ✗ | No action needed |

## Implementation Steps

### us-west-1 Changes

#### Step 1: Create 02-compute directory
```bash
mkdir -p environments/dev/us-west-1/02-compute
```

#### Step 2: Move RDS
```bash
mv environments/dev/us-west-1/01-infra/data-stores/rds \
   environments/dev/us-west-1/02-compute/rds
```

#### Step 3: Move ECS
```bash
mv environments/dev/us-west-1/01-infra/services/ecs-cluster \
   environments/dev/us-west-1/02-compute/ecs-cluster
```

#### Step 4: Update RDS terragrunt.hcl

Update include path and dependency path:

```hcl
# include "envcommon" - change from:
path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/data-stores/rds.hcl"
# To:
path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/compute/rds.hcl"

# dependency "vpc" - change from:
config_path = "../../network/vpc"
# To:
config_path = "../01-infra/network/vpc"
```

#### Step 5: Update ECS terragrunt.hcl

Update include path and dependency paths:

```hcl
# include "envcommon" - change from:
path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/services/ecs-cluster.hcl"
# To:
path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/compute/ecs-cluster.hcl"

# dependency "vpc" - change from:
config_path = "../../network/vpc"
# To:
config_path = "../01-infra/network/vpc"

# dependency "iam" - change from:
config_path = "../../security/iam-roles"
# To:
config_path = "../01-infra/security/iam-roles"
```

#### Step 6: Clean up empty directories
```bash
rmdir environments/dev/us-west-1/01-infra/data-stores
rmdir environments/dev/us-west-1/01-infra/services
```

## Related Files

| Current Path | New Path |
|--------------|----------|
| `environments/dev/us-west-1/01-infra/data-stores/rds/` | `environments/dev/us-west-1/02-compute/rds/` |
| `environments/dev/us-west-1/01-infra/services/ecs-cluster/` | `environments/dev/us-west-1/02-compute/ecs-cluster/` |

## Dependency Path Changes

| Resource | Old Dependency Path | New Dependency Path |
|----------|---------------------|---------------------|
| RDS → VPC | `../../network/vpc` | `../01-infra/network/vpc` |
| ECS → VPC | `../../network/vpc` | `../01-infra/network/vpc` |
| ECS → IAM | `../../security/iam-roles` | `../01-infra/security/iam-roles` |

## Todo List

- [ ] Create 02-compute directory in us-west-1
- [ ] Move rds/ to 02-compute/
- [ ] Move ecs-cluster/ to 02-compute/
- [ ] Update RDS envcommon include path
- [ ] Update RDS VPC dependency path
- [ ] Update ECS envcommon include path
- [ ] Update ECS VPC dependency path
- [ ] Update ECS IAM dependency path
- [ ] Remove empty data-stores/ directory
- [ ] Remove empty services/ directory

## Success Criteria

1. 02-compute/rds/ exists with updated terragrunt.hcl
2. 02-compute/ecs-cluster/ exists with updated terragrunt.hcl
3. All dependency paths resolve correctly
4. Empty directories removed

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Dependency path typo | High | Validate before apply |
| State mismatch | High | Run validate only |
| .terragrunt-cache stale | Low | Clear cache if needed |

## Next Steps

→ Phase 03: Update scaffold script
