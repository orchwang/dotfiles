---
name: specify-with-requirements
description: Read requirements markdown and generate detailed technical specifications. Analyzes requirements, clarifies ambiguities, and updates the specs document. Use when user has written requirements and wants to generate specs. Also handles lite→full pipeline escalation.
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion
user-invocable: true
---

# Specify with Requirements

## Skill Info

Part of the **spec-manager** agent. This skill analyzes requirements and generates detailed technical specifications.

## Input

The user provides a task slug (or task title) as arguments: $ARGUMENTS

If no arguments are provided:
1. List all `*/requirements.md` files in `specs/` directory
2. Ask the user which one to process

If a task title (not slug) is provided, convert it to a slug to find the matching files.

## Process

### Step 1: Locate and Read Requirements

1. Find `specs/{slug}/requirements.md`
2. If the file doesn't exist, inform the user and suggest running `/init-specs` first
3. Read the full requirements document

### Step 1.5: Detect Pipeline Mode (Lite → Full Escalation)

Inspect the `Pipeline:` header field in `requirements.md`:

- `Pipeline: full` (or missing — treat missing as `full` for backward compatibility): proceed to Step 2 normally.
- `Pipeline: lite`: this slug was initialized as a lite-pipeline task and does **not** yet have a `specs.md` file. Calling `/specify-with-requirements` on a lite task means the user wants to **escalate** to full pipeline.

  In this case:

  1. Use AskUserQuestion to confirm:
     ```
     이 태스크는 lite 파이프라인(`Pipeline: lite`)으로 초기화되어 specs.md가 없습니다.
     full 파이프라인으로 escalate 하시겠습니까?
     ```
     Options: `Escalate (recommended)` / `Cancel`.
  2. If **Cancel**: print a one-line note ("Escalation cancelled — task remains lite") and stop.
  3. If **Escalate**:
     a. Update `requirements.md` header: change `Pipeline: lite` → `Pipeline: full`. Also bump `Updated: {today}`.
     b. Create `specs/{slug}/specs.md` from the standard template (status `Pending` — will be filled in Step 5 below).
     c. If `specs/{slug}/plans.md` exists and its current `Status` is not `Pending`, edit its header to:
        ```
        > Status: Stale (specs added — re-run /plan-with-specs to regenerate)
        ```
        and add a row to its Progress Tracking table:
        ```
        | Escalation | Stale | {today} | | lite→full escalation: specs.md added, plan needs regeneration |
        ```
     d. Append a Clarification Log entry to the new `specs.md` (will be added during Step 5 generation) with `Question: "lite→full escalation"`, `Answer: "approved by user"`, today's date.
  4. Continue to Step 2.

### Step 2: Validate Requirements Completeness

Check that requirements are sufficiently detailed:
- Overview section is filled in
- At least one functional requirement is defined
- Acceptance criteria exist

If requirements are incomplete or too vague, inform the user about what's missing and ask them to fill in the gaps before proceeding. Do NOT generate specs from empty templates.

### Step 3: Analyze Requirements

Perform thorough analysis of the requirements:

1. **Decompose** each functional requirement into technical components
2. **Identify** implicit requirements not explicitly stated
3. **Map** requirements to technical decisions (data models, APIs, algorithms)
4. **Detect** conflicts or ambiguities between requirements
5. **Assess** technical feasibility and complexity
6. **Examine** the existing codebase for related code, patterns, and conventions

### Step 4: Clarify if Needed

If analysis reveals ambiguities, conflicts, or gaps:

1. Present findings to the user with specific questions
2. Use AskUserQuestion tool for structured choices when applicable
3. Wait for user responses before finalizing specs
4. Iterate until all open questions are resolved

Example clarifications:
- "FR-1 mentions 'real-time updates' but doesn't specify the mechanism. Should we use WebSocket, SSE, or polling?"
- "FR-2 and FR-3 seem to conflict regarding data access. Which takes priority?"
- "The performance requirement of '<100ms response time' may conflict with the data aggregation in FR-4. Should we add caching?"

### Step 5: Generate Specs

Update `specs/{slug}/specs.md` with comprehensive technical specifications:

```markdown
# Specs: {Original Task Title}

> Created: {original date}
> Updated: {YYYY-MM-DD}
> Status: Draft
> Requirements: [requirements.md](./requirements.md)

## Overview

{Brief technical overview of what will be built, derived from requirements}

## Technical Specifications

### TS-1: {Spec Name} (from FR-1)

- **Description**: {Technical description}
- **Components Involved**: {List of components/modules}
- **Data Flow**: {How data moves through the system}
- **Implementation Approach**: {High-level approach}
- **Constraints**: {Technical constraints}

### TS-2: {Spec Name} (from FR-2)

{Same structure}

## Architecture

### Component Design

{Describe the components that need to be created or modified}

### Data Flow

{Describe how data flows through the system for this feature}

### Integration Points

{How this feature integrates with existing systems}

## Data Models

### {Model Name}

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
|       |      |             |             |

## API / Interface Design

### {Endpoint/Function Name}

- **Method**: {GET/POST/etc. or function signature}
- **Path**: {URL path or module path}
- **Input**: {Request body/parameters}
- **Output**: {Response format}
- **Errors**: {Possible error responses}

## Error Handling

| Scenario | Handling Strategy | User Impact |
|----------|-------------------|-------------|
|          |                   |             |

## Dependencies

### External
- {Library/service}: {Purpose} - {Version/notes}

### Internal
- {Module/component}: {How it's used}

## Security Considerations

- {Security concern and mitigation}

## Performance Considerations

- {Performance concern and mitigation}

## Open Questions

- {Any remaining unresolved questions}

## Clarification Log

| # | Question | Answer | Date |
|---|----------|--------|------|
| 1 | {Question asked} | {Answer received} | {Date} |
```

### Step 6: Report and Request Review

After generating specs, display a summary:

```
Specs generated for: "{Original Task Title}"

Updated: specs/{slug}/specs.md

Summary:
  - {N} technical specifications derived from {M} requirements
  - {X} components identified
  - {Y} API endpoints/interfaces defined
  - {Z} open questions remaining

Please review the generated specs in specs/{slug}/specs.md

If you need to clarify or modify anything, discuss it here.
When specs are finalized, run:
  /plan-with-specs {slug}
```

## Clarification Cycle

If the user requests changes or has questions about the generated specs:

1. Read the current specs file
2. Discuss the user's concerns
3. Update the specs document with agreed changes
4. Log the clarification in the "Clarification Log" table
5. Update the "Updated" date
6. Repeat until the user is satisfied

## Requirement Changes

If the user requests changes to requirements during this process:

1. Update `specs/{slug}/requirements.md` with the changes
2. Re-analyze all requirements (not just the changed ones)
3. Regenerate `specs/{slug}/specs.md` reflecting the changes
4. Note the requirement change in the Clarification Log
5. Reset `specs/{slug}/plans.md` status to "Pending (specs updated)"

## Important

- Always read the requirements file before generating specs - never guess
- Examine the existing codebase for patterns, conventions, and related code
- Specs must be traceable back to requirements (use FR-X references)
- Flag any requirements that are technically infeasible or very costly
- Include a clarification log for audit trail
- Do not proceed to plan generation - wait for user to run `/plan-with-specs`
- When escalating from lite (Step 1.5), never silently regenerate `plans.md`. Mark it stale and let the user explicitly re-run `/plan-with-specs`.
