# Research Report: Infrastructure Scaffold Scripts in Bash

**Date:** 2026-01-20 | **Research ID:** researcher-260120-1005

## Executive Summary

Infrastructure scaffold scripts automate repetitive setup of cloud environments. Key findings:
1. **Interactive Prompts:** Use `read -p`, `select` statements, and `while` loops with validation functions for robust UX
2. **Input Validation:** Combine regex patterns, external tools (ipcalc, AWS CLI), and clear error messages
3. **POSIX Compatibility:** Avoid bashisms (`[[ ]]`, arrays, process substitution), use POSIX-compliant alternatives
4. **Error Handling:** Implement `trap` handlers (EXIT, ERR, INT) with state tracking and phase-based rollbacks
5. **Template Generation:** Use heredocs for file generation; prefer POSIX tools over platform-specific utilities

**Key Recommendation:** Adopt phase-based deployments with state tracking for safe partial deployment recovery.

---

## 1. Interactive Prompt Patterns

### Basic Input with `read -p`
```bash
AWS_REGION=""
DEFAULT_AWS_REGION="us-east-1"

while ! validate_region "$AWS_REGION"; do
  read -p "Enter AWS Region (default: $DEFAULT_AWS_REGION): " input_region
  AWS_REGION="${input_region:-$DEFAULT_AWS_REGION}"
done
```

**Best practices:**
- Always wrap in validation loop
- Provide sensible defaults using `${var:-default}` syntax
- Display defaults in prompt text

### Menu Selection with `select`
```bash
select env_choice in "dev" "staging" "prod" "exit"; do
  case $env_choice in
    "dev"|"staging"|"prod")
      SELECTED_ENV="$env_choice"
      break
      ;;
    "exit")
      echo "Exiting."
      exit 0
      ;;
    *)
      echo "Invalid selection. Enter number 1-4."
      ;;
  esac
done
```

**Advantages:** Automatic numbering, prevents invalid input at source.

---

## 2. Input Validation

### CIDR Block Validation
```bash
validate_cidr() {
  local cidr_regex="^([0-9]{1,3}\.){3}[0-9]{1,3}\/([0-9]|[1-2][0-9]|3[0-2])$"
  if [[ "$1" =~ $cidr_regex ]]; then
    local prefix="${1#*/}"
    if [[ "$prefix" -ge 16 && "$prefix" -le 28 ]]; then
      return 0
    else
      echo "Error: CIDR prefix must be /16 to /28."
      return 1
    fi
  else
    echo "Error: Invalid format. Expected X.X.X.X/Y"
    return 1
  fi
}
```

**For production:** Use `ipcalc` tool if available: `ipcalc -cs "$1"`

### Availability Zone Validation
```bash
# Fetch available AZs from AWS CLI
AVAILABLE_AZS=$(aws ec2 describe-availability-zones \
  --region "$AWS_REGION" \
  --query 'AvailabilityZones[?State==`available`].ZoneName' \
  --output text)
read -r -a AZ_ARRAY <<< "$AVAILABLE_AZS"

# Validate user input against list
if [[ " ${AZ_ARRAY[*]} " =~ " ${user_input} " ]]; then
  # Valid AZ
fi
```

**Pattern:** Always validate against authoritative source (AWS API for regions/AZs).

---

## 3. Template File Generation

### Using Heredocs
```bash
TERRAGRUNT_HCL="environments/$SELECTED_ENV/region.hcl"
mkdir -p "$(dirname "$TERRAGRUNT_HCL")"

cat <<EOF > "$TERRAGRUNT_HCL"
locals {
  aws_region     = "$AWS_REGION"
  environment    = "$SELECTED_ENV"
}

inputs = {
  vpc_cidr_block = "$VPC_CIDR"
}
EOF
```

**Advantages:** Simple string interpolation, preserves formatting.

### Terraform `.tfvars` Generation
```bash
cat <<EOF > terraform.tfvars
aws_region            = "$AWS_REGION"
vpc_cidr_block        = "$VPC_CIDR"
availability_zones    = [$(printf '"%s",' "${SELECTED_AZS[@]}" | sed 's/,$//')]
EOF
```

**Note:** Array syntax requires careful escaping for HCL output.

---

## 4. Error Handling and Rollback

### Trap Handlers for Signal Management
```bash
cleanup() {
  echo "Cleanup: Removing temporary files..."
  rm -f /tmp/my_temp_file.txt
}

rollback() {
  echo "ERROR: Initiating rollback..."
  # Reverse operations in reverse creation order
}

trap cleanup EXIT    # Always run on exit
trap rollback ERR    # On command failure
trap rollback INT    # On Ctrl+C
```

### State Tracking Pattern
```bash
DEPLOYMENT_STATE_FILE=".deployment_state"
touch "$DEPLOYMENT_STATE_FILE"

# After completing Phase 1
echo "PHASE_1_COMPLETED" >> "$DEPLOYMENT_STATE_FILE"

# In rollback: check state before cleanup
if grep -q "PHASE_1_COMPLETED" "$DEPLOYMENT_STATE_FILE"; then
  echo "Rolling back Phase 1..."
  # Delete Phase 1 resources
fi
```

### Phase-Based Deployment
```bash
# Phase 1: Network
log_message "Phase 1: Network Infrastructure..."
if ! grep -q "PHASE_1_COMPLETED" "$DEPLOYMENT_STATE_FILE"; then
  # Deploy network (VPC, subnets, etc.)
  echo "PHASE_1_COMPLETED" >> "$DEPLOYMENT_STATE_FILE"
fi

# Phase 2: Application
log_message "Phase 2: Application Infrastructure..."
if ! grep -q "PHASE_2_COMPLETED" "$DEPLOYMENT_STATE_FILE"; then
  # Deploy application (ECS, RDS, etc.)
  echo "PHASE_2_COMPLETED" >> "$DEPLOYMENT_STATE_FILE"
fi
```

**Benefits:** Allows recovery from partial deployments, enables resumable deployments.

---

## 5. POSIX Compatibility Patterns

### Use `/bin/sh` Shebang
```bash
#!/bin/sh  # Instead of #!/bin/bash
```

### Replace Bashisms

| Bashism | POSIX Alternative |
|---------|-------------------|
| `[[ $VAR =~ regex ]]` | `echo "$VAR" \| grep -E "regex"` |
| `array=(a b c)` | Use space-separated string, process with `while read` |
| `<(cmd)` | Use temporary files: `cmd > /tmp/file; cat /tmp/file` |
| `function foo {}` | `foo() { ... }` |
| `echo -e` | `printf` |
| `local var` | All variables are local if assigned within function (be careful) |

### Portable String/Numeric Tests
```bash
# POSIX-compliant tests
[ -z "$VAR" ]           # Is variable empty?
[ "$VAR" = "value" ]    # String equality
[ "$NUM" -eq 10 ]       # Numeric equality
[ "$NUM" -gt 5 ]        # Numeric greater-than
[ -f "$FILE" ]          # File exists?
[ -d "$DIR" ]           # Directory exists?

# Logical operators (portable)
[ "$A" = "1" ] && [ "$B" = "2" ]    # AND
[ "$A" = "1" ] || [ "$B" = "2" ]    # OR
```

### Portable File Operations
```bash
# In-place sed editing (works on GNU/BSD)
TEMP_FILE=$(mktemp /tmp/sedtemp.XXXXXX) || exit 1
sed 's/old/new/g' "$FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$FILE"

# Instead of: sed -i 's/old/new/g' file.txt  # Inconsistent between GNU/BSD

# Portable find (avoid GNU-specific -maxdepth, -delete)
find . -name "*.tmp" -type f -print | while IFS= read -r file; do
  rm -f "$file"
done
```

### Variable Quoting
```bash
# Always quote variables
"$VAR"                          # Correct
"${VAR:-default_value}"         # Unset or null → default
"${VAR%suffix}"                 # Remove suffix (portable)
$VAR                            # WRONG: Subject to word splitting
```

---

## 6. Validation Best Practices

### Dependency Checking
```bash
check_dependencies() {
  local deps=("aws" "terraform" "terragrunt")
  for cmd in "${deps[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
      echo "Error: $cmd not found. Please install it."
      return 1
    fi
  done
}

check_dependencies || exit 1
```

**Note:** Use `command -v` instead of `which` for POSIX compatibility.

### AWS CLI Validation
```bash
validate_aws_config() {
  if ! aws sts get-caller-identity &> /dev/null; then
    echo "Error: AWS credentials not configured."
    return 1
  fi
}
```

---

## 7. User Experience Patterns

### Logging with Timestamps
```bash
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting deployment..."
```

### Confirmation Prompt
```bash
confirm() {
  local prompt="$1"
  read -p "$prompt (yes/no): " response
  [ "$response" = "yes" ]
}

if confirm "Deploy to production?"; then
  # Proceed
else
  echo "Cancelled."
  exit 0
fi
```

### Progress Indication
```bash
echo "Step 1 of 5: Validating inputs..."
echo "Step 2 of 5: Creating VPC..."
echo "Step 3 of 5: Creating subnets..."
```

---

## 8. Common Pitfalls and Solutions

| Pitfall | Solution |
|---------|----------|
| No input validation | Use loops with `validate_*` functions |
| Hardcoded paths | Use `command -v` and rely on PATH |
| Platform-specific commands | Detect OS; use portable alternatives |
| Missing cleanup on error | Use `trap` handlers |
| No state tracking | Create `.state` files for recovery |
| Bashisms in portable script | Use POSIX shell features only |
| Race conditions | Use `mktemp` for temp file creation |
| Unclear error messages | Always explain what failed and why |

---

## 9. Recommended Script Structure

```bash
#!/bin/sh
set -e  # Exit on error
set -u  # Unset variables are errors

# 1. Logging & Cleanup
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
cleanup() { log "Cleanup"; rm -f /tmp/scaffold_temp.txt; }
rollback() { log "Rollback"; /* reverse operations */; }

trap cleanup EXIT
trap rollback ERR

# 2. Dependency Check
check_dependencies() { /* ... */ }
check_dependencies || exit 1

# 3. Configuration Validation
validate_region() { /* ... */ }
validate_cidr() { /* ... */ }

# 4. User Input Collection
log "Collecting configuration..."
# ... read -p prompts, select statements

# 5. Phase 1: Network
log "Phase 1: Network Infrastructure..."
# ... deployment steps
echo "PHASE_1_COMPLETED" >> "$STATE_FILE"

# 6. Phase 2: Application
log "Phase 2: Application Infrastructure..."
# ... deployment steps
echo "PHASE_2_COMPLETED" >> "$STATE_FILE"

# 7. Success
log "Deployment complete."
rm -f "$STATE_FILE"
```

---

## 10. Testing Recommendations

1. **Test on multiple OSes:** Linux (glibc), macOS, Alpine (musl)
2. **Validate POSIX compliance:** Use `shellcheck -S warning -x script.sh`
3. **Test error paths:** Force failures to verify rollback logic
4. **Test idempotency:** Run script twice with same inputs
5. **Test interrupted deployments:** Use Ctrl+C to verify cleanup

---

## References

- POSIX Shell Command Language: https://pubs.opengroup.org/onlinepubs/9699919799/utilities/
- Bash Manual (for understanding bashisms): https://www.gnu.org/software/bash/manual/
- ShellCheck: Static analysis tool for shell scripts
- ipcalc: CIDR block validation utility

---

## Unresolved Questions

- Should scaffold scripts support --dry-run mode before actual deployment?
- How to handle AWS credential refresh during long deployments?
- Best approach for multi-region scaffolding (serial vs. parallel)?
