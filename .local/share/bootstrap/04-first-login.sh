#!/usr/bin/env bash
# First-login user setup: repo packages, paru, AUR packages, user services
# Usage: ./04-first-login.sh
# Prereqs: dotbare cloned, network up, pacman.conf in place (00-pacman.sh)

set -euo pipefail
here="$(dirname "$(readlink -f "$0")")"

# ============================================================
# REPO PACKAGES
# ============================================================

sudo pacman -S --needed --noconfirm - < "$here/pkglist-official-clean.txt"

# ============================================================
# PARU (AUR HELPER)
# ============================================================

if ! command -v paru &>/dev/null; then
    sudo pacman -S --needed --noconfirm base-devel git
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
    ( cd "$tmp/paru-bin" && makepkg -si --noconfirm )
    rm -rf "$tmp"
fi

# ============================================================
# AUR PACKAGES
# ============================================================

paru -S --needed --noconfirm - < "$here/pkglist-aur-clean.txt"

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
