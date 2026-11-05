#!/bin/bash
# action_sync_file.sh - generic PASSWORDLESS file sync.
# Only use this for files still covered by a NOPASSWD sudoers entry
# (currently: nanorc). Called by a thin wrapper script that exports:
#   SYNC_PATH  - path of the file in your files repo (SYNC_BASE in the config)
#   SYNC_DEST  - destination path on remote host
HOSTS=($TARGET_HOSTS)
source "$(dirname "$0")/lib_check_host.sh"
SYNC_URL=$(sync_url "$SYNC_PATH") || exit "$EXIT_BACK_TO_MENU"

# Download once; -f: a missing file is an error, not an error page or an empty file on the hosts.
LOCAL_TMP="$(mktemp)"
trap 'rm -f "$LOCAL_TMP"' EXIT
if ! curl -sfL "$SYNC_URL" -o "$LOCAL_TMP"; then
    echo -e "\033[1;31m[!] Failed to download $(basename "$SYNC_DEST") from $SYNC_URL\033[0m"
    exit "$EXIT_BACK_TO_MENU"
fi

for HOST in "${HOSTS[@]}"; do
    echo -e "\n\033[1;36m➜ Checking availability of $HOST ...\033[0m"
    if ! check_host_alive "$HOST"; then
        continue
    fi

    echo -e "\033[1;34m➜ Writing $(basename "$SYNC_DEST") to $HOST...\033[0m"

    # The file goes straight into the SSH channel; on the remote host sudo tee
    # overwrites it. No password prompt, since this exact command is in the
    # remote host's NOPASSWD sudoers list.
    if ssh "$HOST" "sudo tee $SYNC_DEST > /dev/null" < "$LOCAL_TMP"; then
        echo -e "\033[1;32m✓ $(basename "$SYNC_DEST") updated on $HOST\033[0m"
    else
        echo -e "\033[1;31m✗ Update failed on $HOST\033[0m"
    fi
done

exit "$EXIT_MAIN_MENU"
