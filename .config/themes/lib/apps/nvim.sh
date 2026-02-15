#!/bin/bash
# Neovim colorscheme handler

apply_nvim() {
    local theme="$1"
    if copy_to_current "$theme" "nvim-colors.lua"; then
        report_ok "nvim"
    else
        report_skip "nvim (no theme file)"
    fi
}
