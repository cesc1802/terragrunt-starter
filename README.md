# 🚀 Terragrunt Infrastructure Starter

A production-ready Terragrunt project structure for managing AWS infrastructure with DRY principles.

## 📁 Project Structure

```
.
├── root.hcl                    # Root config (backend, provider)
├── account.hcl                 # AWS account settings
├── Makefile                    # Common commands
│
├── _envcommon/                 # 📦 Shared module configurations
│   ├── bootstrap/
│   │   └── tfstate-backend.hcl
│   ├── networking/
│   │   └── vpc.hcl
│   ├── data-stores/
│   │   └── rds.hcl
│   ├── services/
│   │   └── ecs-cluster.hcl
│   ├── storage/
│   │   └── s3.hcl
│   └── security/
│       └── iam-roles.hcl
│
├── environments/               # Environment configurations
│   ├── dev/                    # 🔧 Development environment
│   │   ├── env.hcl
│   │   └── us-east-1/
│   │       ├── region.hcl
│   │       ├── networking/vpc/
│   │       ├── data-stores/rds/
│   │       └── services/ecs-cluster/
│   │
│   ├── staging/                # 🧪 Staging environment
│   │   └── ...
│   │
│   ├── uat/                    # ✔️ UAT environment (NEW)
│   │   ├── env.hcl
│   │   └── us-east-1/
│   │       ├── region.hcl
│   │       └── (to be added)
│   │
│   └── prod/                   # 🏭 Production environment
│       ├── us-east-1/          # Primary region
│       └── eu-west-1/          # Secondary region (DR)
```

## 🏗️ Architecture Principles

### DRY Hierarchy

```
Root (root.hcl)
    ↓ provides: backend config, provider generation
Environment (env.hcl)
    ↓ provides: environment name, sizing defaults
Region (region.hcl)
    ↓ provides: AWS region, availability zones
_envcommon/*.hcl
    ↓ provides: module source, common inputs
Resource (terragrunt.hcl)
    → final deployment unit with overrides
```

### Configuration Inheritance

Each level only defines what's **different** from its parent:

- **Root**: Backend, provider, global tags
- **Environment**: Environment name, cost settings, HA settings
- **Region**: AWS region, AZs, region-specific AMIs
- **_envcommon**: Module source, sensible defaults
- **Resource**: Environment-specific overrides only

## 🚦 Getting Started

### Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.5.0
- [Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) >= 0.50.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- Make (optional, for Makefile commands)

### Step 1: Configure Account Settings

Edit `account.hcl` with your AWS account details:

```hcl
locals {
  account_name   = "mycompany"        # Your project/company name
  aws_account_id = "123456789012"     # Your AWS Account ID
}
```

### Step 2: Scaffold Region Configuration

Create directory structure and configuration for a new region:

```bash
# Scaffold new region in dev environment (interactive prompts)
./scripts/scaffold-region.sh dev

# Scaffold in staging or prod environment
./scripts/scaffold-region.sh staging
./scripts/scaffold-region.sh prod
```

The script will prompt for:
- AWS region (us-east-1, eu-west-1, etc.)
- VPC CIDR block with overlap detection
- Availability zones
- Module selection (RDS, ECS, S3, IAM)

This creates:
- `region.hcl` with region-specific variables
- Directory structure for all infrastructure modules
- Terragrunt configurations with proper dependencies

### Step 3: Bootstrap State Backend

Create S3 bucket and DynamoDB table using Terragrunt bootstrap module:

```bash
# Navigate to bootstrap module
cd environments/dev/us-east-1/bootstrap/tfstate-backend

# Run terraform apply (uses local state initially)
terragrunt apply

# After success, uncomment "root" include in terragrunt.hcl, then migrate:
terragrunt init -migrate-state
```

This creates per-environment state backends:
- Bucket: `{account_name}-{environment}-terraform-state`
- DynamoDB: `{account_name}-{environment}-terraform-state`

### Step 4: Deploy Infrastructure

```bash
# Plan a specific module
make plan TARGET=dev/us-east-1/networking/vpc

# Apply a specific module
make apply TARGET=dev/us-east-1/networking/vpc

# Deploy entire environment (respects dependencies)
make apply-all ENV=dev REGION=us-east-1
```

## 📋 Common Commands

| Command | Description |
|---------|-------------|
| `make help` | Show all available commands |
| `make plan TARGET=<path>` | Plan a specific module |
| `make apply TARGET=<path>` | Apply a specific module |
| `make destroy TARGET=<path>` | Destroy a specific module |
| `make plan-all ENV=<env>` | Plan all modules in environment |
| `make apply-all ENV=<env>` | Apply all (with dependency order) |
| `make clean` | Remove all Terragrunt caches |
| `make graph ENV=<env>` | Generate dependency graph |

## 🔗 Dependencies

Terragrunt automatically handles cross-module dependencies:

```hcl
# In services/ecs-cluster/terragrunt.hcl
dependency "vpc" {
  config_path = "../../networking/vpc"
}

inputs = {
  vpc_id = dependency.vpc.outputs.vpc_id
}
```

When running `terragrunt run-all apply`, modules are deployed in correct order.

## 🌍 Multi-Region Setup

Production is configured for multi-region:

```
prod/
├── us-east-1/          # Primary (10.30.0.0/16)
│   ├── networking/vpc/
│   └── ...
└── eu-west-1/          # Secondary (10.40.0.0/16)
    ├── networking/vpc/
    └── ...
```

CIDR ranges are non-overlapping to allow VPC peering if needed.

## 🔒 Security Best Practices

- ✅ State files encrypted in S3 (SSE-S3)
- ✅ State locking with DynamoDB
- ✅ Deletion protection enabled for prod
- ✅ VPC Flow Logs enabled for prod
- ✅ Multi-AZ enabled for prod databases
- ✅ Default tags applied to all resources

## 📦 Adding New Modules

### 1. Create common configuration

```bash
# _envcommon/services/my-service.hcl
terraform {
  source = "tfr:///terraform-aws-modules/..."
}

inputs = {
  # Common defaults
}
```

### 2. Create environment deployment

```bash
mkdir -p dev/us-east-1/services/my-service
```

```hcl
# dev/us-east-1/services/my-service/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders())}/_envcommon/services/my-service.hcl"
}

inputs = {
  # Environment overrides
}
```

## 🔄 CI/CD Integration

See `.github/workflows/` for GitHub Actions examples (TODO).

Basic workflow:
1. PR triggers `terragrunt plan` on affected modules
2. Plan output posted as PR comment
3. Merge triggers `terragrunt apply`

## 📊 Cost Optimization

| Feature | Dev | Staging | Prod |
|---------|-----|---------|------|
| NAT Gateway | Single | Single | Per-AZ |
| RDS Multi-AZ | No | No | Yes |
| RDS Instance | t3.micro | t3.small | r6g.large |
| Container Insights | Off | Off | On |
| VPC Flow Logs | Off | Off | On |

## 🆘 Troubleshooting

### "Backend configuration changed"

```bash
cd <module-path>
terragrunt init -reconfigure
```

### "State lock"

```bash
# Force unlock (use carefully!)
terragrunt force-unlock <LOCK_ID>
```

### Clear all caches

```bash
make clean
```

## 📚 Documentation & Resources

### Project Documentation
- [Project Overview & PDR](./docs/project-overview-pdr.md) - Scope, requirements, roadmap
- [Code Standards](./docs/code-standards.md) - Coding conventions, best practices
- [System Architecture](./docs/system-architecture.md) - Architecture overview, deployment patterns
- [Codebase Summary](./docs/codebase-summary.md) - Directory structure, modules, configuration

### External Resources
- [Terragrunt Documentation](https://terragrunt.gruntwork.io/docs/)
- [Terraform AWS Modules](https://registry.terraform.io/namespaces/terraform-aws-modules)
- [Gruntwork Reference Architecture](https://gruntwork.io/reference-architecture/)

## 📝 License

MIT License - feel free to use this as a starting point for your infrastructure.
