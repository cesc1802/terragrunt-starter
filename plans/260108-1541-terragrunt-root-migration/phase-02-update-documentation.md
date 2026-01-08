# Phase 02: Update Documentation

## Context Links
- Parent: [plan.md](./plan.md)
- Dependency: Phase 01 complete

## Overview
- **Priority**: P1
- **Status**: Pending
- **Description**: Update all documentation references from `terragrunt.hcl` to `root.hcl`

## Key Insights

### Scope
- Only update references to ROOT config (`terragrunt.hcl` at project root)
- Do NOT change references to child `terragrunt.hcl` files (those remain `terragrunt.hcl`)

### Pattern
- **Change**: "Root (terragrunt.hcl)" → "Root (root.hcl)"
- **Keep**: "environments/.../terragrunt.hcl" (these stay as-is)

## Files to Update

### Priority 1: User-Facing Docs
| File | Occurrences | Notes |
|------|-------------|-------|
| `README.md` | 6 | Main entry point |
| `docs/code-standards.md` | 2 | Root config section |
| `docs/system-architecture.md` | 1 | Architecture diagram |
| `docs/codebase-summary.md` | 2 | Directory structure |
| `docs/project-overview-pdr.md` | 3 | PDR config section |

### Priority 2: Optional (Historical)
- `plans/**/*.md` - Historical plans, can leave as-is
- `plans/reports/**/*.md` - Historical reports, can leave as-is

## Implementation Steps

### Step 1: Update README.md
Replace root config references only:
```
├── terragrunt.hcl              # Root config
```
→
```
├── root.hcl                    # Root config
```

And:
```
Root (terragrunt.hcl)
```
→
```
Root (root.hcl)
```

### Step 2: Update docs/code-standards.md
- Line 7: Directory structure
- Line 88: "Root Configuration (terragrunt.hcl)" → "Root Configuration (root.hcl)"

### Step 3: Update docs/system-architecture.md
- Line 40: Architecture diagram reference

### Step 4: Update docs/codebase-summary.md
- Line 14: Directory structure
- Line 112: Config explanation

### Step 5: Update docs/project-overview-pdr.md
- Line 27: Root-level config reference
- Line 144: Config hierarchy
- Line 172: Table reference

## Todo List
- [ ] Update README.md (6 occurrences)
- [ ] Update docs/code-standards.md (2 occurrences)
- [ ] Update docs/system-architecture.md (1 occurrence)
- [ ] Update docs/codebase-summary.md (2 occurrences)
- [ ] Update docs/project-overview-pdr.md (3 occurrences)
- [ ] Commit changes with conventional commit

## Success Criteria
- All user-facing docs reference `root.hcl` for root config
- Child module references still say `terragrunt.hcl` (correct)
- Git commit with conventional message

## Commit Message
```
refactor(config): migrate from terragrunt.hcl to root.hcl

Rename root config per Terragrunt deprecation warning.
Reference: https://terragrunt.gruntwork.io/docs/migrate/migrating-from-root-terragrunt-hcl

- Rename terragrunt.hcl → root.hcl (root config only)
- Update README.md and docs references
- Child modules unchanged (still use terragrunt.hcl)
```
