---
parent: plan.md
phase: 02
status: completed
depends_on: [phase-01]
completed_at: 2026-01-20T16:58
reviewed: code-reviewer-260120-1656
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
config_path = "../../01-infra/network/vpc"  # CORRECTED (was ../01-infra/)
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
config_path = "../../01-infra/network/vpc"  # CORRECTED (was ../01-infra/)

# dependency "iam" - change from:
config_path = "../../security/iam-roles"
# To:
config_path = "../../01-infra/security/iam-roles"  # CORRECTED (was ../01-infra/)
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
| RDS → VPC | `../../network/vpc` | `../../01-infra/network/vpc` |
| ECS → VPC | `../../network/vpc` | `../../01-infra/network/vpc` |
| ECS → IAM | `../../security/iam-roles` | `../../01-infra/security/iam-roles` |

## Todo List

- [x] Create 02-compute directory in us-west-1
- [x] Move rds/ to 02-compute/
- [x] Move ecs-cluster/ to 02-compute/
- [x] Update RDS envcommon include path
- [x] Update RDS VPC dependency path (Fixed: `../../01-infra/network/vpc`)
- [x] Update ECS envcommon include path
- [x] Update ECS VPC dependency path (Fixed: `../../01-infra/network/vpc`)
- [x] Update ECS IAM dependency path (Fixed: `../../01-infra/security/iam-roles`)
- [x] Remove empty data-stores/ directory
- [x] Remove empty services/ directory

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

## Review Results

**Code Review:** `plans/reports/code-reviewer-260120-1656-phase-02-region-restructure.md`
**Test Report:** `plans/reports/tester-260120-1648-phase-02-region-restructure.md`
**Status:** COMPLETED - All dependency path errors resolved

### Resolution Summary

All 3 critical dependency path errors identified in initial code review were successfully resolved:

1. **RDS VPC Dependency Path** - Fixed
   - Updated: `config_path = "../../01-infra/network/vpc"`

2. **ECS VPC Dependency Path** - Fixed
   - Updated: `config_path = "../../01-infra/network/vpc"`

3. **ECS IAM Dependency Path** - Fixed
   - Updated: `config_path = "../../01-infra/security/iam-roles"`

### Completion Verification

- All files moved to 02-compute/ directory structure
- Dependency paths corrected with proper relative path depth
- Include paths updated to reference _envcommon/compute/
- Empty directories cleaned up
- All validation checks passed
- Configuration integrity verified

### Achievements

- us-west-1 RDS module successfully restructured
- us-west-1 ECS module successfully restructured
- Consistent layer architecture implemented (00-bootstrap, 01-infra, 02-compute)
- No breaking changes to existing state
- Foundation established for Phase 03 and 04 completion
