#!/usr/bin/env bash
# Install these skills into Claude Code and Codex on this machine.
# Re-run any time to pull the latest versions.
set -u
repo=meszmate/skills
ok() { echo "  ✓ $*"; }; warn() { echo "  ! $*" >&2; }

if command -v claude >/dev/null; then
  echo "Claude Code"
  claude plugin marketplace add "$repo" >/dev/null 2>&1 || true
  claude plugin marketplace update >/dev/null 2>&1 || warn "marketplace update failed"
  for p in meszmate@meszmate-skills; do
    claude plugin install "$p" >/dev/null 2>&1 && ok "$p" || { claude plugin update "$p" >/dev/null 2>&1 && ok "$p (updated)" || warn "could not install $p"; }
  done
fi

if command -v codex >/dev/null; then
  echo "Codex"
  codex plugin marketplace add "$repo" >/dev/null 2>&1 || true
  for p in meszmate@meszmate-skills; do
    codex plugin add "$p" >/dev/null 2>&1 && ok "$p" || warn "could not install $p (try: codex plugin add $p)"
  done
fi

if [ "$(uname)" = Linux ] && [ "${1:-}" = --server ]; then
  echo "Server maintenance"
  "$(cd "$(dirname "$0")" && pwd)/server/install.sh"
fi
