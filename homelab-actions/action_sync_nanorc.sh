#!/bin/bash
# Sync /etc/nanorc - a nanorc can bind keys to commands, which then run when root
# uses nano, so its NOPASSWD sudoers entry was removed on purpose. This always
# prompts for the sudo password.
export SYNC_PATH="etc/nanorc"
export SYNC_DEST="/etc/nanorc"
exec bash "$(dirname "$0")/libs/action_sync_file_secure.sh"
