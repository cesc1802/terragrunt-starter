# Code Standards & Codebase Structure

## Directory Structure

```
terragrunt-starter/
├── root.hcl                    # Root config (backend, provider)
├── account.hcl                 # AWS account & environment settings
├── Makefile                    # Common commands and workflows
├── README.md                   # Project overview
│
├── _envcommon/                 # Shared module configurations (DRY layer)
│   ├── networking/
│   │   └── vpc.hcl
│   ├── data-stores/
│   │   └── rds.hcl
│   └── services/
│       └── ecs-cluster.hcl
│
├── environments/               # Per-environment configurations
│   ├── dev/
│   │   ├── env.hcl
│   │   └── us-east-1/
│   │       ├── region.hcl
│   │       ├── networking/vpc/terragrunt.hcl
│   │       ├── data-stores/rds/terragrunt.hcl
│   │       └── services/ecs-cluster/terragrunt.hcl
│   ├── staging/
│   │   ├── env.hcl
│   │   └── us-east-1/
│   │       ├── region.hcl
│   │       └── ... (mirrors dev structure)
│   ├── uat/
│   │   ├── env.hcl
│   │   └── us-east-1/
│   │       ├── region.hcl
│   │       └── ... (mirrors dev structure)
│   └── prod/
│       ├── env.hcl
│       ├── us-east-1/
│       │   ├── region.hcl
│       │   └── ... (full HA config)
│       └── eu-west-1/
│           ├── region.hcl
│           └── ... (DR region config)
│
├── plans/                      # Terragrunt plan outputs
│   └── reports/                # Documentation reports
│
└── docs/                       # Project documentation
    ├── project-overview-pdr.md
    ├── code-standards.md
    ├── system-architecture.md
    └── codebase-summary.md
```

## Naming Conventions

### Directories & Files
- **Environment directories:** lowercase (dev, staging, uat, prod)
- **Region directories:** AWS region code (us-east-1, eu-west-1)
- **Module categories:** lowercase plural (networking, data-stores, services)
- **Module names:** lowercase with hyphens (vpc, rds, ecs-cluster)
- **Configuration files:** lowercase with extension (.hcl, .tf)

### Terraform/Terragrunt Identifiers
- **Local variables:** `snake_case` (e.g., `enable_deletion_protection`)
- **Resource names:** `snake_case` (e.g., `aws_vpc`, `aws_rds_instance`)
- **Input variables:** `snake_case` (e.g., `vpc_cidr_block`)
- **Output values:** `snake_case` (e.g., `vpc_id`, `rds_endpoint`)
- **Tags:** `PascalCase` for keys (e.g., `Environment`, `CostAllocation`)

### Variables Scope
```
root/account.hcl (globals)
  ↓
environments/{env}/env.hcl (environment-specific)
  ↓
environments/{env}/{region}/region.hcl (region-specific)
  ↓
_envcommon/{category}/{module}.hcl (module common)
  ↓
environments/{env}/{region}/{category}/{module}/terragrunt.hcl (resource overrides)
```

## Configuration Standards

### Root Configuration (root.hcl)

Must define:
- Backend configuration (S3 + DynamoDB)
- Provider generation with common attributes
- Global tags applied to all resources
- Default validation rules

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
    terraform {
      backend "s3" {
        # Configured by terragrunt
      }
    }
  EOT
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
    provider "aws" {
      region = var.aws_region
      default_tags {
        tags = local.common_tags
      }
    }
  EOT
}
```

### Environment Configuration (env.hcl)

Must define:
- Environment name (dev/staging/uat/prod)
- Instance sizing defaults
- Deletion protection policy
- Multi-AZ setting
- Cost allocation tags

```hcl
locals {
  environment                = "dev"
  instance_size_default      = "small"
  enable_deletion_protection = false
  enable_multi_az            = false
  cost_allocation_tag        = "dev-workloads"
}
```

### Region Configuration (region.hcl)

Must define:
- AWS region
- Availability zones for the region
- Region-specific settings (optional)

```hcl
locals {
  aws_region = "us-east-1"
  azs        = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
```

### Module Commons (_envcommon/{category}/{module}.hcl)

Must define:
- Module source (terraform registry or local)
- Default inputs applicable to all environments
- Documentation of common settings

```hcl
terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws"
}

inputs = {
  # Common defaults
  enable_dns_hostnames = true
  enable_dns_support   = true
}
```

### Resource Configuration (terragrunt.hcl)

Must define:
- Include directives for inheritance chain
- Environment-specific input overrides
- Dependencies on other modules
- Local adjustments only (no defaults)

```hcl
include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders())}/_envcommon/networking/vpc.hcl"
}

dependency "networking" {
  config_path = "../networking/vpc"
}

inputs = {
  # Environment-specific overrides only
  vpc_cidr_block = "10.0.0.0/16"
}
```

## HCL Style Guidelines

### Formatting
- **Indentation:** 2 spaces (never tabs)
- **Line length:** Keep under 120 characters where practical
- **Blank lines:** Separate logical sections with single blank line
- **Comments:** Use `#` for single-line, document complex logic

### Block Organization
```hcl
# 1. Terraform version & requirements
terraform {
  required_version = ">= 1.5.0"
}

# 2. Include directives
include "root" {
  path = find_in_parent_folders()
}

# 3. Local variables
locals {
  environment = "dev"
}

# 4. Dependencies
dependency "vpc" {
  config_path = "../networking/vpc"
}

# 5. Inputs
inputs = {
  vpc_id = dependency.vpc.outputs.vpc_id
}
```

### Variable Handling

**Use locals for:**
- Derived values
- Complex transformations
- Configuration that applies at one level

**Use inputs for:**
- Values passed from parent configurations
- Overrides and customizations
- Cross-environment variations

**Example:**
```hcl
locals {
  # Derived: computed at this level
  nat_gateway_count = local.enable_multi_az ? 3 : 1

  # Configuration from parent
  environment = local.environment
}

inputs = {
  # Passed upward
  nat_gateway_count = local.nat_gateway_count
}
```

## Module Development Standards

### Module Organization
Each module should be deployable independently:
- Single responsibility principle
- Clear input/output contracts
- Minimal cross-module assumptions
- Documented dependencies

### Common Modules

#### VPC (networking/vpc)
- **Source:** terraform-aws-modules/vpc/aws
- **Inputs:** CIDR, AZs, public/private subnet config
- **Outputs:** vpc_id, subnet_ids, nat_gateway_ids
- **Constraints:** CIDR must not overlap with other environments

#### RDS (data-stores/rds)
- **Source:** terraform-aws-modules/rds/aws
- **Inputs:** Engine, instance class, multi-AZ setting
- **Outputs:** rds_endpoint, security_group_id
- **Dependencies:** VPC (for security group)
- **Constraints:** Multi-AZ required for prod

#### ECS Cluster (services/ecs-cluster)
- **Source:** terraform-aws-modules/ecs/aws
- **Inputs:** Cluster name, instance count, logging config
- **Outputs:** cluster_id, cluster_arn
- **Dependencies:** VPC, IAM roles
- **Constraints:** Container Insights required for prod

## Terraform Best Practices

### Resource Naming
```hcl
# DON'T: generic names
resource "aws_instance" "web" {}

# DO: descriptive, context-aware
resource "aws_instance" "web_server" {}

# DO: include environment/service context in tags
tags = {
  Name        = "uat-web-server-01"
  Environment = local.environment
  Service     = "web"
}
```

### State Management
- State is stored remotely (S3 + DynamoDB)
- Never commit .tfstate files
- Use state locking to prevent concurrent modifications
- Regular backups of state files (automated via S3 versioning)

### Variable Defaults
- Avoid magic strings
- Define sensible defaults at module level
- Allow environment-specific overrides
- Document assumptions

```hcl
variable "instance_size" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.micro"
}
```

## CI/CD Standards

### Terragrunt Commands

**For Planning:**
```bash
terragrunt plan --terragrunt-non-interactive
```

**For Applying:**
```bash
terragrunt apply --terragrunt-non-interactive --auto-approve
```

**For Deployment:**
```bash
terragrunt run-all apply --terragrunt-non-interactive
# Respects dependencies automatically
```

### GitHub Actions Integration (Planned)
- PR triggers `terragrunt plan` on affected modules
- Plan output posted as PR comment
- Merge triggers `terragrunt apply` with approval

## Documentation Standards

### Code Comments
- Explain "why", not "what"
- Document non-obvious choices
- Link to external resources when relevant

```hcl
# Enable deletion protection for UAT to prevent accidental destruction
enable_deletion_protection = true

# Single AZ for cost optimization; production uses multi-AZ for HA
enable_multi_az = false
```

### Module Documentation
Include in each module's terragrunt.hcl or adjacent README:
- Purpose and use case
- Input variables and constraints
- Output values and their uses
- Dependencies on other modules
- Example usage for this environment

### Changelog
Update when deploying to production:
- Date and version
- Changes applied
- Breaking changes (if any)
- Rollback procedure

## Validation & Testing

### Pre-commit Validation
```bash
terragrunt validate      # Syntax validation
terraform plan           # Dry-run execution
```

### Environment-Specific Validation
- Dev: Manual testing allowed
- Staging: Full test suite required
- UAT: Full test suite + user validation
- Prod: Full test suite + peer review

### Testing Commands
```bash
# Validate single module
cd environments/dev/us-east-1/networking/vpc
terragrunt plan

# Validate entire environment
terragrunt run-all plan --terragrunt-non-interactive
```

## Security Standards

### Secrets Management
- Never commit secrets (.env files, credentials)
- Use AWS Secrets Manager for sensitive data
- Rotate credentials every 90 days
- Audit secret access logs

### Access Control
- Deletion protection enabled for non-dev environments
- IAM policies follow least-privilege principle
- VPC security groups explicitly allow/deny traffic
- Encryption enabled for data at rest and in transit

### Compliance
- VPC Flow Logs enabled for prod
- CloudTrail logs enabled for audit trail
- Regular security scanning of infrastructure
- Compliance validation before prod deployments

## Maintenance Procedures

### Regular Tasks
- **Monthly:** Validate backup & restore procedures
- **Quarterly:** Review and update module versions
- **Annually:** Security audit and compliance check

### Adding New Modules
1. Create common config: `_envcommon/{category}/{module}.hcl`
2. Create environment deployment: `environments/{env}/{region}/{category}/{module}/terragrunt.hcl`
3. Document in `docs/system-architecture.md`
4. Test in dev environment first
5. Promote to staging, then UAT, then prod

### Updating Existing Modules
1. Create branch for changes
2. Update `_envcommon/{category}/{module}.hcl`
3. Test in dev with `terragrunt plan`
4. Review plan output for unexpected changes
5. Apply changes with approval
6. Update documentation and changelog

## Common Patterns

### Using Outputs from One Module in Another
```hcl
# In services/ecs-cluster/terragrunt.hcl
dependency "vpc" {
  config_path = "../../networking/vpc"
  skip_outputs = false
}

inputs = {
  vpc_id = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_subnet_ids
}
```

### Conditional Resource Creation
```hcl
# In env.hcl
locals {
  enable_deletion_protection = local.environment == "prod" ? true : false
}

# In resource terragrunt.hcl
inputs = {
  deletion_protection = local.enable_deletion_protection
}
```

### Cross-Environment References
```hcl
# Reference another environment (use with caution)
dependency "dev_vpc" {
  config_path = "../../../../dev/us-east-1/networking/vpc"
}
```

## Troubleshooting Guide

| Issue | Cause | Solution |
|---|---|---|
| Backend config changed | Backend config mismatch | `terragrunt init -reconfigure` |
| State lock error | Another process has lock | `terragrunt force-unlock <LOCK_ID>` |
| Module not found | Path incorrect | Verify `config_path` in dependencies |
| Caching issues | Stale Terragrunt cache | `make clean` or `rm -rf .terragrunt-cache` |
| Variable undefined | Missing include or locals | Check include paths and local definitions |
