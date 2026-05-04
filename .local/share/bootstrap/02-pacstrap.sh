#!/usr/bin/env bash
# Pacstrap base + configure locale, time, hostname, network, user
# Usage: ./02-pacstrap.sh
# Prereqs: 01-disks.sh has mounted everything at /mnt
# Run from the live ISO.

set -euo pipefail

# ============================================================
# CONSTANTS
# ============================================================

TIMEZONE="${TIMEZONE:-US/Eastern}"
LANG_VAL="${LANG_VAL:-en_US.UTF-8}"
KEYMAP="${KEYMAP:-us}"

KERNEL_PKGS="linux linux-headers"
UCODE_PKG="amd-ucode"
BASE_PKGS="base base-devel linux-firmware sudo iptables-nft efibootmgr"
FS_PKGS="dosfstools e2fsprogs btrfs-progs"
NET_PKGS="networkmanager wpa_supplicant"
OTHER_PKGS="man-db git vim python"

# ============================================================
# PRE-FLIGHT
# ============================================================

findmnt -n /mnt >/dev/null \
    || { echo "/mnt not mounted. Run 01-disks.sh first."; exit 1; }
[[ -e /mnt/etc/os-release ]] \
    && { echo "/mnt already has a system installed. Aborting."; exit 1; }

# ============================================================
# PROMPTS
# ============================================================

read -rp "Hostname: " HOSTNAME
read -rp "Username (will get sudo via wheel): " USERNAME
[[ -z "$HOSTNAME" || -z "$USERNAME" ]] \
    && { echo "Hostname and username required."; exit 1; }

# ============================================================
# PACSTRAP BASE
# ============================================================

# shellcheck disable=SC2086
pacstrap -K /mnt \
    $BASE_PKGS $KERNEL_PKGS $UCODE_PKG $FS_PKGS $NET_PKGS $OTHER_PKGS

# ============================================================
# FSTAB
# ============================================================

genfstab -U /mnt >> /mnt/etc/fstab
# Strip subvolid — subvol=<name> is enough, and subvolid breaks snapper rollback
sed -i 's/subvolid=[0-9]*,//g' /mnt/etc/fstab

# ============================================================
# TIME ZONE
# ============================================================

arch-chroot /mnt ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
arch-chroot /mnt hwclock --systohc

# ============================================================
# LOCALE
# ============================================================

# Always enable en_US.UTF-8 (some software hardcodes it), plus chosen locale
arch-chroot /mnt sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
if [[ "$LANG_VAL" != "en_US.UTF-8" ]]; then
    arch-chroot /mnt sed -i "s/^#$LANG_VAL UTF-8/$LANG_VAL UTF-8/" /etc/locale.gen
fi
arch-chroot /mnt locale-gen

echo "LANG=$LANG_VAL"  > /mnt/etc/locale.conf
echo "KEYMAP=$KEYMAP"  > /mnt/etc/vconsole.conf

# ============================================================
# HOSTNAME
# ============================================================

echo "$HOSTNAME" > /mnt/etc/hostname

# ============================================================
# NETWORK SERVICES
# ============================================================

ln -sf /run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf
arch-chroot /mnt systemctl enable systemd-resolved.service NetworkManager.service

# ============================================================
# SUDOERS
# ============================================================

# Uncomment %wheel ALL=(ALL:ALL) ALL
sed -i '/^# %wheel ALL=(ALL:ALL) ALL/ s/# //' /mnt/etc/sudoers

# ============================================================
# USER
# ============================================================

arch-chroot /mnt useradd -m -G wheel "$USERNAME"

echo
echo "Set password for $USERNAME:"
arch-chroot /mnt passwd "$USERNAME"

# ============================================================
# ROOT
# ============================================================

read -rp $'\nSet a root password too? [y/N] (otherwise root stays locked): ' ans
if [[ "$ans" =~ ^[Yy] ]]; then
    arch-chroot /mnt passwd
else
    arch-chroot /mnt passwd -l root
    echo "Root account locked. Use 'sudo passwd' as $USERNAME to set later."
fi

echo
echo "Base system installed. Next: 03-post-chroot.sh"
