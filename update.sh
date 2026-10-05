#!/bin/bash

set -Eeuo pipefail

LOG_FILE="/var/log/full-upgrade.log"

exec > >(tee -a "$LOG_FILE") 2>&1

trap 'echo; echo "[ERROR] Upgrade failed at line $LINENO"; echo "[ERROR] Command: $BASH_COMMAND"; exit 1' ERR

# ------------------------------------------------------------
# Root check
# ------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "Root Me!"
    echo "Run:"
    echo "  sudo full-upgrade"
    exit 1
fi

# ------------------------------------------------------------
# Basic checks
# ------------------------------------------------------------

if ! command -v apt-get >/dev/null 2>&1; then
    echo "[ERROR] apt-get is not installed."
    exit 1
fi

if ! command -v dpkg >/dev/null 2>&1; then
    echo "[ERROR] dpkg is not installed."
    exit 1
fi

echo "============================================================"
echo "                 FULL SYSTEM UPGRADE"
echo "============================================================"
echo
echo "This may take a while."
echo "Log: $LOG_FILE"
echo

# ------------------------------------------------------------
# Prevent multiple APT operations
# ------------------------------------------------------------

if pgrep -x apt >/dev/null 2>&1 || \
   pgrep -x apt-get >/dev/null 2>&1 || \
   pgrep -x dpkg >/dev/null 2>&1; then

    echo "[ERROR] Another APT/dpkg process is currently running."
    echo
    ps aux | grep -E '[a]pt|[d]pkg'
    exit 1
fi

# ------------------------------------------------------------
# Check network
# ------------------------------------------------------------

echo "[1/8] Checking network connectivity..."

if ! getent hosts archive.ubuntu.com >/dev/null 2>&1; then
    echo "[ERROR] Cannot resolve archive.ubuntu.com."
    echo "Check your network/DNS connection."
    exit 1
fi

echo "[OK] Network is available."
echo

# ------------------------------------------------------------
# Repair interrupted dpkg operations
# ------------------------------------------------------------

echo "[2/8] Repairing dpkg state..."

dpkg --configure -a

echo "[OK] dpkg configuration completed."
echo

# ------------------------------------------------------------
# Repair broken dependencies
# ------------------------------------------------------------

echo "[3/8] Fixing broken dependencies..."

apt-get -f install -y

echo "[OK] Dependency repair completed."
echo

# ------------------------------------------------------------
# Update repository metadata
# ------------------------------------------------------------

echo "[4/8] Updating package repositories..."

apt-get update

echo "[OK] Repository metadata updated."
echo

# ------------------------------------------------------------
# Full system upgrade
# ------------------------------------------------------------

echo "[5/8] Performing full system upgrade..."

apt-get full-upgrade -y

echo "[OK] System packages upgraded."
echo

# ------------------------------------------------------------
# Second dependency/configuration check
# ------------------------------------------------------------

echo "[6/8] Verifying package configuration..."

dpkg --configure -a
apt-get -f install -y

echo "[OK] Package configuration verified."
echo

# ------------------------------------------------------------
# Remove unnecessary packages
# ------------------------------------------------------------

echo "[7/8] Removing unnecessary packages..."

apt-get autoremove --purge -y

echo "[OK] Unnecessary packages removed."
echo

# ------------------------------------------------------------
# Clean package cache
# ------------------------------------------------------------

echo "[8/8] Cleaning package cache..."

apt-get autoclean -y

echo "[OK] Package cache cleaned."
echo

# ------------------------------------------------------------
# Final verification
# ------------------------------------------------------------

echo "============================================================"
echo "                 FINAL VERIFICATION"
echo "============================================================"

echo
echo "[*] Checking dpkg..."

if dpkg --audit; then
    echo "[OK] dpkg database is clean."
else
    echo
    echo "[WARNING] dpkg reports packages requiring attention."
    dpkg --audit
fi

echo
echo "[*] Checking broken dependencies..."

if apt-get check; then
    echo "[OK] No broken dependencies."
else
    echo "[ERROR] APT reports dependency problems."
    exit 1
fi

echo
echo "[*] Checking pending upgrades..."

apt list --upgradable 2>/dev/null || true

echo
echo "============================================================"
echo "          SYSTEM UPGRADE COMPLETED SUCCESSFULLY"
echo "============================================================"
echo
echo "Log saved to:"
echo "  $LOG_FILE"
echo
