#!/bin/bash
# Shell tools theme handler (fzf, shell-colors, bat, etc.)

apply_fzf() {
    local theme="$1"
    if copy_to_current "$theme" "fzf.sh"; then
        report_ok "fzf"
    else
        report_skip "fzf (no theme file)"
    fi
}

apply_fzf_tab() {
    local theme="$1"
    if copy_to_current "$theme" "fzf-tab-flags.zsh"; then
        report_ok "fzf-tab"
    else
        report_skip "fzf-tab (no theme file)"
    fi
}

apply_shell_colors() {
    local theme="$1"
    if copy_to_current "$theme" "shell-colors.sh"; then
        report_ok "shell-colors"
    else
        report_skip "shell-colors (no theme file)"
    fi
}

apply_dircolors() {
    local theme="$1"
    if copy_to_current "$theme" "dircolors.db"; then
        report_ok "dircolors"
    else
        report_skip "dircolors (no theme file)"
    fi
}

apply_eza() {
    local theme="$1"
    local theme_dir="$THEMES_DIR/$theme"
    if [[ -f "$theme_dir/eza-theme.yml" ]]; then
        mkdir -p "$HOME/.config/eza"
        cp "$theme_dir/eza-theme.yml" "$HOME/.config/eza/theme.yml"
        report_ok "eza"
    else
        report_skip "eza (no theme file)"
    fi
}

apply_bat() {
    local theme="$1"
    local theme_dir="$THEMES_DIR/$theme"

    [[ ! -f "$HOME/.config/bat/config" ]] && return

    if [[ -f "$theme_dir/bat.conf" ]]; then
        local bat_theme=$(grep -oP '(?<=--theme=").*(?=")' "$theme_dir/bat.conf" 2>/dev/null)
        if [[ -n "$bat_theme" ]]; then
            if [[ -f "$theme_dir/bat.tmTheme" ]]; then
                mkdir -p "$HOME/.config/bat/themes"
                cp "$theme_dir/bat.tmTheme" "$HOME/.config/bat/themes/${theme}.tmTheme"
                command -v bat &>/dev/null && bat cache --build &>/dev/null || true
            fi
            sed -i "s|^--theme=.*|--theme=\"$bat_theme\"|" "$HOME/.config/bat/config"
            report_ok "bat"
        else
            report_skip "bat (invalid theme file)"
        fi
    else
        report_skip "bat (no theme file)"
    fi
}

apply_starship() {
    local theme="$1"
    local palette_path="$2"

    [[ ! -f "$HOME/.config/starship/starship.toml" ]] && return

    local palette_name="$theme"
    [[ "$theme" == "catppuccin" ]] && palette_name="catppuccin_mocha"

    if grep -q "palettes.$palette_name" "$HOME/.config/starship/starship.toml"; then
        sed -i "s|^palette = .*|palette = '$palette_name'|" "$HOME/.config/starship/starship.toml"

        # Swap format based on theme style
        local style_bar="rounded"
        if [[ -n "$palette_path" ]]; then
            style_bar=$(grep -oP '^export STYLE_BAR="\K[^"]+' "$palette_path" 2>/dev/null || echo "rounded")
        fi
        local json_palette="$PALETTES_DIR/$theme.json"
        if [[ "$style_bar" == "rounded" && -f "$json_palette" ]]; then
            local json_bar=$(jq -r '.style.bar // empty' "$json_palette" 2>/dev/null)
            [[ -n "$json_bar" ]] && style_bar="$json_bar"
        fi

        [[ -x "$SCRIPTS_DIR/starship-format-swap" ]] && \
            "$SCRIPTS_DIR/starship-format-swap" "$style_bar" >/dev/null 2>&1

        report_ok "starship"
    else
        report_skip "starship (palette not found)"
    fi
}

apply_fsh() {
    local theme="$1"
    local theme_dir="$THEMES_DIR/$theme"

    if [[ -d "$theme_dir/fsh" ]]; then
        mkdir -p "$HOME/.config/fsh"
        local fsh_theme_file=$(find "$theme_dir/fsh" -name "*.ini" -type f | head -1)
        if [[ -n "$fsh_theme_file" ]]; then
            local fsh_name=$(basename "$fsh_theme_file" .ini)
            cp "$fsh_theme_file" "$HOME/.config/fsh/${fsh_name}.ini"
            command -v fast-theme &>/dev/null && fast-theme "XDG:${fsh_name}" 2>/dev/null || true
            report_ok "fast-syntax-highlighting"
        else
            report_skip "fast-syntax-highlighting (no theme file)"
        fi
    else
        report_skip "fast-syntax-highlighting (no theme)"
    fi
}
