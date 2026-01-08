# Phase 03: Environment Deployments

## Context Links
- Parent: [plan.md](./plan.md)
- Dependency: Phase 02 (envcommon configuration)
- Reference: `environments/dev/us-east-1/networking/vpc/terragrunt.hcl`

## Overview
- **Priority**: P2
- **Status**: Completed
- **Description**: Create environment-specific terragrunt.hcl files for dev, uat, and prod

## Key Insights

### Bootstrap Pattern
These files are different from normal Terragrunt deployments:
1. **Cannot include root terragrunt.hcl initially** - root config references the S3 backend that doesn't exist yet
2. Must generate local backend for first run
3. After S3/DynamoDB created, modify to use remote state

### Directory Structure
```
environments/{env}/us-east-1/bootstrap/tfstate-backend/
└── terragrunt.hcl
```

### Environment-Specific Overrides
- **dev**: `force_destroy = true`, `deletion_protection_enabled = false`
- **uat**: `force_destroy = false`, `deletion_protection_enabled = true`
- **prod**: `force_destroy = false`, `deletion_protection_enabled = true`

## Requirements
- Create bootstrap module directories for each environment
- Create terragrunt.hcl with local backend (initial bootstrap)
- Include envcommon configuration
- Provide post-bootstrap migration instructions

## Related Code Files

| Action | File | Description |
|--------|------|-------------|
| Create | `environments/dev/us-east-1/bootstrap/tfstate-backend/terragrunt.hcl` | Dev state backend |
| Create | `environments/uat/us-east-1/bootstrap/tfstate-backend/terragrunt.hcl` | UAT state backend |
| Create | `environments/prod/us-east-1/bootstrap/tfstate-backend/terragrunt.hcl` | Prod state backend |

## Implementation Steps

### Step 1: Create directories

```bash
mkdir -p environments/dev/us-east-1/bootstrap/tfstate-backend
mkdir -p environments/uat/us-east-1/bootstrap/tfstate-backend
mkdir -p environments/prod/us-east-1/bootstrap/tfstate-backend
```

### Step 2: Create Dev terragrunt.hcl

```hcl
# environments/dev/us-east-1/bootstrap/tfstate-backend/terragrunt.hcl
# ---------------------------------------------------------------------------------------------------------------------
# TERRAFORM STATE BACKEND - DEV
# BOOTSTRAP MODULE: Creates S3 bucket and DynamoDB table for Terraform state storage.
#
# BOOTSTRAP PROCEDURE:
# 1. First run: terragrunt apply (uses local state)
# 2. After success: uncomment "root" include, run terragrunt init -migrate-state
# ---------------------------------------------------------------------------------------------------------------------

# UNCOMMENT AFTER BOOTSTRAP IS COMPLETE:
# include "root" {
#   path = find_in_parent_folders()
# }

# Include common tfstate-backend configuration
include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/bootstrap/tfstate-backend.hcl"
  expose = true
}

# Generate local backend for bootstrap (remove after migration)
generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
EOF
}

# Generate provider (since we can't include root during bootstrap)
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Environment = "dev"
      ManagedBy   = "Terragrunt"
      Component   = "bootstrap"
    }
  }
}
EOF
}

# Dev-specific overrides (if any needed beyond envcommon defaults)
inputs = {
  # Dev can have force_destroy for easy cleanup (already set in envcommon)
  # Add any dev-specific overrides here
}
```

### Step 3: Create UAT terragrunt.hcl

```hcl
# environments/uat/us-east-1/bootstrap/tfstate-backend/terragrunt.hcl
# ---------------------------------------------------------------------------------------------------------------------
# TERRAFORM STATE BACKEND - UAT
# BOOTSTRAP MODULE: Creates S3 bucket and DynamoDB table for Terraform state storage.
#
# BOOTSTRAP PROCEDURE:
# 1. First run: terragrunt apply (uses local state)
# 2. After success: uncomment "root" include, run terragrunt init -migrate-state
# ---------------------------------------------------------------------------------------------------------------------

# UNCOMMENT AFTER BOOTSTRAP IS COMPLETE:
# include "root" {
#   path = find_in_parent_folders()
# }

# Include common tfstate-backend configuration
include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/bootstrap/tfstate-backend.hcl"
  expose = true
}

# Generate local backend for bootstrap (remove after migration)
generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
EOF
}

# Generate provider (since we can't include root during bootstrap)
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Environment = "uat"
      ManagedBy   = "Terragrunt"
      Component   = "bootstrap"
    }
  }
}
EOF
}

# UAT-specific overrides
inputs = {
  # UAT has deletion protection enabled (set in envcommon via env.hcl)
}
```

### Step 4: Create Prod terragrunt.hcl

```hcl
# environments/prod/us-east-1/bootstrap/tfstate-backend/terragrunt.hcl
# ---------------------------------------------------------------------------------------------------------------------
# TERRAFORM STATE BACKEND - PROD
# BOOTSTRAP MODULE: Creates S3 bucket and DynamoDB table for Terraform state storage.
#
# BOOTSTRAP PROCEDURE:
# 1. First run: terragrunt apply (uses local state)
# 2. After success: uncomment "root" include, run terragrunt init -migrate-state
# ---------------------------------------------------------------------------------------------------------------------

# UNCOMMENT AFTER BOOTSTRAP IS COMPLETE:
# include "root" {
#   path = find_in_parent_folders()
# }

# Include common tfstate-backend configuration
include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/bootstrap/tfstate-backend.hcl"
  expose = true
}

# Generate local backend for bootstrap (remove after migration)
generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
EOF
}

# Generate provider (since we can't include root during bootstrap)
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Environment = "prod"
      ManagedBy   = "Terragrunt"
      Component   = "bootstrap"
    }
  }
}
EOF
}

# Prod-specific overrides
inputs = {
  # Prod has maximum protection (set in envcommon via env.hcl)
  # DynamoDB point-in-time recovery enabled
  # Deletion protection enabled
}
```

## Todo List
- [x] Create dev bootstrap directory
- [x] Create dev terragrunt.hcl
- [x] Create uat bootstrap directory
- [x] Create uat terragrunt.hcl
- [x] Create prod bootstrap directory
- [x] Create prod terragrunt.hcl
- [x] Verify HCL syntax with `terragrunt hclfmt`

## Success Criteria
- All three environment files created
- Files follow bootstrap pattern (local backend initially)
- HCL syntax valid
- Clear instructions for post-bootstrap migration

## Risk Assessment
- **Medium**: Bootstrap pattern requires manual steps
- **Mitigation**: Clear documentation and comments in files

## Security Considerations
- Provider credentials must be configured before running
- Prod should be bootstrapped with extra care
- Consider running dev first to validate the process

## Next Steps
- Proceed to Phase 04 (Bootstrap & Migration guide)
