#!/usr/bin/env bash
# Build (or attach to) a named tmux session from a predefined pane layout.
#
# This is independent of tmux-resurrect/continuum: resurrect replays whatever
# panes happened to be open at last save, while this script always produces
# the same deliberate split/label/command arrangement for a named session.
# If the session already exists, it is left untouched and just attached.
#
# Usage:
#   tmux-layout.sh <layout-name> [working-directory]
#
# Add a new layout by writing a `layout_<name>` function below and adding a
# case entry for it in main().

set -euo pipefail

label_pane() { tmux set-option -p -t "$1" @label "$2"; }
run_in() { tmux send-keys -t "$1" "$2" Enter; }

# tmux renumbers pane-index by screen position after every split, so later
# splits can't be targeted by a positional index chosen up front. These
# wrappers return the new pane's stable #{pane_id} (e.g. %12) instead, which
# is safe to reuse in later commands regardless of layout changes.
split_h() { tmux split-window -h -p "$2" -t "$1" -P -F '#{pane_id}'; } # new pane gets $2% of the width
split_v() { tmux split-window -v -p "$2" -t "$1" -P -F '#{pane_id}'; } # new pane gets $2% of the height

# ── Layouts ────────────────────────────────────────────────────────────
# Each layout_* function assumes its session does not exist yet and builds
# it detached; main() handles the existence check and attach/switch.

layout_synapse_monorepo() {
	local dir="${1:-$HOME/Projects/synapse}"
	local p1 p2 p3 p4 p5 p6

	p1=$(tmux new-session -d -s synapse-monorepo -c "$dir" -n main -P -F '#{pane_id}')
	label_pane "$p1" "nvim"
	run_in "$p1" "nvim"

	# Right 50% of the window, split into a 3-row column and a 2-row column.
	p2=$(split_h "$p1" 50) # right half
	p3=$(split_h "$p2" 50) # right sub-column (2 rows: lazygit, shell)

	p4=$(split_v "$p2" 67) # bottom 2/3 of the left sub-column
	p5=$(split_v "$p4" 50) # bottom half of that remainder
	label_pane "$p2" "agent-1"
	label_pane "$p4" "agent-2"
	label_pane "$p5" "agent-3"

	p6=$(split_v "$p3" 50) # bottom half of the right sub-column
	label_pane "$p3" "lazygit"
	run_in "$p3" "lazygit"
	label_pane "$p6" "shell"

	tmux select-pane -t "$p1"
}

# ── Registry & entrypoint ───────────────────────────────────────────────

available_layouts() { echo "synapse-monorepo"; }

main() {
	local layout="${1:-}"
	[ -n "$layout" ] && shift

	local build
	case "$layout" in
	synapse-monorepo) build=layout_synapse_monorepo ;;
	*)
		echo "Usage: $(basename "$0") <layout-name> [working-directory]" >&2
		echo "Available layouts: $(available_layouts)" >&2
		exit 1
		;;
	esac

	if tmux has-session -t "=$layout" 2>/dev/null; then
		echo "Session '$layout' already exists; not rebuilding." >&2
	else
		"$build" "$@"
	fi

	if [ -n "${TMUX:-}" ]; then
		tmux switch-client -t "$layout"
	else
		tmux attach-session -t "$layout"
	fi
}

main "$@"
