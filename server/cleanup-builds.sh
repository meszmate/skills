#!/usr/bin/env bash
# Delete Rust build output (target/) in idle agent/t3code worktrees so they
# cannot fill the disk. Code, commits and uncommitted changes are never touched.
#   - skips worktrees a running process is using (cwd inside it)
#   - normally only cleans worktrees with no build activity for IDLE_MIN minutes
#   - above EMERGENCY_PCT disk usage, cleans every idle worktree regardless of age
# Usage: cleanup-builds.sh [--dry-run]
set -u
IDLE_MIN=720
EMERGENCY_PCT=85
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1

used=$(df --output=pcent / | tail -1 | tr -dc '0-9')
emergency=0; [ "$used" -ge "$EMERGENCY_PCT" ] && emergency=1
echo "disk ${used}% used$([ $emergency = 1 ] && echo ' (emergency: ignoring idle time)')"

active=$(for p in $(pgrep -u "$USER"); do readlink "/proc/$p/cwd" 2>/dev/null; done | sort -u)
in_use() { grep -qE "^$(printf '%s' "$1" | sed 's/[][\.*^$]/\\&/g')(/|$)" <<<"$active"; }

shopt -s nullglob
freed=0
for w in "$HOME"/*/.claude/worktrees/* "$HOME"/worktrees/*/*; do
  t="$w/target"; [ -d "$t" ] || continue
  if in_use "$w"; then echo "skip, in use: $w"; continue; fi
  if [ $emergency = 0 ] && [ -n "$(find "$t" -maxdepth 3 -mmin -$IDLE_MIN -print -quit 2>/dev/null)" ]; then
    echo "skip, built recently: $w"; continue
  fi
  kb=$(du -sk "$t" 2>/dev/null | cut -f1); freed=$((freed + kb))
  if [ $DRY = 1 ]; then echo "would remove $((kb/1048576)) GB: $t"; else rm -rf "$t" && echo "removed $((kb/1048576)) GB: $t"; fi
done

if [ $DRY = 0 ] && command -v docker >/dev/null; then
  docker builder prune -f --filter until=72h >/dev/null 2>&1
  docker image prune -f >/dev/null 2>&1
fi
echo "$([ $DRY = 1 ] && echo 'would free' || echo 'freed') ~$((freed/1048576)) GB; disk now $(df --output=pcent / | tail -1 | tr -d ' ') used"
