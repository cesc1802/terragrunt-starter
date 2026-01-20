# Codebase Summary

## Project Overview

**Terragrunt Starter** - A production-ready infrastructure-as-code project for managing AWS environments with DRY principles and configuration inheritance.

**Status:** Active development (Phase 01: Vendor Terraform Modules completed)
**Last Updated:** 2026-01-20

## Directory Structure

```
terragrunt-starter/
├── root.hcl                          # Root configuration (backend, provider, global tags)
├── account.hcl                       # AWS account and environment definitions
├── Makefile                          # Build and deployment commands
├── README.md                         # Project overview and getting started guide
├── release-manifest.json             # Release configuration metadata
│
├── _envcommon/                       # Shared module configurations (DRY layer)
│   ├── bootstrap/
│   │   └── tfstate-backend.hcl       # TFState backend common config (S3 + DynamoDB)
│   ├── networking/
│   │   └── vpc.hcl                   # Common VPC configuration (Phase 05)
│   ├── data-stores/
│   │   └── rds.hcl                   # Common RDS configuration (Phase 02)
│   ├── services/
│   │   └── ecs-cluster.hcl           # Common ECS cluster configuration (Phase 02)
│   ├── storage/
│   │   └── s3.hcl                    # Common S3 bucket configuration (Phase 02)
│   └── security/
│       └── iam-roles.hcl             # Common IAM roles configuration (Phase 02)
│
├── environments/                     # Per-environment and per-region deployments
│   ├── dev/                          # Development environment
│   │   ├── env.hcl                   # Dev environment variables (small instance, no deletion protection)
│   │   └── us-east-1/
│   │       ├── region.hcl            # Dev region configuration
│   │       ├── 00-bootstrap/
│   │       │   └── tfstate-backend/
│   │       │       └── terragrunt.hcl  # Dev state backend (Phase 03)
│   │       ├── 01-infra/
│   │       │   └── network/
│   │       │       └── vpc/
│   │       │           └── terragrunt.hcl  # Dev VPC deployment (Phase 05)
│   │       ├── data-stores/
│   │       │   └── rds/
│   │       │       └── terragrunt.hcl
│   │       └── services/
│   │           └── ecs-cluster/
│   │               └── terragrunt.hcl
│   │
│   ├── staging/                     # Staging environment
│   │   ├── env.hcl                   # Staging environment variables (small instance, no deletion protection)
│   │   └── us-east-1/
│   │       ├── region.hcl
│   │       ├── networking/vpc/terragrunt.hcl
│   │       ├── data-stores/rds/terragrunt.hcl
│   │       └── services/ecs-cluster/terragrunt.hcl
│   │
│   ├── uat/                          # UAT environment (NEW in Phase 01)
│   │   ├── env.hcl                   # UAT environment variables (medium instance, deletion protection enabled)
│   │   └── us-east-1/
│   │       ├── region.hcl            # UAT region configuration
│   │       ├── bootstrap/
│   │       │   └── tfstate-backend/
│   │       │       └── terragrunt.hcl  # UAT state backend (NEW in Phase 03)
│   │       └── (networking, data-stores, services to be added)
│   │
│   └── prod/                         # Production environment
│       ├── env.hcl                   # Prod environment variables (large instance, deletion protection, multi-AZ)
│       ├── us-east-1/                # Primary region
│       │   ├── region.hcl
│       │   ├── bootstrap/
│       │   │   └── tfstate-backend/
│       │   │       └── terragrunt.hcl  # Prod state backend (NEW in Phase 03)
│       │   ├── networking/vpc/terragrunt.hcl
│       │   ├── data-stores/rds/terragrunt.hcl
│       │   └── services/ecs-cluster/terragrunt.hcl
│       └── eu-west-1/                # Secondary region (disaster recovery)
│           ├── region.hcl
│           ├── networking/vpc/terragrunt.hcl
│           ├── data-stores/rds/terragrunt.hcl
│           └── services/ecs-cluster/terragrunt.hcl
│
├── .claude/                          # Claude project configuration and scripts
│   ├── hooks/                        # Git hooks and validation scripts
│   ├── workflows/                    # Development workflows and guidelines
│   ├── skills/                       # Python skills and utilities
│   └── scripts/                      # Additional automation scripts
│
├── scripts/                          # Deployment and bootstrap scripts (NEW in Phase 04)
│   └── bootstrap-tfstate.sh          # Bootstrap S3 + DynamoDB state backend
│
├── .github/                          # GitHub configuration
│   └── workflows/                    # CI/CD pipeline definitions (TODO)
│
├── plans/                            # Terragrunt plan outputs and reports
│   └── reports/                      # Generated documentation reports
│
├── docs/                             # Project documentation (NEW)
│   ├── project-overview-pdr.md       # Project overview and PDR (Product Development Requirements)
│   ├── code-standards.md             # Code standards and conventions
│   ├── system-architecture.md        # System architecture and deployment patterns
│   └── codebase-summary.md           # This file - codebase overview
│
├── modules/                          # Vendored Terraform modules (git subtree)
│   ├── terraform-aws-vpc/            # VPC module (v5.17.0)
│   ├── terraform-aws-rds/            # RDS module (v6.13.1) - Phase 01
│   ├── terraform-aws-ecs/            # ECS module (v5.12.1) - Phase 01
│   ├── terraform-aws-s3-bucket/      # S3 module (v4.11.0) - Phase 01
│   ├── terraform-aws-iam/            # IAM module (v5.60.0) - Phase 01
│   ├── terraform-aws-tfstate-backend/ # TFState backend module (v1.5.0)
│   └── README.md                     # Module version tracking and git remotes
│
├── .gitignore                        # Git ignore patterns
├── .repomixignore                    # Repomix ignore patterns
├── CLAUDE.md                         # Claude project instructions
└── [other config files]
```

## Key Files & Responsibilities

### Root Configuration

**root.hcl**
- Backend configuration (S3 + DynamoDB state management)
- Provider generation with default tags
- Terraform version constraints

**account.hcl**
- AWS account ID
- Account name / company name
- Global environment definitions

**Makefile**
- Common commands: plan, apply, destroy, clean
- Shortcuts for multi-module operations
- Bootstrap state backend creation

### Environment Configuration

**environments/{env}/env.hcl**
- Environment identifier (dev, staging, uat, prod)
- Instance sizing defaults (micro, small, medium, large)
- Deletion protection policy
- Multi-AZ settings
- Cost allocation tags

**environments/{env}/{region}/region.hcl**
- AWS region identifier
- Availability zones for the region
- Region-specific settings (optional)

### Module Commons (_envcommon)

**_envcommon/bootstrap/tfstate-backend.hcl** (Phase 02)
- TFState backend module (Cloud Posse terraform-aws-tfstate-backend)
- S3 bucket with versioning, encryption, public access blocking
- DynamoDB locking table with deletion protection
- Runs with local state first, migrated to S3 after creation

**_envcommon/networking/vpc.hcl** (Phase 05)
- VPC module source: `terraform-aws-modules/vpc/aws v5.17.0`
- Common VPC configuration with DRY pattern
- Subnet CIDRs calculated via cidrsubnet() from vpc_cidr
- Public/private/database subnets (1 per AZ via loops)
- NAT gateway configurable per environment (single_nat_gateway mode)
- VPC Flow Logs configurable per environment
- DNS hostnames and support enabled
- Database subnet group created
- Default security group locked down (no ingress/egress)

**_envcommon/data-stores/rds.hcl** (Phase 02)
- RDS module source: `terraform-aws-modules/rds/aws`
- Database engine defaults (PostgreSQL 15)
- Instance class: t3.micro (dev) → r6g.large (prod)
- Backup retention: 1 day (dev) → 7 days (prod)
- Multi-AZ and deletion protection configurable per environment

**_envcommon/services/ecs-cluster.hcl** (Phase 02)
- ECS module source: `terraform-aws-modules/ecs/aws//modules/cluster`
- Fargate capacity providers (FARGATE + FARGATE_SPOT)
- Container Insights: Enabled for prod only (cost optimization)
- Tags with Component, Environment, ManagedBy

**_envcommon/storage/s3.hcl** (Phase 02)
- S3 module source: `terraform-aws-modules/s3-bucket`
- Versioning and AES256 encryption enabled
- Public access blocking configured
- Force destroy: Enabled for non-prod (cost optimization)

**_envcommon/security/iam-roles.hcl** (Phase 02)
- IAM module source: `terraform-aws-modules/iam//modules/iam-assumable-role`
- Assumed by ECS tasks (trusted_role_services: ecs-tasks.amazonaws.com)
- Configurable role names and policies per environment

### Resource Deployments

**environments/{env}/{region}/{category}/{module}/terragrunt.hcl**
- Include directives (root, envcommon)
- Module-specific dependencies
- Environment overrides and customizations

## Configuration Inheritance Pattern

The project uses a strict DRY (Don't Repeat Yourself) hierarchy:

```
root.hcl (Root)
  ├─ Backend configuration (S3 + DynamoDB)
  ├─ Provider setup
  └─ Global tags
      ↓
environments/{env}/env.hcl
  ├─ Environment (dev/staging/uat/prod)
  ├─ Instance sizing
  ├─ Deletion protection
  └─ Cost allocation
      ↓
environments/{env}/{region}/region.hcl
  ├─ AWS region
  ├─ Availability zones
  └─ Region-specific settings
      ↓
_envcommon/{category}/{module}.hcl
  ├─ Module source
  └─ Common defaults
      ↓
environments/{env}/{region}/{category}/{module}/terragrunt.hcl
  ├─ Dependencies
  └─ Environment overrides
```

**Key Principle:** Each level defines ONLY what's different from its parent.

## Supported Environments

| Environment | Purpose | Instance Size | Multi-AZ | Deletion Protection | Regions |
|---|---|---|---|---|---|
| **dev** | Development & testing | t3.micro/small | No | No | us-east-1 |
| **staging** | Pre-production validation | t3.small | No | No | us-east-1 |
| **uat** | User acceptance testing | t3.medium | No | Yes | us-east-1 |
| **prod** | Production workloads | r6g.large | Yes | Yes | us-east-1, eu-west-1 |

## Deployed Modules

### Vendored Modules (Phase 01)

**Module Registry:**

| Module | Version | Source | Status |
|--------|---------|--------|--------|
| terraform-aws-vpc | 5.17.0 | terraform-aws-modules | Vendored |
| terraform-aws-rds | 6.13.1 | terraform-aws-modules | Vendored (Phase 01) |
| terraform-aws-ecs | 5.12.1 | terraform-aws-modules | Vendored (Phase 01) |
| terraform-aws-s3-bucket | 4.11.0 | terraform-aws-modules | Vendored (Phase 01) |
| terraform-aws-iam | 5.60.0 | terraform-aws-modules | Vendored (Phase 01) |
| terraform-aws-tfstate-backend | 1.5.0 | cloudposse | Vendored |

### Networking
- **VPC** (Virtual Private Cloud) - Phase 05
  - Module: `terraform-aws-modules/vpc/aws v5.17.0`
  - Location: `environments/{env}/{region}/01-infra/network/vpc/`
  - Provides: VPC, subnets (public/private/database), IGW, NAT, route tables, DNS
  - Subnets: Calculated from vpc_cidr using cidrsubnet(), one per AZ
  - Subnet ranges: Public (+1,+2,+3), Private (+11,+12,+13), Database (+21,+22,+23)
  - Dev Config: vpc_cidr=10.10.0.0/16, NAT disabled, Flow Logs disabled
  - Outputs: vpc_id, public_subnet_ids, private_subnet_ids, database_subnet_ids

### Data Stores
- **RDS** (Relational Database Service) - Module available (v6.13.1)
  - Location: `environments/{env}/{region}/data-stores/rds/`
  - Provides: PostgreSQL/MySQL database instances
  - Outputs: rds_endpoint, security_group_id
  - Dependencies: VPC (for security groups)

### Services
- **ECS Cluster** (Elastic Container Service) - Module available (v5.12.1)
  - Location: `environments/{env}/{region}/services/ecs-cluster/`
  - Provides: Container orchestration platform
  - Outputs: cluster_id, cluster_arn
  - Dependencies: VPC, IAM roles

### Storage
- **S3 Bucket** - Module available (v4.11.0)
  - Supports: Versioning, encryption, logging, lifecycle policies

### Identity & Access Management
- **IAM** - Module available (v5.60.0)
  - Supports: Roles, policies, users, groups, cross-account access

## Naming Conventions

### Directories & Files
- **Environment dirs:** lowercase (dev, staging, uat, prod)
- **Region dirs:** AWS region code (us-east-1, eu-west-1)
- **Category dirs:** lowercase plural (networking, data-stores, services)
- **Module dirs:** lowercase with hyphens (vpc, rds, ecs-cluster)
- **Files:** .hcl extension, lowercase with hyphens

### HCL Identifiers
- **Local variables:** snake_case (e.g., enable_deletion_protection)
- **Resource names:** snake_case (e.g., aws_vpc, aws_rds_instance)
- **Input variables:** snake_case (e.g., vpc_cidr_block)
- **Output values:** snake_case (e.g., vpc_id)
- **Tags:** PascalCase keys (e.g., Environment, CostAllocation)

## Key Features

### DRY Configuration
- Configuration inheritance eliminates duplication
- Shared module configs in _envcommon/
- Sensible defaults with environment overrides

### Multi-Environment Support
- Isolated configurations for dev, staging, UAT, and production
- Different sizing and protection policies per environment
- Cost optimization through right-sizing

### Multi-Region Production
- Primary region: us-east-1
- Secondary region: eu-west-1 (disaster recovery)
- Non-overlapping CIDR ranges for VPC peering

### State Management
- Remote state (S3 + DynamoDB)
- State versioning and encryption
- Automatic locking to prevent conflicts

### Security Best Practices
- Deletion protection for production and UAT
- VPC Flow Logs for production
- Multi-AZ RDS in production
- Default tags on all resources
- IAM role-based access control

### Dependency Management
- Terragrunt automatically resolves module dependencies
- Cross-module outputs referenced via dependency blocks
- Correct deployment order ensured by Terragrunt

## State Management Architecture

**Backend:** S3 + DynamoDB (Cloud Posse terraform-aws-tfstate-backend module)
- **Bucket naming:** `{account_name}-{environment}-terraform-state`
- **Versioning:** Enabled per-environment
- **Encryption:** SSE-S3 at rest
- **Locking Table:** `{account_name}-{environment}-terraform-state`
- **PITR:** Enabled for prod (point-in-time recovery)
- **Deletion Protection:** Enabled for UAT/Prod

## Recent Changes

### Phase 02 (Current - _envcommon Updates & Region-Specific CIDR)

**Completed:** 2026-01-20

**Key Changes:**
1. Moved `vpc_cidr` from `env.hcl` to `region.hcl` for region-specific CIDR allocation (multi-region support)
2. Created 4 new _envcommon modules (Phase 02):
   - `_envcommon/data-stores/rds.hcl` - RDS configuration (v6.13.1)
   - `_envcommon/services/ecs-cluster.hcl` - ECS cluster configuration (v5.12.1)
   - `_envcommon/storage/s3.hcl` - S3 bucket configuration (v4.11.0)
   - `_envcommon/security/iam-roles.hcl` - IAM roles configuration (v5.60.0)
3. Updated `_envcommon/networking/vpc.hcl` to source vpc_cidr from region_vars
4. Updated `environments/dev/env.hcl` to remove vpc_cidr (moved to region.hcl)
5. Created `environments/dev/us-east-1/region.hcl` with vpc_cidr = "10.10.0.0/16"

**Documentation Updates (Phase 02):**
- Updated codebase-summary.md: Directory structure, _envcommon section, deployment modules
- Updated system-architecture.md: Module architecture for storage and security layers (planned)
- Updated README.md: _envcommon tree diagram to show storage/ and security/ dirs

### Phase 01 (Vendor Terraform Modules)

**Completed:** 2026-01-20

**New Modules Added:**
1. `terraform-aws-rds` (v6.13.1) - Relational Database Service
2. `terraform-aws-ecs` (v5.12.1) - Elastic Container Service
3. `terraform-aws-s3-bucket` (v4.11.0) - Simple Storage Service
4. `terraform-aws-iam` (v5.60.0) - Identity and Access Management

**New File:**
- `modules/README.md` - Version tracking, update procedures, git remotes

**Key Changes:**
- All Phase 01 modules vendored via git subtree
- Version tracking table updated in modules/README.md
- Git remotes configured for tf-rds, tf-ecs, tf-s3, tf-iam
- Module update SLA established (security: 1wk, minor: monthly, major: quarterly)

### Phase 05 (Completed)

**New Files:**
1. `_envcommon/networking/vpc.hcl` - Common VPC configuration
2. `environments/dev/env.hcl` - Dev environment variables (vpc_cidr, nat, flow_logs)
3. `environments/dev/us-east-1/01-infra/network/vpc/terragrunt.hcl` - Dev VPC deployment

**Key Changes:**
- Module: Official `terraform-aws-modules/vpc/aws v5.17.0`
- vpc_cidr parameterized in env.hcl (dev: 10.10.0.0/16)
- Subnet CIDRs auto-calculated via cidrsubnet() function
- Subnet layout: Public /24s (+1,+2,+3), Private (+11,+12,+13), Database (+21,+22,+23)
- NAT Gateway configurable per environment (dev: disabled, cost optimization ~$32/mo)
- VPC Flow Logs configurable per environment (dev: disabled, cost optimization)
- Default security group locked down (no ingress/egress rules)
- DNS hostnames and support enabled for all environments
- Database subnet group created

### Phase 04 (Completed)

**Files:**
1. `scripts/bootstrap-tfstate.sh` - Bootstrap helper script with prerequisite validation
2. `docs/deployment-guide.md` - Deployment and bootstrap procedures

**Changes:**
- Bootstrap script validates AWS credentials, Terraform, Terragrunt installations
- Makefile targets: bootstrap, bootstrap-migrate, bootstrap-verify, bootstrap-all
- Deployment order enforced: dev → uat → prod
- State migration procedure automated with --migrate flag
- Bootstrap commands integrated into Make workflow

### Phase 03 (Completed)

**Files Created:**
1. `environments/dev/us-east-1/bootstrap/tfstate-backend/terragrunt.hcl` - Dev bootstrap config
2. `environments/uat/us-east-1/bootstrap/tfstate-backend/terragrunt.hcl` - UAT bootstrap config
3. `environments/prod/us-east-1/bootstrap/tfstate-backend/terragrunt.hcl` - Prod bootstrap config

**Key Changes:**
- Bootstrap terragrunt.hcl files created for all environments (dev, uat, prod)
- Root terragrunt.hcl bucket/DynamoDB naming aligned with Cloud Posse module output
- Bucket pattern: `{account_name}-{environment}-terraform-state`
- DynamoDB table pattern: `{account_name}-{environment}-terraform-state`
- Bootstrap procedure documented (local state → migrate to S3)
- README.md updated with bootstrap instructions
- Environment-specific bootstrap configurations with proper tagging

### Phase 02 (Completed)

**New Files:**
1. `_envcommon/bootstrap/tfstate-backend.hcl` - TFState backend common configuration

**Key Additions:**
- Bootstrap module for S3 + DynamoDB remote state management
- Cloud Posse terraform-aws-tfstate-backend integration
- Environment-aware state bucket and locking table setup
- Force destroy capability for dev environment
- Implements DRY pattern with dynamic module paths
- Cloud Posse label inputs (namespace, stage, name, attributes)
- Security defaults: AES256 encryption, public access blocking, deletion protection
- Region tag for multi-region support

**Documentation Updates (Phase 02):**
- Updated README.md: 2 references to root.hcl configuration
- Updated code-standards.md: 2 references to root.hcl and tfstate backend
- Updated system-architecture.md: 1 reference to State Management Architecture
- Updated codebase-summary.md: 3 references to Phase 02 completion and bootstrap module
- Updated project-overview-pdr.md: 3 references to bootstrap functionality

### Phase 01 (Completed)

### New Files
1. `environments/uat/env.hcl` - UAT environment configuration
2. `environments/uat/us-east-1/region.hcl` - UAT region configuration

### Configuration Changes
- Created UAT environment with medium instance sizing
- Enabled deletion protection for UAT
- Configured single AZ for cost optimization

### Directory Restructuring
- Fixed directory typo: `environtments/` → `environments/`
- Ensured all files moved to corrected location

### Documentation Updates
- Created comprehensive project-overview-pdr.md
- Created detailed code-standards.md
- Created system-architecture.md
- Created codebase-summary.md

## Building & Deployment

### Available Commands
```bash
make help                    # Show all available commands
make plan TARGET=path       # Plan specific module
make apply TARGET=path      # Apply specific module
make destroy TARGET=path    # Destroy specific module
make plan-all ENV=env       # Plan all modules in environment
make apply-all ENV=env      # Apply all modules in environment
make clean                  # Clear Terragrunt caches
make graph ENV=env          # Generate dependency graph
make bootstrap-state        # Create S3 + DynamoDB backend
```

### Deployment Order
Terragrunt automatically handles dependencies:
1. **Networking** (VPC) - foundation
2. **Data Stores** (RDS) - depends on VPC
3. **Services** (ECS) - depends on VPC and IAM

### Example Deployments
```bash
# Plan specific module
make plan TARGET=dev/us-east-1/networking/vpc

# Apply specific module
make apply TARGET=dev/us-east-1/networking/vpc

# Plan entire environment
make plan-all ENV=dev REGION=us-east-1

# Apply entire environment (respects dependencies)
make apply-all ENV=dev REGION=us-east-1
```

## Dependencies & Versions

### Required Tools
- **Terraform:** >= 1.5.0
- **Terragrunt:** >= 0.50.0
- **AWS CLI:** Configured with credentials
- **Make:** Optional (for Makefile commands)

### Terraform Modules
- **VPC:** terraform-aws-modules/vpc/aws
- **RDS:** terraform-aws-modules/rds/aws
- **ECS:** terraform-aws-modules/ecs/aws

### AWS Services Used
- EC2 (VPC, subnets, NAT gateways)
- RDS (relational databases)
- ECS (container orchestration)
- S3 (state backend, logs)
- DynamoDB (state locking)
- CloudWatch (monitoring, logs)
- IAM (access control)
- Route53 (DNS, health checks)

## Cost Profile

| Environment | Estimated Monthly Cost | Primary Components |
|---|---|---|
| **dev** | $50-100 | Small instance, single RDS, single NAT |
| **staging** | $100-150 | Small instance, small RDS, single NAT |
| **uat** | $150-200 | Medium instance, small RDS, single NAT |
| **prod** | $300-500+ | Large instances, multi-AZ, per-AZ NAT, secondary region |

## Troubleshooting Reference

| Issue | Solution |
|---|---|
| Backend config changed | `terragrunt init -reconfigure` |
| State lock stuck | `terragrunt force-unlock <LOCK_ID>` |
| Module not found | Verify config_path in dependency blocks |
| Caching issues | `make clean` to clear Terragrunt cache |
| Variable undefined | Check include paths and locals |

## Documentation

Comprehensive documentation available in `./docs/`:

1. **project-overview-pdr.md** - Project scope, PDR, requirements, and roadmap
2. **code-standards.md** - Coding standards, conventions, best practices
3. **system-architecture.md** - Architecture overview, modules, deployment patterns
4. **codebase-summary.md** - This file

## Next Steps & Roadmap

### Completed (Phase 01 - Vendor Terraform Modules)
- ✓ Vendored terraform-aws-rds (v6.13.1)
- ✓ Vendored terraform-aws-ecs (v5.12.1)
- ✓ Vendored terraform-aws-s3-bucket (v4.11.0)
- ✓ Vendored terraform-aws-iam (v5.60.0)
- ✓ Created modules/README.md with version tracking and git remotes

### Completed (Phase 02)
- ✓ TFState backend configuration (`_envcommon/bootstrap/tfstate-backend.hcl`)
- ✓ S3 + DynamoDB remote state setup
- ✓ Cloud Posse module integration

### Completed (Phase 03)
- ✓ Created bootstrap terragrunt.hcl for dev, uat, prod
- ✓ Fixed root terragrunt.hcl naming (S3 bucket + DynamoDB aligned with Cloud Posse module)
- ✓ Updated README.md with bootstrap instructions
- ✓ Environment-specific bootstrap configs with proper tagging

### Completed (Phase 05)
- ✓ Common VPC configuration (`_envcommon/networking/vpc.hcl`) with DRY pattern
- ✓ Dev VPC deployment (`environments/dev/us-east-1/01-infra/network/vpc/terragrunt.hcl`)
- ✓ VPC infrastructure documentation

### Completed (Phase 04)
- ✓ Bootstrap helper script (`scripts/bootstrap-tfstate.sh`) with prerequisite validation
- ✓ Makefile bootstrap targets: bootstrap, bootstrap-migrate, bootstrap-verify, bootstrap-all
- ✓ Deployment guide documentation

### In Progress (Phase 05+)
- [x] Create common VPC configuration (_envcommon/networking/vpc.hcl) - Phase 05
- [x] Deploy dev VPC (environments/dev/us-east-1/01-infra/network/vpc) - Phase 05
- [ ] Deploy VPC for staging environment
- [ ] Deploy VPC for UAT environment
- [ ] Deploy bootstrap infrastructure to prod
- [ ] Deploy VPC to prod primary region (us-east-1)
- [ ] Deploy VPC to prod secondary region (eu-west-1)
- [ ] Deploy RDS infrastructure (all environments)
- [ ] Deploy ECS infrastructure (all environments)

### Planned (Phase 05+)
- [ ] CI/CD pipeline setup (GitHub Actions)
- [ ] Automated deployments
- [ ] Multi-region failover testing
- [ ] Disaster recovery procedures
- [ ] Observability enhancements

## Support & Resources

- **Terragrunt Docs:** https://terragrunt.gruntwork.io/docs/
- **Terraform AWS Modules:** https://registry.terraform.io/namespaces/terraform-aws-modules
- **Gruntwork Reference Architecture:** https://gruntwork.io/reference-architecture/
- **Project Documentation:** See `./docs/` directory

## Maintenance

### Regular Tasks
- **Monthly:** Validate backup and restore procedures
- **Quarterly:** Review and update module versions
- **Annually:** Security audit and compliance check

### Adding New Modules
1. Create common config: `_envcommon/{category}/{module}.hcl`
2. Create environment deployment: `environments/{env}/{region}/{category}/{module}/terragrunt.hcl`
3. Document in system-architecture.md
4. Test in dev first, then stage up through environments

## License

MIT License - See LICENSE file for details
