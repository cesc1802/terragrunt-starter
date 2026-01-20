#!/bin/bash
# =============================================================================
# TERRAFORM STATE BACKEND BOOTSTRAP SCRIPT
# Creates S3 bucket and DynamoDB table for each environment using Terragrunt.
#
# Usage:
#   ./scripts/bootstrap-tfstate.sh <environment> [--migrate]
#
# Examples:
#   ./scripts/bootstrap-tfstate.sh dev          # Bootstrap dev (local state)
#   ./scripts/bootstrap-tfstate.sh dev --migrate # Migrate dev state to S3
#   ./scripts/bootstrap-tfstate.sh uat
#   ./scripts/bootstrap-tfstate.sh prod
#
# Bootstrap Order: dev -> uat -> prod (validate in dev first!)
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# =============================================================================
# Helper Functions
# =============================================================================

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Parse account_name from account.hcl (DRY helper)
get_account_name() {
    grep 'account_name' "$PROJECT_ROOT/account.hcl" | head -1 | sed 's/.*=.*"\([^"]*\)".*/\1/'
}

# Validate environment exists
validate_environment() {
    local env="$1"
    local env_dir="$PROJECT_ROOT/environments/$env"
    if [[ ! -d "$env_dir" ]]; then
        log_error "Environment '$env' not found at: $env_dir"
        log_error "Valid environments: dev, uat, prod"
        exit 1
    fi
}

usage() {
    cat << EOF
Usage: $(basename "$0") <environment> [--migrate]

Arguments:
  environment     Environment to bootstrap (dev|uat|prod)
  --migrate       Migrate local state to S3 (run after initial bootstrap)

Examples:
  $(basename "$0") dev              # Initial bootstrap with local state
  $(basename "$0") dev --migrate    # Migrate dev state to S3
  $(basename "$0") uat
  $(basename "$0") prod

Bootstrap Order: dev -> uat -> prod
EOF
    exit 1
}

verify_aws_credentials() {
    log_info "Verifying AWS credentials..."
    if ! aws sts get-caller-identity &>/dev/null; then
        log_error "AWS credentials not configured. Please run: aws configure"
        exit 1
    fi
    local account_id
    account_id=$(aws sts get-caller-identity --query Account --output text)
    log_success "AWS credentials valid (Account: $account_id)"
}

verify_prerequisites() {
    log_info "Checking prerequisites..."

    # Check Terraform
    if ! command -v terraform &>/dev/null; then
        log_error "Terraform not found. Install from: https://terraform.io/downloads"
        exit 1
    fi
    local tf_version
    tf_version=$(terraform version -json | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4)
    log_info "Terraform version: $tf_version"

    # Check Terragrunt
    if ! command -v terragrunt &>/dev/null; then
        log_error "Terragrunt not found. Install from: https://terragrunt.gruntwork.io/docs/getting-started/install/"
        exit 1
    fi
    local tg_version
    tg_version=$(terragrunt --version | head -1 | awk '{print $NF}')
    log_info "Terragrunt version: $tg_version"

    log_success "Prerequisites verified"
}

verify_account_config() {
    local account_file="$PROJECT_ROOT/account.hcl"
    if [[ ! -f "$account_file" ]]; then
        log_error "account.hcl not found at $account_file"
        exit 1
    fi

    # Extract account_name using DRY helper
    local account_name
    account_name=$(get_account_name)

    if [[ -z "$account_name" ]]; then
        log_error "Could not parse account_name from account.hcl"
        exit 1
    fi

    if [[ "$account_name" == "mycompany" ]]; then
        log_warn "account.hcl still has default value 'mycompany'"
        log_warn "Update account_name in account.hcl before proceeding to prod"
    fi

    log_info "Using account_name: $account_name"
}

# =============================================================================
# Bootstrap Functions
# =============================================================================

bootstrap_environment() {
    local env="$1"
    local region="us-east-1"
    local bootstrap_dir="$PROJECT_ROOT/environments/$env/$region/bootstrap/tfstate-backend"

    if [[ ! -d "$bootstrap_dir" ]]; then
        log_error "Bootstrap directory not found: $bootstrap_dir"
        log_error "Run Phase 03 first to create environment deployments"
        exit 1
    fi

    log_info "Bootstrapping $env environment..."
    log_info "Directory: $bootstrap_dir"

    cd "$bootstrap_dir"

    # Initialize
    log_info "Running terragrunt init..."
    terragrunt init

    # Plan
    log_info "Running terragrunt plan..."
    terragrunt plan -out=tfplan

    # Confirm before apply
    echo ""
    log_warn "Review the plan above before proceeding."
    read -p "Do you want to apply this plan? (yes/no): " confirm

    if [[ "$confirm" != "yes" ]]; then
        log_warn "Aborted by user"
        rm -f tfplan
        exit 0
    fi

    # Apply
    log_info "Running terragrunt apply..."
    terragrunt apply tfplan
    rm -f tfplan

    # Show outputs
    echo ""
    log_success "Bootstrap complete! Outputs:"
    terragrunt output

    echo ""
    log_info "Next steps:"
    echo "  1. Verify resources created in AWS console"
    echo "  2. Run: $(basename "$0") $env --migrate"
}

migrate_state() {
    local env="$1"
    local region="us-east-1"
    local bootstrap_dir="$PROJECT_ROOT/environments/$env/$region/bootstrap/tfstate-backend"
    local terragrunt_file="$bootstrap_dir/terragrunt.hcl"

    if [[ ! -f "$terragrunt_file" ]]; then
        log_error "terragrunt.hcl not found: $terragrunt_file"
        exit 1
    fi

    # Check if local state exists
    if [[ ! -f "$bootstrap_dir/terraform.tfstate" ]]; then
        log_error "No local state file found. Run bootstrap first (without --migrate)"
        exit 1
    fi

    log_info "Migrating $env state to S3..."

    # Backup local state with timestamp to prevent collision
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="$bootstrap_dir/terraform.tfstate.pre-migration-${timestamp}.backup"
    cp "$bootstrap_dir/terraform.tfstate" "$backup_file"
    log_success "Backed up local state to: $backup_file"

    cd "$bootstrap_dir"

    # Show current state
    log_info "Current terragrunt.hcl configuration:"
    echo ""
    echo "  The file will be modified to:"
    echo "  1. Uncomment 'include \"root\"' block"
    echo "  2. Remove 'generate \"backend\"' block"
    echo "  3. Remove 'generate \"provider\"' block"
    echo ""

    read -p "Proceed with migration? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        log_warn "Aborted by user"
        exit 0
    fi

    # Update terragrunt.hcl to use remote state
    log_info "Updating terragrunt.hcl for remote state..."
    update_terragrunt_for_remote "$terragrunt_file" "$env"

    # Run init with migrate-state
    log_info "Running terragrunt init -migrate-state..."
    echo ""
    echo "When prompted, type 'yes' to confirm migration."
    echo ""

    terragrunt init -migrate-state

    # Verify migration
    log_info "Verifying state migration..."
    terragrunt plan

    if terragrunt plan 2>&1 | grep -q "No changes"; then
        log_success "State migration verified - no changes detected"
    else
        log_warn "Plan shows changes - review carefully"
    fi

    # Cleanup
    echo ""
    read -p "Remove local state files? (yes/no): " cleanup
    if [[ "$cleanup" == "yes" ]]; then
        rm -f "$bootstrap_dir/terraform.tfstate" "$bootstrap_dir/terraform.tfstate.backup"
        log_success "Local state files removed"
        log_info "Backup preserved at: $backup_file"
    fi

    echo ""
    log_success "Migration complete for $env!"
}

update_terragrunt_for_remote() {
    local file="$1"
    local env="$2"
    local env_upper
    env_upper=$(echo "$env" | tr '[:lower:]' '[:upper:]')

    # Create post-bootstrap version directly with environment name
    cat > "$file" << EOF
# ---------------------------------------------------------------------------------------------------------------------
# TERRAFORM STATE BACKEND - ${env_upper} (POST-BOOTSTRAP)
# State is now stored in S3. Do not modify without extreme caution.
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path   = "\${dirname(find_in_parent_folders())}/_envcommon/bootstrap/tfstate-backend.hcl"
  expose = true
}

# No additional inputs needed - all defaults from envcommon
inputs = {}
EOF
}

# =============================================================================
# Main
# =============================================================================

main() {
    local env=""
    local migrate=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            dev|uat|prod)
                env="$1"
                shift
                ;;
            --migrate)
                migrate=true
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

    if [[ -z "$env" ]]; then
        log_error "Environment required"
        usage
    fi

    echo ""
    echo "=============================================="
    echo "  Terraform State Backend Bootstrap"
    echo "  Environment: $env"
    echo "  Mode: $(if $migrate; then echo "MIGRATE"; else echo "BOOTSTRAP"; fi)"
    echo "=============================================="
    echo ""

    # Validate environment exists first
    validate_environment "$env"

    # Verify prerequisites
    # verify_prerequisites
    # verify_aws_credentials
    # verify_account_config


    # Execute
    if $migrate; then
        migrate_state "$env"
    else
        bootstrap_environment "$env"
    fi
}

main "$@"
