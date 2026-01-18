#!/bin/bash

# Hardware Information Extraction Script for Homelab Documentation
# Provides clean, copy-paste ready format for hardware table

echo "Node: $(hostname)"
echo

# CPU Information
CPU_MODEL=$(lscpu | grep "Model name" | sed 's/Model name:[[:space:]]*//' | head -1)
CORES_PER_SOCKET=$(lscpu | grep "Core(s) per socket" | awk '{print $4}')
THREADS_PER_CORE=$(lscpu | grep "Thread(s) per core" | awk '{print $4}')
TOTAL_THREADS=$((CORES_PER_SOCKET * THREADS_PER_CORE))

# Clean up CPU model name - remove extra text and normalize
CPU_CLEAN=$(echo "$CPU_MODEL" | sed 's/([^)]*CPU[^)]*)//g' | sed 's/  */ /g' | xargs)
echo "CPU: $CPU_CLEAN ($CORES_PER_SOCKET cores, $TOTAL_THREADS threads)"

# Hardware Information
HARDWARE_VENDOR=$(hostnamectl | grep "Hardware Vendor" | cut -d: -f2 | xargs)
HARDWARE_MODEL=$(hostnamectl | grep "Hardware Model" | cut -d: -f2 | xargs)
CHASSIS=$(hostnamectl | grep "Chassis" | cut -d: -f2 | xargs | sed 's/🖥️//')
ARCHITECTURE=$(hostnamectl | grep "Architecture" | cut -d: -f2 | xargs)
echo "Hardware: $HARDWARE_VENDOR $HARDWARE_MODEL ($CHASSIS, $ARCHITECTURE)"

# Memory Information
# Try to get hardware details first, fallback to free -h if dmidecode fails
if command -v dmidecode >/dev/null 2>&1; then
    # Get memory array info for total slots
    TOTAL_SLOTS=$(dmidecode --type memory 2>/dev/null | grep "Number Of Devices:" | awk '{print $4}')

    # Get all installed memory modules (exclude "No Module Installed")
    MEMORY_MODULES=$(dmidecode --type memory 2>/dev/null | grep -A 20 "Memory Device" | grep -E "Size:|Type:|Speed:|Part Number:" | grep -v "No Module Installed" | grep -v "Error Correction Type")

    # Count populated slots
    POPULATED_SLOTS=$(dmidecode --type memory 2>/dev/null | grep -A 5 "Memory Device" | grep "Size:" | grep -v "No Module Installed" | wc -l)

    # Calculate total memory by summing all module sizes
    TOTAL_SIZE=0
    MEMORY_TYPE=""
    MEMORY_SPEED=""
    MEMORY_PART=""

    # Extract memory details from first installed module
    MEMORY_TYPE=$(echo "$MEMORY_MODULES" | grep "Type:" | grep -v "Type Detail" | head -1 | awk '{print $2}')
    MEMORY_SPEED=$(echo "$MEMORY_MODULES" | grep "Speed:" | head -1 | awk '{print $2 " " $3}')
    MEMORY_PART=$(echo "$MEMORY_MODULES" | grep "Part Number:" | head -1 | awk '{print $3}' | xargs)

    # Sum up all memory sizes
    while read -r line; do
        if [[ $line == *"Size:"* ]] && [[ $line != *"No Module"* ]]; then
            SIZE=$(echo "$line" | awk '{print $2}')
            if [[ $SIZE =~ ^[0-9]+$ ]]; then
                TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
            fi
        fi
    done <<< "$MEMORY_MODULES"

    if [ $TOTAL_SIZE -gt 0 ] && [ ! -z "$MEMORY_TYPE" ] && [ ! -z "$TOTAL_SLOTS" ]; then
        if [ ! -z "$MEMORY_SPEED" ] && [ ! -z "$MEMORY_PART" ]; then
            echo "Memory: ${TOTAL_SIZE}GB $MEMORY_TYPE @ ${MEMORY_SPEED} ($MEMORY_PART) - $POPULATED_SLOTS/$TOTAL_SLOTS slots used"
        else
            echo "Memory: ${TOTAL_SIZE}GB $MEMORY_TYPE ($POPULATED_SLOTS/$TOTAL_SLOTS slots used)"
        fi
    elif [ $TOTAL_SIZE -gt 0 ] && [ ! -z "$MEMORY_TYPE" ]; then
        if [ ! -z "$MEMORY_SPEED" ] && [ ! -z "$MEMORY_PART" ]; then
            echo "Memory: ${TOTAL_SIZE}GB $MEMORY_TYPE @ ${MEMORY_SPEED} ($MEMORY_PART)"
        else
            echo "Memory: ${TOTAL_SIZE}GB $MEMORY_TYPE"
        fi
    else
        # Fallback to free -h
        MEMORY_TOTAL=$(free -h | grep "Mem:" | awk '{print $2}')
        echo "Memory: ${MEMORY_TOTAL}B RAM"
    fi
else
    # Fallback if dmidecode not available
    MEMORY_TOTAL=$(free -h | grep "Mem:" | awk '{print $2}')
    echo "Memory: ${MEMORY_TOTAL}B RAM"
fi

# Storage Information
MAIN_DISK=$(lsblk -d -o NAME,SIZE | grep -E "^sd|^nvme" | head -1)
DISK_SIZE=$(echo "$MAIN_DISK" | awk '{print $2}')
USABLE_SIZE=$(df -h / | tail -1 | awk '{print $2}')

if lvs &>/dev/null; then
    echo "Storage: ${DISK_SIZE}B HDD (LVM managed, ${USABLE_SIZE}B usable)"
else
    echo "Storage: ${DISK_SIZE}B storage (${USABLE_SIZE}B usable)"
fi

# Network Information
ETH_INTERFACE=$(ip link show | grep -E "^[0-9]+: e" | head -1 | cut -d: -f2 | xargs)
MTU=$(ip link show "$ETH_INTERFACE" 2>/dev/null | grep -o "mtu [0-9]*" | cut -d' ' -f2)

if [ ! -z "$ETH_INTERFACE" ] && [ ! -z "$MTU" ]; then
    echo "Network: Gigabit Ethernet ($ETH_INTERFACE interface, $MTU MTU)"
else
    echo "Network: Gigabit Ethernet"
fi

# OS Information
OS_INFO=$(hostnamectl | grep "Operating System" | cut -d: -f2 | xargs)
echo "OS: $OS_INFO"

# Kernel Information
KERNEL_VERSION=$(uname -r)
echo "Kernel: $KERNEL_VERSION"
