#!/bin/bash
# Shared helpers used by the action scripts in this folder and its libs/
# subfolder.

# Your settings (where synced files come from ...), see config.example.
HOMELAB_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/homelab"
[ -f "$HOMELAB_CONFIG/config" ] && source "$HOMELAB_CONFIG/config"

# Exit codes an action script uses to tell homelab where to go next,
# instead of ending the program - only an explicit [q] Quit ends it.
EXIT_BACK_TO_MENU=2 # [b] / errors: action menu (STEP 2), same target host(s)
EXIT_MAIN_MENU=3    # action finished: main menu (STEP 1)

# Menu colors per level: Nord lightened x1.3, same as the foot palette
# (truecolor; real ESC chars, so they work in both `echo -e` and `read -p`).
C_MAIN=$'\033[38;2;163;206;218m'   # nord8  frost  - main menu
C_HOST=$'\033[38;2;184;205;166m'   # nord14 green  - host menu
C_ACTION=$'\033[38;2;197;168;191m' # nord15 purple - action menu
C_SUB=$'\033[38;2;218;162;145m'    # nord12 orange - inside an action

# menu_title <MAIN|HOST|ACTION|SUB> <text>: bold title; the level color
# stays on for the menu items and prompt, until ask() resets it.
menu_title() { local c="C_$1"; echo -e "${!c}\033[1m$2\033[22m"; }
# ask <prompt> <var>
ask() { read -rp "$1" "$2"; echo -ne '\033[0m'; }
# new_screen: the next menu on an empty screen. The old lines scroll up into the
# terminal's history (scroll back to see them), unlike clear, which deletes them.
new_screen() { printf '\n%.0s' $(seq "$(tput lines 2>/dev/null || echo 40)"); printf '\033[H'; }

# wait_bar <pid> <max_s>: braille dot bar filling left to right while <pid>
# runs (full at max_s), cleared when done. 30 chars (~6-8 cm); the leading
# char rises dot by dot (⣀⣄⣤⣦⣶⣷) out of a dim nord3 track.
wait_bar() {
    local pid="$1" max="$2" w=30 t=0 n j bar lv=(⣀ ⣄ ⣤ ⣦ ⣶ ⣷)
    while kill -0 "$pid" 2>/dev/null; do
        n=$(( t++ * w * 6 / (max * 10) )); (( n > w * 6 )) && n=$(( w * 6 ))
        bar=$C_SUB
        for ((j = 0; j < w; j++)); do
            if ((j < n / 6)); then bar+=⣿
            elif ((j == n / 6)); then bar+=${lv[n % 6]}$'\033[38;2;76;86;106m'
            else bar+=⣀; fi
        done
        printf '\r%s\033[0m' "$bar"; sleep 0.1
    done
    printf '\r\033[K'
}

# Usage: if check_host_alive "$HOST"; then ... else continue; fi
check_host_alive() {
    local host="$1" reply pid
    # Unreachable: wait for the user (e.g. to power the container on) and retry
    while true; do
        # ssh in background, so the wait shows as a bar (full = 5s timeout)
        ssh -n -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$host" exit 2>/dev/null &
        pid=$!
        wait_bar "$pid" 5
        wait "$pid" && return 0

        echo -e "\033[1;31m[!] Host '$host' is unreachable (powered off / down?).\033[0m$C_SUB"
        echo "  [Enter/r] Retry"
        echo "  [s]       Skip this host"
        echo "  [b]       Back to action menu"
        echo "  [q]       Quit"
        ask "Choice: " reply
        case "$reply" in
            [Ss]) echo -e "\033[1;33m↷ Skipping $host ...\033[0m"; return 1 ;;
            [Bb]) exit "$EXIT_BACK_TO_MENU" ;;
            [Qq]) echo "Quit."; exit 0 ;;
            *) echo -e "\033[1;36m➜ Retrying $host ...\033[0m" ;;
        esac
    done
}

# Shared "what's next" prompt used by actions that loop over multiple hosts
# one at a time (currently: OS update, Docker update).
# Usage: confirm_next <hosts left after this one> [label for [r]]
#   0 = proceed to next host, or finish if none left (returned)
#   1 = [r] more on current host, only offered with a label (returned)
# "Back" and "quit" leave that per-host loop entirely, so they're handled
# here directly via `exit` rather than a return value.
confirm_next() {
    local left="${1:-1}" more="$2"
    while true; do
        menu_title SUB "\n[?] Host completed. What's next?"
        if [ "$left" -gt 0 ]; then
            echo "  [Enter/n] Proceed to next host ($left left)"
        else
            echo "  [Enter]   Done, back to main menu"
        fi
        [ -n "$more" ] && echo "  [r]       $more"
        echo "  [b]       Back to action menu"
        echo "  [q]       Quit"
        ask "Choice: " REPLY
        echo ""

        if [[ -z "$REPLY" || "$REPLY" =~ ^[Nn]$ ]]; then
            return 0 # Next host / done
        elif [[ -n "$more" && "$REPLY" =~ ^[Rr]$ ]]; then
            return 1
        elif [[ "$REPLY" =~ ^[Bb]$ ]]; then
            exit "$EXIT_BACK_TO_MENU" # homelab prints "Back to action menu"
        elif [[ "$REPLY" =~ ^[Qq]$ ]]; then
            echo "Quit."; exit 0
        else
            echo -e "\033[1;31m[!] Invalid key.\033[0m"
        fi
    done
}

# sync_url <path>: address of <path> in your files repo (SYNC_BASE in the config).
sync_url() {
    if [ -z "$SYNC_BASE" ]; then
        echo -e "\033[1;31m[!] Set SYNC_BASE in $HOMELAB_CONFIG/config (see config.example).\033[0m" >&2
        exit "$EXIT_BACK_TO_MENU"
    fi
    echo "$SYNC_BASE/$1"
}

# Push a local file to $host as $remote_tmp_path, without sudo. Used to
# stage a new version of a file before a separate, sudo-authenticated step
# writes it to its real (possibly privileged) destination.
#
# Both "secure" sync scripts (action_sync_file_secure.sh and
# action_sync_sudoers_homelab.sh) used to curl straight into an ssh pipe
# with identical code; both now fetch to a local temp file first and push
# it from here instead.
stage_remote_file() {
    local host="$1"
    local local_path="$2"
    local remote_tmp_path="$3"
    local label="${4:-$(basename "$remote_tmp_path")}"

    if ! ssh "$host" "cat > $remote_tmp_path" < "$local_path"; then
        echo -e "\033[1;31m✗ Failed to upload $label to $host\033[0m"
        return 1
    fi
    return 0
}
