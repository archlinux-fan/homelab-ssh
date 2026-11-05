#!/bin/bash

HOSTS=($TARGET_HOSTS)
source "$(dirname "$0")/libs/lib_check_host.sh"

menu_title SUB "=== RUN CUSTOM AD-HOC COMMAND ==="
ask "Enter command to execute ([Enter] back, [q] quit): " CUSTOM_CMD
[[ "$CUSTOM_CMD" == "q" || "$CUSTOM_CMD" == "Q" ]] && { echo "Quit."; exit 0; }

if [ -z "$CUSTOM_CMD" ]; then
    echo "No command entered - nothing to do."
    exit "$EXIT_BACK_TO_MENU"
fi

echo -e "--------------------------------------------"
echo -e "Executing: \033[1;36m$CUSTOM_CMD\033[0m on ${#HOSTS[@]} hosts."
echo -e "--------------------------------------------"

for HOST in "${HOSTS[@]}"; do
    echo -e "\n\033[1;35m[ $HOST ]\033[0m"

    # Bug fix: the original script sourced lib_check_host.sh but never
    # actually called it, so a dead/unreachable host would just hang or
    # error out on the ssh line below instead of being skipped cleanly.
    if ! check_host_alive "$HOST"; then
        continue
    fi

    # -t ensures interactive programs work, non-blocking SSH execute
    ssh -t "$HOST" "$CUSTOM_CMD"
done

echo -e "\n\033[1;32m🎉 Custom command execution finished!\033[0m"
exit "$EXIT_MAIN_MENU"
