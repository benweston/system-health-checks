#!/bin/bash

# Comprehensive Firmware, UEFI/BIOS & Hardware Component Diagnostic Script
# Optimised for Lenovo ThinkPad Workstations on Fedora Workstation (GRUB2 & systemd-boot support)
# Usage: sudo ./system-checks/02_01_firmware_check.sh

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "[-] Error: Please execute this script with root privileges (sudo)." >&2
    exit 1
fi

# Resolve project root directory and define the output report path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPORT_DIR="${PROJECT_ROOT}/system-reports"
REPORT_FILE="${REPORT_DIR}/02_01_firmware_report.txt"

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
echo "       FIRMWARE & HARDWARE SUBSYSTEM REPORT       " >> "$REPORT_FILE"
echo "       Generated on: $(date)" >> "$REPORT_FILE"
echo "       Host: $(hostname)" >> "$REPORT_FILE"
echo "==================================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Visual section banner helper
log_section() {
    echo "" >> "$REPORT_FILE"
    echo "--------------------------------------------------" >> "$REPORT_FILE"
    echo "  SECTION: $1" >> "$REPORT_FILE"
    echo "--------------------------------------------------" >> "$REPORT_FILE"
}

# Helper to log missing tool advice
check_tool() {
    if ! command -v "$1" &> /dev/null; then
        echo "[-] Command '$1' not found. Install via: dnf install $2" >> "$REPORT_FILE"
        return 1
    fi
    return 0
}

# 1. System Platform & DMI/SMBIOS Metadata
log_section "SMBIOS / DMI Hardware & Platform Identity"
if check_tool dmidecode dmidecode; then
    echo ">>> System Information <<<" >> "$REPORT_FILE"
    dmidecode -t system | grep -E "(Manufacturer|Product Name|Version|Serial Number|SKU Number|Family)" >> "$REPORT_FILE" 2>&1
    echo "" >> "$REPORT_FILE"
    echo ">>> Chassis Information <<<" >> "$REPORT_FILE"
    dmidecode -t chassis | grep -E "(Manufacturer|Type|Version|Serial Number|Asset Tag)" >> "$REPORT_FILE" 2>&1
    echo "" >> "$REPORT_FILE"
    echo ">>> Baseboard Details <<<" >> "$REPORT_FILE"
    dmidecode -t baseboard | grep -E "(Manufacturer|Product Name|Version|Serial Number)" >> "$REPORT_FILE" 2>&1
fi

# 2. Main System BIOS & Embedded Controller (EC) Versions
log_section "UEFI / BIOS & Embedded Controller (EC) Firmware"
if command -v dmidecode &> /dev/null; then
    dmidecode -t bios >> "$REPORT_FILE" 2>&1
else
    echo "dmidecode not available." >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"
echo ">>> Sysfs Firmware Attributes <<<" >> "$REPORT_FILE"
for node in /sys/class/dmi/id/{bios_vendor,bios_version,bios_date,ec_firmware_release}; do
    if [ -f "$node" ]; then
        echo "$(basename "$node"): $(cat "$node")" >> "$REPORT_FILE"
    fi
done

# 3. UEFI Secure Boot & Platform Key State
log_section "Secure Boot, Bootloader & TPM2 Measurement Telemetry"
if check_tool mokutil mokutil; then
    echo ">>> Secure Boot State <<<" >> "$REPORT_FILE"
    mokutil --sb-state >> "$REPORT_FILE" 2>&1
fi

echo "" >> "$REPORT_FILE"
echo ">>> Bootloader & PCR Bank Status <<<" >> "$REPORT_FILE"
# Branch telemetry based on active EFI bootloader architecture
if [ -d "/boot/efi/loader" ] && [ -f "/boot/efi/loader/loader.conf" ]; then
    echo "Bootloader: systemd-boot detected." >> "$REPORT_FILE"
    if check_tool bootctl systemd-udev; then
        bootctl status 2>&1 | grep -Ei "(secure boot|setup mode|tpm2|loader|firmware)" >> "$REPORT_FILE"
    fi
else
    echo "Bootloader: GRUB2 / shim detected (systemd-boot config absent)." >> "$REPORT_FILE"
    if check_tool tpm2_pcrread tpm2-tools; then
        echo ">>> GRUB2 TPM2 PCR Bank Measurements (SHA-256) <<<" >> "$REPORT_FILE"
        echo "Validating PCR 4 (Boot Manager), PCR 8 (Kernel CMD), PCR 9 (Initrd):" >> "$REPORT_FILE"
        tpm2_pcrread sha256:4,8,9 >> "$REPORT_FILE" 2>&1
    else
        echo "tpm2_pcrread not found. Cannot verify GRUB2 measurements." >> "$REPORT_FILE"
    fi
fi

# 4. fwupd / LVFS Component Inventory & Available Updates
log_section "Linux Vendor Firmware Service (fwupd/LVFS) Status"
if check_tool fwupdmgr fwupd; then
    echo ">>> fwupd Device Topology & Current Releases <<<" >> "$REPORT_FILE"
    fwupdmgr get-devices --no-unreported-check >> "$REPORT_FILE" 2>&1
    echo "" >> "$REPORT_FILE"
    echo ">>> Available Firmware Upgrades (LVFS) <<<" >> "$REPORT_FILE"
    fwupdmgr get-updates --no-unreported-check >> "$REPORT_FILE" 2>&1
fi

# 5. ThinkPad-Specific ACPI Firmware & Power Settings
log_section "ThinkPad ACPI Drivers & Platform Profiles"
if [ -d /sys/devices/platform/thinkpad_acpi ]; then
    echo "thinkpad_acpi interface: Active" >> "$REPORT_FILE"
    if [ -f /proc/acpi/ibm/driver ]; then
        cat /proc/acpi/ibm/driver >> "$REPORT_FILE" 2>&1
    fi
else
    echo "thinkpad_acpi sysfs node not found." >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"
echo ">>> Platform Profile Driver <<<" >> "$REPORT_FILE"
if [ -f /sys/firmware/acpi/platform_profile ]; then
    echo "Current Active Profile: $(cat /sys/firmware/acpi/platform_profile)" >> "$REPORT_FILE"
    echo "Available Profiles: $(cat /sys/firmware/acpi/platform_profile_choices)" >> "$REPORT_FILE"
fi

# 6. Discrete GPU VBIOS & Subsystem Firmware
log_section "GPU VBIOS & Graphics Subsystem"
if command -v nvidia-smi &> /dev/null; then
    echo ">>> NVIDIA Driver & VBIOS Status <<<" >> "$REPORT_FILE"
    nvidia-smi --query-gpu=name,driver_version,vbios_version,pstate,temperature.gpu,power.draw --format=csv >> "$REPORT_FILE" 2>&1
else
    echo "nvidia-smi not detected. Scanning PCI display controllers via lspci:" >> "$REPORT_FILE"
    lspci -nnk -d ::0300 >> "$REPORT_FILE" 2>&1
fi

# 7. Physical Storage Controller Firmware (NVMe)
log_section "NVMe Drive Controller Firmware Revisions"
if check_tool nvme nvme-cli; then
    nvme list >> "$REPORT_FILE" 2>&1
    echo "" >> "$REPORT_FILE"
    for dev in /dev/nvme[0-9]; do
        [ -e "$dev" ] || continue
        echo ">>> Controller Firmware Information: $dev <<<" >> "$REPORT_FILE"
        nvme id-ctrl "$dev" | grep -E "^(mn|fr|sn|fw_rev|ver)" >> "$REPORT_FILE" 2>&1
        echo "" >> "$REPORT_FILE"
    done
fi

# 8. TPM 2.0 Security Subsystem & Microcode Status
log_section "TPM 2.0 State & CPU Microcode Revision"
echo ">>> CPU Microcode Status <<<" >> "$REPORT_FILE"
grep -m 1 "microcode" /proc/cpuinfo >> "$REPORT_FILE" 2>&1
journalctl -b 0 --grep="microcode updated" --no-pager >> "$REPORT_FILE" 2>&1

echo "" >> "$REPORT_FILE"
echo ">>> TPM 2.0 Device Node <<<" >> "$REPORT_FILE"
if [ -c /dev/tpmrm0 ] || [ -c /dev/tpm0 ]; then
    ls -l /dev/tpm* >> "$REPORT_FILE" 2>&1
    if [ -f /sys/class/tpm/tpm0/device/description ]; then
        echo "Description: $(cat /sys/class/tpm/tpm0/device/description)" >> "$REPORT_FILE"
    fi
else
    echo "No TPM character devices exposed." >> "$REPORT_FILE"
fi

# 9. Thunderbolt / USB4 Controller Firmware Status
log_section "Thunderbolt / USB4 Controller Security & Generation"
if check_tool boltctl bolt; then
    echo ">>> Thunderbolt/USB4 Domains & IOMMU Security <<<" >> "$REPORT_FILE"
    boltctl domains >> "$REPORT_FILE" 2>&1
fi

# 10. Kernel Firmware Loading Faults & Missing Blobs
log_section "Kernel Firmware Loading Errors & Missing Blobs (dmesg / journal)"
echo ">>> Journalctl Firmware Warnings & Failures <<<" >> "$REPORT_FILE"
journalctl -b 0 --grep="firmware|ucode|regulatory" -p 0..3 --no-pager >> "$REPORT_FILE" 2>&1

echo "" >> "$REPORT_FILE"
echo ">>> Dmesg Direct Firmware Request Failures <<<" >> "$REPORT_FILE"
dmesg -T | grep -Ei "firmware: failed|Direct firmware load for .* failed" >> "$REPORT_FILE" 2>&1
if [ $? -ne 0 ]; then
    echo "No missing firmware blob errors logged by kernel." >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"
echo "==================================================" >> "$REPORT_FILE"
echo "            END OF DIAGNOSTIC REPORT              " >> "$REPORT_FILE"
echo "==================================================" >> "$REPORT_FILE"

# Restore non-root ownership without dereferencing symlinks when executed via sudo
if [ -n "${SUDO_USER:-}" ]; then
    chown -h "${SUDO_USER}:$(id -gn "$SUDO_USER")" "$REPORT_DIR" "$REPORT_FILE"
fi

# Output completion status to stdout
echo "[+] Firmware diagnostic scan completed. Report written to: $REPORT_FILE"
