---
title: "Terragrunt Root Config Migration"
description: "Rename terragrunt.hcl to root.hcl per Terragrunt deprecation warning"
status: completed
priority: P1
effort: 30m
branch: master
tags: [terragrunt, migration, deprecation, config]
created: 2026-01-08
phase-01-completed: 2026-01-08T16:04:00Z
phase-02-completed: 2026-01-08T16:10:00Z
---

# Terragrunt Root Config Migration Plan

## Overview

Migrate from deprecated `terragrunt.hcl` root config to recommended `root.hcl` per Terragrunt's migration guide.

**Warning Message:**
```
Using `terragrunt.hcl` as the root of Terragrunt configurations is an anti-pattern,
and no longer recommended. In a future version of Terragrunt, this will result in an error.
```

**Reference:** https://terragrunt.gruntwork.io/docs/migrate/migrating-from-root-terragrunt-hcl

## Key Facts

- `find_in_parent_folders()` without args auto-detects `root.hcl` first, then falls back to `terragrunt.hcl`
- Child modules (`environments/**/terragrunt.hcl`) require **NO code changes**
- `_envcommon` modules require **NO code changes**
- Only documentation references need updating

## Phases

| # | Phase | Status | Effort | Link |
|---|-------|--------|--------|------|
| 1 | Rename & Validate | ✅ Complete (Tests: 8/8, Review: 9/10) | 15m | [phase-01](./phase-01-rename-and-validate.md) |
| 2 | Update Documentation | ✅ Complete (Tests: 5/5, Review: N/A) | 15m | [phase-02](./phase-02-update-documentation.md) |

## Impact Analysis

| Component | Count | Changes Required |
|-----------|-------|------------------|
| Root config | 1 | Rename only |
| Child modules | ~30 | None |
| _envcommon modules | 5 | None |
| README.md | 1 | Update references |
| docs/*.md | 4 | Update references |
| plans/**/*.md | 10+ | Optional (historical) |

## Success Criteria

- [x] `root.hcl` exists at project root
- [x] `terragrunt.hcl` removed from project root
- [x] All child modules updated with explicit `find_in_parent_folders("root.hcl")`
- [x] No Terragrunt deprecation warning when running commands
- [x] `terragrunt validate` passes in any child module
- [x] README.md updated with correct filename
- [x] Core docs updated (code-standards, system-architecture, codebase-summary, project-overview-pdr)

## Review Reports

- [Code Review - Phase 01](./reports/code-reviewer-260108-1558-terragrunt-root-migration.md) - Score: 9/10
- [Test Report - Phase 02](./reports/tester-260108-1610-documentation-migration.md) - Pass: 5/5 (100%)
