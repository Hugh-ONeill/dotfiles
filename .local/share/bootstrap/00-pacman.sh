#!/usr/bin/env bash
# Drop pacman/makepkg/hooks config into place
# Usage: sudo ./00-pacman.sh [TARGET_ROOT]   # default /
#        sudo ./00-pacman.sh /mnt            # for chroot install

set -euo pipefail

target="${1:-/}"
src="$(dirname "$(readlink -f "$0")")/etc"

install -m 644 "$src/pacman.conf"  "$target/etc/pacman.conf"
install -m 644 "$src/makepkg.conf" "$target/etc/makepkg.conf"
install -Dm 644 "$src/pacman.d/hooks/checkupdates-refresh.hook" \
    "$target/etc/pacman.d/hooks/checkupdates-refresh.hook"

echo "pacman config installed to $target"
