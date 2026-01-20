# Phase 03: Create Scaffold Script

## Context

Create `scripts/scaffold-region.sh` to automate region setup with interactive prompts. Follow patterns from existing `scripts/bootstrap-tfstate.sh`.

## Overview

Script collects configuration via prompts, validates inputs, and generates:
- `region.hcl` with CIDR, AZs
- Directory structure for all modules
- `terragrunt.hcl` files referencing `_envcommon`

## Requirements

- [ ] Interactive prompts for region configuration
- [ ] CIDR and region validation
- [ ] Template generation using heredocs
- [ ] Error handling with cleanup on failure
- [ ] POSIX-compatible bash (works on Linux/macOS)

## Implementation Steps

### Step 1: Create scripts/scaffold-region.sh

```bash
#!/bin/bash
# =============================================================================
# REGION SCAFFOLD SCRIPT
# Creates directory structure and configuration for a new region.
#
# Usage:
#   ./scripts/scaffold-region.sh <environment>
#
# Examples:
#   ./scripts/scaffold-region.sh dev
#   ./scripts/scaffold-region.sh staging
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# =============================================================================
# Helper Functions
# =============================================================================

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    cat << EOF
Usage: $(basename "$0") <environment>

Arguments:
  environment     Environment to scaffold region in (dev|staging|prod)

Examples:
  $(basename "$0") dev        # Scaffold new region in dev environment
  $(basename "$0") staging    # Scaffold new region in staging environment
EOF
    exit 1
}

validate_region() {
    local region="$1"
    local valid_regions="us-east-1 us-east-2 us-west-1 us-west-2 eu-west-1 eu-west-2 eu-central-1 ap-southeast-1 ap-northeast-1"
    if echo "$valid_regions" | grep -qw "$region"; then
        return 0
    else
        log_error "Invalid region: $region"
        log_error "Valid regions: $valid_regions"
        return 1
    fi
}

validate_cidr() {
    local cidr="$1"
    # Basic CIDR format validation
    if echo "$cidr" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$'; then
        local prefix="${cidr#*/}"
        if [ "$prefix" -ge 16 ] && [ "$prefix" -le 24 ]; then
            return 0
        else
            log_error "CIDR prefix must be /16 to /24"
            return 1
        fi
    else
        log_error "Invalid CIDR format. Expected: X.X.X.X/Y"
        return 1
    fi
}

check_cidr_conflict() {
    local new_cidr="$1"
    local env="$2"
    local env_dir="$PROJECT_ROOT/environments/$env"

    # Extract existing CIDRs from region.hcl files
    for region_file in "$env_dir"/*/region.hcl; do
        if [ -f "$region_file" ]; then
            local existing_cidr
            existing_cidr=$(grep 'vpc_cidr' "$region_file" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || true)
            if [ -n "$existing_cidr" ] && [ "$existing_cidr" = "$new_cidr" ]; then
                log_error "CIDR $new_cidr already used in $(dirname "$region_file")"
                return 1
            fi
        fi
    done
    return 0
}

# =============================================================================
# Input Collection
# =============================================================================

collect_inputs() {
    local env="$1"

    echo ""
    log_info "Collecting configuration for new region in $env environment"
    echo ""

    # Region
    while true; do
        read -p "AWS Region (e.g., us-west-1): " AWS_REGION
        if validate_region "$AWS_REGION"; then
            break
        fi
    done

    # Check if region already exists
    local region_dir="$PROJECT_ROOT/environments/$env/$AWS_REGION"
    if [ -d "$region_dir" ]; then
        log_error "Region $AWS_REGION already exists in $env"
        exit 1
    fi

    # VPC CIDR
    while true; do
        read -p "VPC CIDR (e.g., 10.11.0.0/16): " VPC_CIDR
        if validate_cidr "$VPC_CIDR" && check_cidr_conflict "$VPC_CIDR" "$env"; then
            break
        fi
    done

    # Availability Zones
    local default_azs="${AWS_REGION}a,${AWS_REGION}b"
    read -p "Availability Zones (default: $default_azs): " input_azs
    AZS="${input_azs:-$default_azs}"

    # NAT Gateway
    read -p "Enable NAT Gateway? (y/n, default: n): " enable_nat
    ENABLE_NAT="${enable_nat:-n}"

    # RDS
    read -p "Include RDS module? (y/n, default: y): " include_rds
    INCLUDE_RDS="${include_rds:-y}"

    # ECS
    read -p "Include ECS cluster? (y/n, default: y): " include_ecs
    INCLUDE_ECS="${include_ecs:-y}"

    # S3
    read -p "Include S3 bucket? (y/n, default: y): " include_s3
    INCLUDE_S3="${include_s3:-y}"

    # IAM
    read -p "Include IAM roles? (y/n, default: y): " include_iam
    INCLUDE_IAM="${include_iam:-y}"

    # Confirm
    echo ""
    echo "=============================================="
    echo "  Configuration Summary"
    echo "=============================================="
    echo "  Environment:  $env"
    echo "  Region:       $AWS_REGION"
    echo "  VPC CIDR:     $VPC_CIDR"
    echo "  AZs:          $AZS"
    echo "  NAT Gateway:  $ENABLE_NAT"
    echo "  RDS:          $INCLUDE_RDS"
    echo "  ECS:          $INCLUDE_ECS"
    echo "  S3:           $INCLUDE_S3"
    echo "  IAM:          $INCLUDE_IAM"
    echo "=============================================="
    echo ""

    read -p "Proceed with scaffold? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_warn "Aborted by user"
        exit 0
    fi
}

# =============================================================================
# File Generation
# =============================================================================

create_region_hcl() {
    local region_dir="$1"
    local az_array
    IFS=',' read -ra az_array <<< "$AZS"
    local az_list=""
    for az in "${az_array[@]}"; do
        az_list="${az_list}\"${az}\", "
    done
    az_list="${az_list%, }"

    cat > "$region_dir/region.hcl" << EOF
# ---------------------------------------------------------------------------------------------------------------------
# REGION-LEVEL VARIABLES - ${AWS_REGION^^}
# These variables apply to all resources in this region.
# ---------------------------------------------------------------------------------------------------------------------

locals {
  aws_region = "$AWS_REGION"
  azs        = [$az_list]

  # VPC CIDR for this region
  vpc_cidr = "$VPC_CIDR"
}
EOF
}

create_module_terragrunt() {
    local module_dir="$1"
    local envcommon_path="$2"
    local dependencies="$3"

    mkdir -p "$module_dir"

    local dep_block=""
    if [ -n "$dependencies" ]; then
        IFS=',' read -ra dep_array <<< "$dependencies"
        for dep in "${dep_array[@]}"; do
            dep_block="${dep_block}
dependency \"$dep\" {
  config_path = \"../../${dep//_/\/}\"
}
"
        done
    fi

    cat > "$module_dir/terragrunt.hcl" << EOF
# ---------------------------------------------------------------------------------------------------------------------
# Module: $(basename "$module_dir")
# Generated by scaffold-region.sh
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "\${dirname(find_in_parent_folders(\"root.hcl\"))}/_envcommon/${envcommon_path}"
  expose = true
}
${dep_block}
inputs = {
  # Environment-specific overrides (if any)
}
EOF
}

# =============================================================================
# Main Scaffold
# =============================================================================

scaffold_region() {
    local env="$1"
    local region_dir="$PROJECT_ROOT/environments/$env/$AWS_REGION"

    log_info "Creating directory structure..."

    # Create base directories
    mkdir -p "$region_dir/00-bootstrap/tfstate-backend"
    mkdir -p "$region_dir/01-infra/network/vpc"

    # Create region.hcl
    create_region_hcl "$region_dir"
    log_success "Created region.hcl"

    # Create bootstrap module
    create_module_terragrunt "$region_dir/00-bootstrap/tfstate-backend" "bootstrap/tfstate-backend.hcl" ""
    log_success "Created bootstrap/tfstate-backend"

    # Create VPC
    create_module_terragrunt "$region_dir/01-infra/network/vpc" "networking/vpc.hcl" ""
    log_success "Created network/vpc"

    # Create IAM (no dependencies)
    if [ "$INCLUDE_IAM" = "y" ]; then
        mkdir -p "$region_dir/01-infra/security/iam-roles"
        create_module_terragrunt "$region_dir/01-infra/security/iam-roles" "security/iam-roles.hcl" ""
        log_success "Created security/iam-roles"
    fi

    # Create S3 (no dependencies)
    if [ "$INCLUDE_S3" = "y" ]; then
        mkdir -p "$region_dir/01-infra/storage/s3"
        create_module_terragrunt "$region_dir/01-infra/storage/s3" "storage/s3.hcl" ""
        log_success "Created storage/s3"
    fi

    # Create RDS (depends on VPC)
    if [ "$INCLUDE_RDS" = "y" ]; then
        mkdir -p "$region_dir/01-infra/data-stores/rds"
        create_module_terragrunt "$region_dir/01-infra/data-stores/rds" "data-stores/rds.hcl" "network_vpc"
        log_success "Created data-stores/rds"
    fi

    # Create ECS (depends on VPC, IAM)
    if [ "$INCLUDE_ECS" = "y" ]; then
        mkdir -p "$region_dir/01-infra/services/ecs-cluster"
        local ecs_deps="network_vpc"
        if [ "$INCLUDE_IAM" = "y" ]; then
            ecs_deps="${ecs_deps},security_iam-roles"
        fi
        create_module_terragrunt "$region_dir/01-infra/services/ecs-cluster" "services/ecs-cluster.hcl" "$ecs_deps"
        log_success "Created services/ecs-cluster"
    fi

    echo ""
    log_success "Scaffold complete for $env/$AWS_REGION"
    echo ""
    log_info "Next steps:"
    echo "  1. Review generated files in environments/$env/$AWS_REGION/"
    echo "  2. Run: make bootstrap ENV=$env (if new environment)"
    echo "  3. Deploy VPC: make apply TARGET=environments/$env/$AWS_REGION/01-infra/network/vpc"
    echo "  4. Deploy other modules in dependency order"
}

# =============================================================================
# Main
# =============================================================================

main() {
    local env=""

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            dev|staging|prod)
                env="$1"
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "Unknown argument: $1"
                usage
                ;;
        esac
    done

    if [ -z "$env" ]; then
        log_error "Environment required"
        usage
    fi

    # Validate environment exists
    local env_dir="$PROJECT_ROOT/environments/$env"
    if [ ! -d "$env_dir" ]; then
        log_error "Environment '$env' not found at: $env_dir"
        exit 1
    fi

    echo ""
    echo "=============================================="
    echo "  Region Scaffold Tool"
    echo "  Environment: $env"
    echo "=============================================="

    collect_inputs "$env"
    scaffold_region "$env"
}

main "$@"
```

### Step 2: Make Script Executable

```bash
chmod +x scripts/scaffold-region.sh
```

### Step 3: Test Script

```bash
# Dry run with dev environment
./scripts/scaffold-region.sh dev

# Follow prompts:
# - Region: us-west-1
# - CIDR: 10.11.0.0/16
# - AZs: us-west-1a,us-west-1b
# - NAT: n
# - RDS: y
# - ECS: y
# - S3: y
# - IAM: y
```

## Success Criteria

- [ ] Script runs without errors
- [ ] Validates region against known AWS regions
- [ ] Validates CIDR format and prefix range
- [ ] Checks for CIDR conflicts with existing regions
- [ ] Generates correct directory structure
- [ ] Generates valid HCL files
- [ ] Shows clear next steps

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Invalid HCL syntax | Medium | Test generated files with terragrunt validate |
| Overwrite existing region | High | Check existence before scaffold |
| Incomplete dependency graph | Medium | Document dependencies in _envcommon |

## Verification Commands

```bash
# Verify script syntax
bash -n scripts/scaffold-region.sh

# Verify generated files
terragrunt hclfmt
cd environments/dev/us-west-1
terragrunt run-all validate
```
