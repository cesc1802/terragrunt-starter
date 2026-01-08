# Phase 04: Bootstrap & Migration Guide

## Context Links
- Parent: [plan.md](./plan.md)
- Dependency: Phases 01-03 complete

## Overview
- **Priority**: P2
- **Status**: Pending
- **Description**: Document and execute the bootstrap procedure for each environment

## Key Insights

### The Bootstrap Problem
Terraform state backends are a chicken-and-egg problem:
1. You need S3 bucket to store state
2. But creating S3 bucket generates state
3. That state has nowhere to go (bucket doesn't exist yet)

### Solution: Two-Phase Bootstrap
1. **Phase A**: Create resources with local state
2. **Phase B**: Migrate local state to newly created S3 bucket

### Order of Operations
Bootstrap environments in this order: `dev` → `uat` → `prod`
- Validate process in dev first
- Build confidence before touching prod

## Requirements
- AWS credentials configured with appropriate permissions
- Terraform >= 1.5.0, Terragrunt >= 0.50.0
- Clear rollback procedure documented

## Implementation Steps

### Pre-Requisites

1. **Verify AWS Credentials**
```bash
aws sts get-caller-identity
```

2. **Verify account.hcl is configured**
```bash
cat account.hcl
# Ensure account_name and aws_account_id are set correctly
```

### Bootstrap DEV Environment

```bash
# Step 1: Navigate to dev tfstate-backend
cd environments/dev/us-east-1/bootstrap/tfstate-backend

# Step 2: Initialize and apply (uses local state)
terragrunt init
terragrunt plan
terragrunt apply

# Step 3: Note the outputs
terragrunt output
# s3_bucket_id = "mycompany-dev-terraform-state"
# dynamodb_table_name = "mycompany-dev-terraform-state-lock"

# Step 4: Modify terragrunt.hcl to use remote state
# - Uncomment the "root" include
# - Remove or comment out the "generate backend" block
# - Remove or comment out the "generate provider" block

# Step 5: Migrate state to S3
terragrunt init -migrate-state
# Answer "yes" when prompted

# Step 6: Verify state is in S3
aws s3 ls s3://mycompany-dev-terraform-state/

# Step 7: Clean up local state file (optional)
rm -f terraform.tfstate terraform.tfstate.backup
```

### Post-Bootstrap terragrunt.hcl (Final State)

After migration, the terragrunt.hcl should look like:

```hcl
# environments/dev/us-east-1/bootstrap/tfstate-backend/terragrunt.hcl
# ---------------------------------------------------------------------------------------------------------------------
# TERRAFORM STATE BACKEND - DEV (POST-BOOTSTRAP)
# State is now stored in S3. Do not modify without extreme caution.
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/bootstrap/tfstate-backend.hcl"
  expose = true
}

# No additional inputs needed - all defaults from envcommon
inputs = {}
```

### Bootstrap UAT Environment

```bash
# Repeat same process for UAT
cd environments/uat/us-east-1/bootstrap/tfstate-backend
terragrunt init
terragrunt apply
# ... follow same migration steps as dev
```

### Bootstrap PROD Environment

```bash
# Extra caution for prod
cd environments/prod/us-east-1/bootstrap/tfstate-backend

# Verify deletion protection will be enabled
terragrunt plan | grep deletion_protection
# Should show: deletion_protection_enabled = true

terragrunt apply
# ... follow same migration steps
```

### Update Root terragrunt.hcl (If Needed)

After bootstrap, verify root `terragrunt.hcl` references correct bucket naming:

```hcl
# terragrunt.hcl - remote_state config
config = {
  bucket         = "${local.account_name}-${local.environment}-terraform-state"
  key            = "${path_relative_to_include()}/terraform.tfstate"
  region         = local.aws_region
  encrypt        = true
  dynamodb_table = "${local.account_name}-${local.environment}-terraform-state-lock"
}
```

**Note**: The module creates bucket as `{namespace}-{stage}-terraform-state` (e.g., `mycompany-dev-terraform-state`). Update root config to match.

## Todo List
- [ ] Configure AWS credentials
- [ ] Verify account.hcl settings
- [ ] Bootstrap dev environment
- [ ] Migrate dev state to S3
- [ ] Update dev terragrunt.hcl (post-bootstrap)
- [ ] Bootstrap uat environment
- [ ] Migrate uat state to S3
- [ ] Update uat terragrunt.hcl (post-bootstrap)
- [ ] Bootstrap prod environment
- [ ] Migrate prod state to S3
- [ ] Update prod terragrunt.hcl (post-bootstrap)
- [ ] Update root terragrunt.hcl bucket naming if needed
- [ ] Clean up local state files

## Success Criteria
- S3 buckets created for each environment
- DynamoDB tables created for each environment
- State successfully migrated to S3 for all envs
- `terragrunt plan` shows no changes after migration
- Root terragrunt.hcl correctly references new buckets

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| State corruption during migration | High | Backup local state before migration |
| Wrong bucket naming in root config | Medium | Verify outputs match expected naming |
| Prod bootstrap failure | High | Test in dev/uat first, have rollback plan |

### Rollback Procedure

If something goes wrong during bootstrap:

```bash
# If migration failed, state is still local
# Just fix the issue and retry

# If S3 bucket was created but migration failed:
# 1. Keep local state file safe
# 2. Fix configuration
# 3. Run terragrunt init -migrate-state again

# If you need to destroy and start over (dev only!):
# 1. Ensure local state is being used
# 2. terragrunt destroy
# 3. Delete S3 bucket manually if needed
# 4. Start over
```

## Security Considerations
- AWS credentials should have least-privilege access
- Prod bootstrap should be done by senior team member
- Consider enabling MFA delete on prod S3 bucket (manual post-bootstrap)
- Verify bucket policies block public access

## Verification Commands

```bash
# Verify S3 bucket exists and has versioning
aws s3api get-bucket-versioning --bucket mycompany-dev-terraform-state

# Verify DynamoDB table exists
aws dynamodb describe-table --table-name mycompany-dev-terraform-state-lock

# Verify state file is in S3
aws s3 ls s3://mycompany-dev-terraform-state/ --recursive
```

## Next Steps
- After all environments bootstrapped, update Makefile with bootstrap targets
- Consider adding CI/CD pipeline for bootstrap validation
- Document the process in project README
