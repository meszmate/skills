#!/usr/bin/env bash
# Print this machine's Tailscale URL for a port and check that it answers.
# Usage: preview-url.sh <port> [path]
set -u
port=${1:?usage: preview-url.sh <port> [path]}
path=${2:-/}

host=$(tailscale status --json 2>/dev/null \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))' 2>/dev/null)
[ -n "$host" ] || host=$(tailscale ip -4 2>/dev/null | head -1)
[ -n "$host" ] || { echo "tailscale is not running; cannot build a tailnet URL" >&2; exit 2; }

url="http://$host:$port$path"
if ! ss -ltn 2>/dev/null | grep -qE "[:.]$port\s"; then
  echo "$url"
  echo "nothing is listening on port $port yet" >&2
  exit 1
fi
if ss -ltn 2>/dev/null | grep -E "[:.]$port\s" | grep -qE '127\.0\.0\.1|\[::1\]' \
   && ! ss -ltn 2>/dev/null | grep -E "[:.]$port\s" | grep -qE '0\.0\.0\.0|\*|\[::\]'; then
  echo "$url"
  echo "port $port only listens on localhost; restart the server bound to 0.0.0.0" >&2
  exit 1
fi
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$url")
echo "$url"
if [ "$code" = "000" ]; then echo "no HTTP response from $url" >&2; exit 1; fi
echo "answers with HTTP $code" >&2
