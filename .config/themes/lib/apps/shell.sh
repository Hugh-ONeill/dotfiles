#!/bin/bash
# Shell tools theme handler (fzf, shell-colors, bat, etc.)

apply_fzf()          { apply_simple "$1" "fzf.sh"            "fzf"; }
apply_fzf_tab()      { apply_simple "$1" "fzf-tab-flags.zsh" "fzf-tab"; }
apply_shell_colors() { apply_simple "$1" "shell-colors.sh"   "shell-colors"; }
apply_dircolors()    { apply_simple "$1" "dircolors.db"       "dircolors"; }

apply_eza() {
    local theme="$1"
    local theme_dir="$GENERATED_DIR/$theme"
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
    local theme_dir="$GENERATED_DIR/$theme"

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
    local src="$GENERATED_DIR/$theme/starship.toml"

    [[ ! -d "$HOME/.config/starship" ]] && return

    if [[ -f "$src" ]]; then
        cp "$src" "$HOME/.config/starship/starship.toml"
        report_ok "starship"
    else
        report_skip "starship (no generated config — run generate-theme.sh)"
    fi
}

apply_fsh() {
    local theme="$1"
    local theme_dir="$GENERATED_DIR/$theme"

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
