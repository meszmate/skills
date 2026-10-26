#!/usr/bin/env bash
# Install the dev-server maintenance scripts and timers for the current user.
# Safe to re-run: it overwrites the installed copies with the ones in this repo.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p ~/.local/bin ~/.config/systemd/user
install -m 755 "$here/cleanup-builds.sh" "$here/docker-idle-stop.sh" ~/.local/bin/
install -m 644 "$here"/systemd/*.service "$here"/systemd/*.timer ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now cleanup-builds.timer docker-idle-stop.timer
systemctl --user list-timers cleanup-builds.timer docker-idle-stop.timer --no-pager | head -3
