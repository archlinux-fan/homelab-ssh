#!/bin/bash
# Sync /etc/zsh/zshrc - executes on every zsh login, so its NOPASSWD sudoers
# entry was removed on purpose. This always prompts for the sudo password.
# The zshrc is joined from a folder of zsh parts (*.zsh, in name order), given as
# ZSH_PARTS_API in the config; parts named in ZSH_SKIP are left out, and a new part
# is included by itself.
source "$(dirname "$0")/libs/lib_check_host.sh"
if [ -z "$ZSH_PARTS_API" ]; then
    echo -e "\033[1;31m[!] Set ZSH_PARTS_API in $HOMELAB_CONFIG/config (see config.example).\033[0m"
    exit "$EXIT_BACK_TO_MENU"
fi
export SYNC_URL=$(curl -sf "$ZSH_PARTS_API" | jq -r --arg skip " ${ZSH_SKIP-git pacman} " '
    sort_by(.name)[] | select(.name | endswith(".zsh"))
    | (.name | sub("^[0-9]+-"; "") | rtrimstr(".zsh")) as $part
    | select($skip | contains(" " + $part + " ") | not) | .download_url')
# Nothing found (address wrong, server down): stop, or the sync would fetch SYNC_BASE itself
if [ -z "$SYNC_URL" ]; then
    echo -e "\033[1;31m[!] No zsh parts found at $ZSH_PARTS_API\033[0m"
    exit "$EXIT_BACK_TO_MENU"
fi
export SYNC_DEST="/etc/zsh/zshrc"
exec bash "$(dirname "$0")/libs/action_sync_file_secure.sh"
