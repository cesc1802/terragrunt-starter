---
parent: plan.md
phase: 01
status: completed
completed_at: 2026-01-20T16:40
---

# Phase 01: _envcommon Restructure

## Context
- Parent: [plan.md](plan.md)
- Dependencies: None

## Overview

| Field | Value |
|-------|-------|
| Date | 2026-01-20 |
| Priority | P2 |
| Implementation | COMPLETED |
| Review | COMPLETED (9/10) |

Move RDS and ECS common configs from their current locations to new `_envcommon/compute/` directory.

## Key Insights

- FLAT structure in compute/ (no subcategories)
- Component tag in configs should change from "data-stores"/"services" to "compute"

## Requirements

1. Create `_envcommon/compute/` directory
2. Move `_envcommon/data-stores/rds.hcl` → `_envcommon/compute/rds.hcl`
3. Move `_envcommon/services/ecs-cluster.hcl` → `_envcommon/compute/ecs-cluster.hcl`
4. Update Component tags in both files to "compute"
5. Delete empty source directories

## Related Files

| Current Path | New Path |
|--------------|----------|
| `_envcommon/data-stores/rds.hcl` | `_envcommon/compute/rds.hcl` |
| `_envcommon/services/ecs-cluster.hcl` | `_envcommon/compute/ecs-cluster.hcl` |

## Implementation Steps

### Step 1: Create compute directory
```bash
mkdir -p _envcommon/compute
```

### Step 2: Move rds.hcl
```bash
mv _envcommon/data-stores/rds.hcl _envcommon/compute/rds.hcl
```

### Step 3: Move ecs-cluster.hcl
```bash
mv _envcommon/services/ecs-cluster.hcl _envcommon/compute/ecs-cluster.hcl
```

### Step 4: Update Component tags

In `_envcommon/compute/rds.hcl`:
```hcl
# Change from:
Component = "data-stores"
# To:
Component = "compute"
```

In `_envcommon/compute/ecs-cluster.hcl`:
```hcl
# Change from:
Component = "services"
# To:
Component = "compute"
```

### Step 5: Clean up empty directories
```bash
rmdir _envcommon/data-stores
rmdir _envcommon/services
```

## Todo List

- [x] Create `_envcommon/compute/` directory
- [x] Move rds.hcl to compute/
- [x] Move ecs-cluster.hcl to compute/
- [x] Update Component tag in rds.hcl
- [x] Update Component tag in ecs-cluster.hcl
- [x] Remove empty data-stores/ directory
- [x] Remove empty services/ directory

## Success Criteria

1. `_envcommon/compute/rds.hcl` exists with correct content
2. `_envcommon/compute/ecs-cluster.hcl` exists with correct content
3. Old directories deleted
4. Component tags updated to "compute"

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| File content loss | High | Git tracks changes |

## Review Results

**Date:** 2026-01-20 16:39
**Score:** 9/10
**Report:** [code-reviewer-260120-1639-phase-01-envcommon.md](../reports/code-reviewer-260120-1639-phase-01-envcommon.md)

**Summary:**
- All success criteria met ✓
- Component tags correctly updated ✓
- Directory structure correct ✓
- No security issues ✓
- No syntax errors ✓
- Known issue: environment configs reference old paths (expected, will be fixed in Phase 02)

## Next Steps

→ Phase 02: Restructure region directories
