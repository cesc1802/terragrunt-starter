# Codebase Summary

## Project Overview

**Terragrunt Starter** - A production-ready infrastructure-as-code project for managing AWS environments with DRY principles and configuration inheritance.

**Status:** Active development (Phase 03: Bootstrap Infrastructure Configuration completed)
**Last Updated:** 2026-01-08

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
│   │   └── vpc.hcl                   # Common VPC configuration
│   ├── data-stores/
│   │   └── rds.hcl                   # Common RDS configuration
│   └── services/
│       └── ecs-cluster.hcl           # Common ECS cluster configuration
│
├── environments/                     # Per-environment and per-region deployments
│   ├── dev/                          # Development environment
│   │   ├── env.hcl                   # Dev environment variables (small instance, no deletion protection)
│   │   └── us-east-1/
│   │       ├── region.hcl            # Dev region configuration
│   │       ├── bootstrap/
│   │       │   └── tfstate-backend/
│   │       │       └── terragrunt.hcl  # Dev state backend (NEW in Phase 03)
│   │       ├── networking/
│   │       │   └── vpc/
│   │       │       └── terragrunt.hcl
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

**_envcommon/networking/vpc.hcl**
- VPC module source (terraform-aws-modules/vpc/aws)
- Common VPC configuration
- Subnet and NAT gateway defaults

**_envcommon/data-stores/rds.hcl**
- RDS module source (terraform-aws-modules/rds/aws)
- Database engine defaults
- Backup and retention settings

**_envcommon/services/ecs-cluster.hcl**
- ECS module source (terraform-aws-modules/ecs/aws)
- Cluster defaults
- Logging configuration

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

### Networking
- **VPC** (Virtual Private Cloud)
  - Location: `environments/{env}/{region}/networking/vpc/`
  - Provides: VPC, subnets, NAT gateways, route tables
  - Outputs: vpc_id, subnet_ids, nat_gateway_ids

### Data Stores
- **RDS** (Relational Database Service)
  - Location: `environments/{env}/{region}/data-stores/rds/`
  - Provides: PostgreSQL/MySQL database instances
  - Outputs: rds_endpoint, security_group_id
  - Dependencies: VPC (for security groups)

### Services
- **ECS Cluster** (Elastic Container Service)
  - Location: `environments/{env}/{region}/services/ecs-cluster/`
  - Provides: Container orchestration platform
  - Outputs: cluster_id, cluster_arn
  - Dependencies: VPC, IAM roles

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

### Phase 04 (Current)

**New Files:**
1. `scripts/bootstrap-tfstate.sh` - Bootstrap helper script with prerequisite validation
2. `docs/deployment-guide.md` - Deployment and bootstrap procedures

**Key Changes:**
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

### Completed (Phase 01)
- ✓ UAT environment configuration
- ✓ Directory structure fixes
- ✓ Comprehensive documentation

### Completed (Phase 02)
- ✓ TFState backend configuration (`_envcommon/bootstrap/tfstate-backend.hcl`)
- ✓ S3 + DynamoDB remote state setup
- ✓ Cloud Posse module integration

### Completed (Phase 03)
- ✓ Created bootstrap terragrunt.hcl for dev, uat, prod
- ✓ Fixed root terragrunt.hcl naming (S3 bucket + DynamoDB aligned with Cloud Posse module)
- ✓ Updated README.md with bootstrap instructions
- ✓ Environment-specific bootstrap configs with proper tagging

### Completed (Phase 04)
- ✓ Bootstrap helper script (`scripts/bootstrap-tfstate.sh`) with prerequisite validation
- ✓ Makefile bootstrap targets: bootstrap, bootstrap-migrate, bootstrap-verify, bootstrap-all
- ✓ Deployment guide documentation

### In Progress (Phase 04+)
- [ ] Deploy bootstrap infrastructure to dev
- [ ] Migrate dev state to S3 backend
- [ ] Deploy bootstrap infrastructure to uat
- [ ] Deploy UAT infrastructure (networking, RDS, ECS)
- [ ] Validate UAT networking stack
- [ ] Validate UAT data stores
- [ ] Deploy bootstrap infrastructure to prod
- [ ] Deploy prod primary region (us-east-1)
- [ ] Deploy prod secondary region (eu-west-1)

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
