# Phase 01: UAT Environment Setup

## Context Links
- Parent: [plan.md](./plan.md)
- Reference: `environments/dev/env.hcl`, `environments/prod/env.hcl`

## Overview
- **Priority**: P2
- **Status**: Completed
- **Description**: Create missing UAT environment configuration files

## Key Insights
- UAT env is missing but dev/staging/prod exist
- Follow existing patterns from dev/prod env.hcl files
- UAT typically sits between dev and prod in terms of settings

## Requirements
- Create `environments/uat/env.hcl` with environment settings
- Create `environments/uat/us-east-1/region.hcl` with region config

## Related Code Files

| Action | File | Description |
|--------|------|-------------|
| Create | `environments/uat/env.hcl` | UAT environment variables |
| Create | `environments/uat/us-east-1/region.hcl` | UAT us-east-1 region config |

## Implementation Steps

### Step 1: Create UAT env.hcl

```hcl
# environments/uat/env.hcl
locals {
  environment = "uat"

  # UAT settings - between dev and prod
  instance_size_default = "medium"
  enable_deletion_protection = true  # Protect UAT resources
  enable_multi_az = false            # Single AZ (cost saving)

  # Tagging
  cost_allocation_tag = "uat-workloads"
}
```

### Step 2: Create UAT region.hcl

```hcl
# environments/uat/us-east-1/region.hcl
locals {
  aws_region = "us-east-1"
  azs = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
```

## Todo List
- [x] Create `environments/uat/` directory
- [x] Create `environments/uat/env.hcl`
- [x] Create `environments/uat/us-east-1/` directory
- [x] Create `environments/uat/us-east-1/region.hcl`

## Success Criteria
- UAT environment files exist and follow same pattern as dev/prod
- No syntax errors in HCL files

## Risk Assessment
- **Low risk**: Simple file creation following existing patterns

## Next Steps
- Proceed to Phase 02 (envcommon configuration)
