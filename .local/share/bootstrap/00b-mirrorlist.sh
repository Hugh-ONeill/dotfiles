#!/usr/bin/env bash
# Generate /etc/pacman.d/mirrorlist using archinstall's approach: fetch the
# live mirror status JSON, filter active+healthy mirrors, sort by score, take
# the top N from the chosen country/countries.
# Usage: sudo ./00b-mirrorlist.sh [TARGET_ROOT]    # default /
#        sudo ./00b-mirrorlist.sh /mnt             # to refresh inside chroot
# Env:   COUNTRIES (comma-separated ISO codes, default US)
#        TOP_N (default 20)

set -euo pipefail

target="${1:-/}"
COUNTRIES="${COUNTRIES:-US}"
TOP_N="${TOP_N:-20}"
URL="https://archlinux.org/mirrors/status/json/"

command -v jq >/dev/null || pacman -Sy --noconfirm jq

# ============================================================
# FETCH + FILTER + SORT
# ============================================================

countries_json=$(printf '%s' "$COUNTRIES" | tr ',' '\n' | jq -R . | jq -s .)

mirrorlist=$(curl -sfL "$URL" | jq -r \
    --argjson n "$TOP_N" \
    --argjson countries "$countries_json" '
    .urls
    | map(select(
        .active == true
        and .last_sync != null
        and .score != null and .score < 100
        and (.url | startswith("http"))
        and (.country_code | IN($countries[]))
      ))
    | sort_by(.score)
    | .[0:$n]
    | map("Server = " + .url + "$repo/os/$arch")
    | join("\n")
')

[[ -z "$mirrorlist" ]] && {
    echo "ERROR: no mirrors matched (countries=$COUNTRIES). Aborting."
    exit 1
}

# ============================================================
# WRITE
# ============================================================

dest="$target/etc/pacman.d/mirrorlist"
install -dm 755 "$(dirname "$dest")"
{
    echo "## Generated $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    echo "## Source: $URL"
    echo "## Countries: $COUNTRIES, top $TOP_N by score"
    echo
    echo "$mirrorlist"
} > "$dest"

count=$(grep -c "^Server = " "$dest" || true)
echo "wrote $dest ($count mirrors)"
