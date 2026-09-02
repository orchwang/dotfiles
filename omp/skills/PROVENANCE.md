# Vendored skills — provenance

The skill directories here (and the subagents in `../agents/`) are vendored
copies, managed directly in this repo as the source of truth. `make
set-omp-skills` (via `../install-skills.sh`) symlinks each `<name>/` that
contains a `SKILL.md` into omp's user paths (`~/.omp/agent/skills` and
`~/.omp/agent/agents`).

Add or edit skills right here; changes take effect in the next omp session.
Non-directory files at this level (this note, `LICENSE.sdd-helper`) are ignored
by the installer — only `<name>/SKILL.md` directories are linked.

## Origin

| skills / subagent | source plugin | license |
|---|---|---|
| `init-specs`, `specify-with-requirements`, `plan-with-specs`, `plan-with-requirements`, `update-requirements`, `sync-to-jira`, agent `spec-manager` | `sdd-helper` (Datamaker `synapse-marketplace`) | see `LICENSE.sdd-helper` |
