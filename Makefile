# =============================================================================
# TERRAGRUNT MAKEFILE
# Common commands for managing infrastructure
# =============================================================================

.PHONY: help init plan apply destroy fmt validate clean graph

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
