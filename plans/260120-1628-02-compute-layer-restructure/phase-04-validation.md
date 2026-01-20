---
parent: plan.md
phase: 04
status: pending
depends_on: [phase-03]
---

# Phase 04: Validation

## Context
- Parent: [plan.md](plan.md)
- Dependencies: [Phase 03](phase-03-update-scaffold-script.md)

## Overview

| Field | Value |
|-------|-------|
| Date | 2026-01-20 |
| Priority | P2 |
| Implementation | PENDING |
| Review | PENDING |

Validate all changes work correctly without breaking existing infrastructure.

## Validation Steps

### Step 1: Validate _envcommon structure
```bash
ls -la _envcommon/compute/
# Expected: rds.hcl, ecs-cluster.hcl
```

### Step 2: Validate us-west-1 structure
```bash
ls -la environments/dev/us-west-1/02-compute/
# Expected: rds/, ecs-cluster/
```

### Step 3: Terragrunt validate on RDS
```bash
cd environments/dev/us-west-1/02-compute/rds
terragrunt validate
# Expected: Success
```

### Step 4: Terragrunt validate on ECS
```bash
cd environments/dev/us-west-1/02-compute/ecs-cluster
terragrunt validate
# Expected: Success
```

### Step 5: Test scaffold script (dry-run simulation)

Create temp test directory and run scaffold:
```bash
# Create temp environment for testing
mkdir -p /tmp/test-scaffold/environments/test
cp environments/dev/env.hcl /tmp/test-scaffold/environments/test/

# Run scaffold (answer prompts with test values)
# Region: us-west-2, CIDR: 10.99.0.0/16
./scripts/scaffold-region.sh test

# Verify structure
ls -la /tmp/test-scaffold/environments/test/us-west-2/02-compute/
# Expected: rds/, ecs-cluster/

# Cleanup
rm -rf /tmp/test-scaffold
```

### Step 6: Verify dependency resolution

```bash
cd environments/dev/us-west-1/02-compute/ecs-cluster
terragrunt graph-dependencies
# Verify shows: 01-infra/network/vpc, 01-infra/security/iam-roles
```

## Validation Checklist

| Check | Command | Expected |
|-------|---------|----------|
| envcommon structure | `ls _envcommon/compute/` | rds.hcl, ecs-cluster.hcl |
| us-west-1 structure | `ls environments/dev/us-west-1/02-compute/` | rds/, ecs-cluster/ |
| RDS validate | `terragrunt validate` | Success |
| ECS validate | `terragrunt validate` | Success |
| Dependencies | `terragrunt graph-dependencies` | Shows 01-infra deps |
| Scaffold test | Manual run | Creates 02-compute/ |

## Todo List

- [ ] Validate _envcommon/compute/ structure
- [ ] Validate us-west-1/02-compute/ structure
- [ ] Run terragrunt validate on RDS
- [ ] Run terragrunt validate on ECS
- [ ] Test scaffold script creates correct structure
- [ ] Verify dependency paths resolve

## Success Criteria

1. All `terragrunt validate` commands pass
2. Scaffold script creates correct directory structure
3. No old paths remain in 01-infra/data-stores or 01-infra/services

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Validate fails | Low | Fix path issues |
| State drift warning | Medium | Expected - no apply needed |

## Post-Validation Notes

- Do NOT run `terragrunt apply` - this restructure is for organization only
- If infrastructure needs actual migration, that requires state manipulation (separate effort)
- This restructure assumes resources haven't been deployed yet OR state will be managed separately

## Completion

After validation passes:
1. Commit changes with message: `refactor: restructure to 02-compute layer for CPU/RAM resources`
2. Update any documentation referencing old paths
3. Mark plan as complete
