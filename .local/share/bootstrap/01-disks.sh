#!/usr/bin/env bash
# Partition + format + mount disks for an Arch install
# Usage: ./01-disks.sh                       # interactive (gdisk-driven)
#        AUTO_DISK=/dev/vda ./01-disks.sh    # non-interactive: wipe + 2 partitions
# Run from the live ISO. Stops at /mnt fully mounted; 02 runs pacstrap next.
#
# Layout (interactive: 3 partitions on potentially different disks):
#   EFI (FAT32)               -> /mnt/efi
#   Root (btrfs, ~18 subvols) -> /mnt + /mnt/var/* + /mnt/.snapshots etc.
#   Home (btrfs, @home)       -> /mnt/home
#
# Layout (AUTO_DISK: 2 partitions on the named disk):
#   1G EFI (FAT32)            -> /mnt/efi
#   rest btrfs (~18 subvols + @home) -> /mnt + /mnt/home + the rest
#
# No swap partition (zram handles swap, configured in 03-post-chroot.sh).

set -euo pipefail

# ============================================================
# CONSTANTS
# ============================================================

# space_cache=v2 is default since kernel 5.15, no need to specify
BTRFS_OPTS="ssd,noatime,compress=zstd:1,autodefrag"
HARDENED="nodev,nosuid,noexec"

# Subvolumes on root partition. Format: subvol_name:mountpoint:extra_opts
# extra_opts is comma-prefixed or empty. @home lives on its own partition.
ROOT_SUBVOLS=(
    "@:::"
    "@data:/data:,${HARDENED}"
    "@root:/root:,${HARDENED}"
    "@snapshots:/.snapshots:"
    "@srv:/srv:,${HARDENED}"
    "@usr_local:/usr/local:,${HARDENED}"
    "@var_cache:/var/cache:,${HARDENED}"
    "@var_crash:/var/crash:,${HARDENED}"
    "@var_lib_docker:/var/lib/docker:,${HARDENED}"
    "@var_lib_flatpak:/var/lib/flatpak:,${HARDENED}"
    "@var_lib_libvirt_images:/var/lib/libvirt/images:,${HARDENED}"
    "@var_lib_machines:/var/lib/machines:,${HARDENED}"
    "@var_lib_postgresql:/var/lib/postgresql:,${HARDENED}"
    "@var_log:/var/log:,${HARDENED}"
    "@var_opt:/var/opt:,${HARDENED}"
    "@var_spool:/var/spool:,${HARDENED}"
    "@var_tmp:/var/tmp:,${HARDENED}"
    "@var_www:/var/www:,${HARDENED}"
)

# ============================================================
# PRE-FLIGHT CHECKS
# ============================================================

[[ -e /sys/firmware/efi/efivars ]] || { echo "Not booted in UEFI mode."; exit 1; }
ping -c 1 -W 3 archlinux.org >/dev/null 2>&1 || { echo "No internet."; exit 1; }
timedatectl set-ntp true

umount -R /mnt 2>/dev/null || true

if [[ -n "${AUTO_DISK:-}" ]]; then
    # ============================================================
    # AUTO MODE
    # ============================================================
    [[ -b "$AUTO_DISK" ]] || { echo "AUTO_DISK=$AUTO_DISK is not a block device."; exit 1; }
    echo "AUTO MODE: will wipe $AUTO_DISK in 3 seconds. Ctrl-C to abort."
    sleep 3

    wipefs --all --force "$AUTO_DISK"
    sgdisk --zap-all "$AUTO_DISK"
    sgdisk \
        -n 1:0:+1G -t 1:ef00 -c 1:EFI \
        -n 2:0:0   -t 2:8300 -c 2:Linux \
        "$AUTO_DISK"
    partprobe "$AUTO_DISK"
    udevadm settle

    # Resolve part paths (handles sdX1 / nvmeXnYpZ / vdXY alike)
    mapfile -t _parts < <(lsblk -lnpo NAME "$AUTO_DISK" | tail -n +2)
    efi_part="${_parts[0]}"
    root_part="${_parts[1]}"
    home_part="$root_part"  # @home as subvol of the root btrfs FS
    echo "Partitioned: EFI=$efi_part, ROOT/HOME=$root_part"
else
    # ============================================================
    # EFI ENTRY CLEANUP (OPTIONAL)
    # ============================================================
    efibootmgr --unicode || true
    read -rp $'\nDelete any boot entries? Enter boot number (empty to skip, repeat to delete more): ' efi_id
    while [[ -n "$efi_id" ]]; do
        efibootmgr --bootnum "$efi_id" --delete-bootnum --unicode
        read -rp "Another? (empty to continue): " efi_id
    done

    # ============================================================
    # DISK SELECTION + PARTITIONING
    # ============================================================
    devices=$(lsblk --nodeps --paths --list --noheadings --sort=size \
        --output=name,size,model | grep -v loop | cat -n)

    while true; do
        echo -e "\nAvailable devices:"
        echo "$devices"
        read -rp "Pick a device number to partition with gdisk (empty to finish): " dev_id
        [[ -z "$dev_id" ]] && break
        device=$(echo "$devices" | awk -v n="$dev_id" '$1 == n { print $2 }')
        [[ -z "$device" ]] && { echo "Invalid choice."; continue; }
        gdisk "$device"
    done

    # ============================================================
    # IDENTIFY PARTITIONS
    # ============================================================
    partitions=$(lsblk --paths --list --noheadings \
        --output=name,size,model | grep -v loop | cat -n)

    pick_partition() {
        # Send display to stderr so command substitution captures only the chosen path
        local prompt="$1" id
        echo -e "\n$partitions" >&2
        read -rp "$prompt partition number: " id
        awk -v n="$id" '$1 == n { print $2 }' <<< "$partitions"
    }

    efi_part=$(pick_partition "EFI")
    root_part=$(pick_partition "Root")
    home_part=$(pick_partition "Home")

    [[ -b "$efi_part" && -b "$root_part" && -b "$home_part" ]] \
        || { echo "Invalid partition selection."; exit 1; }

    # ============================================================
    # CONFIRMATION
    # ============================================================
    cat <<EOF

About to DESTROY ALL DATA on:
  EFI : $efi_part
  Root: $root_part
  Home: $home_part

EOF
    read -rp "Type DESTROY to proceed: " confirm
    [[ "$confirm" == "DESTROY" ]] || { echo "Aborted."; exit 1; }
fi

# ============================================================
# FORMAT
# ============================================================

_format_targets=("$efi_part" "$root_part")
[[ "$home_part" != "$root_part" ]] && _format_targets+=("$home_part")
for p in "${_format_targets[@]}"; do
    wipefs --all --force "$p"
done

mkfs.fat -F32 -n ESP "$efi_part"
mkfs.btrfs -L ROOT -f "$root_part"
[[ "$home_part" != "$root_part" ]] && mkfs.btrfs -L HOME -f "$home_part"
udevadm settle

# ============================================================
# BTRFS SUBVOLUMES
# ============================================================

# Create root subvols (and @home here too if home shares the root FS)
mount "$root_part" /mnt
for entry in "${ROOT_SUBVOLS[@]}"; do
    name="${entry%%:*}"
    btrfs subvolume create "/mnt/$name"
done
[[ "$home_part" == "$root_part" ]] && btrfs subvolume create /mnt/@home
umount /mnt

# Create @home on its own partition (separate-disk mode)
if [[ "$home_part" != "$root_part" ]]; then
    mount "$home_part" /mnt
    btrfs subvolume create /mnt/@home
    umount /mnt
fi

# ============================================================
# MOUNT
# ============================================================

# Mount root @ first so we can mkdir nested mountpoints
mount -o "$BTRFS_OPTS,subvol=@" "$root_part" /mnt

# Make all mountpoints (skip @ since it IS /mnt)
for entry in "${ROOT_SUBVOLS[@]}"; do
    IFS=: read -r name mp _ <<< "$entry"
    [[ -z "$mp" ]] && continue
    mkdir -p "/mnt$mp"
done
mkdir -p /mnt/efi /mnt/home

# Mount each root subvol
for entry in "${ROOT_SUBVOLS[@]}"; do
    IFS=: read -r name mp extra <<< "$entry"
    [[ -z "$mp" ]] && continue
    mount -o "${BTRFS_OPTS}${extra},subvol=$name" "$root_part" "/mnt$mp"
done

# Mount EFI and home
mount "$efi_part" /mnt/efi
mount -o "${BTRFS_OPTS},nodev,subvol=@home" "$home_part" /mnt/home

# ============================================================
# DONE
# ============================================================

echo
echo "Mounted at /mnt:"
findmnt -R /mnt | head -40
echo
echo "Disks ready. Next: 02-pacstrap.sh"
