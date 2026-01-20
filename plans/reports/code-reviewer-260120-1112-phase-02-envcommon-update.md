# Code Review: Phase 02 - Update _envcommon and Move CIDR to region.hcl

## Code Review Summary

### Scope
- **Files reviewed:** 7 files (3 modified, 4 new)
- **Lines of code analyzed:** ~320 lines
- **Review focus:** Recent changes for Phase 02 implementation
- **Updated plans:** None (no plan file provided for update)

**Modified files:**
1. `environments/dev/us-east-1/region.hcl` - Added `vpc_cidr = "10.10.0.0/16"`
2. `environments/dev/env.hcl` - Removed `vpc_cidr`, updated comments
3. `_envcommon/networking/vpc.hcl` - Changed source from `env_vars` to `region_vars`

**New files:**
4. `_envcommon/data-stores/rds.hcl` - PostgreSQL RDS configuration
5. `_envcommon/services/ecs-cluster.hcl` - ECS Fargate cluster configuration
6. `_envcommon/storage/s3.hcl` - S3 bucket with versioning/encryption
7. `_envcommon/security/iam-roles.hcl` - IAM assumable role configuration

### Overall Assessment

**Score: 8.5/10**

Solid implementation following DRY/KISS/YAGNI principles. Architecture properly separates concerns with region-specific CIDR at correct hierarchy level. Security defaults strong (encryption enabled, deletion protection, public access blocked). Minor issues with commented dependencies and module path assumptions that need environment-specific deployment to verify.

### Critical Issues

**None detected.**

Security fundamentals strong:
- RDS encryption enabled (`storage_encrypted = true`)
- S3 public access fully blocked (all 4 settings)
- S3 encryption enabled (AES256)
- No hardcoded credentials/secrets
- Deletion protection properly configured per environment

### High Priority Findings

**1. Commented Network Dependencies in RDS Config**

**File:** `_envcommon/data-stores/rds.hcl` (lines 44-45)

**Issue:** Network configuration commented out prevents deployment:
```hcl
# db_subnet_group_name   = dependency.vpc.outputs.database_subnet_group_name
# vpc_security_group_ids = [dependency.vpc.outputs.default_security_group_id]
```

**Impact:** RDS module requires VPC configuration. Without these inputs, `terragrunt plan` will fail when creating environment-specific deployment.

**Recommendation:** Document in phase plan that environment-specific `terragrunt.hcl` must include:
```hcl
dependency "vpc" {
  config_path = "../../networking/vpc"
}

inputs = {
  db_subnet_group_name   = dependency.vpc.outputs.database_subnet_group_name
  vpc_security_group_ids = [dependency.vpc.outputs.default_security_group_id]
}
```

**2. Bucket Name Required Input in S3 Config**

**File:** `_envcommon/storage/s3.hcl` (lines 24-25)

**Issue:** Bucket name commented out - required parameter:
```hcl
# bucket = "${local.account_name}-${local.environment}-<purpose>"
```

**Impact:** S3 module requires `bucket` parameter. Deployment will fail without environment-specific override.

**Recommendation:** Document requirement for environment-specific `terragrunt.hcl`:
```hcl
inputs = {
  bucket = "${local.account_name}-${local.environment}-app-data"
}
```

**3. IAM Role Name Required Input**

**File:** `_envcommon/security/iam-roles.hcl` (lines 23-24)

**Issue:** Role name commented - required parameter:
```hcl
# role_name = "${local.role_name_prefix}-<service>-role"
```

**Impact:** IAM module needs `role_name`. Will fail without environment override.

**Recommendation:** Document in deployment guide.

### Medium Priority Improvements

**1. Module Path Verification Needed**

**Files:** All 4 new `_envcommon` files

**Issue:** Module paths assume specific structure without verification:
```hcl
# RDS
source = "${dirname(find_in_parent_folders("account.hcl"))}/modules/terraform-aws-rds"

# ECS
source = "${dirname(find_in_parent_folders("account.hcl"))}/modules/terraform-aws-ecs//modules/cluster"

# S3
source = "${dirname(find_in_parent_folders("account.hcl"))}/modules/terraform-aws-s3-bucket"

# IAM
source = "${dirname(find_in_parent_folders("account.hcl"))}/modules/terraform-aws-iam//modules/iam-assumable-role"
```

**Observation:** Verification shows modules exist in `modules/` directory (Phase 01 vendored correctly). Submodule paths (ECS cluster, IAM assumable-role) use `//` notation correctly.

**Recommendation:** Test each `_envcommon` file with actual deployment to verify module subpaths resolve correctly. ECS and IAM use submodules that may have different input requirements than root module.

**2. Missing Database Credentials Management**

**File:** `_envcommon/data-stores/rds.hcl`

**Issue:** No credential configuration defined. Module typically requires `username` and `password` or random password generation.

**Recommendation:** Add to inputs:
```hcl
inputs = {
  # ... existing inputs ...

  # Credentials - use Secrets Manager in environment terragrunt.hcl
  username               = "admin"  # Override per environment
  manage_master_user_password = true  # Let AWS manage password via Secrets Manager
  # OR
  # password = "use-secrets-manager-reference"
}
```

**3. RDS Instance Class Logic May Not Match Module Requirements**

**File:** `_envcommon/data-stores/rds.hcl` (line 25)

**Issue:** Hardcoded instance class selection:
```hcl
instance_class = local.environment == "prod" ? "db.r6g.large" : "db.t3.micro"
```

**Observation:** Does not respect `instance_size_default` from `env.hcl`. Creates hardcoded prod assumption.

**Recommendation:** Align with environment-level sizing configuration:
```hcl
instance_class = try(
  local.env_vars.locals.instance_size_default == "large" ? "db.r6g.large" :
  local.env_vars.locals.instance_size_default == "medium" ? "db.t3.medium" :
  "db.t3.micro",
  "db.t3.micro"
)
```

**4. ECS Cluster Settings Schema Issue**

**File:** `_envcommon/services/ecs-cluster.hcl` (lines 44-47)

**Issue:** `cluster_settings` should be array, not object:
```hcl
# Current (incorrect):
cluster_settings = {
  name  = "containerInsights"
  value = local.enable_container_insights ? "enabled" : "disabled"
}

# Correct:
cluster_settings = [
  {
    name  = "containerInsights"
    value = local.enable_container_insights ? "enabled" : "disabled"
  }
]
```

**Impact:** Terraform will reject object when array expected. Deployment will fail.

**Recommendation:** Fix immediately - wrap in array brackets.

**5. Missing Security Group for RDS**

**File:** `_envcommon/data-stores/rds.hcl`

**Issue:** Uses VPC default security group which is locked down (lines 79-80 in vpc.hcl):
```hcl
default_security_group_ingress = []
default_security_group_egress  = []
```

**Impact:** RDS will have no ingress rules. Applications cannot connect.

**Recommendation:** Create dedicated RDS security group or document requirement for environment-specific security group creation.

### Low Priority Suggestions

**1. Consider NAT Gateway Cost Comment Update**

**File:** `environments/dev/env.hcl` (line 15)

**Comment:** States `~$32/mo savings` for disabled NAT gateway.

**Suggestion:** Cost is accurate for single NAT gateway. Consider documenting multi-AZ NAT cost (~$96/mo for 3 AZs) for production planning.

**2. Add Module Version Constraints**

**Files:** RDS, ECS, S3, IAM `_envcommon` files

**Observation:** VPC uses explicit version (`version=5.17.0`). Vendored modules have no version constraints.

**Suggestion:** Document vendored module versions in comments:
```hcl
terraform {
  # terraform-aws-rds v6.10.0 (vendored Phase 01)
  source = "${dirname(find_in_parent_folders("account.hcl"))}/modules/terraform-aws-rds"
}
```

**3. Force Destroy Logic Could Be Explicit**

**File:** `_envcommon/storage/s3.hcl` (line 20)

**Current:**
```hcl
force_destroy = local.environment != "prod"
```

**Suggestion:** Make staging/UAT explicit:
```hcl
force_destroy = contains(["dev"], local.environment)  # Only dev, not staging/uat
```

**Rationale:** Prevents accidental data loss in staging/UAT which may contain valuable test data.

**4. Consider Backup Window Defaults**

**File:** `_envcommon/data-stores/rds.hcl`

**Missing:** Backup window and maintenance window not defined. AWS will choose randomly.

**Suggestion:** Add sensible defaults:
```hcl
inputs = {
  # ... existing ...
  backup_window      = "03:00-04:00"  # 3-4 AM UTC
  maintenance_window = "Mon:04:00-Mon:05:00"  # After backup
}
```

**5. Add Lifecycle Rules Comment for S3**

**File:** `_envcommon/storage/s3.hcl`

**Missing:** No lifecycle rules for transitioning old versions to cheaper storage classes.

**Suggestion:** Add comment documenting where to add lifecycle rules in environment-specific config for cost optimization.

### Positive Observations

**Excellent architectural decisions:**

1. **CIDR Hierarchy Correct** - Moving `vpc_cidr` from `env.hcl` to `region.hcl` enables multi-region deployment. Proper separation of concerns.

2. **Security-First Defaults:**
   - S3 fully blocks public access (all 4 settings)
   - Encryption enabled everywhere (RDS, S3)
   - Deletion protection follows environment type
   - Force destroy restricted to non-prod

3. **Cost Optimization Logic:**
   - Container Insights prod-only (`~$10/mo` savings in dev)
   - Multi-AZ disabled in dev (`~$32/mo` NAT + RDS cost savings)
   - Backup retention 1 day dev vs 7 days prod
   - Skip final snapshot for non-prod

4. **DRY Principles Applied:**
   - Consistent variable loading pattern across all files
   - Shared naming conventions (`${account_name}-${environment}-*`)
   - Proper use of `try()` for optional variables with fallbacks
   - Module source computed from hierarchy

5. **Consistent Tagging:**
   - All resources tagged with Component, Environment, ManagedBy
   - Enables cost allocation and resource tracking

6. **Documentation Quality:**
   - Clear file headers explaining purpose
   - Inline comments explain non-obvious decisions
   - Comments indicate what must be overridden in environment configs

### Recommended Actions

**Priority 1 (Before Phase 03 deployment):**

1. Fix ECS `cluster_settings` array schema (wrap in `[]`)
2. Document RDS network dependency requirements for environment configs
3. Document S3 bucket name requirement for environment configs
4. Document IAM role name requirement for environment configs
5. Add RDS credential management strategy (Secrets Manager)

**Priority 2 (Before production):**

6. Test all module paths resolve correctly with actual deployment
7. Create RDS security group configuration
8. Consider instance class sizing logic alignment with `env.hcl`
9. Add backup/maintenance windows to RDS config
10. Update force_destroy logic to be more explicit about staging/UAT

**Priority 3 (Nice to have):**

11. Document vendored module versions in comments
12. Add lifecycle rules guidance for S3
13. Update NAT gateway cost comment with multi-AZ details

### Metrics

- **Type Coverage:** N/A (HCL configuration, not typed language)
- **Test Coverage:** N/A (requires actual deployment to test)
- **Linting Issues:** 0 detected (consistent HCL formatting observed)
- **Security Issues:** 0 critical (strong security defaults)
- **Architecture Violations:** 0 (follows documented standards)

### Verification Status

**Completed:**
- ✅ File syntax review (no parse errors detected)
- ✅ Security defaults audit (encryption, public access, deletion protection)
- ✅ Module path structure verification (paths exist)
- ✅ Variable hierarchy consistency check
- ✅ Cost optimization logic review

**Cannot verify without AWS credentials:**
- ⚠️ Terragrunt plan execution (AWS credentials not configured)
- ⚠️ Module input compatibility (requires init)
- ⚠️ Backend S3 access

**Requires Phase 03 (environment deployment):**
- 📋 Actual VPC unchanged validation (need working deployment)
- 📋 Module subpath resolution (ECS cluster, IAM assumable-role)
- 📋 Dependency graph resolution
- 📋 RDS security group connectivity

### Plan File Status

**No plan file provided for update.**

Per instructions, plan file should be at:
`/Users/thuocnguyen/Documents/personal-workspace/terragrunt-starter/plans/260120-0953-dev-env-template-us-west-1/phase-02-update-envcommon.md`

**Tasks from plan (from read):**

Requirements checklist:
- [x] Move vpc_cidr from env.hcl to region.hcl (us-east-1)
- [x] Update _envcommon/networking/vpc.hcl to read from region.hcl
- [x] Create _envcommon/data-stores/rds.hcl
- [x] Create _envcommon/services/ecs-cluster.hcl
- [x] Create _envcommon/storage/s3.hcl
- [x] Create _envcommon/security/iam-roles.hcl

Success criteria:
- [x] `vpc_cidr` removed from `env.hcl`
- [x] `vpc_cidr` added to `region.hcl` for us-east-1
- [x] `_envcommon/networking/vpc.hcl` reads CIDR from `region_vars`
- [x] All 4 new `_envcommon` files created
- [ ] Existing VPC still deploys correctly - **CANNOT VERIFY** (AWS credentials required)

### Next Steps

**Before declaring Phase 02 complete:**

1. Fix ECS cluster_settings array issue (1 line change)
2. Document in Phase 03 plan:
   - RDS requires vpc dependency + security group
   - S3 requires bucket name input
   - IAM requires role_name input
3. Test VPC deployment unchanged (requires AWS access)

**Phase 03 considerations:**

- Create environment-specific `terragrunt.hcl` files for each service
- Configure RDS dependencies on VPC outputs
- Define bucket names for S3 deployments
- Define role names for IAM deployments
- Consider security group creation for RDS

## Unresolved Questions

1. **RDS Password Management:** Should use Secrets Manager auto-generation or require manual secret creation? Need to decide strategy before Phase 03.

2. **RDS Security Group:** Create as separate module or include in environment-specific config? Affects Phase 03 planning.

3. **S3 Bucket Naming:** What naming convention for multi-purpose buckets? (e.g., `app-data`, `logs`, `backups`). Need convention before deployment.

4. **ECS Module Compatibility:** Does vendored `terraform-aws-ecs` v5.x support `fargate_capacity_providers` input format used? Need to check module README or test deployment.

5. **IAM Policies:** `iam-assumable-role` creates role but no policies. What policies should be attached? (S3 read/write, RDS connect, etc.). Need to define before deployment.

6. **Multi-region CIDR Planning:** us-east-1 uses 10.10.0.0/16. What CIDR for us-west-1? (10.20.0.0/16?). Need allocation plan for additional regions.
