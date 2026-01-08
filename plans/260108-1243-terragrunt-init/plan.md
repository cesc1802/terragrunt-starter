---
title: "Terragrunt TFState Backend Module"
description: "Configure per-environment S3 state backends using terraform-aws-tfstate-backend module"
status: in-progress
priority: P2
effort: 2h
branch: main
tags: [infra, terragrunt, bootstrap, aws]
created: 2026-01-08
updated: 2026-01-08
---

# Terragrunt TFState Backend Implementation Plan

## Overview

Provision Terraform state backend infrastructure (S3 bucket + DynamoDB table) for each environment (dev, uat, prod) using the Cloud Posse `terraform-aws-tfstate-backend` module with Terragrunt DRY patterns.

## Key Decisions

- **Per-environment backends**: Each env has isolated S3 bucket + DynamoDB
- **Configurable region**: State bucket region set per environment
- **Local module**: Uses `modules/terraform-aws-tfstate-backend` (not registry)
- **Bootstrap pattern**: First run uses local state, then migrates to S3

## Phases

| # | Phase | Status | Effort | Link |
|---|-------|--------|--------|------|
| 1 | UAT Environment Setup | Completed | 15m | [phase-01](./phase-01-uat-environment-setup.md) |
| 2 | Common Module Config | Completed | 30m | [phase-02-envcommon-tfstate-backend.md](./phase-02-envcommon-tfstate-backend.md) |
| 3 | Environment Deployments | Pending | 45m | [phase-03](./phase-03-environment-deployments.md) |
| 4 | Bootstrap & Migration | Pending | 30m | [phase-04](./phase-04-bootstrap-migration.md) |

## Dependencies

- AWS credentials configured with S3/DynamoDB permissions
- Terraform >= 1.1.0
- Terragrunt >= 0.50.0
- `modules/terraform-aws-tfstate-backend` module present

## Files to Create

```
_envcommon/bootstrap/tfstate-backend.hcl
environments/uat/env.hcl
environments/uat/us-east-1/region.hcl
environments/dev/us-east-1/bootstrap/tfstate-backend/terragrunt.hcl
environments/uat/us-east-1/bootstrap/tfstate-backend/terragrunt.hcl
environments/prod/us-east-1/bootstrap/tfstate-backend/terragrunt.hcl
```

## Unresolved Questions

1. Should Makefile be updated with bootstrap commands?
2. Should prod have a secondary region (eu-west-1) tfstate-backend?
