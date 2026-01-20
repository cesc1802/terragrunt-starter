---
title: "02-compute Layer Restructure"
description: "Move RDS and ECS to new 02-compute layer for CPU/RAM resources"
status: in-progress
priority: P2
effort: 2h
branch: master
tags: [terragrunt, restructure, layer-organization]
created: 2026-01-20
---

# 02-compute Layer Restructure

## Objective

Reorganize infrastructure resources by creating a new `02-compute` layer containing all resources that require CPU/RAM (RDS, ECS), separating them from foundational infrastructure in `01-infra`.

## Current State

```
environments/dev/{region}/
├── 00-bootstrap/tfstate-backend/
├── 01-infra/
│   ├── network/vpc/
│   ├── security/iam-roles/
│   ├── storage/s3/
│   ├── data-stores/rds/          ← CPU/RAM resource
│   └── services/ecs-cluster/     ← CPU/RAM resource

_envcommon/
├── bootstrap/tfstate-backend.hcl
├── networking/vpc.hcl
├── security/iam-roles.hcl
├── storage/s3.hcl
├── data-stores/rds.hcl           ← to move
└── services/ecs-cluster.hcl      ← to move
```

## Target State

```
environments/dev/{region}/
├── 00-bootstrap/tfstate-backend/
├── 01-infra/
│   ├── network/vpc/
│   ├── security/iam-roles/
│   └── storage/s3/
├── 02-compute/
│   ├── rds/                      ← FLAT structure
│   └── ecs-cluster/              ← FLAT structure

_envcommon/
├── bootstrap/tfstate-backend.hcl
├── networking/vpc.hcl
├── security/iam-roles.hcl
├── storage/s3.hcl
└── compute/
    ├── rds.hcl                   ← moved
    └── ecs-cluster.hcl           ← moved
```

## Layer Classification

| Layer | Purpose | Resources |
|-------|---------|-----------|
| 00-bootstrap | State management | tfstate-backend |
| 01-infra | Foundational (no CPU/RAM) | VPC, IAM, S3 |
| 02-compute | CPU/RAM resources | RDS, ECS |

## Phases

| Phase | Description | Effort | Status |
|-------|-------------|--------|--------|
| [01](phase-01-envcommon-restructure.md) | Move _envcommon files to compute/ | 30m | DONE |
| [02](phase-02-region-restructure.md) | Restructure us-west-1 and us-east-1 | 45m | PENDING |
| [03](phase-03-update-scaffold-script.md) | Update scaffold-region.sh for 02-compute | 30m | PENDING |
| [04](phase-04-validation.md) | Validate configs and test scaffold | 15m | PENDING |

## Dependency Graph

```
Phase 01 ─► Phase 02 ─► Phase 03 ─► Phase 04
```

## Updated Resource Deployment Order

```
00-bootstrap: tfstate-backend
         │
         ▼
01-infra: IAM ──► S3
         │
         ▼
       VPC
         │
         ▼
02-compute: RDS ◄──┐
            │      │
            ECS ───┘ (depends: VPC, IAM)
```

## Success Criteria

1. All configs pass `terragrunt validate`
2. Dependency paths work (ECS→VPC, ECS→IAM, RDS→VPC)
3. Scaffold script creates 02-compute structure
4. No breaking changes to existing state

## Risks

| Risk | Mitigation |
|------|------------|
| State path mismatch | Run validate-only, no apply |
| Dependency breakage | Update relative paths carefully |
| Scaffold script regression | Test with dry-run |
