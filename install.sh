#!/bin/bash

set -Eeuo pipefail

# ============================================================
# Ubuntu System Administrator Package Setup
# ============================================================

LOG_FILE="/var/log/sysadmin-package-install.log"

# ------------------------------------------------------------
# Error handling
# ------------------------------------------------------------

trap 'echo "[ERROR] Command failed at line $LINENO: $BASH_COMMAND" | tee -a "$LOG_FILE"' ERR

exec > >(tee -a "$LOG_FILE") 2>&1

echo "============================================================"
echo " Ubuntu System Administrator Package Setup"
echo "============================================================"
echo "Log file: $LOG_FILE"
echo

# ------------------------------------------------------------
# Require root privileges through sudo
# ------------------------------------------------------------

if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    if ! command -v sudo >/dev/null 2>&1; then
        echo "[ERROR] sudo is not installed."
        exit 1
    fi

    SUDO="sudo"
fi

# ------------------------------------------------------------
# Check OS
# ------------------------------------------------------------

if [[ ! -f /etc/os-release ]]; then
    echo "[ERROR] Cannot determine operating system."
    exit 1
fi

source /etc/os-release

if [[ "${ID:-}" != "ubuntu" && "${ID_LIKE:-}" != *"debian"* ]]; then
    echo "[ERROR] This script is intended for Ubuntu/Debian systems."
    echo "Detected: ${PRETTY_NAME:-Unknown}"
    exit 1
fi

echo "[OK] Operating system: ${PRETTY_NAME:-Unknown}"

# ------------------------------------------------------------
# Check required commands
# ------------------------------------------------------------

for cmd in apt-get dpkg; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[ERROR] Required command '$cmd' is missing."
        exit 1
    fi
done

# ------------------------------------------------------------
# Check network connectivity
# ------------------------------------------------------------

echo
echo "[1/10] Checking network connectivity..."

if ! getent hosts archive.ubuntu.com >/dev/null 2>&1; then
    echo "[WARNING] DNS/repository connectivity check failed."
    echo "APT operations may fail."
else
    echo "[OK] Ubuntu repository DNS is reachable."
fi

# ------------------------------------------------------------
# Repair interrupted dpkg/APT state
# ------------------------------------------------------------

echo
echo "[2/10] Checking and repairing dpkg/APT state..."

echo "[*] Configuring any unpacked packages..."
$SUDO dpkg --configure -a

echo "[*] Fixing broken dependencies..."
$SUDO apt-get -f install -y

echo "[*] Checking package database..."
$SUDO dpkg --audit || true

echo "[OK] dpkg/APT repair completed."

# ------------------------------------------------------------
# Clean stale package state
# ------------------------------------------------------------

echo
echo "[3/10] Cleaning APT package cache..."

$SUDO apt-get clean
$SUDO apt-get autoclean -y

echo "[OK] APT cache cleaned."

# ------------------------------------------------------------
# Update repositories
# ------------------------------------------------------------

echo
echo "[4/10] Updating package repositories..."

if ! $SUDO apt-get update; then
    echo "[ERROR] apt update failed."
    echo
    echo "Try:"
    echo "  sudo apt-get update"
    echo
    exit 1
fi

echo "[OK] Package repositories updated."

# ------------------------------------------------------------
# Package installation function
# ------------------------------------------------------------

install_packages() {

    local section="$1"
    shift
    local packages=("$@")

    echo
    echo "------------------------------------------------------------"
    echo "Installing: $section"
    echo "------------------------------------------------------------"

    if $SUDO apt-get install -y "${packages[@]}"; then
        echo "[OK] $section installed."
        return 0
    fi

    echo "[WARNING] Initial installation failed for: $section"
    echo "[*] Attempting dpkg repair..."

    $SUDO dpkg --configure -a || true
    $SUDO apt-get -f install -y || true

    echo "[*] Retrying: $section"

    if $SUDO apt-get install -y "${packages[@]}"; then
        echo "[OK] $section installed after repair."
        return 0
    fi

    echo "[ERROR] Failed to install: $section"
    return 1
}

# ------------------------------------------------------------
# General Ubuntu essentials
# ------------------------------------------------------------

echo
echo "[5/10] Installing general Ubuntu essentials..."

install_packages "General Ubuntu Essentials" \
    build-essential \
    linux-headers-$(uname -r) \
    dkms \
    gcc \
    g++ \
    make \
    cmake \
    pkg-config \
    git \
    curl \
    wget \
    unzip \
    zip \
    tar \
    gzip \
    bzip2 \
    xz-utils \
    rsync \
    tree \
    file \
    lsof \
    psmisc \
    procps \
    util-linux \
    pciutils \
    usbutils \
    ethtool \
    net-tools \
    iproute2 \
    iputils-ping \
    traceroute \
    dnsutils \
    tcpdump \
    nmap \
    socat \
    openssh-client \
    openssh-server \
    ca-certificates \
    gnupg \
    software-properties-common \
    apt-transport-https \
    bash-completion \
    vim \
    nano \
    tmux \
    htop \
    jq

# ------------------------------------------------------------
# Filesystem support
# ------------------------------------------------------------

echo
echo "[6/10] Installing filesystem support..."

install_packages "Filesystem Support" \
    e2fsprogs \
    xfsprogs \
    btrfs-progs \
    exfatprogs \
    ntfs-3g \
    dosfstools \
    f2fs-tools \
    jfsutils \
    nilfs-tools \
    udftools \
    nfs-common \
    cifs-utils \
    sshfs \
    fuse3

# ------------------------------------------------------------
# Storage
# ------------------------------------------------------------

echo
echo "[7/10] Installing storage and development tools..."

install_packages "Disk and Storage Tools" \
    parted \
    gdisk \
    fdisk \
    lvm2 \
    mdadm \
    smartmontools \
    nvme-cli \
    hdparm \
    testdisk \
    gpart

install_packages "Development and Runtime Dependencies" \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    default-jdk \
    nodejs \
    npm \
    libssl-dev \
    libffi-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncurses-dev

# ------------------------------------------------------------
# Monitoring and troubleshooting
# ------------------------------------------------------------

echo
echo "[8/10] Installing monitoring and troubleshooting tools..."

install_packages "System Monitoring" \
    iotop \
    iftop \
    nload \
    sysstat \
    ncdu \
    btop \
    strace \
    sysdig \
    ltrace \
    dstat

# ------------------------------------------------------------
# Networking, backup, security and hardware
# ------------------------------------------------------------

echo
echo "[9/10] Installing networking, backup, security and hardware tools..."

install_packages "Networking and Sysadmin Tools" \
    mtr-tiny \
    arp-scan \
    iperf3 \
    netcat-openbsd \
    telnet \
    whois \
    bind9-utils \
    bridge-utils \
    vlan \
    tshark \
    openssl \
    rclone \
    borgbackup \
    restic \
    p7zip-full \
    rar \
    unrar \
    zstd \
    lz4 \
    pigz \
    dmidecode \
    lshw \
    hwinfo \
    lm-sensors \
    auditd \
    audispd-plugins \
    acct \
    logwatch \
    chrony

# ------------------------------------------------------------
# Selected administration packages
# ------------------------------------------------------------

echo
echo "[10/10] Installing selected administration packages..."

install_packages "Selected Administration Packages" \
    ufw \
    fail2ban \
    cron \
    logrotate \
    unattended-upgrades

# ------------------------------------------------------------
# Final dpkg/APT repair
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Final dpkg/APT verification"
echo "============================================================"

echo "[*] Running dpkg configuration..."
$SUDO dpkg --configure -a

echo "[*] Checking/fixing dependencies..."
$SUDO apt-get -f install -y

echo "[*] Checking package database..."
$SUDO dpkg --audit || true

# ------------------------------------------------------------
# Enable requested services
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Service status"
echo "============================================================"

for service in cron fail2ban unattended-upgrades chrony; do

    if systemctl list-unit-files | grep -q "^${service}.service"; then

        echo
        echo "[$service]"

        if $SUDO systemctl enable "$service" 2>/dev/null; then
            echo "[OK] Enabled."
        else
            echo "[WARNING] Could not enable $service."
        fi

        if $SUDO systemctl is-active --quiet "$service"; then
            echo "[OK] Running."
        else
            echo "[INFO] Not currently running."
        fi
    fi
done

# ------------------------------------------------------------
# UFW
# ------------------------------------------------------------

echo
echo "============================================================"
echo " UFW"
echo "============================================================"

if command -v ufw >/dev/null 2>&1; then
    echo "[OK] UFW installed."
    echo
    echo "UFW has NOT been enabled automatically."
    echo "Enable it manually after configuring SSH rules:"
    echo
    echo "  sudo ufw allow OpenSSH"
    echo "  sudo ufw enable"
fi

# ------------------------------------------------------------
# Final package count
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Installation Summary"
echo "============================================================"

echo "[*] Installed package count:"
dpkg-query -W -f='${binary:Package}\n' 2>/dev/null | wc -l

echo
echo "[*] dpkg status:"
if $SUDO dpkg --audit 2>/dev/null | grep -q .; then
    echo "[WARNING] dpkg reports packages requiring attention."
    $SUDO dpkg --audit || true
else
    echo "[OK] dpkg package database is clean."
fi

echo
echo "============================================================"
echo " Installation completed"
echo "============================================================"

echo "Log saved to:"
echo "  $LOG_FILE"
echo
