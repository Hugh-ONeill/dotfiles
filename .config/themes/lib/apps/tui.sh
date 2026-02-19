#!/bin/bash
# TUI apps theme handler (lazygit, gitui, btop, ranger, etc.)

apply_lazygit()     { apply_simple "$1" "lazygit.yml"     "lazygit"; }
apply_gitui()       { apply_simple "$1" "gitui.ron"       "gitui"; }
apply_btop()        { apply_simple "$1" "btop.theme"      "btop"; }
apply_ranger()      { apply_simple "$1" "ranger.py"       "ranger"; }
apply_glow()        { apply_simple "$1" "glow.json"       "glow"; }
apply_youtube_tui() { apply_simple "$1" "youtube-tui.yml" "youtube-tui"; }
apply_sptlrx() {
    if copy_to_current "$1" "sptlrx.yaml"; then
        # inject persistent cookie from local file
        local cookie_file="$HOME/.config/sptlrx/cookie"
        if [[ -f "$cookie_file" ]]; then
            local cookie
            cookie=$(<"$cookie_file")
            awk -v c="$cookie" '{
                if ($0 ~ /^cookie: "/) print "cookie: \"" c "\""
                else print
            }' "$CURRENT_DIR/sptlrx.yaml" > "$CURRENT_DIR/sptlrx.yaml.tmp" \
                && mv "$CURRENT_DIR/sptlrx.yaml.tmp" "$CURRENT_DIR/sptlrx.yaml"
        fi
        report_ok "sptlrx"
    else
        report_skip "sptlrx (no theme file)"
    fi
}
apply_fastfetch()   { apply_simple "$1" "fastfetch.jsonc"  "fastfetch"; }

apply_spotify_player() {
    local theme="$1"
    local src="$GENERATED_DIR/$theme/spotify-player.toml"
    local app_conf="$HOME/.config/spotify-player/app.toml"
    [[ ! -f "$src" ]] && { report_skip "spotify-player (no theme file)"; return; }
    copy_to_current "$theme" "spotify-player.toml"
    cp "$src" "$HOME/.config/spotify-player/theme.toml"
    # point app.toml at the current theme name
    if [[ -f "$app_conf" ]]; then
        sed -i "s|^theme = .*|theme = \"$theme\"|" "$app_conf"
    fi
    report_ok "spotify-player"
}

apply_cava() {
    local theme="$1"
    local colors_file="$GENERATED_DIR/$theme/cava-colors.conf"
    if [[ ! -f "$colors_file" ]]; then
        report_skip "cava (no theme file)"
        return
    fi
    copy_to_current "$theme" "cava-colors.conf"

    # splice color section into both cava configs
    local configs=("$HOME/.config/cava/config" "$HOME/.config/cava/config-waybar")
    for cfg in "${configs[@]}"; do
        [[ -f "$cfg" ]] || continue
        awk -v colorfile="$colors_file" '
            /^\[color\]/ { in_color=1; while((getline line < colorfile) > 0) print line; next }
            /^\[/ { in_color=0 }
            !in_color { print }
        ' "$cfg" > "$cfg.tmp" && mv "$cfg.tmp" "$cfg"
    done
    # signal running cava instances to reload config
    pkill -USR1 cava 2>/dev/null || true
    report_ok "cava"
}

apply_claude() {
    local theme="$1"
    if copy_to_current "$theme" "statusline.sh"; then
        # Update claude's statusline symlink to point to current theme
        ln -sf "$CURRENT_DIR/statusline.sh" "$HOME/.claude/statusline-current.sh"
        report_ok "claude"
    else
        report_skip "claude (no theme file)"
    fi
}
