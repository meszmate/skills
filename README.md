# skills

My skills for Claude Code and Codex, plus the maintenance scripts for my AI dev server.
One repo, installable as a plugin in both tools, so every machine gets the same skills.

## Install

```bash
git clone https://github.com/meszmate/skills ~/skills
~/skills/install.sh            # skills + pstack into Claude Code and Codex
~/skills/install.sh --server   # also the dev-server cleanup timer (Linux)
```

Or by hand:

| | Claude Code | Codex |
|---|---|---|
| add marketplace | `/plugin marketplace add meszmate/skills` | `codex plugin marketplace add meszmate/skills` |
| install | `/plugin install meszmate@meszmate-skills` | `codex plugin add meszmate@meszmate-skills` |
| update | `/plugin marketplace update` | re-run `install.sh` |

`install.sh` also installs [pstack](https://github.com/michael-denyer/pstack-claude) (Lauren Tan's engineering-workflow skills). Start with `/poteto-mode`, or `/poteto-help` to find the right command.

## Skills

| Skill | Use it for |
|---|---|
| `preview-urls` | Sharing dev servers and previews by their Tailscale URL instead of `localhost` |
| `rust-builds` | Keeping `target/` small: one target dir per worktree, `cargo check` first, cleaning extra dirs |
| `docker-hygiene` | Labelling, limiting and cleaning up containers, so agents don't leak databases |
| `server-health` | Disk / RAM / CPU / pressure report and what is safe to delete |
| `cliproxy-admin` | Managing the CLIProxyAPI proxy: accounts, priorities, plugins, logs |

## Layout

```
.claude-plugin/marketplace.json   Claude Code marketplace
.agents/plugins/marketplace.json  Codex marketplace
plugins/meszmate/
  .claude-plugin/plugin.json
  .codex-plugin/plugin.json
  skills/<name>/SKILL.md          one folder per skill, optional scripts/
server/                           cleanup-builds script + systemd timer
install.sh
```

## Adding a skill

1. Create `plugins/meszmate/skills/<name>/SKILL.md` with `name` and a `description` that says *when* to use it (that's what the agent matches on).
2. Bump `version` in both `plugin.json` files and in `.claude-plugin/marketplace.json`.
3. Push, then run `install.sh` (or `/plugin marketplace update`) on each machine.

Rule of thumb: if you explain the same thing to an agent twice, make it a skill.

**This repo is public.** Never commit keys, tokens, IPs, emails or auth files. Skills look those up at runtime instead.
