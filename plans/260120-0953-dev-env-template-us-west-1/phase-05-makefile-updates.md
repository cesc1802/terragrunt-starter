# Phase 05: Makefile Updates

## Context

Add new Makefile targets for scaffold script and module updates. Follow existing Makefile patterns.

## Overview

New targets:
- `scaffold-region`: Run scaffold script for new region
- `update-modules`: Update vendored modules to new versions
- `list-modules`: Show vendored modules and versions

## Requirements

- [ ] Add scaffold-region target
- [ ] Add update-modules target
- [ ] Add list-modules target
- [ ] Update help section
- [ ] Test all new targets

## Implementation Steps

### Step 1: Add New Targets to Makefile

Append to existing Makefile after `# BOOTSTRAP COMMANDS` section:

```makefile
# =============================================================================
# SCAFFOLD COMMANDS
# =============================================================================

scaffold-region: ## Scaffold new region in an environment (ENV required)
ifndef ENV
	$(error ENV is required. Example: make scaffold-region ENV=dev)
endif
	@echo "$(GREEN)Scaffolding new region in $(ENV)...$(NC)"
	./scripts/scaffold-region.sh $(ENV)

# =============================================================================
# MODULE MANAGEMENT COMMANDS
# =============================================================================

list-modules: ## List vendored modules and versions
	@echo "$(GREEN)Vendored Terraform Modules:$(NC)"
	@echo ""
	@if [ -f modules/README.md ]; then \
		grep -A 100 '| Module |' modules/README.md | head -10; \
	else \
		echo "  modules/README.md not found"; \
		echo "  Listing module directories:"; \
		ls -d modules/*/ 2>/dev/null | sed 's/modules\//  - /' | sed 's/\///' || echo "  No modules found"; \
	fi

update-modules: ## Update vendored modules (MODULE and VERSION required)
ifndef MODULE
	$(error MODULE is required. Example: make update-modules MODULE=terraform-aws-vpc VERSION=5.18.0)
endif
ifndef VERSION
	$(error VERSION is required. Example: make update-modules MODULE=terraform-aws-vpc VERSION=5.18.0)
endif
	@echo "$(YELLOW)Updating $(MODULE) to $(VERSION)...$(NC)"
	@REMOTE_NAME="tf-$$(echo $(MODULE) | sed 's/terraform-aws-//')"; \
	if ! git remote | grep -q "$$REMOTE_NAME"; then \
		echo "$(RED)Remote $$REMOTE_NAME not found. Add it first:$(NC)"; \
		echo "  git remote add $$REMOTE_NAME https://github.com/terraform-aws-modules/$(MODULE).git"; \
		exit 1; \
	fi; \
	echo "$(GREEN)Fetching from $$REMOTE_NAME...$(NC)"; \
	git fetch $$REMOTE_NAME; \
	echo "$(GREEN)Pulling $(VERSION) into modules/$(MODULE)...$(NC)"; \
	git subtree pull --prefix=modules/$(MODULE) $$REMOTE_NAME $(VERSION) --squash; \
	echo "$(GREEN)Update complete! Don't forget to update modules/README.md$(NC)"

add-module: ## Add new vendored module (MODULE and VERSION required)
ifndef MODULE
	$(error MODULE is required. Example: make add-module MODULE=terraform-aws-rds VERSION=6.10.0)
endif
ifndef VERSION
	$(error VERSION is required. Example: make add-module MODULE=terraform-aws-rds VERSION=6.10.0)
endif
	@echo "$(GREEN)Adding $(MODULE) at $(VERSION)...$(NC)"
	@REMOTE_NAME="tf-$$(echo $(MODULE) | sed 's/terraform-aws-//')"; \
	if git remote | grep -q "$$REMOTE_NAME"; then \
		echo "Remote $$REMOTE_NAME already exists"; \
	else \
		echo "Adding remote $$REMOTE_NAME..."; \
		git remote add $$REMOTE_NAME https://github.com/terraform-aws-modules/$(MODULE).git; \
	fi; \
	git fetch $$REMOTE_NAME; \
	echo "$(GREEN)Adding subtree...$(NC)"; \
	git subtree add --prefix=modules/$(MODULE) $$REMOTE_NAME $(VERSION) --squash; \
	echo "$(GREEN)Module added! Update modules/README.md with version info$(NC)"

# =============================================================================
# DEVELOPMENT HELPERS
# =============================================================================

show-regions: ## Show all configured regions per environment
	@echo "$(GREEN)Configured Regions:$(NC)"
	@for env_dir in environments/*/; do \
		env=$$(basename $$env_dir); \
		echo ""; \
		echo "  $(YELLOW)$$env:$(NC)"; \
		for region_dir in $$env_dir*/; do \
			if [ -f "$$region_dir/region.hcl" ]; then \
				region=$$(basename $$region_dir); \
				cidr=$$(grep 'vpc_cidr' "$$region_dir/region.hcl" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || echo "N/A"); \
				echo "    - $$region (CIDR: $$cidr)"; \
			fi; \
		done; \
	done
```

### Step 2: Update .PHONY Declaration

Add new targets to `.PHONY` at top of Makefile:

```makefile
.PHONY: help init plan apply destroy fmt validate clean graph \
        plan-all apply-all destroy-all init-all output \
        bootstrap bootstrap-migrate bootstrap-verify bootstrap-all \
        scaffold-region list-modules update-modules add-module show-regions
```

### Step 3: Update Help Section

The help target auto-generates from `## ` comments, so no changes needed.

### Step 4: Full Updated Makefile Section

Insert after line 161 (after `bootstrap-all` target):

```makefile
# =============================================================================
# SCAFFOLD COMMANDS
# =============================================================================

scaffold-region: ## Scaffold new region in an environment (ENV required)
ifndef ENV
	$(error ENV is required. Example: make scaffold-region ENV=dev)
endif
	@echo "$(GREEN)Scaffolding new region in $(ENV)...$(NC)"
	./scripts/scaffold-region.sh $(ENV)

# =============================================================================
# MODULE MANAGEMENT COMMANDS
# =============================================================================

list-modules: ## List vendored modules and versions
	@echo "$(GREEN)Vendored Terraform Modules:$(NC)"
	@echo ""
	@if [ -f modules/README.md ]; then \
		grep -A 100 '| Module |' modules/README.md | head -10; \
	else \
		echo "  modules/README.md not found"; \
		echo "  Listing module directories:"; \
		ls -d modules/*/ 2>/dev/null | sed 's/modules\//  - /' | sed 's/\///' || echo "  No modules found"; \
	fi

update-modules: ## Update vendored modules (MODULE and VERSION required)
ifndef MODULE
	$(error MODULE is required. Example: make update-modules MODULE=terraform-aws-vpc VERSION=5.18.0)
endif
ifndef VERSION
	$(error VERSION is required. Example: make update-modules MODULE=terraform-aws-vpc VERSION=5.18.0)
endif
	@echo "$(YELLOW)Updating $(MODULE) to $(VERSION)...$(NC)"
	@REMOTE_NAME="tf-$$(echo $(MODULE) | sed 's/terraform-aws-//')"; \
	if ! git remote | grep -q "$$REMOTE_NAME"; then \
		echo "$(RED)Remote $$REMOTE_NAME not found. Add it first:$(NC)"; \
		echo "  git remote add $$REMOTE_NAME https://github.com/terraform-aws-modules/$(MODULE).git"; \
		exit 1; \
	fi; \
	git fetch $$REMOTE_NAME; \
	git subtree pull --prefix=modules/$(MODULE) $$REMOTE_NAME $(VERSION) --squash; \
	echo "$(GREEN)Update complete! Update modules/README.md$(NC)"

add-module: ## Add new vendored module (MODULE and VERSION required)
ifndef MODULE
	$(error MODULE is required. Example: make add-module MODULE=terraform-aws-rds VERSION=6.10.0)
endif
ifndef VERSION
	$(error VERSION is required. Example: make add-module MODULE=terraform-aws-rds VERSION=6.10.0)
endif
	@echo "$(GREEN)Adding $(MODULE) at $(VERSION)...$(NC)"
	@REMOTE_NAME="tf-$$(echo $(MODULE) | sed 's/terraform-aws-//')"; \
	if git remote | grep -q "$$REMOTE_NAME"; then \
		echo "Remote $$REMOTE_NAME already exists"; \
	else \
		git remote add $$REMOTE_NAME https://github.com/terraform-aws-modules/$(MODULE).git; \
	fi; \
	git fetch $$REMOTE_NAME; \
	git subtree add --prefix=modules/$(MODULE) $$REMOTE_NAME $(VERSION) --squash; \
	echo "$(GREEN)Module added! Update modules/README.md$(NC)"

# =============================================================================
# DEVELOPMENT HELPERS
# =============================================================================

show-regions: ## Show all configured regions per environment
	@echo "$(GREEN)Configured Regions:$(NC)"
	@for env_dir in environments/*/; do \
		env=$$(basename $$env_dir); \
		echo ""; \
		echo "  $(YELLOW)$$env:$(NC)"; \
		for region_dir in $$env_dir*/; do \
			if [ -f "$$region_dir/region.hcl" ]; then \
				region=$$(basename $$region_dir); \
				cidr=$$(grep 'vpc_cidr' "$$region_dir/region.hcl" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || echo "N/A"); \
				echo "    - $$region (CIDR: $$cidr)"; \
			fi; \
		done; \
	done
```

## Success Criteria

- [ ] `make help` shows new targets
- [ ] `make scaffold-region ENV=dev` runs scaffold script
- [ ] `make list-modules` shows vendored modules
- [ ] `make update-modules MODULE=x VERSION=y` updates module
- [ ] `make add-module MODULE=x VERSION=y` adds new module
- [ ] `make show-regions` displays all regions and CIDRs

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Git subtree conflicts | Medium | Use --squash flag |
| Missing remote | Low | Check and warn user |
| Makefile syntax error | Medium | Test incrementally |

## Verification Commands

```bash
# Test help
make help

# Test list-modules
make list-modules

# Test show-regions
make show-regions

# Test scaffold (will prompt interactively)
make scaffold-region ENV=dev

# Test update-modules (dry run first)
# Would require actual remote, skip for testing
```

## Usage Examples

```bash
# Scaffold new region
make scaffold-region ENV=dev
# Prompts for: region, CIDR, AZs, modules to include

# List current modules
make list-modules

# Update VPC module
make update-modules MODULE=terraform-aws-vpc VERSION=5.18.0

# Add new module
make add-module MODULE=terraform-aws-rds VERSION=6.10.0

# Show all regions
make show-regions
# Output:
#   dev:
#     - us-east-1 (CIDR: 10.10.0.0/16)
#     - us-west-1 (CIDR: 10.11.0.0/16)
```
