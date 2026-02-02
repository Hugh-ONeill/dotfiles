#!/bin/bash
# Regenerate all theme configs from palette files
# Usage: ./regenerate-all.sh [--cursors]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BUILD_CURSORS=false
for arg in "$@"; do
    case "$arg" in
        --cursors) BUILD_CURSORS=true ;;
    esac
done

echo "=== Regenerating all themes ==="

# Create temp dir for output
tmpdir=$(mktemp -d)
trap "rm -rf $tmpdir" EXIT

# Generate theme configs in parallel
pids=()
themes=()
for palette in palettes/*.json; do
    [[ ! -f "$palette" ]] && continue
    theme=$(basename "$palette" .json)
    themes+=("$theme")
    ./generate-theme.sh "$theme" > "$tmpdir/$theme.log" 2>&1 &
    pids+=($!)
done

# Wait for all and collect results
failed=()
for i in "${!pids[@]}"; do
    if ! wait "${pids[$i]}"; then
        failed+=("${themes[$i]}")
    fi
done

# Convert hex to ANSI true color block
hex_block() {
    local hex="${1#\#}"
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    printf "\033[48;2;%d;%d;%dm  \033[0m" "$r" "$g" "$b"
}

# Print gradient blocks for a theme
print_gradient() {
    local palette="palettes/$1.json"
    [[ ! -f "$palette" ]] && return
    local colors=$(jq -r '.gradient[]' "$palette" 2>/dev/null)
    for color in $colors; do
        # Resolve color references
        if [[ ! "$color" =~ ^# ]]; then
            color=$(jq -r ".colors.$color // \"$color\"" "$palette" 2>/dev/null)
        fi
        [[ "$color" =~ ^# ]] && hex_block "$color"
    done
}

# Print summary
for theme in "${themes[@]}"; do
    if [[ " ${failed[*]} " =~ " $theme " ]]; then
        echo "  ✗ $theme"
        echo "--- output ---"
        cat "$tmpdir/$theme.log"
        echo "--------------"
    else
        printf "  ✓ %-12s " "$theme"
        print_gradient "$theme"
        echo ""
    fi
done

# Update starship palettes
./update-starship-palettes.sh > "$tmpdir/starship.log" 2>&1 && echo "  ✓ starship" || echo "  ✗ starship"

# Build cursor themes (optional)
if [[ "$BUILD_CURSORS" == true ]]; then
    ./build-cursors.sh > "$tmpdir/cursors.log" 2>&1 && echo "  ✓ cursors" || echo "  ✗ cursors"
fi

echo ""
if [[ ${#failed[@]} -gt 0 ]]; then
    echo "=== Failed: ${failed[*]} ==="
    exit 1
else
    echo "=== Done ==="
fi
