---
name: rust-builds
description: Use before running cargo build/test/clippy/bench in a Rust project on a shared dev server, especially in worktrees, when spawning subagents that compile, or when setting CARGO_TARGET_DIR. Keeps target/ from growing to hundreds of GB and filling the disk.
---

# Rust builds on a shared server

Several agents build in parallel worktrees on one disk. A single worktree once grew to 308 GB because each subagent was given its own `CARGO_TARGET_DIR` (`target/agents/aws`, `target/agents/perf`, …), which means a full separate build of every dependency per subagent. Avoid that.

## Rules

1. **One target dir per worktree.** Do not set `CARGO_TARGET_DIR` per subagent or per task. Subagents working in the same worktree share `./target`. If cargo prints `Blocking waiting for file lock on build directory`, that is fine: wait, do not work around it with a new target dir.
2. **If you truly need a separate target dir** (e.g. different feature sets that keep invalidating each other), use at most one extra, name it `target/alt`, and delete it before you finish: `rm -rf target/alt`.
3. **Check, don't build, when you can.** `cargo check` / `cargo clippy` are far smaller than `cargo build`. Build or run tests only for the crates you changed: `cargo test -p <crate>`, not the whole workspace every time.
4. **Smaller debug info.** For local iteration, export `CARGO_PROFILE_DEV_DEBUG=line-tables-only` (and `CARGO_PROFILE_TEST_DEBUG=line-tables-only`) in your shell. It cuts `target/` size a lot and still gives file/line in backtraces. Do not edit the project's `Cargo.toml` profiles without asking.
5. **Release / bench builds** are a second full build. Only run them when the task needs them (benchmarks, perf numbers), not as a routine check.
6. **Before you finish**, run `du -sh target target/* 2>/dev/null | sort -rh | head`. If there are extra target dirs you created, delete them. If `target/` is over ~60 GB, tell the user.

## Cleanup that already exists

A timer runs `~/.local/bin/cleanup-builds.sh` every 3 hours. It deletes `target/` in worktrees that are idle for 12 h, or every idle worktree once the disk is over 85 % full. It never deletes code. Do not disable it; run it with `--dry-run` to see what it would do.
