#!/bin/bash
HOSTS=($TARGET_HOSTS)
source "$(dirname "$0")/libs/lib_check_host.sh"

i=0
while [ $i -lt ${#HOSTS[@]} ]; do
    HOST=${HOSTS[$i]}
    echo -e "\n${C_SUB}======================================================="
    menu_title SUB "➜ RUNNING SYSTEM UPDATE: $HOST"
    echo -e "=======================================================\033[0m"

    if ! check_host_alive "$HOST"; then
        ((i++))
        continue
    fi

    ssh -t "$HOST" "sudo apt update && sudo apt dist-upgrade && sudo apt autoremove && sudo apt clean"

    confirm_next $(( ${#HOSTS[@]} - i - 1 ))
    ((i++))
done
echo -e "\n\033[1;32m🎉 All hosts successfully updated!\033[0m"
exit "$EXIT_MAIN_MENU"
