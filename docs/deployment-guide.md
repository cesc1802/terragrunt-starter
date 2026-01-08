# Deployment Guide

## Overview

This guide documents the deployment procedures for bootstrapping and deploying infrastructure using Terragrunt. Covers prerequisite validation, state backend setup, and environment-specific deployment order.

**Last Updated:** 2026-01-08

## Prerequisites

Verify these are installed and configured before deployment:

### Required Tools
- **Terraform** >= 1.5.0: Infrastructure as Code
- **Terragrunt** >= 0.50.0: Configuration management layer
- **AWS CLI**: AWS credentials and account access
- **Make** (optional): Makefile command shortcuts
- **Git**: Version control

### AWS Account Setup

1. Edit `account.hcl` with your AWS account details:
```hcl
locals {
  account_name   = "mycompany"        # Your project name
  aws_account_id = "123456789012"     # Your AWS Account ID
}
```

2. Configure AWS credentials:
```bash
aws configure
# or use environment variables:
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
```

3. Verify credentials:
```bash
aws sts get-caller-identity
# Output should show your Account ID and User ARN
```

## Bootstrap Procedure

### Purpose

Bootstrap creates the S3 bucket and DynamoDB table needed for Terraform state management. Each environment gets isolated state:
- **S3 Bucket:** `{account_name}-{environment}-terraform-state`
- **DynamoDB Table:** `{account_name}-{environment}-terraform-state` (locking)

### Bootstrap Phases

#### Phase 1: Validate Prerequisites

The bootstrap script automatically validates:
- AWS credentials configured and valid
- Terraform installed and version >= 1.5.0
- Terragrunt installed and version >= 0.50.0

Run validation manually:
```bash
# Check AWS credentials
aws sts get-caller-identity

# Check Terraform
terraform version

# Check Terragrunt
terragrunt --version
```

#### Phase 2: Create Bootstrap Infrastructure

Bootstrap with local state first:
```bash
# Bootstrap dev environment
make bootstrap ENV=dev

# or directly run the script:
./scripts/bootstrap-tfstate.sh dev
```

This creates:
- S3 bucket with versioning and encryption
- DynamoDB table for state locking
- Proper tagging for cost allocation
- Resources remain with local state temporarily

**Output Example:**
```
[SUCCESS] AWS credentials valid (Account: 123456789012)
[INFO] Checking prerequisites...
[INFO] Terraform version: 1.6.0
[INFO] Terragrunt version: 0.55.0
[SUCCESS] All prerequisites satisfied
[INFO] Bootstrapping dev environment...
[SUCCESS] Bootstrap complete: dev-us-east-1
```

#### Phase 3: Migrate State to S3

After bootstrap creates resources, migrate local state to S3:
```bash
# Migrate dev state
make bootstrap-migrate ENV=dev

# or directly:
./scripts/bootstrap-tfstate.sh dev --migrate
```

Terraform will prompt:
```
Do you want to copy existing state to the new backend?
Enter a value: yes
```

**After migration:**
- Local state files removed
- State now stored in S3
- DynamoDB table prevents concurrent modifications

### Deployment Order

**IMPORTANT:** Bootstrap environments in this order:
1. **dev** - Validate bootstrap procedure first
2. **uat** - Medium-tier environment
3. **prod** - Production (both us-east-1 and eu-west-1)

Never bootstrap prod first. If dev bootstrap fails, all subsequent deployments are blocked.

### Bootstrap All Environments (Automated)

To bootstrap all environments with interactive confirmations:
```bash
make bootstrap-all
```

This will:
1. Bootstrap dev → ask for state migration confirmation
2. Bootstrap uat → ask for state migration confirmation
3. Bootstrap prod → ask for state migration confirmation

Stops if any step fails.

## Verification & Troubleshooting

### Verify Bootstrap Resources

After bootstrap and migration, verify resources exist:
```bash
# Verify dev bootstrap
make bootstrap-verify ENV=dev

# Expected output:
# Checking S3 bucket: mycompany-dev-terraform-state
#   [SUCCESS] S3 bucket exists
# Checking DynamoDB table: mycompany-dev-terraform-state
#   [SUCCESS] DynamoDB table exists
```

### Verify AWS Resources Directly

```bash
# List S3 buckets
aws s3 ls | grep terraform-state

# Check DynamoDB tables
aws dynamodb list-tables --query 'TableNames[?contains(@, `terraform-state`)]'

# List state file versions
aws s3api list-object-versions --bucket mycompany-dev-terraform-state
```

### Common Issues & Solutions

| Issue | Symptom | Solution |
|-------|---------|----------|
| AWS credentials not configured | `ERROR: AWS credentials not configured` | Run `aws configure` and verify with `aws sts get-caller-identity` |
| Terraform not installed | `ERROR: Terraform not found` | Install from https://terraform.io/downloads |
| Terragrunt not installed | `ERROR: Terragrunt not found` | Install from https://terragrunt.gruntwork.io/docs/getting-started/install/ |
| Bootstrap bucket already exists | `ERROR: bucket already owned by you` | Resource already bootstrapped, proceed to migration |
| State migration fails | Stuck at "Do you want to copy" prompt | Ensure DynamoDB table created successfully first |
| State lock stuck | `Error: Error acquiring the state lock` | Run `terragrunt force-unlock <LOCK_ID>` (use carefully!) |

### Debug Bootstrap Process

Enable verbose logging:
```bash
# With Terragrunt debug output
TG_LOG=debug ./scripts/bootstrap-tfstate.sh dev

# With Terraform debug
TF_LOG=debug ./scripts/bootstrap-tfstate.sh dev
```

Check script output in stages:
```bash
# Run bootstrap script with shell tracing
bash -x ./scripts/bootstrap-tfstate.sh dev 2>&1 | tee bootstrap.log
```

## Infrastructure Deployment

### Single Module Deployment

Deploy one module at a time:
```bash
# Plan specific module
make plan TARGET=dev/us-east-1/networking/vpc

# Review plan output

# Apply specific module
make apply TARGET=dev/us-east-1/networking/vpc
```

### Environment-Wide Deployment

Deploy entire environment respecting dependencies:
```bash
# Plan all modules in environment
make plan-all ENV=dev REGION=us-east-1

# Review all plan outputs

# Apply all modules (dependency order automatic)
make apply-all ENV=dev REGION=us-east-1
```

Terragrunt automatically:
1. Resolves module dependencies
2. Deploys in correct order
3. Waits for each module completion
4. Rolls back on failure

### Deployment Order per Module

Modules deployed in this automatic order:

**1. Networking (VPC)**
   - Foundation: VPC, subnets, NAT gateways, route tables
   - Location: `{env}/us-east-1/networking/vpc`

**2. Data Stores (RDS)**
   - Dependencies: VPC (for security groups)
   - Location: `{env}/us-east-1/data-stores/rds`

**3. Services (ECS Cluster)**
   - Dependencies: VPC, IAM roles
   - Location: `{env}/us-east-1/services/ecs-cluster`

## Makefile Commands Reference

### Bootstrap Commands
```bash
make bootstrap ENV=dev              # Bootstrap state backend (local state)
make bootstrap-migrate ENV=dev      # Migrate state to S3 after bootstrap
make bootstrap-verify ENV=dev       # Verify bootstrap resources exist
make bootstrap-all                  # Bootstrap all environments (interactive)
```

### Planning & Applying
```bash
make plan TARGET=dev/us-east-1/networking/vpc       # Plan single module
make apply TARGET=dev/us-east-1/networking/vpc      # Apply single module
make plan-all ENV=dev REGION=us-east-1              # Plan all in environment
make apply-all ENV=dev REGION=us-east-1             # Apply all in environment
```

### Utility Commands
```bash
make init TARGET=dev/us-east-1/networking/vpc       # Initialize module
make destroy TARGET=dev/us-east-1/networking/vpc    # Destroy module
make clean                          # Clear Terragrunt caches
make fmt                            # Format HCL files
make validate ENV=dev               # Validate configurations
make graph ENV=dev                  # Generate dependency graph
make output TARGET=dev/us-east-1/vpc  # Show module outputs
make help                           # Show all commands
```

## State Management

### Remote State Architecture

State is managed via:
- **Storage:** S3 bucket `{account_name}-{environment}-terraform-state`
- **Locking:** DynamoDB table `{account_name}-{environment}-terraform-state`
- **Encryption:** SSE-S3 at rest
- **Versioning:** Enabled (rollback capability)

### State File Operations

```bash
# View current state
terragrunt state list

# Show resource in state
cd dev/us-east-1/networking/vpc && terragrunt state show aws_vpc.this

# Export state (careful!)
terragrunt state pull > state.json

# Import existing resource into state
terragrunt import aws_vpc.this vpc-1234567890abcdef0
```

### Backup & Restore

**S3 versioning provides automatic backups:**
```bash
# List state file versions
aws s3api list-object-versions --bucket mycompany-dev-terraform-state

# Restore previous state version
aws s3api get-object --bucket mycompany-dev-terraform-state \
  --key env:/mycompany/dev/us-east-1/terraform.tfstate \
  --version-id <VERSION_ID> state.json
```

## Environment Progression

### Development → UAT → Production Path

**1. Dev Environment (Validation)**
```bash
# Bootstrap dev and test bootstrap procedure
make bootstrap ENV=dev
make bootstrap-migrate ENV=dev
make bootstrap-verify ENV=dev

# Deploy infrastructure to dev
make apply-all ENV=dev REGION=us-east-1

# Validate all components work
# - VPC created and accessible
# - RDS database running
# - ECS cluster operational
```

**2. UAT Environment (Acceptance Testing)**
```bash
# Bootstrap uat (after dev validated)
make bootstrap ENV=uat
make bootstrap-migrate ENV=uat
make bootstrap-verify ENV=uat

# Deploy UAT infrastructure
make apply-all ENV=uat REGION=us-east-1

# Run acceptance tests
# - Database connectivity verified
# - Container deployments tested
# - Multi-AZ behavior (not enabled in uat)
```

**3. Production Environment (Careful Deployment)**
```bash
# Bootstrap prod (multi-region)
make bootstrap ENV=prod
make bootstrap-migrate ENV=prod
make bootstrap-verify ENV=prod

# Deploy prod primary region
make apply-all ENV=prod REGION=us-east-1

# Verify primary region
# - Multi-AZ RDS running
# - NAT gateways per AZ
# - Container Insights enabled

# Deploy prod secondary region (if needed)
make apply-all ENV=prod REGION=eu-west-1

# Validate multi-region
# - VPC peering configured (if needed)
# - Failover procedures tested
```

## Monitoring Deployments

### Real-Time Logs

Watch Terragrunt output during deployment:
```bash
# See all operations in real-time
make apply-all ENV=dev REGION=us-east-1 2>&1 | tee deployment.log

# Follow logs after deployment
tail -f deployment.log
```

### Dependency Graph

Visualize deployment dependencies:
```bash
# Generate dependency graph PNG
make graph ENV=dev

# View at: dev/us-east-1/graph.png
```

### Cleanup & Rollback

**Destroy infrastructure (in reverse order):**
```bash
# Destroy single module
make destroy TARGET=dev/us-east-1/services/ecs-cluster

# Destroy entire environment (automatic reverse order)
make destroy-all ENV=dev REGION=us-east-1
```

**Preserve state backend when destroying environment:**
```bash
# Bootstrap resources are preserved
# Only application infrastructure destroyed
# State stored in S3 remains for recovery
```

## CI/CD Integration (Future)

Future GitHub Actions workflows will automate:
- PR: Run `terragrunt plan` on affected modules
- PR: Post plan output as PR comment for review
- Merge to main: Run `terragrunt apply` on approved modules
- Scheduled: Run compliance checks and cost analysis

See `.github/workflows/` for implementation details (TODO).

## Best Practices

1. **Bootstrap in Order:** Always dev → uat → prod
2. **Plan Before Apply:** Always review `terragrunt plan` output
3. **Backup Before Destroy:** Export state before destroying resources
4. **Test in Dev First:** Validate changes in dev before uat/prod
5. **Document Changes:** Update relevant docs after deployments
6. **Monitor Costs:** Check AWS Cost Explorer after major deployments
7. **Lock Deletion:** Deletion protection enabled for UAT/Prod
8. **Version Management:** Keep Terraform/Terragrunt versions aligned

## Support & Resources

- **Terragrunt Docs:** https://terragrunt.gruntwork.io/docs/
- **Terraform Docs:** https://www.terraform.io/docs
- **AWS CLI Reference:** https://docs.aws.amazon.com/cli/
- **Project Docs:** See `./docs/` directory
- **Bootstrap Script:** `./scripts/bootstrap-tfstate.sh --help`

## Troubleshooting Checklist

- [ ] AWS credentials valid: `aws sts get-caller-identity`
- [ ] account.hcl configured with correct AWS Account ID
- [ ] Terraform/Terragrunt versions meet minimum requirements
- [ ] Dev bootstrap completed and state migrated
- [ ] Dev infrastructure deploys successfully
- [ ] UAT bootstrap completed after dev validation
- [ ] State locks not stuck: Check DynamoDB for stale entries
- [ ] Network connectivity to AWS verified (VPN, firewall)
- [ ] CloudTrail enabled for audit logging
- [ ] Cost alerts configured in AWS Billing

