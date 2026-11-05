#!/bin/bash
# Sync /etc/ssh/sshd_config and restart the ssh service. Writing this file
# controls SSH access itself, so its NOPASSWD sudoers entry was removed on
# purpose - this always prompts for the sudo password. Restarting the
# service stays passwordless (low risk on its own, see sudoers.d/homelab).
export SYNC_PATH="etc/ssh/sshd_config"
export SYNC_DEST="/etc/ssh/sshd_config"
export SYNC_CUSTOM_CMD="sudo systemctl restart ssh"
exec bash "$(dirname "$0")/libs/action_sync_file_secure.sh"
