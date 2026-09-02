# spec-manager Agent

Orchestrates the full specification lifecycle for task planning and implementation.

> **Agent Type**: This is an **orchestrator agent**. It coordinates four skills (init-specs, specify-with-requirements, plan-with-specs, update-requirements) to manage the complete requirements → specs → plans workflow.

## Overview

**Purpose**: Manage task specifications from initial requirements through implementation planning, with support for iterative updates.

## Skills

| Skill | Command | Description |
|-------|---------|-------------|
| init-specs | `/init-specs <title>` | Scaffold spec documents for a new task |
| specify-with-requirements | `/specify-with-requirements <slug>` | Generate technical specs from requirements |
| plan-with-specs | `/plan-with-specs <slug>` | Generate implementation plan from specs |
| update-requirements | `/update-requirements <changes>` | Update requirements and cascade to specs/plans |

## Workflow

```
/init-specs "My Feature"
    ↓
  User writes requirements
    ↓
/specify-with-requirements my-feature
    ↓
  User reviews & clarifies specs
    ↓
/plan-with-specs my-feature
    ↓
  User reviews plan → starts implementation
    ↓
/update-requirements "Add caching requirement"  (as needed)
```

## File Structure

```
specs/
└── {slug}/
    ├── requirements.md   # User-authored requirements
    ├── specs.md           # Generated technical specifications
    └── plans.md           # Generated implementation plan
```

## Traceability

All documents maintain traceability:
- `FR-X` (Functional Requirements) → `TS-X` (Technical Specs) → `Step N` (Plan Steps)
- Changes cascade: requirements → specs → plans
