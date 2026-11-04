#!/usr/bin/env bash
# Install the root-owned config under system/etc and system/usr into place.
#
# These files can't live in the normal dotfiles tree: the repo's work-tree is
# $HOME and these belong to root. The layout under system/etc mirrors the real
# destination paths, so installing is a straight copy with the prefix swapped.
#
# Usage:   sudo system/install.sh          # install
#          system/install.sh --diff        # show what differs from live, no root

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Each top-level dir here mirrors the same dir under /: etc/ -> /etc, usr/ -> /usr.
# usr/ is only for files no package owns (e.g. an SDDM theme's theme.conf.user).
TREES=(etc usr)

each_file() {   # prints "<source>\0<destination>\0" for every mirrored file
    local t f
    for t in "${TREES[@]}"; do
        [[ -d "$ROOT/$t" ]] || continue
        while IFS= read -r -d '' f; do
            printf '%s\0%s\0' "$f" "/${f#"$ROOT"/}"
        done < <(find "$ROOT/$t" -type f -print0)
    done
}

if [[ ${1:-} == --diff ]]; then
    rc=0
    while IFS= read -r -d '' f && IFS= read -r -d '' dst; do
        if ! diff -q "$f" "$dst" >/dev/null 2>&1; then
            echo "differs: $dst"
            diff -u "$dst" "$f" 2>/dev/null | sed 's/^/  /' || true
            rc=1
        fi
    done < <(each_file)
    ((rc == 0)) && echo "in sync with /etc and /usr"
    exit 0
fi

if [[ $EUID -ne 0 ]]; then
    echo "needs root: sudo $0" >&2
    exit 1
fi

rebuild_uki=0
while IFS= read -r -d '' f && IFS= read -r -d '' dst; do
    if ! cmp -s "$f" "$dst"; then
        case "$dst" in /etc/kernel/*|/etc/mkinitcpio.d/*|/etc/mkinitcpio.conf*) rebuild_uki=1 ;; esac
    fi
    install -Dm644 "$f" "$dst"
    echo "installed $dst"
done < <(each_file)

# The kernel cmdline and the presets are baked into the UKIs, so a change to
# either only takes effect once both images are rebuilt.
if ((rebuild_uki)); then
    echo
    echo "boot config changed: rebuilding the default and fallback UKIs"
    mkinitcpio -P
fi

sysctl --system >/dev/null
systemctl daemon-reexec

echo
echo "watchdog=$(systemctl show -p RuntimeWatchdogUSec --value) state=$(cat /sys/class/watchdog/watchdog0/state 2>/dev/null)"
sysctl kernel.hardlockup_panic kernel.panic_on_oops kernel.panic
