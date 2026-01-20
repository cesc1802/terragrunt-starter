# Terraform AWS Module Vendoring Research

## 1. Vendoring Approaches

### Copy-Based (Current Approach)
Clone entire GitHub repo into `./modules/{module-name}`, commit as-is. **Advantage:** Full control, offline capability, complete auditability. **Disadvantage:** Git history bloat.

### Git Subtree
Add remote, use `git subtree add --prefix=modules/vpc https://github.com/terraform-aws-modules/terraform-aws-vpc.git v5.2.0 --squash`. Creates merge commits without full history. **Better for:** Large modules, clean git log.

### Git Submodules
`git submodule add` approach. **Use when:** Team familiar with submodules, need to track remote HEAD. **Gotcha:** `git clone --recursive` required, harder CI/CD integration.

## 2. Local Source Reference Syntax (Terragrunt)

**Correct pattern for vendored modules:**
```hcl
terraform {
  source = "${dirname(find_in_parent_folders())}/../modules/terraform-aws-vpc"
}
```

**Why double-slash matters:**
- Local paths: No double-slash (`source = "./modules/vpc"`)
- Git remote: Use double-slash (`git::https://github.com/.../modules//vpc`)
- Terragrunt downloads pre-slash content to temp folder for relative path resolution

**Path functions in Terragrunt:**
- `get_terragrunt_dir()` - Current .hcl file directory
- `dirname(find_in_parent_folders())` - Root directory location
- `path_relative_to_include()` - Path to included file

## 3. Version Pinning for Vendored Modules

### Git Tag Based
```bash
# Add module at specific tag
git subtree add --prefix=modules/vpc git@github.com:terraform-aws-modules/terraform-aws-vpc.git v5.31.0 --squash

# Update to newer tag
git fetch [remote-name] && git subtree pull --prefix=modules/vpc [remote] v5.32.0 --squash
```

### VERSION File Pattern (Recommended)
Create `modules/vpc/.terraform-version` containing:
```
version = "5.31.0"
source = "git@github.com:terraform-aws-modules/terraform-aws-vpc.git"
```

**In Terragrunt** - Pin at composition level only:
```hcl
terraform {
  source = "${dirname(find_in_parent_folders())}/../modules/terraform-aws-vpc"
  # Version locked via git tag/commit in repo
}
```

### Lock Strategy
- **Modules:** Constrain min versions (`>= 5.0`) for flexibility
- **Root/Composition:** Exact pin (`= 5.31.0`) in `versions.tf`
- **Providers:** Use ~> for patch flexibility (`~> 5.31`)

## 4. Safe Update Workflow

### Step 1: Assess Changes
```bash
cd modules/terraform-aws-vpc
git log v5.31.0..v5.32.0 --oneline
```

### Step 2: Test in Sandbox
```bash
# Create feature branch
git checkout -b chore/update-vpc-module-5.32

# Update module via subtree
git subtree pull --prefix=modules/terraform-aws-vpc [remote] v5.32.0 --squash

# Run tests
terragrunt plan -out=tfplan
```

### Step 3: Review & Merge
- Review plan output for unexpected changes
- Test in dev environment first
- Merge via PR after approval
- Tag commit for audit trail

### Step 4: Document
Add to CHANGELOG: "Updated terraform-aws-vpc from v5.31.0 to v5.32.0"

## 5. Critical Gotchas

### Path Resolution in CI/CD
Terragrunt executes in `.terragrunt-cache/` temp folder. Relative paths must account for this:
- **❌ Wrong:** `file("../../../data/config.txt")`
- **✅ Right:** `file("${path_relative_to_include()}/../../data/config.txt")`

### Module Wrapper Pattern
Your VPC module includes `./wrappers/` submodules. When vendoring:
```hcl
# In modules/vpc/wrappers/main.tf
module "vpc" {
  source = "../" # Points to root of vendored module
}
```
This works because Terragrunt downloads entire pre-slash path.

### git Shallow Clones Don't Work
```bash
# ❌ This breaks version resolution
git clone --depth 1 https://github.com/terraform-aws-modules/terraform-aws-vpc.git

# ✅ Use full clone for modules
git clone https://github.com/terraform-aws-modules/terraform-aws-vpc.git
```

### .git File in Subdirectories
When you have `modules/terraform-aws-vpc/.git` (as currently vendored), it's a git subtree marker. Don't remove it; it enables `git subtree pull` updates.

## 6. Recommended Setup for This Project

**Current state:** VPC module already vendored at `modules/terraform-aws-vpc/`

**Next steps:**
1. Document module versions in `modules/README.md`:
   ```markdown
   | Module | Version | Last Updated | Source |
   |--------|---------|--------------|--------|
   | terraform-aws-vpc | v5.x.x | YYYY-MM-DD | github.com/terraform-aws-modules |
   ```

2. Establish update SLA:
   - Security patches: Apply within 1 week
   - Minor versions: Review monthly
   - Major versions: Quarterly assessment

3. For RDS, ECS, S3, IAM modules: Follow same pattern:
   ```bash
   git subtree add --prefix=modules/terraform-aws-rds [remote] v6.x.x --squash
   ```

4. CI/CD integration: Add `terraform-docs` generation for each module

## 7. Multi-Module Management Script

Create `scripts/update-modules.sh`:
```bash
#!/bin/bash
MODULE=$1
VERSION=$2

echo "Updating $MODULE to $VERSION..."
git subtree pull --prefix=modules/$MODULE terraform-aws-modules-remote $VERSION --squash
git add modules/$MODULE
git commit -m "chore(modules): update $MODULE to $VERSION"
```

## Unresolved Questions
- Should submodules use SemVer or fixed commits?
- Automated dependency scanning for module updates?
- Override pattern for module inputs (wrapper vs direct)?

## Sources
- [Vendoring Terraform Modules With Git Subtree](https://blog.zacharyloeber.com/article/vendoring-terraform-modules-with-git-subtree/)
- [Terraform source for Modules from Git](https://www.devopsschool.com/blog/terraform-source-for-modules-from-git-all-patterns-examples/)
- [HashiCorp: Use modules in your configuration](https://developer.hashicorp.com/terraform/language/modules/configuration)
- [HashiCorp: Version Constraints](https://developer.hashicorp.com/terraform/language/expressions/version-constraints)
- [Terragrunt: Keep your Terraform code DRY](https://davidbegin.github.io/terragrunt/use_cases/keep-your-terraform-code-dry.html)
- [AWS Prescriptive Guidance: Terraform Code Base Structure](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/structure.html)
