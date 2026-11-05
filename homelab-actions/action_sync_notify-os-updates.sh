#!/bin/bash
# Sync /usr/local/bin/notify-os-updates.sh and make sure the periodic cron
# job that runs it exists. This script runs unattended via cron, so its
# NOPASSWD sudoers entry was removed on purpose - this always prompts for
# the sudo password.
export SYNC_PATH="usr/local/bin/notify-os-updates.sh"
export SYNC_DEST="/usr/local/bin/notify-os-updates.sh"
export SYNC_CUSTOM_CMD='sudo chmod +x /usr/local/bin/notify-os-updates.sh && (sudo crontab -l 2>/dev/null | grep -qF "/usr/local/bin/notify-os-updates.sh" || (sudo crontab -l 2>/dev/null; echo "0 8,19 * * * sleep \$(shuf -i 0-300 -n 1); /usr/local/bin/notify-os-updates.sh > /dev/null 2>&1") | sudo crontab -)'
exec bash "$(dirname "$0")/libs/action_sync_file_secure.sh"
