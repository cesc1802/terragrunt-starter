# Vendored Terraform Modules

This directory contains vendored Terraform modules managed via `git subtree`.

| Module | Version | Last Updated | Source |
|--------|---------|--------------|--------|
| terraform-aws-vpc | 5.17.0 | 2026-01-02 | github.com/terraform-aws-modules |
| terraform-aws-tfstate-backend | 1.5.0 | 2025-12-31 | github.com/cloudposse |
| terraform-aws-rds | 6.13.1 | 2026-01-20 | github.com/terraform-aws-modules |
| terraform-aws-ecs | 5.12.1 | 2026-01-20 | github.com/terraform-aws-modules |
| terraform-aws-s3-bucket | 4.11.0 | 2026-01-20 | github.com/terraform-aws-modules |
| terraform-aws-iam | 5.60.0 | 2026-01-20 | github.com/terraform-aws-modules |

## Update Process

```bash
# Update module to new version
git fetch tf-<module>
git subtree pull --prefix=modules/terraform-aws-<module> tf-<module> vX.Y.Z --squash

# Or use Makefile target
make update-modules MODULE=terraform-aws-vpc VERSION=5.18.0
```

## Git Remotes

Configured remotes for subtree operations:

| Remote | URL |
|--------|-----|
| tf-vpc | https://github.com/terraform-aws-modules/terraform-aws-vpc.git |
| tf-rds | https://github.com/terraform-aws-modules/terraform-aws-rds.git |
| tf-ecs | https://github.com/terraform-aws-modules/terraform-aws-ecs.git |
| tf-s3 | https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git |
| tf-iam | https://github.com/terraform-aws-modules/terraform-aws-iam.git |

## Update SLA

- Security patches: Apply within 1 week
- Minor versions: Review monthly
- Major versions: Quarterly assessment

## Adding New Modules

```bash
# Add remote
git remote add tf-<name> https://github.com/terraform-aws-modules/terraform-aws-<name>.git

# Fetch and add
git fetch tf-<name>
git subtree add --prefix=modules/terraform-aws-<name> tf-<name> vX.Y.Z --squash

# Or use Makefile target
make add-module MODULE=terraform-aws-<name> VERSION=vX.Y.Z
```
