#!/bin/bash

# Master Diagnostic Execution Runner
# Sequentially executes all numbered diagnostic scripts in system-checks/
# Usage: sudo ./run_checks.sh

set -uo pipefail

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "[-] Error: Please execute this script with root privileges (sudo)." >&2
    exit 1
fi

# Resolve project root, check scripts directory, and report output directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKS_DIR="${PROJECT_ROOT}/system-checks"
REPORT_DIR="${PROJECT_ROOT}/system-reports"

if [ ! -d "$CHECKS_DIR" ]; then
    echo "[-] Error: Diagnostic checks directory not found: $CHECKS_DIR" >&2
    exit 1
fi

# Discover numbered diagnostic scripts in deterministic lexical order
mapfile -d '' -t CHECKS < <(
    LC_ALL=C find "$CHECKS_DIR" -maxdepth 1 -type f \
        -name '[0-9][0-9]_[0-9][0-9]_*.sh' -print0 | LC_ALL=C sort -z
)

TOTAL="${#CHECKS[@]}"
if [ "$TOTAL" -eq 0 ]; then
    echo "[-] Error: No numbered check scripts found in: $CHECKS_DIR" >&2
    exit 1
fi

if [ -L "$REPORT_DIR" ]; then
    echo "[-] Error: Refusing to use symbolic link as reports directory: $REPORT_DIR" >&2
    exit 1
fi

mkdir -p "$REPORT_DIR"

echo "=================================================="
echo "     SYSTEM HEALTH CHECKS - DIAGNOSTIC RUNNER     "
echo "     Started on: $(date)"
echo "     Host: $(hostname)"
echo "     Scripts queued: ${TOTAL}"
echo "=================================================="

PASSED=0
FAILED=0
FAILED_SCRIPTS=()
INDEX=0

for script in "${CHECKS[@]}"; do
    INDEX=$((INDEX + 1))
    SCRIPT_NAME="$(basename "$script")"
    echo ""
    echo "[*] [${INDEX}/${TOTAL}] Executing ${SCRIPT_NAME}..."

    if bash "$script"; then
        PASSED=$((PASSED + 1))
    else
        EXIT_CODE=$?
        FAILED=$((FAILED + 1))
        FAILED_SCRIPTS+=("${SCRIPT_NAME} (exit ${EXIT_CODE})")
        echo "[-] Warning: ${SCRIPT_NAME} exited with status ${EXIT_CODE}; continuing..." >&2
    fi
done

# Ensure non-root ownership without dereferencing symlinks when executed via sudo
if [ -n "${SUDO_USER:-}" ] && [ -d "$REPORT_DIR" ]; then
    chown -hR "${SUDO_USER}:$(id -gn "$SUDO_USER")" "$REPORT_DIR"
fi

echo ""
echo "=================================================="
if [ "$FAILED" -eq 0 ]; then
    echo "[+] All diagnostic checks completed (${PASSED}/${TOTAL} succeeded)."
    echo "[+] Reports directory: ${REPORT_DIR}"
    echo "=================================================="
    exit 0
else
    echo "[-] Diagnostic run completed with errors (${PASSED}/${TOTAL} succeeded, ${FAILED} failed):" >&2
    for failed_item in "${FAILED_SCRIPTS[@]}"; do
        echo "    - ${failed_item}" >&2
    done
    echo "==================================================" >&2
    exit 1
fi
