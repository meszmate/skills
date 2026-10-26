#!/usr/bin/env bash
# Install the dev-server maintenance scripts and timers for the current user.
# Safe to re-run: it overwrites the installed copies with the ones in this repo.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p ~/.local/bin ~/.config/systemd/user
install -m 755 "$here/cleanup-builds.sh" ~/.local/bin/cleanup-builds.sh
install -m 644 "$here"/systemd/cleanup-builds.{service,timer} ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now cleanup-builds.timer
echo "installed; next run: $(systemctl --user list-timers cleanup-builds.timer --no-pager | sed -n 2p | awk '{print $1,$2,$3}')"
