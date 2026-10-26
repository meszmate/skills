#!/usr/bin/env bash
# Pull upstream pstack changes (michael-denyer/pstack-claude) into this repo's skills.
# Applies only what changed upstream since the last sync, so local edits are kept.
# Conflicts are left as *.rej files next to the affected file for you to resolve.
# Usage: scripts/sync-pstack.sh
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
mark=plugins/meszmate/PSTACK_UPSTREAM
base=$(cat "$mark")
agents='poteto-agent|comment-sicko|thermo-nuclear-review-subagent|thermo-nuclear-code-quality-review-subagent'

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
git clone -q https://github.com/michael-denyer/pstack-claude "$tmp/up"
new=$(git -C "$tmp/up" rev-parse HEAD)
if [ "$new" = "$base" ]; then echo "already up to date (${base:0:7})"; exit 0; fi

echo "upstream ${base:0:7} -> ${new:0:7}:"
git -C "$tmp/up" log --oneline "$base..$new" -- plugins/pstack/skills plugins/pstack/agents | head -20

# Same renames as the initial import: pstack's agents live in this plugin.
git -C "$tmp/up" diff "$base" "$new" -- plugins/pstack/skills plugins/pstack/agents \
  | sed -E "s/pstack:($agents)/meszmate:\1/g" > "$tmp/patch"
if [ ! -s "$tmp/patch" ]; then echo "no changes to skills or agents"; echo "$new" > "$mark"; exit 0; fi

if git apply -p3 --directory=plugins/meszmate --whitespace=nowarn "$tmp/patch"; then
  echo "applied cleanly"
else
  echo "some hunks conflict with your edits; applying the rest and writing *.rej files"
  git apply -p3 --directory=plugins/meszmate --whitespace=nowarn --reject "$tmp/patch" || true
  find plugins/meszmate -name '*.rej'
fi
echo "$new" > "$mark"
echo "review with: git diff, then bump the version and commit"
