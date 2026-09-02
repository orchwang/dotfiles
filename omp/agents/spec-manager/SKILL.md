---
name: spec-manager
description: Orchestrates specification management workflow by coordinating init-specs, specify-with-requirements, plan-with-specs, plan-with-requirements, update-requirements, and sync-to-jira skills. Manages the full lifecycle of task specifications from requirements through implementation planning and Jira push-back.
allowed-tools: Skill, Read, Write, Edit, Glob, Grep
user-invocable: false
---

# Spec Manager Agent

## Agent Type

This is an **orchestrator agent** that coordinates the full specification lifecycle for task planning. Unlike worker skills that perform specific tasks, this agent manages the workflow across requirements, specs, and plans — branching by **task difficulty** and optionally syncing back to Jira when the MCP server is available.

## Coordinated Skills

- **init-specs**: Scaffold spec documents for a new task. Reads `--difficulty` / `--pipeline` flags, infers difficulty from Jira metadata when available, and auto-fills `requirements.md` from a Jira ticket.
- **specify-with-requirements**: Analyze requirements and generate technical specs (`specs.md`). Handles lite → full pipeline escalation.
- **plan-with-specs**: Generate implementation plans from finalized specs (full pipeline).
- **plan-with-requirements**: Generate implementation plans directly from requirements, skipping the specs step (lite pipeline).
- **update-requirements**: Update requirements and cascade changes — full cascade for `Pipeline: full`, plans-only cascade for `Pipeline: lite`.
- **sync-to-jira**: Push the finalized `specs.md` / `plans.md` back into the Jira issue's description (or a custom field) via the Jira MCP server's `jira_update_ticket_from_markdown` tool.

## Purpose

This agent manages the complete specification lifecycle, with two pipeline shapes:

```
LITE  pipeline (low difficulty):
  init-specs (lite)  →  user writes requirements  →  plan-with-requirements  →  implementation  →  sync-to-jira

FULL  pipeline (medium / high difficulty):
  init-specs (full) → user writes requirements → specify-with-requirements → plan-with-specs → implementation → sync-to-jira
```

`update-requirements` runs at any point after the initial generation; `sync-to-jira` is optional and only meaningful when a Jira ticket ID is attached and the Jira MCP is available.

## Architecture

### Orchestrator Pattern

```
spec-manager (Orchestrator)
├── Phase 1: Initialize
│   └── Invokes init-specs
│       - Resolves difficulty (flag → Jira heuristic → user prompt)
│       - Resolves pipeline (lite for low, full otherwise)
│       - (Optional) Auto-fills requirements.md from Jira ticket
├── Phase 2: Specify (full pipeline only; also entry point for lite→full escalation)
│   └── Invokes specify-with-requirements → Generate technical specs
├── Phase 3: Plan
│   ├── Full pipeline → invokes plan-with-specs
│   └── Lite pipeline → invokes plan-with-requirements
├── Phase 4: Update (iterative)
│   └── Invokes update-requirements → Cascade changes
│       - Full: requirements → specs → plans
│       - Lite: requirements → plans (specs skipped)
└── Phase 5: Sync (optional, Jira MCP required)
    └── Invokes sync-to-jira → push specs/plans to Jira description (ADF)
```

### File Structure

All spec documents live in `specs/` directory. The file set differs by pipeline:

```
specs/{task-slug}/
├── requirements.md    # Always (with Difficulty/Pipeline/Source headers)
├── specs.md           # Full pipeline only
└── plans.md           # Always
```

## Workflow

### Full Lifecycle (full pipeline)

1. **User** runs `/init-specs <ticket-id> <task title>` to scaffold documents (`requirements.md`, `specs.md`, `plans.md`).
2. **User** writes/reviews requirements in `specs/{slug}/requirements.md`.
3. **User** runs `/specify-with-requirements <slug>` to generate specs.
4. **Agent** analyzes requirements, asks clarifying questions if needed.
5. **User** reviews generated specs, iterates on clarifications.
6. **User** runs `/plan-with-specs <slug>` to generate the implementation plan.
7. **User** reviews the plan and begins implementation.
8. During implementation, specs and plans are updated as needed.
9. If requirements change, **user** runs `/update-requirements <change description>` to cascade updates.
10. **(Optional)** When `specs.md`/`plans.md` are finalized, **user** runs `/sync-to-jira <slug>` to push them into the Jira ticket.

### Lite Lifecycle (lite pipeline)

1. **User** runs `/init-specs <ticket-id> <task title> --difficulty low` (or accepts inferred `low` from Jira). Only `requirements.md` and `plans.md` are created.
2. **User** writes/reviews requirements in `specs/{slug}/requirements.md`.
3. **User** runs `/plan-with-requirements <slug>` to generate the implementation plan directly.
4. **User** reviews the plan and begins implementation.
5. If requirements change, **user** runs `/update-requirements <change description>` — only `plans.md` is touched.
6. **(Optional)** **User** runs `/sync-to-jira <slug>` to push the plan into the Jira ticket.

### Lite → Full Escalation

If midway through lite the task turns out to need deeper analysis, the user can escalate by running `/specify-with-requirements <slug>`. The skill will:
- Confirm escalation (AskUserQuestion).
- Update `requirements.md` header to `Pipeline: full`.
- Create `specs.md` from scratch.
- Mark the existing `plans.md` as `Stale (specs added)`. The user must explicitly re-run `/plan-with-specs` to regenerate.

### Skill Invocation

Each skill is invoked independently by the user via slash commands. The spec-manager agent provides the shared context and conventions that all skills follow.

## Conventions

### File Naming

- Task titles are slugified: lowercase, hyphens for spaces, no special characters.
- Example: "User Authentication Flow" → `user-authentication-flow`.

### Required Header Fields in `requirements.md`

| Field | Required | Values | Purpose |
|-------|----------|--------|---------|
| `Created` | yes | date | Initial creation. |
| `Updated` | recommended | date | Last modification. |
| `Status` | yes | `Draft` / `Draft (from Jira)` / `Final` | Lifecycle state. |
| `Ticket` | yes | ticket ID or `N/A` | Used by `sync-to-jira` and `init-specs` Jira fetch. |
| `Difficulty` | yes | `low` / `medium` / `high` | Determines pipeline. Missing → treated as `medium`. |
| `Pipeline` | yes | `lite` / `full` | Determines file set + skill routing. Missing → treated as `full`. |
| `Source` | optional | `manual` / `jira:<ticket-id>` | Provenance for the requirements draft. |

### Document Cross-References

- Requirements link to nothing (they are the source of truth).
- `specs.md` (full only) links back to requirements via `> Requirements: [...]`.
- `plans.md` links back to requirements; for full it also links to `specs.md`, for lite it shows `Specs: N/A (lite pipeline)`.

### Traceability

- Functional Requirements: `FR-1`, `FR-2`, ...
- Technical Specifications (full only): `TS-1` (from `FR-1`), `TS-2` (from `FR-2`), ...
- Implementation Steps:
  - Full: `Step N` references `TS-X`.
  - Lite: `Step N` references `FR-X` directly.

### Status Flow

| Document | Pipeline | Flow |
|----------|----------|------|
| `requirements.md` | both | `Draft` / `Draft (from Jira)` → `Final` |
| `specs.md` | full only | `Pending` → `Draft` → `Final` |
| `plans.md` | both | `Pending` → `Ready` → `In Progress` → `Completed`. After lite→full escalation, may transition to `Stale (specs added)` until `/plan-with-specs` is re-run. |

## Guidelines

### Do:
- Always read existing documents before making changes.
- Maintain traceability between requirements → specs → plans (or requirements → plans for lite).
- Preserve completed work when cascading changes — especially completed plan steps.
- Log all clarifications and changes for audit trail (full pipeline `specs.md` Clarification Log).
- Examine the codebase for context when generating specs and plans.
- Respect the `Pipeline:` header in every skill — don't ask the user the same question twice.
- Treat Jira MCP as optional in every skill: degrade gracefully when unavailable.

### Don't:
- Generate specs from empty/template requirements.
- Skip the clarification step when ambiguities exist.
- Silently drop requirements, specs, or plan steps.
- Modify completed implementation steps without explicit warning.
- Proceed to the next phase without user review.
- Silently mutate Jira — `sync-to-jira` must always show a diff and ask for confirmation before writing.
- Auto-regenerate `plans.md` after lite→full escalation; mark it stale and let the user trigger regeneration.
