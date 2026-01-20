---
title: "Dev Environment Template for us-west-1"
description: "Create parameterized template for deploying full-stack infra to new regions"
status: in-progress
priority: P2
effort: 6h
branch: master
tags: [terragrunt, multi-region, infrastructure, automation]
created: 2026-01-20
completed_phases: 3
phase_03_completed: 2026-01-20T13:23:00Z
---

# Dev Environment Template for us-west-1

## Objective

Create reusable template structure for deploying full-stack infrastructure (VPC, RDS, ECS, S3, IAM) to new regions within dev environment, starting with `us-west-1`.

## Current State

- VPC module vendored at `modules/terraform-aws-vpc/`
- tfstate-backend module vendored at `modules/terraform-aws-tfstate-backend/`
- `_envcommon` has: `bootstrap/tfstate-backend.hcl`, `networking/vpc.hcl`
- `dev/us-east-1` exists with VPC deployed, vpc_cidr in `env.hcl`

## Target State

- 4 additional modules vendored (RDS, ECS, S3, IAM)
- `vpc_cidr` moved to `region.hcl` for region-specific CIDRs
- New `_envcommon` files for all resource types
- `us-west-1` directory structure with full stack
- Scaffold script for future regions
- Makefile targets for scaffold and module updates

## Phases

| Phase | Description | Effort | Status |
|-------|-------------|--------|--------|
| [01](phase-01-vendor-modules.md) | Vendor RDS, ECS, S3, IAM modules | 1h | COMPLETE |
| [02](phase-02-update-envcommon.md) | Create _envcommon files + move CIDR | 1.5h | COMPLETE |
| [03](phase-03-scaffold-script.md) | Create scaffold script with prompts | 1h | COMPLETE |
| [04](phase-04-us-west-1-deployment.md) | Create us-west-1 structure and deploy | 1.5h | PENDING |
| [05](phase-05-makefile-updates.md) | Add Makefile targets | 1h | PENDING |

## Dependency Graph

```
Phase 01 ─► Phase 02 ─► Phase 03
                │           │
                └───────────┴──► Phase 04 ─► Phase 05
```

## CIDR Allocation

| Region | VPC CIDR |
|--------|----------|
| us-east-1 | 10.10.0.0/16 |
| us-west-1 | 10.11.0.0/16 |

## Resource Deployment Order (per region)

```
IAM Roles (standalone)
    │
    ├──► S3 (standalone, optional IAM)
    │
    ▼
  VPC ◄─────────────────────────┐
    │                           │
    ├──► RDS (depends: VPC)     │
    │                           │
    └──► ECS (depends: VPC, IAM)
```

## Success Criteria

1. New region scaffolded in < 5 minutes via script
2. `terragrunt run-all apply` deploys full stack with correct order
3. No CIDR conflicts between regions
4. All modules use vendored sources

## Risks

| Risk | Mitigation |
|------|------------|
| Module version mismatch | Document versions in modules/README.md |
| CIDR overlap | Enforce via region.hcl, validate in script |
| Bootstrap order | Document in README, enforce via directory naming |
