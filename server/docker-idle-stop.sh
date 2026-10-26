#!/usr/bin/env bash
# Stop Docker containers nobody is using, so leftover test databases and
# services from finished agent tasks don't pile up in memory.
#   - "idle" = CPU and network both below a small threshold for IDLE_HOURS
#   - containers are only stopped, never removed: data stays, `docker start <name>` brings one back
#   - never touches containers named in KEEP_FILE or labelled keep=true
# Run every 30 min by docker-idle-stop.timer.
# Usage: docker-idle-stop.sh [--dry-run]
set -u
IDLE_HOURS=${IDLE_HOURS:-3}
CPU_SEC_PER_HOUR=${CPU_SEC_PER_HOUR:-60}   # below this a container counts as idle (idle Postgres uses ~1 s/h)
NET_MB_PER_HOUR=${NET_MB_PER_HOUR:-2}
KEEP_FILE=${KEEP_FILE:-$HOME/.config/docker-idle-stop/keep}
STATE=${STATE:-$HOME/.local/state/docker-idle-stop/state.tsv}
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1

mkdir -p "$(dirname "$STATE")" "$(dirname "$KEEP_FILE")"
[ -f "$KEEP_FILE" ] || printf '# one container name per line; these are never stopped\nroll-engine-ref\n' > "$KEEP_FILE"
touch "$STATE"
now=$(date +%s)
new_state=$(mktemp)

for id in $(docker ps -q --no-trunc); do
  read -r name pid keep < <(docker inspect -f '{{.Name}} {{.State.Pid}} {{index .Config.Labels "keep"}}' "$id")
  name=${name#/}
  cpu=$(awk '/^usage_usec/{print $2}' "/sys/fs/cgroup/system.slice/docker-$id.scope/cpu.stat" 2>/dev/null || echo 0)
  net=$(awk 'NR>2 && $1!="lo:"{b+=$2+$10} END{print b+0}' "/proc/$pid/net/dev" 2>/dev/null || echo 0)

  # previous sample: id ts cpu net last_active
  read -r _ pts pcpu pnet last < <(grep "^$id " "$STATE" || echo "$id $now $cpu $net $now")
  elapsed_h=$(awk -v a="$now" -v b="$pts" 'BEGIN{h=(a-b)/3600; print (h<0.01?0.01:h)}')
  active=$(awk -v c="$cpu" -v pc="$pcpu" -v n="$net" -v pn="$pnet" -v h="$elapsed_h" \
             -v ct="$CPU_SEC_PER_HOUR" -v nt="$NET_MB_PER_HOUR" \
             'BEGIN{print (((c-pc)/1e6/h > ct) || ((n-pn)/1048576/h > nt)) ? 1 : 0}')
  [ "$active" = 1 ] && last=$now
  idle_h=$(( (now - last) / 3600 ))

  if [ "$keep" = "true" ] || grep -qxF "$name" "$KEEP_FILE"; then
    echo "$id $now $cpu $net $last" >> "$new_state"; continue
  fi
  if [ $((now - last)) -ge $((IDLE_HOURS * 3600)) ]; then
    if [ $DRY = 1 ]; then echo "would stop $name (idle ${idle_h}h)"; echo "$id $now $cpu $net $last" >> "$new_state"
    else docker stop -t 30 "$id" >/dev/null && echo "stopped $name (idle ${idle_h}h)"; fi
  else
    echo "$id $now $cpu $net $last" >> "$new_state"
  fi
done

[ $DRY = 1 ] || mv "$new_state" "$STATE"
rm -f "$new_state"
