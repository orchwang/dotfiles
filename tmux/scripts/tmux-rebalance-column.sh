#!/usr/bin/env bash
# Evenly redistribute pane heights within a column — a vertical stack of
# panes sharing the same left edge — without touching the window's
# horizontal split ratio (e.g. a 50|25|25 layout) or any other column.
#
# tmux has no "balance just these panes" primitive: select-layout even-*
# always applies to the whole window. This instead resizes every pane but
# the last one in the target column to floor(total/n) (+1 for the first
# `total % n` of them so the remainder isn't lost), then lets the last pane
# absorb whatever's left — which keeps the column's total height, and thus
# every other column's width, unchanged.
#
# Usage:
#   tmux-rebalance-column.sh [pane-id]   # defaults to the current pane

set -euo pipefail

target="${1:-${TMUX_PANE:?not inside a tmux pane}}"
window=$(tmux display-message -p -t "$target" '#{window_id}')
left=$(tmux display-message -p -t "$target" '#{pane_left}')

# Panes in the same column: same left edge, ordered top to bottom.
mapfile -t rows < <(
	tmux list-panes -t "$window" -F '#{pane_left} #{pane_top} #{pane_id} #{pane_height}' |
		awk -v left="$left" '$1 == left' | sort -k2 -n
)

n=${#rows[@]}
[ "$n" -le 1 ] && exit 0

total=0
ids=()
for row in "${rows[@]}"; do
	read -r _ _ id height <<<"$row"
	ids+=("$id")
	total=$((total + height))
done

base=$((total / n))
rem=$((total % n))

for ((i = 0; i < n - 1; i++)); do
	size=$base
	[ "$i" -lt "$rem" ] && size=$((size + 1))
	tmux resize-pane -t "${ids[$i]}" -y "$size"
done
