#!/bin/bash
# action_docker_update.sh - Update one or more Docker Compose stacks on the
# selected host(s).
#
# For each host, the list of stacks (folders) is auto-detected by SSH-ing in
# and listing the subfolders of DOCKER_BASE_DIR (default: /srv/docker-compose).
# If that fails (host unreachable mid-scan, path missing, empty result...),
# it falls back to ~/.config/homelab/docker_folders.conf, where stacks can be
# listed manually per host as a last resort:
#
#   host:folder1,folder2,folder3
#
# If even that has no entry for the host, you get one last chance to type
# folder name(s) in by hand for that run.
#
# "Update" means: docker compose pull && docker compose up -d --remove-orphans
# in that folder. This assumes the remote user is already in the "docker"
# group (same as the dcu/dcd aliases used interactively), so no sudo prompt
# is expected here.
HOSTS=($TARGET_HOSTS)
source "$(dirname "$0")/libs/lib_check_host.sh"

DOCKER_BASE_DIR="${DOCKER_BASE_DIR:-/srv/docker-compose}"
FOLDERS_CONF="$HOMELAB_CONFIG/docker_folders.conf"

# Auto-detect subfolders of DOCKER_BASE_DIR on the remote host.
list_remote_folders() {
    local host="$1"
    ssh -o ConnectTimeout=5 "$host" \
        "find '$DOCKER_BASE_DIR' -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort" \
        2>/dev/null
}

# Fallback: "host:folder1,folder2" line in docker_folders.conf.
list_fallback_folders() {
    local host="$1"
    [ -f "$FOLDERS_CONF" ] || return 0
    local line
    line=$(grep -m1 "^${host}:" "$FOLDERS_CONF")
    [ -n "$line" ] || return 0
    echo "${line#*:}" | tr ',' '\n'
}

i=0
while [ $i -lt ${#HOSTS[@]} ]; do
    HOST=${HOSTS[$i]}
    new_screen
    echo -e "${C_SUB}======================================================="
    menu_title SUB "➜ UPDATING DOCKER STACKS: $HOST"
    echo -e "=======================================================\033[0m"

    if ! check_host_alive "$HOST"; then
        ((i++))
        continue
    fi

    echo -e "\033[1;36m➜ Scanning $DOCKER_BASE_DIR on $HOST ...\033[0m"
    mapfile -t FOLDERS < <(list_remote_folders "$HOST")

    if [ ${#FOLDERS[@]} -eq 0 ]; then
        echo -e "\033[1;33m[!] Auto-scan found nothing (unreachable path, empty, or permission issue).\033[0m"
        echo -e "\033[1;36m➜ Checking docker_folders.conf fallback ...\033[0m"
        mapfile -t FOLDERS < <(list_fallback_folders "$HOST")
    fi

    if [ ${#FOLDERS[@]} -eq 0 ]; then
        echo -e "\033[1;33m[!] No known stacks for $HOST. You can type folder name(s) manually,\033[0m"
        echo -e "\033[1;33m    comma-separated (relative to $DOCKER_BASE_DIR), leave empty to skip,\033[0m"
        echo -e "\033[1;33m    [b] back to action menu, [q] quit.\033[0m"
        ask "${C_SUB}Folder name(s): " MANUAL_INPUT
        if [[ "$MANUAL_INPUT" == "b" || "$MANUAL_INPUT" == "B" ]]; then
            exit "$EXIT_BACK_TO_MENU"
        fi
        if [[ "$MANUAL_INPUT" == "q" || "$MANUAL_INPUT" == "Q" ]]; then
            echo "Quit."; exit 0
        fi
        if [ -z "$MANUAL_INPUT" ]; then
            echo -e "\033[1;33m↷ Skipping $HOST ...\033[0m"
            ((i++))
            continue
        fi
        IFS=',' read -ra FOLDERS <<< "$MANUAL_INPUT"
        for idx in "${!FOLDERS[@]}"; do
            FOLDERS[$idx]="${FOLDERS[$idx]// /}"
        done
    else
        menu_title SUB "=== STACKS FOUND ON $HOST ==="
        echo "  [Enter] ALL STACKS"
        for j in "${!FOLDERS[@]}"; do
            echo "  [$((j+1))] ${FOLDERS[$j]}"
        done
        echo "  [s] Skip this host"
        echo "  [b] Back to action menu"
        echo "  [q] Quit"
        echo -e "--------------------------------------------"
        ask "Choose stack number(s) (e.g. 1,3), [Enter] all or [b] action menu: " STACK_REPLY

        if [[ "$STACK_REPLY" == "q" || "$STACK_REPLY" == "Q" ]]; then
            echo "Quit."; exit 0
        fi

        if [[ "$STACK_REPLY" == "s" || "$STACK_REPLY" == "S" ]]; then
            echo -e "\033[1;33m↷ Skipping $HOST ...\033[0m"
            ((i++))
            continue
        fi

        if [[ "$STACK_REPLY" == "b" || "$STACK_REPLY" == "B" ]]; then
            exit "$EXIT_BACK_TO_MENU"
        fi

        if [ -n "$STACK_REPLY" ]; then
            SELECTED=()
            IFS=',' read -ra PICKS <<< "$STACK_REPLY"
            for p in "${PICKS[@]}"; do
                p="${p// /}"
                if [[ "$p" =~ ^[0-9]+$ ]] && [ "$p" -ge 1 ] && [ "$p" -le "${#FOLDERS[@]}" ]; then
                    SELECTED+=("${FOLDERS[$((p-1))]}")
                else
                    echo -e "\033[1;31m[!] Ignoring invalid selection: $p\033[0m"
                fi
            done
            FOLDERS=("${SELECTED[@]}")
        fi
    fi

    if [ ${#FOLDERS[@]} -eq 0 ]; then
        echo -e "\033[1;33m[!] Nothing selected for $HOST, skipping.\033[0m"
        ((i++))
        continue
    fi

    for FOLDER in "${FOLDERS[@]}"; do
        echo -e "\n\033[1;35m[ $HOST :: $FOLDER ]\033[0m"
        if ssh -t "$HOST" "cd '$DOCKER_BASE_DIR/$FOLDER' && docker compose pull && docker compose up -d --remove-orphans"; then
            echo -e "\033[1;32m✓ $FOLDER updated on $HOST\033[0m"
        else
            echo -e "\033[1;31m✗ $FOLDER failed to update on $HOST\033[0m"
        fi
    done

    echo ""
    ask "${C_SUB}Run 'docker image prune -f' on $HOST to remove now-unused images? [y/N]: " PRUNE_REPLY
    if [[ "$PRUNE_REPLY" =~ ^[Yy]$ ]]; then
        ssh -t "$HOST" "docker image prune -f"
    fi

    # [r] rescans this host and shows the stack menu again
    confirm_next $(( ${#HOSTS[@]} - i - 1 )) "Update more stacks on this host" && ((i++))
done
echo -e "\n\033[1;32m🎉 Docker stack update run finished!\033[0m"
exit "$EXIT_MAIN_MENU"
