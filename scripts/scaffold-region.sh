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

# Global variables for collected inputs (set by collect_inputs, used by scaffold_region)
AWS_REGION=""
VPC_CIDR=""
AZS=""
ENABLE_NAT=""
INCLUDE_RDS=""
INCLUDE_ECS=""
INCLUDE_S3=""
INCLUDE_IAM=""
REGION_DIR=""

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

# Cleanup handler for failed scaffolds
cleanup_on_failure() {
    if [ -n "$REGION_DIR" ] && [ -d "$REGION_DIR" ]; then
        log_warn "Cleaning up incomplete scaffold at $REGION_DIR"
        rm -rf "$REGION_DIR"
    fi
}

validate_region() {
    local region="$1"
    # Common AWS regions - extend as needed
    local valid_regions="us-east-1 us-east-2 us-west-1 us-west-2 eu-west-1 eu-west-2 eu-west-3 eu-central-1 eu-north-1 ap-southeast-1 ap-southeast-2 ap-northeast-1 ap-northeast-2 ap-south-1 sa-east-1 ca-central-1"
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
    # Validate CIDR format
    if ! echo "$cidr" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$'; then
        log_error "Invalid CIDR format. Expected: X.X.X.X/Y"
        return 1
    fi

    # Validate each octet is 0-255
    local ip_part="${cidr%/*}"
    IFS='.' read -ra octets <<< "$ip_part"
    for octet in "${octets[@]}"; do
        if [ "$octet" -lt 0 ] || [ "$octet" -gt 255 ]; then
            log_error "Invalid IP octet: $octet (must be 0-255)"
            return 1
        fi
    done

    # Validate prefix length
    local prefix="${cidr#*/}"
    if [ "$prefix" -lt 16 ] || [ "$prefix" -gt 24 ]; then
        log_error "CIDR prefix must be /16 to /24"
        return 1
    fi

    return 0
}

# Convert IP to integer for CIDR overlap comparison
ip_to_int() {
    local ip="$1"
    local a b c d
    IFS='.' read -r a b c d <<< "$ip"
    echo $(( (a << 24) + (b << 16) + (c << 8) + d ))
}

# Check if two CIDR ranges overlap
cidrs_overlap() {
    local cidr1="$1"
    local cidr2="$2"

    local ip1="${cidr1%/*}"
    local prefix1="${cidr1#*/}"
    local ip2="${cidr2%/*}"
    local prefix2="${cidr2#*/}"

    local int1 int2
    int1=$(ip_to_int "$ip1")
    int2=$(ip_to_int "$ip2")

    # Calculate network masks
    local mask1=$(( 0xFFFFFFFF << (32 - prefix1) & 0xFFFFFFFF ))
    local mask2=$(( 0xFFFFFFFF << (32 - prefix2) & 0xFFFFFFFF ))

    # Get network addresses
    local net1=$(( int1 & mask1 ))
    local net2=$(( int2 & mask2 ))

    # Use the smaller prefix (larger network) as the common mask
    local common_mask
    if [ "$prefix1" -le "$prefix2" ]; then
        common_mask=$mask1
    else
        common_mask=$mask2
    fi

    # Networks overlap if they share the same network address when masked
    # with the larger network's (smaller prefix) mask
    if [ $(( net1 & common_mask )) -eq $(( net2 & common_mask )) ]; then
        return 0  # Overlap detected
    fi
    return 1  # No overlap
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
            if [ -n "$existing_cidr" ]; then
                # Check exact match
                if [ "$existing_cidr" = "$new_cidr" ]; then
                    log_error "CIDR $new_cidr already used in $(dirname "$region_file")"
                    return 1
                fi
                # Check CIDR overlap using proper network math
                if cidrs_overlap "$new_cidr" "$existing_cidr"; then
                    log_warn "CIDR $new_cidr overlaps with $existing_cidr in $(dirname "$region_file")"
                    read -p "Continue anyway? (y/n): " continue_overlap
                    if [ "$continue_overlap" != "y" ]; then
                        return 1
                    fi
                fi
            fi
        fi
    done
    return 0
}

# Sanitize input - remove special characters
sanitize_input() {
    local input="$1"
    # Remove leading/trailing whitespace, replace special chars
    echo "$input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -cd '[:alnum:].,_-/'
}

# Validate availability zones format
validate_azs() {
    local azs="$1"
    local region="$2"

    # Check if empty
    if [ -z "$azs" ]; then
        log_error "Availability zones cannot be empty"
        return 1
    fi

    # Validate each AZ follows pattern: region + letter (a-z)
    IFS=',' read -ra az_array <<< "$azs"
    for az in "${az_array[@]}"; do
        # AZ must start with region name and end with a single letter
        if ! echo "$az" | grep -qE "^${region}[a-z]$"; then
            log_error "Invalid AZ format: $az (expected: ${region}[a-z])"
            return 1
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
        read -p "AWS Region (e.g., us-west-1): " input_region
        AWS_REGION=$(sanitize_input "$input_region")
        if validate_region "$AWS_REGION"; then
            break
        fi
    done

    # Check if region already exists
    REGION_DIR="$PROJECT_ROOT/environments/$env/$AWS_REGION"
    if [ -d "$REGION_DIR" ]; then
        log_error "Region $AWS_REGION already exists in $env"
        exit 1
    fi

    # VPC CIDR
    while true; do
        read -p "VPC CIDR (e.g., 10.11.0.0/16): " input_cidr
        VPC_CIDR=$(sanitize_input "$input_cidr")
        if validate_cidr "$VPC_CIDR" && check_cidr_conflict "$VPC_CIDR" "$env"; then
            break
        fi
    done

    # Availability Zones
    local default_azs="${AWS_REGION}a,${AWS_REGION}b"
    while true; do
        read -p "Availability Zones (default: $default_azs): " input_azs
        AZS=$(sanitize_input "${input_azs:-$default_azs}")
        if validate_azs "$AZS" "$AWS_REGION"; then
            break
        fi
    done

    # NAT Gateway (collected for future use / summary display)
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
    echo "  NAT Gateway:  $ENABLE_NAT (configure in _envcommon/networking/vpc.hcl)"
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

    local region_upper
    region_upper=$(echo "$AWS_REGION" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

    cat > "$region_dir/region.hcl" << EOF
# ---------------------------------------------------------------------------------------------------------------------
# REGION-LEVEL VARIABLES - ${region_upper}
# These variables apply to all resources in this region.
# ---------------------------------------------------------------------------------------------------------------------

locals {
  aws_region = "$AWS_REGION"

  # Availability zones for this region
  azs = [$az_list]

  # VPC CIDR for this region (moved from env.hcl for region-specific allocation)
  vpc_cidr = "$VPC_CIDR"

  # Region-specific settings (optional)
  # ami_id = "ami-xxxxxxxxx"  # Region-specific AMI if needed
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
            # Dependencies use :: as separator (e.g., network::vpc -> network/vpc)
            # This avoids conflicts with module names containing underscores/hyphens
            local dep_path
            dep_path=$(echo "$dep" | tr ':' '/')
            # Clean up double slashes from :: conversion
            dep_path=$(echo "$dep_path" | sed 's|//|/|g')
            dep_block="${dep_block}
dependency \"$(echo "$dep" | tr ':' '_')\" {
  config_path = \"../../${dep_path}\"
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

    # Set trap for cleanup on failure
    trap cleanup_on_failure EXIT

    log_info "Creating directory structure..."

    # Create base directories
    mkdir -p "$REGION_DIR/00-bootstrap/tfstate-backend"
    mkdir -p "$REGION_DIR/01-infra/network/vpc"
    mkdir -p "$REGION_DIR/02-compute"

    # Create region.hcl
    create_region_hcl "$REGION_DIR"
    log_success "Created region.hcl"

    # Create bootstrap module
    create_module_terragrunt "$REGION_DIR/00-bootstrap/tfstate-backend" "bootstrap/tfstate-backend.hcl" ""
    log_success "Created 00-bootstrap/tfstate-backend"

    # Create VPC
    create_module_terragrunt "$REGION_DIR/01-infra/network/vpc" "networking/vpc.hcl" ""
    log_success "Created 01-infra/network/vpc"

    # Create IAM (no dependencies)
    if [ "$INCLUDE_IAM" = "y" ]; then
        mkdir -p "$REGION_DIR/01-infra/security/iam-roles"
        create_module_terragrunt "$REGION_DIR/01-infra/security/iam-roles" "security/iam-roles.hcl" ""
        log_success "Created 01-infra/security/iam-roles"
    fi

    # Create S3 (no dependencies)
    if [ "$INCLUDE_S3" = "y" ]; then
        mkdir -p "$REGION_DIR/01-infra/storage/s3"
        create_module_terragrunt "$REGION_DIR/01-infra/storage/s3" "storage/s3.hcl" ""
        log_success "Created 01-infra/storage/s3"
    fi

    # Create RDS (depends on VPC) - in 02-compute layer
    if [ "$INCLUDE_RDS" = "y" ]; then
        mkdir -p "$REGION_DIR/02-compute/rds"
        create_module_terragrunt "$REGION_DIR/02-compute/rds" "compute/rds.hcl" "01-infra::network::vpc"
        log_success "Created 02-compute/rds"
    fi

    # Create ECS (depends on VPC, IAM) - in 02-compute layer
    if [ "$INCLUDE_ECS" = "y" ]; then
        mkdir -p "$REGION_DIR/02-compute/ecs-cluster"
        local ecs_deps="01-infra::network::vpc"
        if [ "$INCLUDE_IAM" = "y" ]; then
            ecs_deps="${ecs_deps},01-infra::security::iam-roles"
        fi
        create_module_terragrunt "$REGION_DIR/02-compute/ecs-cluster" "compute/ecs-cluster.hcl" "$ecs_deps"
        log_success "Created 02-compute/ecs-cluster"
    fi

    # Clear trap on success
    trap - EXIT

    echo ""
    log_success "Scaffold complete for $env/$AWS_REGION"
    echo ""
    log_info "Next steps:"
    echo "  1. Review generated files in environments/$env/$AWS_REGION/"
    echo "  2. Bootstrap state (if needed): Update bootstrap-tfstate.sh for this region"
    echo "  3. Deploy 01-infra: make apply TARGET=environments/$env/$AWS_REGION/01-infra/network/vpc"
    echo "  4. Deploy 02-compute: make apply TARGET=environments/$env/$AWS_REGION/02-compute/rds"
    echo "  5. Deploy other modules in dependency order"
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
