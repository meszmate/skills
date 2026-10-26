---
name: preview-urls
description: Use whenever you start something the user should open in a browser on a remote dev server (dev server, preview, Storybook, docs site, API, Docker container with a published port) and need to give them a working URL. Covers which host and port to use, binding, and checking the URL before sharing it.
---

# Preview URLs on a remote dev server

The user is never sitting at this machine. They open links from their laptop or phone over Tailscale, so `localhost`, `127.0.0.1` and `0.0.0.0` URLs point at *their* device and do not work.

## Get the URL

Run the helper; it prints this machine's Tailscale URL for a port and checks that something answers there:

```bash
"<this skill's directory>/scripts/preview-url.sh" <port>
```

Without the script: the host is this machine's Tailscale DNS name, `tailscale status --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))'`. The URL is `http://<that-name>:<port>`. If MagicDNS fails, fall back to `http://$(tailscale ip -4):<port>`.

## Rules

1. **Bind to all interfaces**, or the tailnet cannot reach it:
   - Vite / Astro / Nuxt / SvelteKit: `--host 0.0.0.0`
   - Next.js: `-H 0.0.0.0`
   - Django: `runserver 0.0.0.0:<port>`, Rails: `-b 0.0.0.0`, Go / Rust servers: listen on `0.0.0.0:<port>`
   - Docker: `-p <port>:<port>` is enough.
2. **Pick a free port.** Check with `ss -ltn | grep -w :<port>` first. Never use 443 (Tailscale Serve uses it for T3 Code) or 3773 (T3 Code itself).
3. **Do not touch the firewall** (ufw, iptables, the `DOCKER-USER` rule). Ports are only reachable from the tailnet on purpose; never open them to the public internet.
4. **Verify before sharing.** Only tell the user it is ready after `scripts/preview-url.sh <port>` (or `curl -sI <url>`) gets an HTTP response.
5. **Long-running servers** should survive the end of your turn: run them in the background (`nohup … &`, a tmux session, or `docker run -d`) and tell the user how to stop them.
6. When reporting, give the full clickable URL, e.g. `http://my-server.example.ts.net:5173`, not just the port.
