---
name: server-health
description: Use when the user asks how the dev server is doing (disk, RAM, CPU, load, swap, "why is it slow", "is it frozen", "how much space is left"), or before/after heavy work, to get a quick health report and find what is using the resources. Also covers what is safe to delete when space runs low.
---

# Server health

Run `scripts/health.sh` from this skill's directory (read-only, takes a few seconds; the `du` part can take longer on a big disk):

```bash
scripts/health.sh            # summary
scripts/health.sh --deep     # also sizes of the biggest folders and build dirs
```

## Reading it

- **Load vs cores:** load up to ~the core count (`nproc`) is fine. Far above it means work is queuing.
- **Pressure (`/proc/pressure`)** matters more than load. `some avg60` for IO above ~20 % or memory above ~5 % means the machine feels slow or freezes. CPU pressure under ~10 % is fine.
- **RAM:** look at *available*, not *free*. `buff/cache` is given back on demand.
- **Swap** in use is fine if memory pressure is ~0; it only hurts if pressure is high too.
- **Disk:** under 80 % is fine. The cleanup timer starts deleting idle builds at 85 %.

## Freeing space, safest first

1. Idle Rust build output: `~/.local/bin/cleanup-builds.sh --dry-run`, then without `--dry-run`. Only touches `target/` in idle worktrees.
2. Docker build cache: `docker builder prune -f --filter until=24h`. Dangling images: `docker image prune -f`.
3. Go build cache: `go clean -cache` (rebuilds are slower once afterwards).
4. Leaked containers/volumes from finished tasks: see the `docker-hygiene` skill; only remove ones that are clearly yours or that the user confirms.

## Never delete without asking

- Session and app data: `~/.t3`, `~/.claude`, `~/.codex`.
- Any repo or worktree folder itself (it may have uncommitted work), only its `target/`.
- Docker volumes you did not create.
