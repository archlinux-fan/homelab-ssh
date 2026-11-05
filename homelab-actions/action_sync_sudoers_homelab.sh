#!/bin/bash
# ==============================================================================
# Sync /etc/sudoers.d/homelab from your files repo to all target hosts.
#
# SAFETY CRITICAL: this file grants passwordless root privileges, so its
# syntax is ALWAYS validated with `visudo -c` before it touches the real
# file. A broken sudoers file can lock you out of sudo entirely on that host.
#
# This action is intentionally NOT covered by any NOPASSWD rule - a
# password-less way to rewrite the password-less privilege list would defeat
# its own purpose. Expect a sudo password prompt here, on every host.
# ==============================================================================
HOSTS=($TARGET_HOSTS)
source "$(dirname "$0")/libs/lib_check_host.sh"
SUDOERS_URL=$(sync_url "etc/sudoers.d/homelab") || exit "$EXIT_BACK_TO_MENU"
SUDOERS_DEST="/etc/sudoers.d/homelab"

LOCAL_TMP="$(mktemp)"
trap 'rm -f "$LOCAL_TMP"' EXIT

echo -e "\033[1;36m➜ Fetching sudoers.d/homelab ...\033[0m"
if ! curl -sfL "$SUDOERS_URL" -o "$LOCAL_TMP"; then
    echo -e "\033[1;31m[!] Failed to download sudoers.d/homelab.\033[0m"
    exit "$EXIT_BACK_TO_MENU"
fi

for HOST in "${HOSTS[@]}"; do
    echo -e "\n\033[1;36m➜ Checking availability of $HOST ...\033[0m"
    if ! check_host_alive "$HOST"; then
        continue
    fi

    echo -e "\033[1;34m➜ Staging sudoers.d/homelab on $HOST...\033[0m"
    REMOTE_TMP="/tmp/sudoers_homelab.$$"

    # Push the already-downloaded file to a temp path WITHOUT sudo.
    if ! stage_remote_file "$HOST" "$LOCAL_TMP" "$REMOTE_TMP" "sudoers.d/homelab"; then
        continue
    fi

    # Separate, interactive SSH session (-t forces a pseudo-tty) so sudo can
    # prompt for a password - this action has no NOPASSWD rule, on purpose.
    #
    # - "visudo -c -f": validates the staged file's syntax BEFORE it ever
    #   touches the real /etc/sudoers.d/homelab. If this fails, the chain
    #   stops here and the currently-active sudoers file is left untouched.
    # - "install -m 0440": sudoers.d files must be root:root, mode 0440
    #   (read-only, no group/other write), or sudo silently ignores them.
    if ssh -t "$HOST" "
        sudo visudo -c -f $REMOTE_TMP &&
        sudo install -o root -g root -m 0440 $REMOTE_TMP $SUDOERS_DEST &&
        rm -f $REMOTE_TMP
    "; then
        echo -e "\033[1;32m✓ sudoers.d/homelab validated and updated on $HOST\033[0m"
    else
        echo -e "\033[1;31m✗ Aborted on $HOST (syntax check failed or sudo error) - existing sudoers file left untouched\033[0m"
        # Best-effort cleanup of the temp file even on failure/rejected password.
        ssh "$HOST" "rm -f $REMOTE_TMP" 2>/dev/null
    fi
done

exit "$EXIT_MAIN_MENU"
