#!/usr/bin/env bash
# Reset the top-level column widths of a window to fixed percentages, left
# to right (e.g. a 50|25|25 layout whose columns have drifted). Only the
# first N-1 columns are explicitly resized; the last one absorbs whatever
# width is left, so — like tmux-rebalance-column.sh on the vertical axis —
# rounding doesn't need to add up to exactly 100.
#
# Usage:
#   tmux-set-column-widths.sh 50 25 25          # current window
#   tmux-set-column-widths.sh -t <window-id> 50 25 25

set -euo pipefail

if [ "${1:-}" = "-t" ]; then
	window="$2"
	shift 2
else
	window="${TMUX_PANE:?not inside a tmux pane}"
fi
window=$(tmux display-message -p -t "$window" '#{window_id}')

pcts=("$@")
[ "${#pcts[@]}" -ge 2 ] || {
	echo "usage: $(basename "$0") [-t window] pct1 pct2 [pct3 ...]" >&2
	exit 1
}

total_width=$(tmux display-message -p -t "$window" '#{window_width}')

# Top-level columns: the topmost pane of each column sits at the window's
# minimum pane_top (same offset for every column, border-status line and
# all), ordered left to right.
top=$(tmux list-panes -t "$window" -F '#{pane_top}' | sort -n | head -1)
mapfile -t cols < <(
	tmux list-panes -t "$window" -F '#{pane_top} #{pane_left} #{pane_id}' |
		awk -v top="$top" '$1 == top' | sort -k2 -n
)

n=${#cols[@]}
[ "${#pcts[@]}" -eq "$n" ] || {
	echo "column count ($n) doesn't match percentage count (${#pcts[@]})" >&2
	exit 1
}

for ((i = 0; i < n - 1; i++)); do
	read -r _ _ id <<<"${cols[$i]}"
	width=$((total_width * ${pcts[$i]} / 100))
	tmux resize-pane -t "$id" -x "$width"
done
