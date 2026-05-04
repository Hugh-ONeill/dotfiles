#!/usr/bin/env bash
# Phase-aware bootstrap dispatcher.
# Usage:
#   sudo ./bootstrap.sh live    # from the Arch live ISO: runs 00 -> 01 -> 02 -> 03
#   ./bootstrap.sh user         # post-reboot as your user: clones dotbare + runs 04
#
# How to obtain this script on a fresh live ISO (chicken-and-egg, since it lives
# inside the dotbare repo):
#   pacman -Sy --noconfirm git
#   git clone https://github.com/GrumpyRumpus/dotfiles.git /tmp/dots
#   /tmp/dots/.local/share/bootstrap/bootstrap.sh live

set -euo pipefail
here="$(dirname "$(readlink -f "$0")")"

DOTBARE_REMOTE="${DOTBARE_REMOTE:-https://github.com/GrumpyRumpus/dotfiles.git}"
DOTBARE_DIR="$HOME/.dotfiles"
gbare() { git --git-dir="$DOTBARE_DIR" --work-tree="$HOME" "$@"; }

phase="${1:-}"
[[ -z "$phase" ]] && { echo "usage: $0 {live|user}"; exit 1; }

case "$phase" in
    live)
        [[ "$EUID" -eq 0 ]] || { echo "live phase needs root."; exit 1; }
        bash "$here/00-pacman.sh"
        bash "$here/00b-mirrorlist.sh"
        bash "$here/01-disks.sh"
        bash "$here/02-pacstrap.sh"
        bash "$here/00-pacman.sh" /mnt
        bash "$here/00b-mirrorlist.sh" /mnt
        bash "$here/03-post-chroot.sh"
        echo
        echo "Live phase complete. Reboot, log in as your user, then run:"
        echo "  ./bootstrap.sh user"
        ;;
    user)
        [[ "$EUID" -ne 0 ]] || { echo "user phase: run as your normal user, not root."; exit 1; }
        if [[ ! -d "$DOTBARE_DIR" ]]; then
            echo "Cloning dotfiles..."
            git clone --bare "$DOTBARE_REMOTE" "$DOTBARE_DIR"
            gbare config --local status.showUntrackedFiles no
            # First checkout may collide with skel defaults (.bashrc etc); rename
            # those to .skel and retry. Anything still conflicting is real user data.
            if ! gbare checkout 2>/dev/null; then
                gbare checkout 2>&1 | awk '/^\s+\./ {print $1}' | while read -r f; do
                    mv "$HOME/$f" "$HOME/${f}.skel"
                done
                gbare checkout
            fi
        fi
        bash "$HOME/.local/share/bootstrap/04-first-login.sh"
        ;;
    *)
        echo "usage: $0 {live|user}"
        exit 1
        ;;
esac
