#!/usr/bin/env bash
# Install the dotfiles-managed omp (Oh My Pi) skills, subagents, and
# system-prompt files into omp by symlinking, so edits in this repo take effect
# in the next omp session.
#
#   omp/skills/<name>/    ->  ~/.omp/agent/skills/<name>     (user skills)
#   omp/agents/<name>/    ->  ~/.omp/agent/agents/<name>     (user subagents)
#   omp/PERSONALITY.md    ->  ~/.omp/agent/PERSONALITY.md    (personality block)
#   omp/APPEND_SYSTEM.md  ->  ~/.omp/agent/APPEND_SYSTEM.md  (appended to prompt)
#
# Idempotent: re-running re-points the symlinks. It never writes into
# ~/.omp/agent/managed-skills (omp's isolated auto-learn store) and refuses to
# clobber a real (non-symlink) path already sitting at a target.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_SKILLS="$SCRIPT_DIR/skills"
SRC_AGENTS="$SCRIPT_DIR/agents"
OMP_AGENT_DIR="$HOME/.omp/agent"
OMP_SKILLS_DIR="$OMP_AGENT_DIR/skills"
OMP_AGENTS_DIR="$OMP_AGENT_DIR/agents"

mkdir -p "$OMP_SKILLS_DIR" "$OMP_AGENTS_DIR"

# link_dir <src-parent> <dest-dir> <label>
# symlink every <src-parent>/<name>/ that holds a SKILL.md into dest-dir.
link_dir() {
  local src="$1" dest="$2" label="$3" d name tgt found=0
  [ -d "$src" ] || return 0
  for d in "$src"/*/; do
    [ -f "${d}SKILL.md" ] || continue
    name="$(basename "$d")"
    tgt="$dest/$name"
    if [ -e "$tgt" ] && [ ! -L "$tgt" ]; then
      echo "    skip $label/$name (real dir at $tgt — move it aside to manage)"
      continue
    fi
    ln -sfn "${d%/}" "$tgt"
    echo "    linked $label/$name"
    found=1
  done
  [ "$found" -eq 1 ] || echo "    (no $label found in $src)"
}

# link_file <src-file> <dest-path> <label>
link_file() {
  local src="$1" tgt="$2" label="$3"
  [ -f "$src" ] || { echo "    (no $label at $src)"; return 0; }
  if [ -e "$tgt" ] && [ ! -L "$tgt" ]; then
    echo "    skip $label (real file at $tgt — move it aside to manage)"
    return 0
  fi
  ln -sfn "$src" "$tgt"
  echo "    linked $label -> $tgt"
}

echo "Installing dotfiles-managed omp skills/subagents"
echo "  skills:"
link_dir "$SRC_SKILLS" "$OMP_SKILLS_DIR" skill
echo "  subagents:"
link_dir "$SRC_AGENTS" "$OMP_AGENTS_DIR" agent
echo "  system-prompt files:"
link_file "$SCRIPT_DIR/PERSONALITY.md"   "$OMP_AGENT_DIR/PERSONALITY.md"   PERSONALITY.md
link_file "$SCRIPT_DIR/APPEND_SYSTEM.md" "$OMP_AGENT_DIR/APPEND_SYSTEM.md" APPEND_SYSTEM.md

echo "Done."
echo "  skills   -> $OMP_SKILLS_DIR"
echo "  subagents-> $OMP_AGENTS_DIR"
echo "  prompt   -> $OMP_AGENT_DIR/{PERSONALITY,APPEND_SYSTEM}.md"
echo "Start a new omp session to pick them up (list skills with /skills)."
