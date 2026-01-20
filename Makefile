# =============================================================================
# TERRAGRUNT MAKEFILE
# Common commands for managing infrastructure
# =============================================================================

.PHONY: help init plan apply destroy fmt validate clean graph \
        plan-all apply-all destroy-all init-all output \
        bootstrap bootstrap-migrate bootstrap-verify bootstrap-all \
        scaffold-region list-modules update-modules add-module show-regions

# Default environment and region
ENV ?= dev
REGION ?= us-east-1
TARGET ?= 

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help
	@echo "$(GREEN)Terragrunt Infrastructure Management$(NC)"
	@echo ""
	@echo "Usage: make <target> [ENV=dev|staging|prod] [REGION=us-east-1|eu-west-1] [TARGET=path]"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make plan ENV=prod REGION=us-east-1"
	@echo "  make apply TARGET=dev/us-east-1/networking/vpc"
	@echo "  make destroy ENV=dev"

# =============================================================================
# SINGLE MODULE COMMANDS
# =============================================================================

init: ## Initialize a specific module (TARGET required)
ifndef TARGET
	$(error TARGET is required. Example: make init TARGET=dev/us-east-1/networking/vpc)
endif
	@echo "$(GREEN)Initializing $(TARGET)...$(NC)"
	cd $(TARGET) && terragrunt init

plan: ## Plan changes for a specific module (TARGET required)
ifndef TARGET
	$(error TARGET is required. Example: make plan TARGET=dev/us-east-1/networking/vpc)
endif
	@echo "$(GREEN)Planning $(TARGET)...$(NC)"
	cd $(TARGET) && terragrunt plan

apply: ## Apply changes for a specific module (TARGET required)
ifndef TARGET
	$(error TARGET is required. Example: make apply TARGET=dev/us-east-1/networking/vpc)
endif
	@echo "$(YELLOW)Applying $(TARGET)...$(NC)"
	cd $(TARGET) && terragrunt apply

destroy: ## Destroy a specific module (TARGET required)
ifndef TARGET
	$(error TARGET is required. Example: make destroy TARGET=dev/us-east-1/networking/vpc)
endif
	@echo "$(RED)Destroying $(TARGET)...$(NC)"
	cd $(TARGET) && terragrunt destroy

# =============================================================================
# ENVIRONMENT-WIDE COMMANDS (run-all)
# =============================================================================

plan-all: ## Plan all modules in an environment
	@echo "$(GREEN)Planning all modules in $(ENV)/$(REGION)...$(NC)"
	cd $(ENV)/$(REGION) && terragrunt run-all plan

apply-all: ## Apply all modules in an environment (with dependency ordering)
	@echo "$(YELLOW)Applying all modules in $(ENV)/$(REGION)...$(NC)"
	cd $(ENV)/$(REGION) && terragrunt run-all apply

destroy-all: ## Destroy all modules in an environment (reverse dependency order)
	@echo "$(RED)Destroying all modules in $(ENV)/$(REGION)...$(NC)"
	cd $(ENV)/$(REGION) && terragrunt run-all destroy

init-all: ## Initialize all modules in an environment
	@echo "$(GREEN)Initializing all modules in $(ENV)/$(REGION)...$(NC)"
	cd $(ENV)/$(REGION) && terragrunt run-all init

# =============================================================================
# UTILITY COMMANDS
# =============================================================================

fmt: ## Format all Terragrunt/Terraform files
	@echo "$(GREEN)Formatting HCL files...$(NC)"
	terragrunt hclfmt
	terraform fmt -recursive

validate: ## Validate all configurations
	@echo "$(GREEN)Validating configurations...$(NC)"
	cd $(ENV)/$(REGION) && terragrunt run-all validate

clean: ## Clean all Terragrunt caches
	@echo "$(YELLOW)Cleaning Terragrunt caches...$(NC)"
	find . -type d -name ".terragrunt-cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@echo "$(GREEN)Clean complete!$(NC)"

graph: ## Generate dependency graph for an environment
	@echo "$(GREEN)Generating dependency graph for $(ENV)/$(REGION)...$(NC)"
	cd $(ENV)/$(REGION) && terragrunt graph-dependencies | dot -Tpng > graph.png
	@echo "Graph saved to $(ENV)/$(REGION)/graph.png"

output: ## Show outputs for a specific module (TARGET required)
ifndef TARGET
	$(error TARGET is required. Example: make output TARGET=dev/us-east-1/networking/vpc)
endif
	cd $(TARGET) && terragrunt output

# =============================================================================
# BOOTSTRAP COMMANDS
# =============================================================================

bootstrap: ## Bootstrap tfstate-backend for an environment (ENV required)
ifndef ENV
	$(error ENV is required. Example: make bootstrap ENV=dev)
endif
	@echo "$(GREEN)Bootstrapping $(ENV) tfstate-backend...$(NC)"
	./scripts/bootstrap-tfstate.sh $(ENV)

bootstrap-migrate: ## Migrate tfstate to S3 after bootstrap (ENV required)
ifndef ENV
	$(error ENV is required. Example: make bootstrap-migrate ENV=dev)
endif
	@echo "$(GREEN)Migrating $(ENV) state to S3...$(NC)"
	./scripts/bootstrap-tfstate.sh $(ENV) --migrate

bootstrap-verify: ## Verify bootstrap resources exist (ENV required)
ifndef ENV
	$(error ENV is required. Example: make bootstrap-verify ENV=dev)
endif
	@echo "$(GREEN)Verifying $(ENV) bootstrap resources...$(NC)"
	@ACCOUNT_NAME=$$(grep 'account_name' account.hcl | head -1 | sed 's/.*=.*"\([^"]*\)".*/\1/'); \
	if [ -z "$$ACCOUNT_NAME" ]; then echo "$(RED)ERROR: Could not parse account_name from account.hcl$(NC)"; exit 1; fi; \
	BUCKET_NAME="$${ACCOUNT_NAME}-$(ENV)-terraform-state"; \
	TABLE_NAME="$${ACCOUNT_NAME}-$(ENV)-terraform-state-lock"; \
	echo "Checking S3 bucket: $${BUCKET_NAME}"; \
	aws s3api head-bucket --bucket $${BUCKET_NAME} 2>/dev/null && echo "  $(GREEN)S3 bucket exists$(NC)" || echo "  $(RED)S3 bucket NOT found$(NC)"; \
	echo "Checking DynamoDB table: $${TABLE_NAME}"; \
	aws dynamodb describe-table --table-name $${TABLE_NAME} --query 'Table.TableStatus' --output text 2>/dev/null && echo "  $(GREEN)DynamoDB table exists$(NC)" || echo "  $(RED)DynamoDB table NOT found$(NC)"

bootstrap-all: ## Bootstrap all environments in order (dev -> uat -> prod)
	@echo "$(YELLOW)This will bootstrap ALL environments in order: dev -> uat -> prod$(NC)"
	@echo "$(YELLOW)Make sure to update account.hcl with your AWS Account ID first!$(NC)"
	@read -p "Continue? (yes/no): " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		for env in dev uat prod; do \
			echo ""; \
			echo "$(GREEN)=== Bootstrapping $$env ===$(NC)"; \
			./scripts/bootstrap-tfstate.sh $$env; \
			echo ""; \
			read -p "Continue to migrate $$env state? (yes/no): " migrate; \
			if [ "$$migrate" = "yes" ]; then \
				./scripts/bootstrap-tfstate.sh $$env --migrate; \
			fi; \
		done; \
	fi

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
ifeq ($(findstring terraform-aws-,$(MODULE)),)
	$(error MODULE must start with 'terraform-aws-'. Got: $(MODULE))
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
ifeq ($(findstring terraform-aws-,$(MODULE)),)
	$(error MODULE must start with 'terraform-aws-'. Got: $(MODULE))
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
	@# Note: Environment/region directory names are trusted (infra team controlled)
	@for env_dir in environments/*/; do \
		env=$$(basename "$$env_dir" | tr -cd '[:alnum:]-_'); \
		echo ""; \
		echo "  $(YELLOW)$$env:$(NC)"; \
		for region_dir in "$$env_dir"*/; do \
			if [ -f "$$region_dir/region.hcl" ]; then \
				region=$$(basename "$$region_dir" | tr -cd '[:alnum:]-_'); \
				cidr=$$(grep 'vpc_cidr' "$$region_dir/region.hcl" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || echo "N/A"); \
				echo "    - $$region (CIDR: $$cidr)"; \
			fi; \
		done; \
	done
