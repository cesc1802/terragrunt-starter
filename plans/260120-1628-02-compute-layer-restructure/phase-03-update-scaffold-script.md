---
parent: plan.md
phase: 03
status: completed
completed_at: 2026-01-20T17:40
depends_on: [phase-02]
---

# Phase 03: Update Scaffold Script

## Context
- Parent: [plan.md](plan.md)
- Dependencies: [Phase 02](phase-02-region-restructure.md)
- Script: `scripts/scaffold-region.sh`

## Overview

| Field | Value |
|-------|-------|
| Date | 2026-01-20 |
| Priority | P2 |
| Implementation | COMPLETED |
| Review | COMPLETED |

Update scaffold-region.sh to create `02-compute/` layer with flat structure for RDS and ECS.

## Key Changes

1. Create `02-compute/` directory instead of nested paths under `01-infra/`
2. Update envcommon paths to `compute/rds.hcl` and `compute/ecs-cluster.hcl`
3. Update dependency paths to use `../01-infra/` prefix
4. Update summary output to reflect new structure

## Implementation Steps

### Step 1: Add 02-compute directory creation

In `scaffold_region()` function, add:

```bash
mkdir -p "$REGION_DIR/02-compute"
```

### Step 2: Update RDS creation block

Change from:
```bash
if [ "$INCLUDE_RDS" = "y" ]; then
    mkdir -p "$REGION_DIR/01-infra/data-stores/rds"
    create_module_terragrunt "$REGION_DIR/01-infra/data-stores/rds" "data-stores/rds.hcl" "network::vpc"
    log_success "Created 01-infra/data-stores/rds"
fi
```

To:
```bash
if [ "$INCLUDE_RDS" = "y" ]; then
    mkdir -p "$REGION_DIR/02-compute/rds"
    create_module_terragrunt "$REGION_DIR/02-compute/rds" "compute/rds.hcl" "01-infra::network::vpc"
    log_success "Created 02-compute/rds"
fi
```

### Step 3: Update ECS creation block

Change from:
```bash
if [ "$INCLUDE_ECS" = "y" ]; then
    mkdir -p "$REGION_DIR/01-infra/services/ecs-cluster"
    local ecs_deps="network::vpc"
    if [ "$INCLUDE_IAM" = "y" ]; then
        ecs_deps="${ecs_deps},security::iam-roles"
    fi
    create_module_terragrunt "$REGION_DIR/01-infra/services/ecs-cluster" "services/ecs-cluster.hcl" "$ecs_deps"
    log_success "Created 01-infra/services/ecs-cluster"
fi
```

To:
```bash
if [ "$INCLUDE_ECS" = "y" ]; then
    mkdir -p "$REGION_DIR/02-compute/ecs-cluster"
    local ecs_deps="01-infra::network::vpc"
    if [ "$INCLUDE_IAM" = "y" ]; then
        ecs_deps="${ecs_deps},01-infra::security::iam-roles"
    fi
    create_module_terragrunt "$REGION_DIR/02-compute/ecs-cluster" "compute/ecs-cluster.hcl" "$ecs_deps"
    log_success "Created 02-compute/ecs-cluster"
fi
```

### Step 4: Update create_module_terragrunt function

The dependency path generation needs adjustment for cross-layer dependencies:

```bash
# Current: dep_path=$(echo "$dep" | tr ':' '/')
# The :: separator already produces correct paths like 01-infra/network/vpc
# Just need to adjust the relative prefix

# Change config_path from:
config_path = \"../../${dep_path}\"
# To:
config_path = \"../${dep_path}\"
```

Note: The `../../` worked for nested paths like `01-infra/data-stores/rds` → `../../network/vpc`
Now with flat `02-compute/rds` → `../01-infra/network/vpc`, we need single `../`

### Step 5: Update log messages

Update "Next steps" section at end of scaffold:
```bash
echo "  4. Deploy 02-compute modules: make apply TARGET=environments/$env/$AWS_REGION/02-compute/rds"
```

## Related Files

| File | Changes |
|------|---------|
| `scripts/scaffold-region.sh` | Multiple function updates |

## Todo List

- [ ] Update directory creation to include 02-compute/
- [ ] Update RDS creation to use 02-compute/rds/
- [ ] Update ECS creation to use 02-compute/ecs-cluster/
- [ ] Update envcommon paths to compute/*.hcl
- [ ] Update dependency path generation for cross-layer deps
- [ ] Update log/success messages
- [ ] Update "Next steps" output

## Success Criteria

1. Script creates `02-compute/` directory
2. RDS placed in `02-compute/rds/`
3. ECS placed in `02-compute/ecs-cluster/`
4. Dependencies resolve to `../01-infra/...`
5. No syntax errors in script

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Script syntax error | Medium | Test with dry-run |
| Path generation bug | Medium | Validate generated files |

## Next Steps

→ Phase 04: Validation
