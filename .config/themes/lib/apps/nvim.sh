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

# vim reads colors/palette.vim, a symlink to current/vim-colors.vim
apply_vim() {
    local theme="$1"
    if copy_to_current "$theme" "vim-colors.vim"; then
        mkdir -p "$HOME/.config/vim/colors"
        ln -sfn "$CURRENT_DIR/vim-colors.vim" "$HOME/.config/vim/colors/palette.vim"
        report_ok "vim"
    else
        report_skip "vim (no theme file)"
    fi
}
