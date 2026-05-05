#!/usr/bin/env bash
# First-login user setup: repo packages, paru, AUR packages, user services
# Usage: ./04-first-login.sh
# Prereqs: dotbare cloned, network up, pacman.conf in place (00-pacman.sh)

set -euo pipefail
here="$(dirname "$(readlink -f "$0")")"

# ============================================================
# SUPPRESS SNAP-PAC DURING BULK INSTALL
# ============================================================

# 03 enabled snapper + snap-pac, which creates pre+post root snapshots on
# every pacman/paru transaction. During this script that's ~200+ snapshots
# pinning every intermediate FS state — easy way to fill a small VM disk.
# Symlinking the hook files to /dev/null is the canonical "disable" pattern;
# an EXIT trap restores them no matter how the script ends.
SNAPPAC_HOOKS=(05-snap-pac-pre.hook 10-snap-pac-removal.hook zz-snap-pac-post.hook)
SNAPPAC_DISABLED=0

restore_snappac() {
    [[ "$SNAPPAC_DISABLED" -eq 1 ]] || return 0
    for h in "${SNAPPAC_HOOKS[@]}"; do
        sudo rm -f "/etc/pacman.d/hooks/$h"
    done
    echo "snap-pac hooks restored"
}
trap restore_snappac EXIT

if pacman -Q snap-pac &>/dev/null; then
    echo "Suppressing snap-pac for bulk install..."
    sudo install -d /etc/pacman.d/hooks
    for h in "${SNAPPAC_HOOKS[@]}"; do
        sudo ln -sf /dev/null "/etc/pacman.d/hooks/$h"
    done
    SNAPPAC_DISABLED=1
fi

# ============================================================
# REPO PACKAGES
# ============================================================

sudo pacman -S --needed --noconfirm - < "$here/pkglist-official-clean.txt"

# ============================================================
# PARU (AUR HELPER)
# ============================================================

if ! command -v paru &>/dev/null; then
    # Source paru, not paru-bin: the -bin package links against whatever
    # libalpm.so.X was current when the AUR maintainer rebuilt it, and breaks
    # whenever pacman SONAME-bumps faster than the AUR package gets rebuilt.
    # Compiling from source picks up the system's actual libalpm.
    sudo pacman -S --needed --noconfirm base-devel git
    # rustup ships no toolchain by default; install + select stable so cargo works.
    command -v rustup &>/dev/null && rustup default stable
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/paru.git "$tmp/paru"
    ( cd "$tmp/paru" && makepkg -si --noconfirm )
    rm -rf "$tmp"
fi

# ============================================================
# AUR PACKAGES
# ============================================================

# Install one at a time: provider-resolution prompts and individual build
# failures don't take down the whole list. --skipreview avoids PKGBUILD
# review prompts. Failures are collected and reported at the end so you
# can re-attempt them manually.
aur_failed=()
while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    paru -S --needed --noconfirm --skipreview "$pkg" || aur_failed+=("$pkg")
done < "$here/pkglist-aur-clean.txt"

if (( ${#aur_failed[@]} > 0 )); then
    echo
    echo "WARN: ${#aur_failed[@]} AUR package(s) failed:"
    printf '  - %s\n' "${aur_failed[@]}"
    echo "Re-run manually to resolve, then re-run this script (it's idempotent)."
fi

# ============================================================
# FLATPAKS
# ============================================================

if command -v flatpak &>/dev/null && [[ -s "$here/flatpaks.txt" ]]; then
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    xargs -a "$here/flatpaks.txt" flatpak install --noninteractive flathub
fi

# ============================================================
# USER SYSTEMD SERVICES
# ============================================================

systemctl --user daemon-reload
systemctl --user enable --now checkupdates.timer reminder-check.timer

echo "first-login setup complete"
