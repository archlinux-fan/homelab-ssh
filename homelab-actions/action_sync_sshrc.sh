#!/bin/bash
# Sync /etc/ssh/sshrc - executes on every SSH login, so its NOPASSWD sudoers
# entry was removed on purpose. This always prompts for the sudo password.
export SYNC_PATH="etc/ssh/sshrc"
export SYNC_DEST="/etc/ssh/sshrc"
exec bash "$(dirname "$0")/libs/action_sync_file_secure.sh"
