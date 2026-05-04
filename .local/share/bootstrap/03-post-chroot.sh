#!/usr/bin/env bash
# Post-pacstrap customization: mkinitcpio, UKI, sbctl, zram, snapper, btrfs-balance
# Usage: ./03-post-chroot.sh
# Prereqs: 02-pacstrap.sh has run; /mnt has a working Arch install.
# Run from the live ISO. Uses arch-chroot for in-system commands.

set -euo pipefail

HERE="$(dirname "$(readlink -f "$0")")"

# ============================================================
# CONSTANTS
# ============================================================

# Modern v39+ HOOKS line: microcode hook replaces the legacy ucode-in-cmdline trick.
# No sd-encrypt — unencrypted disks. No keymap — sd-vconsole handles it.
MKINITCPIO_HOOKS="base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck"

EXTRA_PKGS="zram-generator sbctl snapper snap-pac"

# nvidia kernel modules are NOT baked in here — nvidia-open-dkms is installed
# from the pkglist in 04, which triggers mkinitcpio rebuild via pacman hook.
# First boot is tty-only on framebuffer; full GPU acceleration arrives after 04.

# ============================================================
# PRE-FLIGHT
# ============================================================

[[ -e /mnt/etc/os-release ]] \
    || { echo "/mnt has no system. Run 02-pacstrap.sh first."; exit 1; }
findmnt -n /mnt/efi >/dev/null \
    || { echo "/mnt/efi not mounted."; exit 1; }

# ============================================================
# DETECT PARTITIONS FROM /mnt MOUNTS
# ============================================================

ROOT_PART="$(findmnt -no SOURCE /mnt)"
ROOT_UUID="$(findmnt -no UUID /mnt)"
EFI_PART="$(findmnt -no SOURCE /mnt/efi)"
EFI_DEV="/dev/$(lsblk -no PKNAME "$EFI_PART")"
EFI_PART_NUM="${EFI_PART##*[!0-9]}"

echo "Root: $ROOT_PART (UUID=$ROOT_UUID)"
echo "EFI : $EFI_PART (disk=$EFI_DEV, part=$EFI_PART_NUM)"

# ============================================================
# EXTRA PACKAGES (zram, sbctl, snapper, snap-pac)
# ============================================================

# shellcheck disable=SC2086
arch-chroot /mnt pacman --noconfirm -S --needed $EXTRA_PKGS

# ============================================================
# MKINITCPIO HOOKS + MODULES
# ============================================================

sed -i "s|^HOOKS=.*|HOOKS=($MKINITCPIO_HOOKS)|" /mnt/etc/mkinitcpio.conf

# ============================================================
# KERNEL CMDLINE
# ============================================================

mkdir -p /mnt/etc/kernel

# Build cmdline as one space-separated line (UKIs accept newlines too, but
# heredoc continuations don't auto-join — flat string avoids surprises).
echo "root=UUID=$ROOT_UUID rw rootfstype=btrfs rootflags=subvol=/@ zswap.enabled=0 amd_iommu=on iommu=pt nvidia_drm.modeset=1 nvidia_drm.fbdev=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1 quiet loglevel=3 systemd.show_status=auto vt.global_cursor_default=0 fbcon=nodefer" \
    > /mnt/etc/kernel/cmdline

# Fallback cmdline: drop GPU params + silent-boot, keep root + iommu
echo "root=UUID=$ROOT_UUID rw rootfstype=btrfs rootflags=subvol=/@ zswap.enabled=0 amd_iommu=on iommu=pt" \
    > /mnt/etc/kernel/cmdline_fallback

# ============================================================
# ZRAM
# ============================================================

cat > /mnt/etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
fs-type = swap
EOF

# ============================================================
# UKI PRESETS
# ============================================================

mkdir -p /mnt/efi/EFI/Linux

# Rewrite each kernel preset to emit UKI files instead of classic initramfs
for preset in /mnt/etc/mkinitcpio.d/*.preset; do
    kname="$(basename "$preset" .preset)"
    sed -i -E \
        -e "s|^(#?\s*)default_uki=.*|default_uki=\"/efi/EFI/Linux/arch-${kname}.efi\"|" \
        -e "s|^(#?\s*)fallback_uki=.*|fallback_uki=\"/efi/EFI/Linux/arch-${kname}-fallback.efi\"|" \
        -e "s|^(#?\s*)default_options=.*|default_options=\"\"|" \
        -e "s|^(#?\s*)fallback_options=.*|fallback_options=\"-S autodetect --cmdline /etc/kernel/cmdline_fallback\"|" \
        -e "s|^(#?\s*)default_image=|#default_image=|" \
        -e "s|^(#?\s*)fallback_image=|#fallback_image=|" \
        "$preset"
done

# Clean up any old initramfs files from previous runs
rm -f /mnt/efi/initramfs-*.img /mnt/boot/initramfs-*.img 2>/dev/null || true

# Build UKIs
arch-chroot /mnt mkinitcpio -P

# ============================================================
# SECURE BOOT (SBCTL)
# ============================================================

# Only attempt enrollment if firmware is in Setup Mode. Otherwise skip and
# warn — the user can set up Secure Boot manually later from the running system.
setup_mode=$(bootctl status 2>/dev/null | grep -c "Secure Boot.*setup" || true)
if (( setup_mode == 1 )); then
    arch-chroot /mnt sbctl create-keys
    arch-chroot /mnt chattr -i /sys/firmware/efi/efivars/{PK,KEK,db}* 2>/dev/null || true
    arch-chroot /mnt sbctl enroll-keys --microsoft
    for uki in /mnt/efi/EFI/Linux/*.efi; do
        rel="${uki#/mnt}"
        arch-chroot /mnt sbctl sign --save "$rel"
    done
    echo "Secure Boot keys enrolled and UKIs signed."
else
    echo "WARN: firmware not in Secure Boot Setup Mode; skipping sbctl enrollment."
    echo "      Run 'sbctl create-keys && sudo sbctl enroll-keys --microsoft' later."
fi

# ============================================================
# DIRECT UEFI BOOT ENTRIES
# ============================================================

bootorder=""
for uki in /mnt/efi/EFI/Linux/*.efi; do
    name="$(basename "$uki" .efi)"
    loader="EFI\\Linux\\${name}.efi"
    arch-chroot /mnt efibootmgr --create \
        --disk "$EFI_DEV" --part "$EFI_PART_NUM" \
        --label "$name" --loader "$loader" --quiet --unicode
    bootnum=$(efibootmgr --unicode | awk -v n="$name" '$0 ~ "\\s"n"$" { print substr($1, 5, 4); exit }')
    bootorder="${bootorder:+$bootorder,}$bootnum"
done
[[ -n "$bootorder" ]] && arch-chroot /mnt efibootmgr --bootorder "$bootorder" --quiet --unicode

# ============================================================
# BTRFS-BALANCE CUSTOM TIMER
# ============================================================

install -Dm 644 "$HERE/etc/systemd/system/btrfs-balance.service" \
    /mnt/etc/systemd/system/btrfs-balance.service
install -Dm 644 "$HERE/etc/systemd/system/btrfs-balance.timer" \
    /mnt/etc/systemd/system/btrfs-balance.timer

# ============================================================
# SNAPPER
# ============================================================

# Skip snapper's create-config since /.snapshots is already a subvol from 01.
# Manually drop in tuned configs + register them.
install -Dm 640 -g 0 -o 0 "$HERE/etc/snapper/configs/root" /mnt/etc/snapper/configs/root
install -Dm 640 -g 0 -o 0 "$HERE/etc/snapper/configs/home" /mnt/etc/snapper/configs/home
echo 'SNAPPER_CONFIGS="root home"' > /mnt/etc/conf.d/snapper

# ============================================================
# ENABLE SERVICES
# ============================================================

arch-chroot /mnt systemctl enable \
    btrfs-balance.timer \
    snapper-timeline.timer \
    snapper-cleanup.timer \
    fstrim.timer

echo
echo "Post-chroot setup complete. You can now reboot."
echo "After reboot, run 04-first-login.sh as $USER to install user packages."
