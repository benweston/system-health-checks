#!/bin/bash

# Comprehensive System, Kernel & Session Forensic Diagnostic Script
# Usage: sudo ./system-checks/01_01_system_check.sh

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "[-] Error: Please execute this script with root privileges (sudo)." >&2
    exit 1
fi

# Resolve project root directory and define the output report path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPORT_DIR="${PROJECT_ROOT}/system-reports"
REPORT_FILE="${REPORT_DIR}/01_01_system_report.txt"

# Ensure destination directory exists
mkdir -p "$REPORT_DIR"

# Ensure the file starts fresh and clean on every run
echo "==================================================" > "$REPORT_FILE"
echo "        SYSTEM DIAGNOSTIC FORENSIC REPORT          " >> "$REPORT_FILE"
echo "        Generated on: $(date)" >> "$REPORT_FILE"
echo "        Host: $(hostname)" >> "$REPORT_FILE"
echo "==================================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Function to inject clean visual banners for readability
log_section() {
    echo "" >> "$REPORT_FILE"
    echo "--------------------------------------------------" >> "$REPORT_FILE"
    echo "  SECTION: $1" >> "$REPORT_FILE"
    echo "--------------------------------------------------" >> "$REPORT_FILE"
}

# 1. Suspend/Wake Power Transitions
log_section "Kernel Suspend / Resume / Wake Events"
journalctl -b 0 --grep='\b(suspend(ed|ing)?|resum(e|ed|ing)|wak(e|ing|eup))\b' -n 200 --no-pager >> "$REPORT_FILE" 2>&1

# 2. Systemd Logind Daemon Activity
log_section "Systemd-Logind Service Status (Lid/Session)"
journalctl -b 0 -u systemd-logind.service --no-pager | tail -n 50 >> "$REPORT_FILE" 2>&1

# 3. Critical Kernel Pitfalls
log_section "Critical Kernel Faults (Failed/Errors/Panics/BUGs)"
journalctl -b 0 -p 0..3 --grep="Failed|Error|Kernel panic|BUG:|Oops" --no-pager >> "$REPORT_FILE" 2>&1

# 4. Hardware Machine Check Exceptions
log_section "Machine Check Exceptions (MCE / Hardware Errors)"
journalctl -b 0 --grep="Machine check|MCE|hardware error" --no-pager >> "$REPORT_FILE" 2>&1

# 5. Dmesg Subsystem Warning/Timeout Trace
log_section "Dmesg Hardware Timeouts and Warnings (Tail 50)"
dmesg -T | grep -Ei "err|fail|crit|warn|timeout" | tail -n 50 >> "$REPORT_FILE" 2>&1

# 6. Storage Controller & PCIe Bus Lockups
log_section "PCIe Bus and Storage Controller Exceptions (NVMe/ATA)"
journalctl -b 0 --grep="nvme|pcie|ata|scsi" -p 0..3 --no-pager >> "$REPORT_FILE" 2>&1

# 7. Physical Storage & Volume Layout
log_section "Storage Topology and LUKS/Btrfs Mapping"
if command -v smartctl &> /dev/null; then
    smartctl --scan >> "$REPORT_FILE" 2>&1
fi
lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINTS,STATE >> "$REPORT_FILE" 2>&1

# 8. Failed System Daemons
log_section "Failed Systemd Service Units"
systemctl list-units --state=failed >> "$REPORT_FILE" 2>&1

# 9. Application and System Coredumps
log_section "Application Crash Coredumps (Last 30 Days)"
coredumpctl list --since="-30 days" --no-pager >> "$REPORT_FILE" 2>&1

echo "" >> "$REPORT_FILE"
echo "==================================================" >> "$REPORT_FILE"
echo "            END OF DIAGNOSTIC REPORT              " >> "$REPORT_FILE"
echo "==================================================" >> "$REPORT_FILE"

# Restore non-root ownership when executed via sudo
if [ -n "${SUDO_USER:-}" ]; then
    chown "${SUDO_USER}:$(id -gn "$SUDO_USER")" "$REPORT_DIR" "$REPORT_FILE"
fi

# Output completion status to stdout
echo "[+] Diagnostic scan completed. Report written to: $REPORT_FILE"
