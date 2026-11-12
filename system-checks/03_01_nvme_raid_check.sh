#!/bin/bash

# Comprehensive NVMe RAID1 & Physical Drive Health Diagnostic Script
# Usage: sudo ./system-checks/03_01_nvme_raid_check.sh

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "[-] Error: Please execute this script with root privileges (sudo)." >&2
    exit 1
fi

# Resolve project root directory and define the output report path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPORT_DIR="${PROJECT_ROOT}/system-reports"
REPORT_FILE="${REPORT_DIR}/03_01_nvme_raid_report.txt"

# Refuse symlinked report directory or output file when running as root
if [ -L "$REPORT_DIR" ] || [ -L "$REPORT_FILE" ]; then
    echo "[-] Error: Refusing to write to symbolic link: $REPORT_FILE" >&2
    exit 1
fi

# Ensure destination directory exists and enforce 0600 report permissions
mkdir -p "$REPORT_DIR"
umask 077
rm -f "$REPORT_FILE"

# Initialize report header
echo "==================================================" > "$REPORT_FILE"
echo "      NVMe RAID1 & DRIVE HEALTH DIAGNOSTIC REPORT  " >> "$REPORT_FILE"
echo "      Generated on: $(date)" >> "$REPORT_FILE"
echo "      Host: $(hostname)" >> "$REPORT_FILE"
echo "==================================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Visual section banner helper
log_section() {
    echo "" >> "$REPORT_FILE"
    echo "--------------------------------------------------" >> "$REPORT_FILE"
    echo "  SECTION: $1" >> "$REPORT_FILE"
    echo "--------------------------------------------------" >> "$REPORT_FILE"
}

# 1. Block Device & Partition Topology
log_section "Block Device Hierarchy & Mount Layout"
lsblk -o NAME,TYPE,FSTYPE,SIZE,UUID,STATE,MOUNTPOINTS >> "$REPORT_FILE" 2>&1

# 2. Linux Software RAID (mdadm) Status & Details
log_section "Linux Software RAID (mdstat & Detailed Arrays)"
if [ -f /proc/mdstat ]; then
    cat /proc/mdstat >> "$REPORT_FILE" 2>&1
    echo "" >> "$REPORT_FILE"
    for array in $(awk '/^md/ {print "/dev/" $1}' /proc/mdstat); do
        echo ">>> mdadm Details for $array <<<" >> "$REPORT_FILE"
        mdadm --detail "$array" >> "$REPORT_FILE" 2>&1
        echo "" >> "$REPORT_FILE"
    done
else
    echo "No /proc/mdstat detected (mdadm driver not loaded or not in use)." >> "$REPORT_FILE"
fi

# 3. Filesystem-Level RAID Status (Btrfs / ZFS Fallback)
log_section "Filesystem-Level RAID Diagnostics (Btrfs / ZFS)"
if command -v btrfs &> /dev/null; then
    echo ">>> Btrfs Filesystem Show <<<" >> "$REPORT_FILE"
    btrfs filesystem show >> "$REPORT_FILE" 2>&1
    echo "" >> "$REPORT_FILE"
fi

if command -v zpool &> /dev/null; then
    echo ">>> ZFS Pool Status <<<" >> "$REPORT_FILE"
    zpool status >> "$REPORT_FILE" 2>&1
    echo "" >> "$REPORT_FILE"
fi

# 4. NVMe Subsystem & Controller Topology
log_section "NVMe Subsystem Device List"
if command -v nvme &> /dev/null; then
    nvme list >> "$REPORT_FILE" 2>&1
    echo "" >> "$REPORT_FILE"
    nvme list-subsys >> "$REPORT_FILE" 2>&1
else
    echo "nvme-cli is not installed. Run: apt install nvme-cli / dnf install nvme-cli" >> "$REPORT_FILE"
fi

# 5. SMART & Health Metrics (Per Physical NVMe Device)
log_section "Physical NVMe Health, Wear, and SMART Logs"
# Discover primary character/block NVMe controllers (nvme0, nvme1, etc.)
NVME_DEVS=$(ls /dev/nvme[0-9] 2>/dev/null)

if [ -n "$NVME_DEVS" ]; then
    for dev in $NVME_DEVS; do
        echo "==================================================" >> "$REPORT_FILE"
        echo " Health Check: $dev" >> "$REPORT_FILE"
        echo "==================================================" >> "$REPORT_FILE"
        
        if command -v nvme &> /dev/null; then
            echo ">>> nvme smart-log ($dev) <<<" >> "$REPORT_FILE"
            nvme smart-log "$dev" >> "$REPORT_FILE" 2>&1
            echo "" >> "$REPORT_FILE"
            echo ">>> nvme error-log ($dev - Tail 20) <<<" >> "$REPORT_FILE"
            nvme error-log "$dev" -e 20 >> "$REPORT_FILE" 2>&1
            echo "" >> "$REPORT_FILE"
        fi

        if command -v smartctl &> /dev/null; then
            echo ">>> smartctl NVMe Health Summary ($dev) <<<" >> "$REPORT_FILE"
            smartctl -H -i -A "$dev" >> "$REPORT_FILE" 2>&1
            echo "" >> "$REPORT_FILE"
        fi
    done
else
    echo "No /dev/nvme[0-9] controllers detected." >> "$REPORT_FILE"
fi

# 6. PCIe Link Status & Bus Speed Degradation
log_section "PCIe Link Speeds & Bus Negotiation"
lspci -vvv -d ::0108 2>/dev/null | grep -E "(Capabilities:.*Express|LnkCap:|LnkSta:)" >> "$REPORT_FILE" 2>&1
if [ $? -ne 0 ]; then
    echo "lspci check skipped or no NVMe PCIe controllers found." >> "$REPORT_FILE"
fi

# 7. Kernel Storage & NVMe Error Events
log_section "Kernel NVMe & mdadm Log Events (Recent 100)"
journalctl -b 0 --grep="nvme|mdadm|raid1|blk_update_request" -n 100 --no-pager >> "$REPORT_FILE" 2>&1

# 8. Dmesg I/O & Storage Subsystem Faults
log_section "Dmesg NVMe Hardware Timeouts and I/O Errors"
dmesg -T | grep -Ei "nvme[0-9]|md[0-9]|I/O error|resetting controller|abort" | tail -n 50 >> "$REPORT_FILE" 2>&1

echo "" >> "$REPORT_FILE"
echo "==================================================" >> "$REPORT_FILE"
echo "            END OF DIAGNOSTIC REPORT              " >> "$REPORT_FILE"
echo "==================================================" >> "$REPORT_FILE"

# Restore non-root ownership without dereferencing symlinks when executed via sudo
if [ -n "${SUDO_USER:-}" ]; then
    chown -h "${SUDO_USER}:$(id -gn "$SUDO_USER")" "$REPORT_DIR" "$REPORT_FILE"
fi

# Output completion status to stdout
echo "[+] Diagnostic scan completed. Report written to: $REPORT_FILE"
