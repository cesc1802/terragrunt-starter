# Terragrunt Starter - Project Overview & PDR

## Project Overview

A production-ready Terragrunt project structure for managing AWS infrastructure with DRY (Don't Repeat Yourself) principles. Provides enterprise-grade configuration inheritance, environment isolation, and multi-region support across dev, staging, UAT, and production environments.

**Status:** Phase 03 Bootstrap Infrastructure Configuration - completed
**Last Updated:** 2026-01-08

## Current Environments

| Environment | Region(s) | Instance Size | Multi-AZ | Deletion Protection | Purpose |
|---|---|---|---|---|---|
| **dev** | us-east-1 | small | No | No | Development & testing |
| **staging** | us-east-1 | small | No | No | Pre-production validation |
| **uat** | us-east-1 | medium | No | Yes | User acceptance testing |
| **prod** | us-east-1, eu-west-1 | large | Yes | Yes | Production workloads |

## Product Development Requirements (PDR)

### Functional Requirements

#### F1: Infrastructure as Code Foundation
- **Requirement:** Multi-environment Terraform/Terragrunt configuration with DRY hierarchy
- **Status:** Complete
- **Implementation:**
  - Root-level config (terragrunt.hcl): Backend, provider generation, global tags
  - Environment-level (env.hcl): Environment name, instance sizing, cost settings
  - Region-level (region.hcl): AWS region, availability zones
  - Module commons (_envcommon/): Shared module configs, sensible defaults
  - Resource-level: Environment-specific overrides only

#### F2: Multi-Environment Support
- **Requirement:** Isolated infrastructure configurations for dev, staging, UAT, and production
- **Status:** In Progress (UAT environment added)
- **Implementation:**
  - dev: Single AZ, no deletion protection, minimal sizing
  - staging: Single AZ, no deletion protection, moderate sizing
  - uat: Single AZ, deletion protection enabled, medium instance sizing
  - prod: Multi-AZ, deletion protection enabled, large instance sizing, multi-region (us-east-1 primary, eu-west-1 secondary)

#### F3: Cross-Module Dependency Management
- **Requirement:** Automatic handling of infrastructure dependencies between modules
- **Status:** Complete
- **Implementation:**
  - Terragrunt dependency blocks enable module ordering
  - Examples: ECS clusters depend on VPCs, RDS depends on networking

#### F4: Multi-Region Support (Production)
- **Requirement:** Production infrastructure across primary and secondary regions
- **Status:** Complete (us-east-1 & eu-west-1)
- **Implementation:**
  - CIDR ranges: us-east-1 (10.30.0.0/16), eu-west-1 (10.40.0.0/16)
  - VPC peering ready via non-overlapping CIDR design

#### F5: Bootstrap & State Management
- **Requirement:** S3 + DynamoDB state backend with encryption and locking
- **Status:** Complete (Phase 02 & 03 delivered)
- **Implementation:**
  - Cloud Posse terraform-aws-tfstate-backend module
  - S3 versioning for state files per environment
  - DynamoDB table for state locking per environment
  - SSE-S3 encryption at rest
  - PITR enabled for production
  - Deletion protection for UAT/Prod backends
  - Bootstrap terragrunt.hcl files for all environments
  - Naming pattern: `{account_name}-{environment}-terraform-state`

### Non-Functional Requirements

#### N1: Security
- **Requirement:** Enable deletion protection for non-dev environments, implement tagging strategy
- **Status:** Complete
- **Implementation:**
  - Prod & UAT: Deletion protection enabled
  - VPC Flow Logs enabled for prod
  - Multi-AZ RDS in production
  - Default tags applied to all resources

#### N2: Cost Optimization
- **Requirement:** Right-size compute and storage across environments
- **Status:** Complete
- **Implementation:**
  - Dev/Staging: t3.micro/t3.small RDS, single NAT gateway
  - UAT: Medium instances, single AZ
  - Prod: r6g.large RDS, per-AZ NAT gateways

#### N3: Observability
- **Requirement:** Enable monitoring and logging for production
- **Status:** Complete
- **Implementation:**
  - Container Insights enabled for prod ECS
  - VPC Flow Logs enabled for prod

#### N4: Maintainability
- **Requirement:** DRY configuration to minimize duplication
- **Status:** Complete
- **Implementation:**
  - Shared configs in _envcommon/
  - Configuration inheritance through terragrunt.hcl chains
  - Consistent HCL structure across all environments

### Acceptance Criteria

#### Phase 01: UAT Environment Setup
- [x] Create UAT environment configuration (env.hcl)
- [x] Create UAT region configuration (us-east-1/region.hcl)
- [x] Configure medium instance sizing for UAT
- [x] Enable deletion protection for UAT resources
- [x] Fix directory typo: environtments → environments
- [x] Update README to reflect UAT environment
- [x] Completed 2026-01-08

#### Phase 02: TFState Backend Module Setup
- [x] Create common bootstrap module config (_envcommon/bootstrap/tfstate-backend.hcl)
- [x] Cloud Posse terraform-aws-tfstate-backend integration
- [x] Environment-aware bucket + locking table naming
- [x] Force destroy for dev, deletion protection for UAT/Prod
- [x] Completed 2026-01-08

#### Phase 03: Bootstrap Infrastructure Configuration
- [x] Create dev bootstrap terragrunt.hcl (environments/dev/us-east-1/bootstrap/tfstate-backend/)
- [x] Create uat bootstrap terragrunt.hcl (environments/uat/us-east-1/bootstrap/tfstate-backend/)
- [x] Create prod bootstrap terragrunt.hcl (environments/prod/us-east-1/bootstrap/tfstate-backend/)
- [x] Fix root terragrunt.hcl naming (S3 bucket + DynamoDB table)
- [x] Align bucket/table naming with Cloud Posse module output format
- [x] Update README.md with bootstrap deployment instructions
- [x] Environment-specific bootstrap configurations with proper tagging
- [x] Completed 2026-01-08

#### Phase 04: Bootstrap Deployment & State Migration
- [ ] Deploy bootstrap infrastructure to dev environment
- [ ] Migrate dev terraform state from local to S3 backend
- [ ] Deploy bootstrap infrastructure to uat environment
- [ ] Deploy bootstrap infrastructure to prod environments (us-east-1, eu-west-1)
- [ ] Validate state locking and versioning
- [ ] Deploy UAT infrastructure (networking, RDS, ECS)
- [ ] Validate UAT networking stack
- [ ] Validate UAT data stores

## Architecture Hierarchy

```
terragrunt.hcl (ROOT)
  ├─ Backend: S3 + DynamoDB
  ├─ Provider generation
  └─ Global tags
      ↓
  environments/{environment}/env.hcl
      ├─ Environment name (dev/staging/uat/prod)
      ├─ Instance sizing defaults
      ├─ Deletion protection policy
      └─ Cost allocation tags
          ↓
  environments/{environment}/{region}/region.hcl
      ├─ AWS region
      ├─ Availability zones
      └─ Region-specific settings
          ↓
  _envcommon/{category}/{module}.hcl
      ├─ Module source
      └─ Common defaults
          ↓
  environments/{environment}/{region}/{category}/{module}/terragrunt.hcl
      └─ Environment-specific overrides
```

## Key Configuration Files

| File | Purpose | Scope |
|---|---|---|
| `terragrunt.hcl` | Root config | Global (all environments) |
| `account.hcl` | AWS account settings | Global |
| `environments/{env}/env.hcl` | Environment variables | Single environment |
| `environments/{env}/{region}/region.hcl` | Region variables | Single region |
| `_envcommon/**/*.hcl` | Module commons | All environments |
| `environments/{env}/{region}/**/*.hcl` | Resource deployments | Single deployment unit |

## Module Structure

### Networking
- **vpc**: Virtual Private Cloud with public/private subnets, NAT gateways, route tables
- **Location:** `environments/{env}/{region}/networking/vpc/terragrunt.hcl`

### Data Stores
- **rds**: Relational database (RDS) with environment-specific sizing and multi-AZ
- **Location:** `environments/{env}/{region}/data-stores/rds/terragrunt.hcl`

### Services
- **ecs-cluster**: Elastic Container Service cluster with Container Insights
- **Location:** `environments/{env}/{region}/services/ecs-cluster/terragrunt.hcl`

## Getting Started

### Prerequisites
- Terraform >= 1.5.0
- Terragrunt >= 0.50.0
- AWS CLI configured with appropriate credentials
- Make (optional)

### Quick Setup
1. Edit `account.hcl` with your AWS account ID and name
2. Run `make bootstrap-state` to create S3 + DynamoDB backend
3. Deploy environments: `make apply TARGET=dev/us-east-1/networking/vpc`

## Deployment Strategy

### Plan & Apply Flow
```bash
# Single module
make plan TARGET=dev/us-east-1/networking/vpc
make apply TARGET=dev/us-east-1/networking/vpc

# Entire environment (respects dependencies)
make plan-all ENV=dev REGION=us-east-1
make apply-all ENV=dev REGION=us-east-1
```

### Dependency Resolution
Terragrunt automatically orders deployments:
1. VPC (networking foundation)
2. RDS (data layer)
3. ECS clusters (compute layer)

## Cost Optimization Strategy

| Feature | Dev | Staging | UAT | Prod |
|---|---|---|---|---|
| Instance Type | t3.micro | t3.small | t3.medium | r6g.large |
| NAT Gateway | Single | Single | Single | Per-AZ |
| Multi-AZ | No | No | No | Yes |
| RDS Multi-AZ | No | No | No | Yes |
| Container Insights | Off | Off | Off | On |
| VPC Flow Logs | Off | Off | Off | On |

**Monthly Cost Profile:**
- Dev: ~$50-100 (minimal)
- Staging: ~$100-150 (moderate)
- UAT: ~$150-200 (baseline production config, single AZ)
- Prod: ~$300-500+ (full HA, multi-region)

## Known Issues & Roadmap

### Completed
- Phase 01: UAT environment setup (✓ 2026-01-08)
- Phase 02: TFState backend module setup (✓ 2026-01-08)
- Phase 03: Bootstrap infrastructure configuration (✓ 2026-01-08)
- Directory typo fix: environtments → environments

### In Progress
- Phase 04: Bootstrap deployment & state migration

### Planned
- Phase 05: Application infrastructure deployment (networking, RDS, ECS)
- Phase 06: CI/CD pipeline setup (GitHub Actions)
- Phase 07: Multi-region failover testing
- Phase 08: Automated backup & disaster recovery
- Phase 09: Observability enhancements (DataDog/CloudWatch)

## Maintenance & Support

### Regular Tasks
- Review and update environment configurations quarterly
- Rotate credentials and secrets regularly
- Monitor state file S3 bucket for growth
- Validate backup restore procedures monthly

### Common Issues
- **Backend configuration changed:** Run `terragrunt init -reconfigure`
- **State lock issues:** Use `terragrunt force-unlock <LOCK_ID>` (carefully)
- **Caching problems:** Run `make clean` to clear Terragrunt caches

## References

- [Terragrunt Documentation](https://terragrunt.gruntwork.io/docs/)
- [Terraform AWS Modules](https://registry.terraform.io/namespaces/terraform-aws-modules)
- [Gruntwork Reference Architecture](https://gruntwork.io/reference-architecture/)
