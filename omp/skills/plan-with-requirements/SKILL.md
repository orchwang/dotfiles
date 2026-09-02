---
name: plan-with-requirements
description: Lite 파이프라인 — requirements.md에서 곧장 plans.md를 생성합니다. low 난이도 / 단순 작업에 사용. specs.md 단계를 건너뜁니다.
allowed-tools: Read, Write, Edit, Glob, Grep
user-invocable: true
---

# Plan with Requirements (Lite Pipeline)

## Skill Info

Part of the **spec-manager** agent. This skill generates an implementation plan directly from `requirements.md`, skipping the `specs.md` step.

It is the lite-pipeline counterpart to `/plan-with-specs`. Use it when:
- `requirements.md` header has `Pipeline: lite`, **or**
- The task is small enough that an intermediate technical spec adds no value (low difficulty).

## Input

The user provides a task slug (or task title) as arguments: $ARGUMENTS

If no arguments are provided:
1. List all `*/requirements.md` files in `specs/` directory that have `Pipeline: lite` in the header.
2. Ask the user which one to generate a plan for.

If a task title (not slug) is provided, convert it to a slug to find the matching files.

## Process

### Step 1: Read the Requirements Document

1. Read `specs/{slug}/requirements.md`. If missing, stop and suggest `/init-specs`.
2. Read `specs/{slug}/plans.md`. It should exist as a placeholder from `/init-specs`.

### Step 2: Validate Pipeline Mode

Inspect the `Pipeline:` header in `requirements.md`:

- `Pipeline: lite` → proceed.
- `Pipeline: full` → stop and tell the user:
  ```
  This task uses the full pipeline. Use /specify-with-requirements then /plan-with-specs instead.
  If you want to switch to the lite pipeline, edit requirements.md header to set Pipeline: lite
  and remove specs.md (or run /init-specs with --pipeline lite for a new slug).
  ```
- Missing `Pipeline` header → treat as `full` for backward compatibility and stop with the same message.

### Step 3: Validate Requirements Completeness

Check that requirements are sufficiently detailed:
- Overview section is filled in
- At least one functional requirement is defined (`FR-1` with Description + Acceptance Criteria)
- Goals checklist has at least one item

If requirements are incomplete, do NOT generate a plan from an empty template. Tell the user what is missing and ask them to fill in the gaps first.

### Step 4: Analyze Codebase

Before generating the plan:
1. Examine the existing codebase structure (project layout, frameworks, patterns).
2. Identify existing files that need modification.
3. Find reusable components, utilities, or patterns.
4. Check test structure and conventions.

### Step 5: Generate the Plan

Update `specs/{slug}/plans.md` with the implementation plan. The structure mirrors `/plan-with-specs` but **references `FR-X` instead of `TS-X`** because there is no specs.md.

```markdown
# Plans: {Original Task Title}

> Created: {original date}
> Updated: {YYYY-MM-DD}
> Status: Ready
> Pipeline: lite
> Requirements: [requirements.md](./requirements.md)
> Specs: N/A (lite pipeline)

## Overview

{Brief summary of what will be implemented and the approach}

## Prerequisites

- {Any setup, dependencies, or preparatory work needed before starting}

## Implementation Steps

### Step 1: {Step Name}

- **Goal**: {What this step achieves}
- **Requirements Reference**: FR-{X}
- **Files**:
  - `{path/to/file}` - {Create | Modify} - {What changes}
- **Details**:
  {Detailed implementation instructions}
- **Validation**:
  - {How to verify this step is complete}
- **Complexity**: Simple | Medium | Complex

### Step 2: {Step Name}

{Same structure}

## Task Breakdown

Ordered checklist for tracking progress:

- [ ] **Step 1**: {Brief description}
- [ ] **Step 2**: {Brief description}
- [ ] ...
- [ ] **Final**: Verify all acceptance criteria

## File Change Summary

| File | Action | Step | Description |
|------|--------|------|-------------|
| `path/to/file` | Create/Modify/Delete | Step N | Brief description |

## Dependencies Between Steps

{Describe which steps depend on others and which can be parallelized}

## Testing Strategy

### Unit Tests
- {What to test and where}

### Manual Verification
- {Steps to manually verify the feature works}

## Rollback Plan

{How to safely undo changes at each major checkpoint}

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| {Risk} | Low/Medium/High | Low/Medium/High | {How to mitigate} |

## Progress Tracking

| Step | Status | Started | Completed | Notes |
|------|--------|---------|-----------|-------|
| Step 1 | Pending | | | |
| Step 2 | Pending | | | |

## Acceptance Criteria Checklist

Copy each `Acceptance Criteria` checkbox from each FR in requirements.md verbatim:

- [ ] {From FR-1}
- [ ] {From FR-2}
- [ ] ...
```

### Step 6: Report and Request Review

```
Implementation plan generated for: "{Original Task Title}" (lite pipeline)

Updated: specs/{slug}/plans.md

Summary:
  - {N} implementation steps
  - {X} files to create, {Y} files to modify
  - Estimated complexity: {overall assessment}
  - {Z} risks identified

Please review the plan in specs/{slug}/plans.md.

If you discover that the task needs deeper technical analysis (multiple components,
non-obvious data model, breaking changes), escalate to the full pipeline by running:
  /specify-with-requirements {slug}
This adds specs.md and marks plans.md as `Stale (specs added)` so you can regenerate it.
```

## Lite ↔ Full Escalation

This skill is *forward-compatible* with escalation:

- If the user later runs `/specify-with-requirements <slug>`, `requirements.md` is updated to `Pipeline: full`, `specs.md` is created, and this plan is marked stale. The user must explicitly re-run `/plan-with-specs` to regenerate.
- If the user runs `/update-requirements <change>` on a lite slug, the change cascades only into `plans.md` (no specs.md to update). See `update-requirements/SKILL.md`.

## Important

- Always read `requirements.md` before generating plans — never guess.
- Steps must be ordered by dependency, not arbitrary sequence.
- Each step must be independently verifiable.
- Plans must be detailed enough that another developer could follow them.
- The lite pipeline is for *low-difficulty* work. If you find yourself writing more than ~5 steps, or the steps reference >3 files, consider escalating to full pipeline.
