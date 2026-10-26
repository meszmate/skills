#!/usr/bin/env bash
# Read-only health report for a Linux dev server.
# Usage: health.sh [--deep]
set -u
deep=0; [ "${1:-}" = "--deep" ] && deep=1

echo "== $(hostname)  $(uptime -p)"
echo "load: $(cut -d' ' -f1-3 /proc/loadavg) on $(nproc) threads"
for r in cpu io memory; do
  printf 'pressure %-6s %s\n' "$r" "$(grep some /proc/pressure/$r 2>/dev/null | cut -d' ' -f2-4)"
done
echo
free -h | head -3
echo
df -h / /home 2>/dev/null | awk 'NR==1 || !seen[$1]++'
echo
echo "== top memory by process name"
ps -eo rss,comm --sort=-rss | awk 'NR>1{a[$2]+=$1;n[$2]++} END{for(k in a) printf "%6.1f GB %4d x %s\n",a[k]/1048576,n[k],k}' | sort -rn | head -8
echo
echo "== top cpu"
ps -eo pcpu,comm --sort=-pcpu | head -6
if command -v docker >/dev/null && docker info >/dev/null 2>&1; then
  echo
  echo "== docker"
  docker system df
  echo "running containers: $(docker ps -q | wc -l)"
fi
if systemctl --user list-timers cleanup-builds.timer --no-pager >/dev/null 2>&1; then
  echo
  echo "== cleanup timer"
  systemctl --user list-timers cleanup-builds.timer --no-pager | sed -n 2p
fi
if [ $deep = 1 ]; then
  echo
  echo "== biggest folders in \$HOME"
  du -xsh "$HOME"/* "$HOME"/.[!.]* 2>/dev/null | sort -rh | head -10
  echo
  echo "== biggest Rust target/ dirs"
  find "$HOME" -xdev -maxdepth 6 -type d -name target -prune 2>/dev/null \
    | xargs -r du -sh 2>/dev/null | sort -rh | head -10
fi
