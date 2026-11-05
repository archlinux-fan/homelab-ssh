#!/bin/bash
# action_sync_file_secure.sh - generic file sync for files WITHOUT a NOPASSWD
# sudoers entry (medium+ risk: they get parsed/executed on login, or control
# SSH access). Always prompts for the sudo password. Called by a thin
# wrapper script that exports:
#   SYNC_PATH         - path of the file in your files repo (SYNC_BASE in the config)
#   SYNC_URL          - or full URL(s) instead; several (space or newline separated)
#                        are joined into one file, in that order
#   SYNC_DEST         - destination path on remote host
#   SYNC_CUSTOM_CMD  - optional command to run after the file is written
#                        (e.g. "sudo systemctl restart ssh")
HOSTS=($TARGET_HOSTS)
source "$(dirname "$0")/lib_check_host.sh"
new_screen
[ -n "$SYNC_URL" ] || SYNC_URL=$(sync_url "$SYNC_PATH") || exit "$EXIT_BACK_TO_MENU"

LOCAL_TMP="$(mktemp)"
trap 'rm -f "$LOCAL_TMP"' EXIT

echo -e "\033[1;36m➜ Fetching $(basename "$SYNC_DEST") ...\033[0m"
# -f: a missing file is an error, not an error page written as the file
if ! curl -sfL --fail-early $SYNC_URL > "$LOCAL_TMP"; then
    echo -e "\033[1;31m[!] Failed to download $(basename "$SYNC_DEST").\033[0m"
    exit "$EXIT_BACK_TO_MENU"
fi

for HOST in "${HOSTS[@]}"; do
    echo -e "\n\033[1;36m➜ Checking availability of $HOST ...\033[0m"
    if ! check_host_alive "$HOST"; then
        continue
    fi

    echo -e "\033[1;34m➜ Staging $(basename "$SYNC_DEST") on $HOST...\033[0m"
    REMOTE_TMP="/tmp/$(basename "$SYNC_DEST").$$"

    # Step 1: push the already-downloaded file to a temp path WITHOUT
    # sudo. This step needs no password.
    if ! stage_remote_file "$HOST" "$LOCAL_TMP" "$REMOTE_TMP" "$(basename "$SYNC_DEST")"; then
        continue
    fi

    # Step 2: separate, interactive SSH session (-t forces a pseudo-tty) so
    # sudo has a real terminal to prompt for a password. This file has no
    # NOPASSWD entry on purpose, so expect a prompt here every time.
    if ssh -t "$HOST" "
        sudo tee $SYNC_DEST < $REMOTE_TMP > /dev/null &&
        rm -f $REMOTE_TMP ${SYNC_CUSTOM_CMD:+&& $SYNC_CUSTOM_CMD}
    "; then
        echo -e "\033[1;32m✓ $(basename "$SYNC_DEST") updated on $HOST\033[0m"
    else
        echo -e "\033[1;31m✗ Update failed on $HOST (sudo/tee/restart)\033[0m"
        # Best-effort cleanup of the temp file even if the step above failed.
        ssh "$HOST" "rm -f $REMOTE_TMP" 2>/dev/null
    fi
done

exit "$EXIT_MAIN_MENU"
