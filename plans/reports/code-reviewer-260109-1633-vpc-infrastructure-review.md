# VPC Infrastructure Code Review

**Score: 8.5/10**

## Scope
- Files reviewed:
  - `_envcommon/networking/vpc.hcl` (82 lines)
  - `environments/dev/us-east-1/01-infra/network/vpc/terragrunt.hcl` (59 lines)
  - `modules/terraform-aws-vpc/main.tf` (1544 lines - vendored module)
- Lines of code analyzed: ~1682
- Review focus: Dev VPC infrastructure for cost-optimized dev environment
- Updated plans: N/A (no plan file provided)

## Overall Assessment

Strong implementation following Terragrunt DRY hierarchy pattern. Security posture good with locked-down default SG. Architecture clean with proper 3-tier subnet isolation. Cost-optimized for dev (NAT Gateway + Flow Logs disabled). Minor concerns around vendored module maintenance and private subnet internet access.

## Critical Issues

None.

## High Priority Findings

### 1. Private Subnets No Internet Access
**Severity:** High
**Location:** `environments/dev/us-east-1/01-infra/network/vpc/terragrunt.hcl:49`

```hcl
# NAT Gateway - disabled for dev (cost optimization)
# Private subnets won't have outbound internet access
enable_nat_gateway = false
```

**Impact:**
- Private subnets (10.10.11-13.0/24) cannot reach internet
- Blocks: package downloads, API calls, OS updates
- Workloads requiring internet must use public subnets (less secure)

**Recommendation:**
- If truly no internet needed in dev, OK
- Otherwise, enable single NAT Gateway: `enable_nat_gateway = true, single_nat_gateway = true` (~$32/month vs $96/month for multi-AZ)
- Document this limitation in README or deployment guide

### 2. Vendored Module Maintenance Risk
**Severity:** High (Operational)
**Location:** `modules/terraform-aws-vpc/` (entire directory)

**Issues:**
- 1544-line forked module (terraform-aws-vpc)
- Contains political statement variable (`putin_khuylo` line 1676)
- Missing upstream updates, security patches, bug fixes
- No documented fork reasoning or version tracking

**Recommendation:**
- **Preferred:** Use official module from Terraform Registry:
  ```hcl
  terraform {
    source = "tfr:///terraform-aws-modules/vpc/aws?version=~> 5.0"
  }
  ```
- **Alternative:** Document fork rationale, version, sync strategy in `modules/terraform-aws-vpc/README.md`
- Set reminder to review upstream quarterly

## Medium Priority Improvements

### 3. VPC Flow Logs Disabled
**Severity:** Medium
**Location:** `_envcommon/networking/vpc.hcl:56`

```hcl
# VPC Flow Logs - disabled by default, enable for prod
enable_flow_log = false
```

**Issue:** No network traffic visibility for debugging, security analysis, compliance

**Recommendation:**
- Enable even for dev (S3 storage cheap: ~$0.50/GB ingestion + storage)
- Add to envcommon with conditional:
  ```hcl
  enable_flow_log                      = local.environment == "prod"
  flow_log_destination_type            = "s3"
  flow_log_destination_arn             = "arn:aws:s3:::${local.account_name}-vpc-flow-logs"
  flow_log_traffic_type                = "ALL"
  flow_log_retention_in_days           = local.environment == "prod" ? 90 : 7
  ```

### 4. Kubernetes Tags on Unused Clusters
**Severity:** Medium (YAGNI violation)
**Location:** `_envcommon/networking/vpc.hcl:73-80`

```hcl
# EKS/ELB subnet tags (for future Kubernetes readiness)
public_subnet_tags = {
  "kubernetes.io/role/elb" = "1"
}
private_subnet_tags = {
  "kubernetes.io/role/internal-elb" = "1"
}
```

**Issue:**
- Pre-optimizing for Kubernetes not yet deployed
- Adds noise to subnet tags
- No indication EKS planned in docs

**Recommendation:**
- Remove until EKS actually needed
- If planned soon, keep but add comment with target date/issue tracking number

### 5. CIDR Range Not Parameterized
**Severity:** Medium
**Location:** `environments/dev/us-east-1/01-infra/network/vpc/terragrunt.hcl:24`

```hcl
cidr = "10.10.0.0/16"
```

**Issue:** Hardcoded per environment, should be in `env.hcl` for consistency

**Recommendation:**
```hcl
# environments/dev/env.hcl
locals {
  environment = "dev"
  vpc_cidr    = "10.10.0.0/16"  # 10.10.0.0/16 = dev, 10.20.0.0/16 = staging, 10.30.0.0/16 = prod
}

# _envcommon/networking/vpc.hcl
cidr = local.env_vars.locals.vpc_cidr
```

### 6. Subnet CIDR Calculation Manual
**Severity:** Low-Medium
**Location:** `environments/dev/us-east-1/01-infra/network/vpc/terragrunt.hcl:27-45`

**Issue:**
- Manual subnet CIDR definitions error-prone
- Doesn't scale to new environments
- Risk of overlapping subnets

**Recommendation:**
```hcl
# Use cidrsubnet function for automatic calculation
locals {
  vpc_cidr = "10.10.0.0/16"
}

inputs = {
  cidr = local.vpc_cidr

  # Public: 10.10.[1-3].0/24
  public_subnets = [
    for idx in range(3) : cidrsubnet(local.vpc_cidr, 8, idx + 1)
  ]

  # Private: 10.10.[11-13].0/24
  private_subnets = [
    for idx in range(3) : cidrsubnet(local.vpc_cidr, 8, idx + 11)
  ]

  # Database: 10.10.[21-23].0/24
  database_subnets = [
    for idx in range(3) : cidrsubnet(local.vpc_cidr, 8, idx + 21)
  ]
}
```

## Low Priority Suggestions

### 7. Inconsistent Multi-AZ Configuration
**Location:** `_envcommon/networking/vpc.hcl:33`

```hcl
enable_multi_az = try(local.env_vars.locals.enable_multi_az, false)
```

**Issue:** Variable defined but never used in module inputs

**Fix:** Remove unused variable or implement multi-AZ NAT Gateway logic

### 8. Missing Output Definitions
**Issue:** No outputs defined for VPC ID, subnet IDs needed by downstream resources

**Recommendation:** Add `outputs.tf`:
```hcl
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "public_subnet_ids" {
  value = module.vpc.public_subnets
}

output "database_subnet_ids" {
  value = module.vpc.database_subnets
}
```

### 9. No Database Internet Gateway Route Protection
**Issue:** Default allows `create_database_internet_gateway_route` = false, but no explicit setting

**Recommendation:** Explicitly set in envcommon:
```hcl
create_database_internet_gateway_route = false  # Databases never need public internet
create_database_nat_gateway_route      = false  # Explicitly disable
```

## Positive Observations

✅ **Security:**
- Default security group properly locked down (lines 62-64)
- Empty ingress/egress rules = deny all by default
- Database subnets isolated from public subnets

✅ **Architecture:**
- Clean 3-tier design (public/private/database)
- Proper subnet CIDR spacing for expansion
- Follows Terragrunt DRY hierarchy correctly

✅ **Cost Optimization:**
- NAT Gateway disabled saves ~$32-96/month
- Flow Logs disabled saves ~$10-50/month
- Single AZ approach for dev appropriate

✅ **DRY Principles:**
- Good variable loading from hierarchy (account/env/region)
- Minimal duplication between envcommon and env-specific configs
- Proper use of locals for computed values

✅ **Maintainability:**
- Clear comments explaining cost decisions
- Logical file structure
- Proper tagging strategy (Component, Environment, ManagedBy)

## YAGNI/KISS/DRY Compliance

**YAGNI Violations:**
- Kubernetes tags without EKS cluster (Medium)
- `enable_multi_az` variable unused (Low)

**KISS Adherence:** Good
- Simple configuration, minimal complexity
- No over-engineering

**DRY Adherence:** Excellent
- Proper hierarchy usage
- Minimal repetition
- Good separation of concerns

## Recommended Actions

1. **Immediate:**
   - Document private subnet internet limitation in deployment guide
   - Decide: switch to official terraform-aws-modules/vpc or document fork strategy

2. **Short-term:**
   - Remove Kubernetes tags or add EKS timeline
   - Move VPC CIDR to env.hcl
   - Add outputs.tf for downstream resource consumption

3. **Medium-term:**
   - Implement automated subnet CIDR calculation
   - Enable Flow Logs (at least for prod)
   - Set up module update tracking if keeping vendor fork

4. **Long-term:**
   - Evaluate NAT Gateway need based on actual dev workload requirements
   - Consider VPC endpoint strategy for common AWS services

## Unresolved Questions

1. Why fork terraform-aws-vpc instead of using official registry module?
2. What workloads planned for private subnets? Will they need internet?
3. Is EKS deployment planned? If yes, when?
4. Any VPC peering/Transit Gateway architecture planned?
5. Should dev have GuardDuty VPC Flow Log integration?
