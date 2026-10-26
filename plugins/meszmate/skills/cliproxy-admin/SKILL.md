---
name: cliproxy-admin
description: Use when managing the self-hosted CLIProxyAPI (CPA) proxy that Claude Code and Codex route through - adding or removing Claude/Codex/other accounts, changing account priority or routing, installing or configuring CPA plugins, reading proxy logs, restarting it, or debugging "proxy errors", 401/429s and quota from the agents.
---

# CLIProxyAPI administration

All Claude Code and Codex traffic goes through one CLIProxyAPI instance. It runs on the host `archlinux-host` (reach it over Tailscale SSH) as a **systemd user service**, port `8317`.

| What | Where |
|---|---|
| Service | `systemctl --user {status,restart} cli-proxy-api`, logs: `journalctl --user -u cli-proxy-api` |
| Config | `~/.cli-proxy-api/config.yaml` |
| Account (auth) files | `~/.cli-proxy-api/*.json`, one per account, e.g. `claude-<email>.json`, `codex-<email>.json` |
| Plugins | binaries in `~/plugins/linux/amd64/*.so`, enabled under `plugins.configs.<id>` in the config |
| Config backups | `~/.cli-proxy-api-backups/` |
| Account reordering | `~/.local/bin/cpa-rebalance.py` (daily timer `cpa-rebalance.timer`) |
| Web UI (CPAMC) | `http://archlinux-host:8317/management.html` |

## Secrets: hard rules

- **Never print** API keys, the management key, OAuth tokens or the contents of auth JSON files. If you must refer to one, show at most the last 4 characters.
- The management key in the config is stored as a bcrypt hash (`$2a$…`); the plaintext is not on disk. If you need the management API, **ask the user** for the key instead of guessing or resetting it.
- Do not commit any of these files anywhere.

## Routing

- `routing.strategy: fill-first`: the proxy uses the highest-`priority` account until it is rate-limited, then the next one. Session affinity keeps a conversation on one account.
- Priorities are set by `cpa-rebalance.py` every morning: personal accounts get `10 × rank` by remaining **weekly** quota (most remaining = highest). The **work account is pinned low (-10)** so it is used last, except when its weekly window resets within 24 h and it still has quota; then it is promoted to the top and demoted again 5 minutes after the reset.
- Preview without changing anything: `~/.local/bin/cpa-rebalance.py --dry-run`. Do not hand-edit `priority` fields; the next run overwrites them. Change the script instead.

## Common tasks

- **Add an account:** run the CLI's login on the host (`cli-proxy-api --config ~/.cli-proxy-api/config.yaml --claude-login`, `--codex-login`, …; check `--help` for the exact flag), complete the OAuth link the user opens, then run the rebalance once so the new account gets a priority.
- **Remove an account:** move its auth JSON out of `~/.cli-proxy-api/` (into the backups folder, don't delete), the proxy reloads automatically.
- **Install a plugin:** download the `linux_amd64` zip from the plugin's GitHub release, **verify it against the release's `checksums.txt`**, copy the `.so` (renamed `<id>-v<version>.so`) and any `ui/` folder into `~/plugins/linux/amd64/`, add `plugins.configs.<id>: {enabled: true}`, back up the config first, then `systemctl --user restart cli-proxy-api` and check the log for `plugin registered plugin_id=<id>`. Avoid scheduler/reordering plugins: they conflict with `cpa-rebalance.py`.
- **After any change**, test both clients end to end from a machine that uses the proxy: `claude -p "reply only: ok"` and `codex exec --skip-git-repo-check "reply only: ok"`.

## Debugging

- `journalctl --user -u cli-proxy-api --since -15min | grep -E 'error|warn| 4[0-9]{2} | 5[0-9]{2} '`
- 401 on one account: its OAuth login expired; log it in again.
- 429: that account hit its limit; fill-first moves on automatically. If every account is limited, say so and show reset times rather than retrying.
- Plugin failures show as `pluginhost:` lines. A plugin that fails to start usually has an unknown field in its `plugins.configs.<id>` block.
