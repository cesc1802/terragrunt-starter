# Phase 02: Common Module Configuration

## Context Links
- Parent: [plan.md](./plan.md)
- Dependency: Phase 01 (UAT environment setup)
- Reference: `_envcommon/networking/vpc.hcl` (pattern to follow)
- Module: `modules/terraform-aws-tfstate-backend`

## Overview
- **Priority**: P2
- **Status**: Completed
- **Description**: Create shared tfstate-backend module configuration in `_envcommon/bootstrap/`

## Key Insights

### Module Source
- Local path: `${get_terragrunt_dir()}/../../../../modules/terraform-aws-tfstate-backend`
- Cannot use `tfr:///` registry format - must use local path

### Cloud Posse Label System
Module uses `cloudposse/label/null` for resource naming:
- `namespace`: org abbreviation (from account.hcl `account_name`)
- `stage`: environment (dev/uat/prod)
- `name`: component name ("terraform")
- `attributes`: additional identifiers (["state"])
- Result: `{namespace}-{stage}-terraform-state` (e.g., `mycompany-dev-terraform-state`)

### Bootstrap Challenge
- This module creates the S3 backend that stores state
- First apply must use local state (chicken-and-egg problem)
- After creation, migrate state to newly created S3 bucket
- The `_envcommon` file must NOT use `include "root"` initially

## Requirements

### Functional
- Configure Cloud Posse label inputs (namespace, stage, name, attributes)
- Set security defaults (encryption, public access blocking)
- Environment-aware settings via `read_terragrunt_config`

### Non-Functional
- DRY: All common config in one place
- Maintainable: Clear comments explaining bootstrap process

## Architecture

```
_envcommon/bootstrap/tfstate-backend.hcl
    └── terraform.source = local module path
    └── locals: reads env.hcl, region.hcl, account.hcl
    └── inputs: namespace, stage, name, attributes, security settings
```

## Related Code Files

| Action | File | Description |
|--------|------|-------------|
| Create | `_envcommon/bootstrap/tfstate-backend.hcl` | Shared module configuration |

## Implementation Steps

### Step 1: Create bootstrap directory

```bash
mkdir -p _envcommon/bootstrap
```

### Step 2: Create tfstate-backend.hcl

```hcl
# _envcommon/bootstrap/tfstate-backend.hcl
# ---------------------------------------------------------------------------------------------------------------------
# COMMON TFSTATE-BACKEND CONFIGURATION
# Creates S3 bucket and DynamoDB table for Terraform remote state.
# BOOTSTRAP MODULE: Run with local state first, then migrate to S3.
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  # Local module - Cloud Posse terraform-aws-tfstate-backend
  source = "${get_terragrunt_dir()}/../../../../modules/terraform-aws-tfstate-backend"
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

  # Environment-specific protection settings
  enable_deletion_protection = local.env_vars.locals.enable_deletion_protection

  # Determine if force_destroy should be enabled (only for dev)
  force_destroy = local.environment == "dev"
}

# ---------------------------------------------------------------------------------------------------------------------
# Default inputs - can be overridden by environment-specific terragrunt.hcl
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  # Cloud Posse Label inputs
  namespace  = local.account_name
  stage      = local.environment
  name       = "terraform"
  attributes = ["state"]

  # S3 Bucket settings
  force_destroy               = local.force_destroy
  prevent_unencrypted_uploads = true
  enable_public_access_block  = true
  block_public_acls           = true
  block_public_policy         = true
  ignore_public_acls          = true
  restrict_public_buckets     = true

  # DynamoDB settings
  billing_mode                  = "PAY_PER_REQUEST"
  enable_point_in_time_recovery = true
  deletion_protection_enabled   = local.enable_deletion_protection

  # Encryption
  sse_encryption = "AES256"

  # Tags
  tags = {
    Component   = "bootstrap"
    Environment = local.environment
    ManagedBy   = "Terragrunt"
  }
}
```

## Todo List
- [x] Create `_envcommon/bootstrap/` directory
- [x] Create `_envcommon/bootstrap/tfstate-backend.hcl`
- [x] Verify HCL syntax with `terragrunt hclfmt`

## Success Criteria
- File follows existing _envcommon patterns
- All required module inputs configured
- Environment-specific logic (force_destroy, deletion_protection) works correctly
- No HCL syntax errors

## Risk Assessment
- **Medium**: Module source path must be correct relative to deployment location
- **Mitigation**: Test path resolution in dev first

## Security Considerations
- S3 bucket encryption enabled (AES256)
- Public access blocking enabled
- DynamoDB deletion protection for non-dev environments
- Unencrypted uploads prevented

## Next Steps
- Proceed to Phase 03 (environment-specific deployments)
