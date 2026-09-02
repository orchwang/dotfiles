---
name: sync-to-jira
description: 완성된 specs/plans 문서를 Jira 이슈로 push-back 합니다 (Markdown → ADF 자동 변환). Jira MCP가 가용한 환경에서만 동작합니다.
allowed-tools: Read, Glob, Grep, AskUserQuestion
user-invocable: true
---

# Sync to Jira

## Skill Info

Part of the **spec-manager** agent. This skill takes the finalized `specs.md` and/or `plans.md` for a slug and pushes them back into the linked Jira issue's `description` (or a configured custom field), wrapping the content with marker comments so the same region can be updated repeatedly.

The actual markdown → ADF conversion and the PUT call live in the Jira MCP server (tool: `jira_update_ticket_from_markdown`). This skill is the **orchestration layer**: detection, payload assembly, diff confirmation, and result reporting.

## Input

`/sync-to-jira <slug> [--target=spec|plan|both] [--field=description|customfield_<id>]`

Flags:

| Flag | Values | Default | Effect |
|------|--------|---------|--------|
| `--target` | `spec` / `plan` / `both` | `both` | Which documents to include in the payload. |
| `--field` | `description` or `customfield_<id>` | `description` | Where on the Jira issue to write. `description` uses marker splice; custom fields are overwritten. |

If `<slug>` is omitted, list slugs in `specs/` and ask the user to pick.

## Markers

The skill uses two marker strings to delimit the region inside Jira's description that it owns:

- `markerStart`: `<!-- sdd:start -->`
- `markerEnd`: `<!-- sdd:end -->`

These are passed to `jira_update_ticket_from_markdown` so subsequent syncs replace only the bounded region. The first sync to a ticket appends a new marker block at the end of the description (the MCP tool reports `mode: "append-marker"`).

## Process

### Step 1: Argument Parsing

1. Extract `<slug>` (positional).
2. Parse `--target` and `--field` flags.
3. Validate: `--target` ∈ {`spec`, `plan`, `both`}; `--field` is `description` or matches `^customfield_\d+$`.

### Step 2: Load Spec Files

1. Read `specs/{slug}/requirements.md` to extract the `Ticket:` header. If `N/A` or missing, stop with:
   ```
   sync-to-jira aborted: requirements.md has no Jira ticket (Ticket: N/A).
   ```
2. Also read the `Pipeline:` header.
   - If `--target` includes `spec` and `Pipeline: lite`, warn the user that lite tasks have no `specs.md` and either:
     - Auto-fall back to `--target=plan` if `--target=both`, or
     - Stop if `--target=spec` was explicit.
3. Based on `--target`, load:
   - `--target=spec` → `specs/{slug}/specs.md`
   - `--target=plan` → `specs/{slug}/plans.md`
   - `--target=both` → both (in order: specs, plans)
4. Validate that each loaded file's `Status` is not `Pending` (i.e., it has real content). If a target file is still pending, warn and ask whether to abort or proceed anyway.

### Step 3: Detect Jira MCP Availability

Look in the available tools for any of:
- `mcp__jira__jira_get_ticket` and `mcp__jira__jira_update_ticket_from_markdown`
- `mcp__platform-dev-team-common__jira__jira_get_ticket` and `mcp__platform-dev-team-common__jira__jira_update_ticket_from_markdown`
- any tool ending with `jira_update_ticket_from_markdown`

If the matching pair is not available, stop with:
```
sync-to-jira aborted: Jira MCP is not available in this session.
설치 안내: plugins/platform-dev-team-common/mcp-servers/jira/README.md
```

Record the active prefix; reuse it for the calls in Steps 4 and 6.

### Step 4: Assemble Markdown Payload

Concatenate the loaded documents into one markdown string, omitting their YAML-like header blocks (the `> Created:` / `> Status:` / etc. lines) so Jira gets the substantive content only.

```
## SDD: Specs

<body of specs.md after its header block>

## SDD: Plans

<body of plans.md after its header block>
```

If only one target is selected, include only that heading + body. Do not include the marker comments here — the MCP tool wraps the payload with markers automatically.

### Step 5: Fetch Current Description for Diff

Call:
```
jira_get_ticket({ ticketId, fields: ["description"] })
```

Extract the existing marker region:
- If the description ADF contains both `markerStart` and `markerEnd` paragraphs, render the blocks between them back into markdown (best-effort: paragraph text, headings as `#`, lists, code blocks).
- If markers are absent, the current region is treated as empty.

Show the user a unified-style diff (rendered as a fenced code block in the terminal) between the current region's rendered markdown and the new payload. Keep it concise: if the diff exceeds ~200 lines, truncate with `[... N lines elided ...]` and offer a "show full diff" option.

### Step 6: Confirm and Apply

Use AskUserQuestion:

```
Jira 이슈 {ticketId}의 description {markerStart}~{markerEnd} 구간을 위 내용으로 갱신할까요?
```

Options: `Apply` / `Cancel`.

If **Cancel**: stop with a one-line acknowledgement. No external call is made.

If **Apply**: call:
```
jira_update_ticket_from_markdown({
  ticketId,
  markdown: <assembled payload from Step 4>,
  field: <--field value>,
  markerStart: "<!-- sdd:start -->",
  markerEnd: "<!-- sdd:end -->",
})
```

When `--field` is a `customfield_<id>`, omit `markerStart`/`markerEnd` so the field is fully overwritten.

### Step 7: Report

On success, print:
```
Sync to Jira: success

Ticket:     {ticketId}
Field:      {field}
Mode:       {splice-marker | append-marker | replace-full}
Targets:    {spec / plan / both}
Warnings:   {none | list}
Link:       https://<jira-base>/browse/{ticketId}
```

On failure (Jira API error, etc.), print the error returned by the MCP tool and suggest checking `JIRA_*` env vars or ticket permissions.

## Error Handling

| Scenario | Strategy |
|----------|----------|
| `Ticket: N/A` or missing | Stop in Step 2 with explicit message |
| Jira MCP not available | Stop in Step 3 with install hint |
| Target file `Status: Pending` | Ask the user whether to abort or push the pending content |
| Jira 401/403 | Surface error, suggest re-issuing `JIRA_API_TOKEN` |
| Jira 404 (ticket not found) | Stop, ask user to verify the Ticket ID |
| Empty diff (no changes) | Skip Apply, print "No changes to sync" |
| Marker absent (first sync) | Proceed; MCP tool will create the marker block and report `mode: append-marker` |
| `--field=customfield_<id>` with `--target=both` | Allowed; the custom field is fully overwritten with the assembled payload |

## Important

- This skill **never silently mutates Jira**. Step 6 confirmation is mandatory.
- Do not store `JIRA_API_TOKEN` or any credential anywhere — the MCP server owns auth.
- For `--field=description`, always use the marker pattern; never overwrite the entire description (that would clobber human-written context above/below).
- For `--field=customfield_<id>`, the custom field is fully overwritten — make this clear in the confirmation prompt.
- If you encounter ADF nodes the MCP converter doesn't recognize, surface the `warnings` list verbatim in Step 7 so the user knows what fell back to plain text.
- The lite pipeline has no `specs.md`. Respect this in Step 2: don't error on missing files; fall back to plan-only or stop based on `--target`.
