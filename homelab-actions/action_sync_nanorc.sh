#!/bin/bash
# Sync /etc/nanorc - negligible risk, still covered by a NOPASSWD sudoers
# entry, so this runs without any password prompt.
export SYNC_PATH="etc/nanorc"
export SYNC_DEST="/etc/nanorc"
exec bash "$(dirname "$0")/libs/action_sync_file.sh"
