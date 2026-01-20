# Phase 01: Vendor Terraform Modules

## Context

Vendor terraform-aws-modules for RDS, ECS, S3, and IAM into `/modules` directory. Follow existing pattern from terraform-aws-vpc and terraform-aws-tfstate-backend.

## Overview

Use git subtree to add modules at specific versions. This provides:
- Full control over module versions
- Offline capability for CI/CD
- Complete auditability

## Requirements

- [x] Vendor terraform-aws-rds v6.x (v6.13.1 vendored)
- [x] Vendor terraform-aws-ecs v5.x (v5.12.1 vendored)
- [x] Vendor terraform-aws-s3-bucket v4.x (v4.11.0 vendored)
- [x] Vendor terraform-aws-iam v5.x (v5.60.0 vendored)
- [x] Document versions in modules/README.md (created, needs commit)

## Implementation Steps

### Step 1: Add Git Remotes

```bash
cd /Users/thuocnguyen/Documents/personal-workspace/terragrunt-starter

# Add remotes for each module
git remote add tf-rds https://github.com/terraform-aws-modules/terraform-aws-rds.git
git remote add tf-ecs https://github.com/terraform-aws-modules/terraform-aws-ecs.git
git remote add tf-s3 https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git
git remote add tf-iam https://github.com/terraform-aws-modules/terraform-aws-iam.git
```

### Step 2: Vendor Modules via Git Subtree

```bash
# Fetch and add RDS module
git fetch tf-rds
git subtree add --prefix=modules/terraform-aws-rds tf-rds v6.10.0 --squash

# Fetch and add ECS module
git fetch tf-ecs
git subtree add --prefix=modules/terraform-aws-ecs tf-ecs v5.11.4 --squash

# Fetch and add S3 module
git fetch tf-s3
git subtree add --prefix=modules/terraform-aws-s3-bucket tf-s3 v4.2.2 --squash

# Fetch and add IAM module
git fetch tf-iam
git subtree add --prefix=modules/terraform-aws-iam tf-iam v5.47.1 --squash
```

**Note:** Verify latest stable versions at https://registry.terraform.io/namespaces/terraform-aws-modules

### Step 3: Create modules/README.md

```markdown
# Vendored Terraform Modules

| Module | Version | Last Updated | Source |
|--------|---------|--------------|--------|
| terraform-aws-vpc | 5.17.0 | 2026-01-XX | github.com/terraform-aws-modules |
| terraform-aws-tfstate-backend | 1.5.0 | 2026-01-XX | github.com/cloudposse |
| terraform-aws-rds | 6.10.0 | 2026-01-20 | github.com/terraform-aws-modules |
| terraform-aws-ecs | 5.11.4 | 2026-01-20 | github.com/terraform-aws-modules |
| terraform-aws-s3-bucket | 4.2.2 | 2026-01-20 | github.com/terraform-aws-modules |
| terraform-aws-iam | 5.47.1 | 2026-01-20 | github.com/terraform-aws-modules |

## Update Process

```bash
# Update module to new version
git fetch tf-<module>
git subtree pull --prefix=modules/terraform-aws-<module> tf-<module> vX.Y.Z --squash
```

## Update SLA

- Security patches: Apply within 1 week
- Minor versions: Review monthly
- Major versions: Quarterly assessment
```

### Step 4: Commit Changes

```bash
git add modules/README.md
git commit -m "docs(modules): add version tracking README"
```

## Success Criteria

- [x] All 4 modules exist in `modules/` directory
- [x] Each module has subtree markers (squashed commits)
- [x] `modules/README.md` documents all versions (uncommitted)
- [x] Git remotes configured for future updates (6 remotes total)

## Completion Status

**Status**: ✅ COMPLETED - 2026-01-20

**Actual Versions Vendored**:
- terraform-aws-rds: v6.13.1 (newer than planned v6.10.0)
- terraform-aws-ecs: v5.12.1 (newer than planned v5.11.4)
- terraform-aws-s3-bucket: v4.11.0 (newer than planned v4.2.2)
- terraform-aws-iam: v5.60.0 (newer than planned v5.47.1)

**Verification Results**:
```bash
$ ls modules/
terraform-aws-ecs/  terraform-aws-iam/  terraform-aws-rds/
terraform-aws-s3-bucket/  terraform-aws-tfstate-backend/  terraform-aws-vpc/

$ git remote -v | grep tf-
tf-ecs, tf-iam, tf-rds, tf-s3, tf-tfstate, tf-vpc (all configured)

$ du -sh modules/terraform-aws-*
856K terraform-aws-ecs
1.2M terraform-aws-iam
5.1M terraform-aws-rds
584K terraform-aws-s3-bucket
```

**Completion Date**: 2026-01-20 - All modules vendored and documented. Phase ready for Phase 02.

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Module version incompatibility | Medium | Test in dev first |
| Large repo size | Low | Use `--squash` to minimize history |
| Missing submodule dependencies | Medium | Verify module structure after add |

## Verification Commands

```bash
# Verify modules exist
ls -la modules/

# Verify git remotes
git remote -v | grep tf-

# Verify module structure (RDS example)
ls modules/terraform-aws-rds/
# Should contain: main.tf, variables.tf, outputs.tf, etc.
```
