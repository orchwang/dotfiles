---
name: init-specs
description: Initialize spec documents (requirements, specs, plans) for a new task. Creates scaffolded markdown files in specs/ directory. Use when user wants to start a new task specification.
allowed-tools: Read, Write, Glob, Bash, AskUserQuestion
user-invocable: true
---

# Init Specs

## Skill Info

Part of the **spec-manager** agent. This skill scaffolds the initial spec documents for a new task.

The pipeline that `init-specs` scaffolds depends on the task's **difficulty**:

- `low` → **lite pipeline**: only `requirements.md` and `plans.md` are created. `specs.md` is skipped. The next step is `/plan-with-requirements`.
- `medium` / `high` → **full pipeline**: `requirements.md`, `specs.md`, `plans.md` are all created (legacy behavior). The next step is `/specify-with-requirements`.

If Jira MCP is available **and** a ticket ID is provided, `init-specs` will also auto-populate `requirements.md` from the Jira issue.

## Input

The user provides a task title as arguments: $ARGUMENTS

Arguments may optionally include a ticket ID prefix and the flags below:
- `/init-specs SYN-1234 User Authentication Flow` — ticket ID + title
- `/init-specs User Authentication Flow` — title only (ticket ID asked later)
- `/init-specs SYN-1234 Fix copy typo --difficulty low` — force lite pipeline
- `/init-specs SYN-1234 Big refactor --difficulty high --pipeline full` — force full pipeline
- `/init-specs SYN-1234 Some task --no-jira` — skip Jira auto-fill even if MCP is available

Recognized flags (any order, before or after the title):

| Flag | Values | Default | Effect |
|------|--------|---------|--------|
| `--difficulty` | `low` / `medium` / `high` | inferred | Forces difficulty. Skips inference. |
| `--pipeline` | `lite` / `full` | derived from difficulty | Overrides pipeline. `lite` ⇒ no specs.md. |
| `--no-jira` | (bool) | off | Disables Jira MCP detection + auto-fill. |

If no task title is provided, ask the user for a task title before proceeding.

## Process

### Step 0: Collect Ticket ID

1. Check if the first argument matches a ticket ID pattern (e.g., `SYN-1234`, `PROJ-99`, `#123`). If so, extract it as the ticket ID and use the remaining text as the task title.
2. If no ticket ID was found in the arguments, ask the user for a ticket ID using AskUserQuestion. Provide options:
   - **Skip** — No ticket ID for this task
   - **Other** — Let the user type a ticket ID
3. The ticket ID will be used for:
   - The git branch name
   - The `Ticket` field in the requirements template
   - Jira auto-fill (Step 0.7) and difficulty inference (Step 0.6) when Jira MCP is available

### Step 0.5: Detect Jira MCP Availability

Skip this step entirely if `--no-jira` was passed or no ticket ID exists.

Otherwise, determine whether Jira MCP tools are available in the current session:

1. Look for any of these tool name prefixes in the available tools:
   - `mcp__jira__jira_get_ticket`
   - `mcp__platform-dev-team-common__jira__jira_get_ticket`
   - any tool whose name ends with `jira_get_ticket`
2. Use the first matching prefix. Record it as the active Jira MCP prefix for this run (used by Steps 0.6 and 0.7).
3. If no matching tool is found, set Jira MCP availability to `false`. Do not error — Jira features are optional.

Record the result internally; do **not** write it to any file.

### Step 0.6: Resolve Difficulty

Difficulty determines the pipeline (`low` ⇒ lite, others ⇒ full) and is recorded in `requirements.md` header.

Resolution order (use the first that succeeds):

1. **Explicit flag**: If `--difficulty=<value>` was passed, use it.
2. **Jira heuristic** (only when Jira MCP available + ticket ID exists):
   - Call `jira_get_ticket(ticketId, fields=["summary", "priority", "labels"])`.
   - Apply rules in order:
     - `priority` ∈ {`Lowest`, `Low`} **OR** any label in {`trivial`, `chore`, `docs`} → `low`
     - `priority` ∈ {`Highest`, `High`} **OR** any label in {`epic`, `spike`} → `high`
     - Otherwise → `medium`
3. **User prompt**: If neither succeeded, use AskUserQuestion:
   - Options: `low (lite)` / `medium (full, default)` / `high (full)`
   - Default selection: `medium`.

If `--pipeline=<value>` was provided, it overrides the pipeline derived from difficulty. Otherwise: `low` → `lite`, `medium`/`high` → `full`.

### Step 0.7: (Reserved for Jira auto-fill — executed at Step 4.5)

Skip; see Step 4.5 below.

### Step 1: Slug the Task Title

Convert the task title to a URL-friendly slug:
- Lowercase all characters
- Replace spaces and special characters with hyphens
- Remove consecutive hyphens
- Trim leading/trailing hyphens

**Example**: "User Authentication Flow" -> `user-authentication-flow`

### Step 2: Create Git Branch

Create and checkout a new git branch for this task:

1. **Build branch name**:
   - If ticket ID exists: `{ticket-id}-{slug}` (e.g., `syn-1234-user-authentication-flow`)
   - If no ticket ID: `feat-{slug}` (e.g., `feat-user-authentication-flow`)
   - Entire branch name should be lowercased

2. **Check current git state**:
   - Run `git status` to check for uncommitted changes
   - If there are uncommitted changes, warn the user and ask whether to proceed (changes will carry over to the new branch) or abort

3. **Create and checkout the branch**:
   - Run `git checkout -b {branch-name}`
   - If the branch already exists, warn the user and ask whether to:
     - Switch to the existing branch (`git checkout {branch-name}`)
     - Choose a different name
     - Abort

4. **Report**: Confirm the branch was created and checked out

### Step 3: Check for Existing Directory

Check if a directory already exists at `specs/{slug}/`. If it does, warn the user and ask whether to overwrite or choose a different title.

### Step 4: Create Spec Files

Create the `specs/{slug}/` directory and the following files inside it. **Which files are created depends on the resolved pipeline** (Step 0.6):

- **lite pipeline**: `requirements.md` + `plans.md` only. Do NOT create `specs.md`.
- **full pipeline**: `requirements.md` + `specs.md` + `plans.md` (legacy behavior).

#### 1. `specs/{slug}/requirements.md` (always created)

```markdown
# Requirements: {Original Task Title}

> Created: {YYYY-MM-DD}
> Status: {Draft | Draft (from Jira)}
> Ticket: {ticket-id or "N/A"}
> Difficulty: {low | medium | high}
> Pipeline: {lite | full}
> Source: {manual | jira:{ticket-id}}

## Overview

<!-- Describe the task/feature at a high level. What problem does it solve? -->

## Goals

<!-- What are the primary goals of this task? -->

- [ ] Goal 1
- [ ] Goal 2

## Functional Requirements

<!-- Describe what the system should DO. Be specific and measurable. -->

### FR-1: {Requirement Name}

- **Description**:
- **Acceptance Criteria**:
  - [ ]

### FR-2: {Requirement Name}

- **Description**:
- **Acceptance Criteria**:
  - [ ]

## Non-Functional Requirements

<!-- Performance, security, scalability, maintainability, etc. -->

- **Performance**:
- **Security**:
- **Scalability**:

## Constraints

<!-- Technical constraints, time constraints, dependencies, etc. -->

-

## Out of Scope

<!-- Explicitly state what is NOT included in this task -->

-

## References

<!-- Links to related documents, designs, APIs, etc. -->

-
```

> **Header field semantics**:
> - `Difficulty`: from Step 0.6. Drives pipeline.
> - `Pipeline`: `lite` or `full`. Other skills (`specify-with-requirements`, `update-requirements`, `sync-to-jira`) read this to branch behavior.
> - `Source`: `manual` if user is filling by hand, `jira:<ticketId>` if Step 4.5 auto-filled from Jira. Used by escalation logic.

#### 2. `specs/{slug}/specs.md` (full pipeline only)

Skip creating this file when pipeline is `lite`.

```markdown
# Specs: {Original Task Title}

> Created: {YYYY-MM-DD}
> Status: Pending (waiting for requirements)
> Requirements: [requirements.md](./requirements.md)

## Overview

<!-- This document will be generated from requirements. Run /specify-with-requirements after completing requirements. -->

## Technical Specifications

<!-- Auto-generated from requirements analysis -->

## Architecture

<!-- Component design, data flow, integrations -->

## API / Interface Design

<!-- Endpoints, function signatures, data models -->

## Error Handling

<!-- Error scenarios and handling strategies -->

## Dependencies

<!-- External and internal dependencies -->

## Open Questions

<!-- Unresolved questions to clarify -->

-
```

#### 3. `specs/{slug}/plans.md` (always created)

The "Status" line differs slightly by pipeline:

- lite: `> Status: Pending (waiting for requirements — run /plan-with-requirements)`
- full: `> Status: Pending (waiting for specs)`

The "Specs" link in lite pipeline points to `N/A (lite)` instead of `specs.md`.

```markdown
# Plans: {Original Task Title}

> Created: {YYYY-MM-DD}
> Status: {see above}
> Requirements: [requirements.md](./requirements.md)
> Specs: {[specs.md](./specs.md) | N/A (lite pipeline)}

## Overview

<!-- This document will be generated from {specs | requirements}. Run {/plan-with-specs | /plan-with-requirements} after the prior step is finalized. -->

## Implementation Steps

<!-- Auto-generated -->

## Task Breakdown

<!-- Ordered list of implementation tasks -->

## Testing Strategy

<!-- Test plan for verification -->

## Rollback Plan

<!-- How to undo changes if needed -->

## Progress Tracking

| Step | Status | Notes |
|------|--------|-------|
|      |        |       |
```

### Step 4.5: Auto-fill requirements.md from Jira (when MCP available + ticket ID)

Skip if any of the following holds:
- `--no-jira` was passed
- No ticket ID
- Jira MCP availability is `false` (Step 0.5)

Otherwise:

1. Call `jira_get_ticket` (using the prefix detected in Step 0.5) with:
   ```
   { ticketId, fields: ["summary", "description", "priority", "labels", "comment"], commentLimit: 5 }
   ```
2. If the call fails (auth, network, 404), do **not** overwrite the empty template. Keep `> Status: Draft` and append a note to the Overview section:
   ```
   > Jira 자동 채움 실패 (사유: {error}). 수동으로 작성해주세요.
   ```
3. On success, transform the Jira response into markdown sections:
   - **Header**: set `Status: Draft (from Jira)`, `Source: jira:{ticketId}`.
   - **Overview**: `summary` as one-line summary, followed by the first paragraph of the description.
   - **Goals**: best-effort extraction — if description contains a heading like `## Goals` or `## 목표`, copy its bullet list. Otherwise leave the goals template as-is with a comment noting that Goals were not auto-detected.
   - **Functional Requirements**: best-effort extraction from a `Acceptance Criteria` / `수락 조건` section if present. Each top-level bullet or task-list item becomes a `FR-N`. If no such section exists, leave a single placeholder `FR-1` and add a comment.
   - **References**: append the canonical Jira link as the first reference: `- [Jira: {ticketId}](https://<jira-base>/browse/{ticketId})`.
4. The Jira description is ADF JSON. Use a conservative ADF→markdown reducer:
   - `heading` → `#` × level
   - `paragraph` → blank-line separated text
   - `bulletList` / `orderedList` / `taskList` → `- item` / `1. item` / `- [ ] item`
   - `text` node `marks` → wrap with `**`, `*`, `` ` ``, `~~`, or `[text](href)` accordingly
   - Anything else → render plain text and continue (no error)
5. For sections that could not be auto-mapped, leave the template comment in place and add `<!-- Jira에서 자동 매핑되지 않았습니다. 수동 작성이 필요합니다. -->`.

### Step 5: Report Completion

After creating files, display a summary tailored to the pipeline:

```
Spec documents initialized for: "{Original Task Title}"

Branch: {branch-name}
Ticket: {ticket-id or "N/A"}
Difficulty: {low | medium | high}
Pipeline: {lite | full}
Source: {manual | jira:{ticket-id}}

Created files:
  - specs/{slug}/requirements.md  <- {Write your requirements | Review the auto-filled draft}
  {full only} - specs/{slug}/specs.md         <- Generated after /specify-with-requirements
  - specs/{slug}/plans.md         <- Generated after {/plan-with-specs | /plan-with-requirements}

Next step: Edit specs/{slug}/requirements.md, then run:
  {full} /specify-with-requirements {slug}
  {lite} /plan-with-requirements {slug}

Tip: lite로 시작했더라도 나중에 /specify-with-requirements {slug}를 호출하면 specs.md가 추가되며 full로 escalate 됩니다.
```

## Important

- Always create the `specs/` directory if it doesn't exist
- Use the actual current date for the "Created" field
- Preserve the original task title (with proper casing) in document headers
- Use the slugged version only for file names and cross-references
- Never error out because Jira MCP is unavailable — degrade gracefully. The plugin must work fully offline.
- Difficulty and Pipeline headers are mandatory: if missing on an existing file, treat as `medium` / `full` for compatibility.
