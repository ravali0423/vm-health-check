#!/bin/bash

# Colors for output
# Colors for output (macOS compatible)
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

# Thresholds
CPU_THRESHOLD=1
MEM_THRESHOLD=1
DISK_THRESHOLD=1

# Flags
explain=false

# --------- CPU Check ----------
check_cpu() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: use ps
        cpu=$(ps -A -o %cpu | awk '{s+=$1} END {print s}')
    else
        # Linux
        cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    fi

    cpu=${cpu%.*}
    if [ "$cpu" -ge "$CPU_THRESHOLD" ]; then
        msg="${RED}✖ CPU usage is high: ${cpu}%${RESET}"
        [ "$explain" = true ] && msg="$msg → Performance may degrade under high load."
        exit_code=2
    else
        msg="${GREEN}✔ CPU usage is healthy: ${cpu}%${RESET}"
        exit_code=0
    fi
    echo -e "$msg"
    return $exit_code
}


# --------- Memory Check ----------
check_memory() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: use vm_stat
        pages_free=$(vm_stat | awk '/Pages free/ {print $3}' | sed 's/\.//')
        pages_active=$(vm_stat | awk '/Pages active/ {print $3}' | sed 's/\.//')
        pages_inactive=$(vm_stat | awk '/Pages inactive/ {print $3}' | sed 's/\.//')
        pages_spec=$(vm_stat | awk '/Pages speculative/ {print $3}' | sed 's/\.//')
        pages_wired=$(vm_stat | awk '/Pages wired down/ {print $4}' | sed 's/\.//')
        total_pages=$((pages_free + pages_active + pages_inactive + pages_spec + pages_wired))
        used_pages=$((pages_active + pages_inactive + pages_spec + pages_wired))
        mem_usage=$((100 * used_pages / total_pages))
    else
        # Linux: use free
        mem_usage=$(free | awk '/Mem/ {printf("%.0f", $3/$2 * 100)}')
    fi

    if [ "$mem_usage" -ge "$MEM_THRESHOLD" ]; then
        msg="${YELLOW}⚠ Memory usage is high: ${mem_usage}%${RESET}"
        [ "$explain" = true ] && msg="$msg → System may experience memory pressure."
        exit_code=2
    else
        msg="${GREEN}✔ Memory usage is healthy: ${mem_usage}%${RESET}"
        exit_code=0
    fi
    echo -e "$msg"
    return $exit_code
}


# --------- Disk Check ----------
check_disk() {
    disk_usage=$(df / | awk 'END {print $5}' | sed 's/%//')
    if [ "$disk_usage" -ge "$DISK_THRESHOLD" ]; then
        msg="${YELLOW}⚠ Disk usage is high: ${disk_usage}%${RESET}"
        [ "$explain" = true ] && msg="$msg → Consider cleaning logs or freeing up space."
        exit_code=2
    else
        msg="${GREEN}✔ Disk usage is healthy: ${disk_usage}%${RESET}"
        exit_code=0
    fi
    echo -e "$msg"
    return $exit_code
}

# --------- Main Execution ----------
main() {
    case "$1" in
        --explain) explain=true
    esac

    echo "----- VM Health Check -----"
    check_cpu; cpu_status=$?
    check_memory; mem_status=$?
    check_disk; disk_status=$?

    # Aggregate exit codes (critical > warning > ok)
    if [ $cpu_status -eq 2 ] && [ $mem_status -eq 2 ] && [ $disk_status -eq 2 ]; then
        overall=2
    elif [ $cpu_status -eq 2 ] || [ $mem_status -eq 2 ] || [ $disk_status -eq 2 ]; then
        overall=1
    else
        overall=0
    fi

    echo "---------------------------"
    case $overall in
        0) echo -e "${GREEN}Overall Status: HEALTHY ✅${RESET}" ;;
        1) echo -e "${YELLOW}Overall Status: WARNING ⚠${RESET}" ;;
        2) echo -e "${RED}Overall Status: CRITICAL ❌${RESET}" ;;
    esac

    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] CPU: $cpu% | MEM: $mem_usage% | DISK: $disk_usage% | STATUS: $overall" >> ./vm_health.log 2>/dev/null


    exit $overall
}

main "$@"
