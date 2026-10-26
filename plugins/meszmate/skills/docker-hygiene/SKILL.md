---
name: docker-hygiene
description: Use when starting Docker containers, compose stacks, databases (Postgres, Elasticsearch, OpenSearch, Redis, S3/MinIO) or test fixtures on a shared dev server, and when cleaning them up. Prevents leaked containers, volumes and memory from piling up across agents.
---

# Docker on a shared dev server

Many agents share one Docker daemon. Leaked containers add up fast (one day: 45 containers, 111 volumes, 150 Postgres processes, 19 GB of Java). Clean up what you start, and only what you start.

## Starting things

1. **Label and name everything you create** with the worktree it belongs to:
   ```bash
   wt=$(basename "$(git rev-parse --show-toplevel)")
   docker run -d --name "$wt-postgres" --label agent.worktree="$wt" ...
   ```
   For compose, always pass a project name: `docker compose -p "$wt" up -d`.
2. **One-off containers use `--rm`.**
3. **Reuse before you create.** Check `docker ps --filter label=agent.worktree="$wt"` first; do not start a second copy of the same database.
4. **Limit memory**, especially JVM services:
   - Elasticsearch / OpenSearch: `-m 2g -e ES_JAVA_OPTS="-Xms1g -Xmx1g"` (OpenSearch: `OPENSEARCH_JAVA_OPTS`), `-e discovery.type=single-node`
   - anything else heavy: `-m 2g` unless the task needs more.
5. **Ports:** pick a free one (`ss -ltn`), publish with `-p <port>:<port>`. Share URLs with the `preview-urls` skill. Do not change firewall or `DOCKER-USER` rules.

## Cleaning up

When the task is done (or the user says the stack is no longer needed):

```bash
docker compose -p "$wt" down -v          # compose stacks
docker rm -f $(docker ps -aq --filter label=agent.worktree="$wt")
docker volume rm $(docker volume ls -q --filter label=agent.worktree="$wt") 2>/dev/null
```

Leave a container running only if the user is still using it, and say so in your final message.

A timer (`~/.local/bin/docker-idle-stop.sh`, every 30 min) also **stops** containers with no real CPU or network activity for 3 hours. Stopped containers keep their data: if you need one again, `docker start <name>` instead of creating a new one. To protect a long-lived container, add its name to `~/.config/docker-idle-stop/keep` or start it with `--label keep=true`.

## Never

- `docker system prune -a`, `docker volume prune`, or `docker rm -f $(docker ps -aq)`: these delete other agents' and the user's data.
- Removing or recreating containers you did not create (for example long-lived shared databases like `*-ref`). Ask first.
- `docker builder prune` without `--filter until=…`: a timer already prunes build cache older than 72 h.
