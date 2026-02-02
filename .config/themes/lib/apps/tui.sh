#!/bin/bash
# TUI apps theme handler (lazygit, gitui, btop, ranger, etc.)

apply_lazygit() {
    local theme="$1"
    if copy_to_current "$theme" "lazygit.yml"; then
        report_ok "lazygit"
    else
        report_skip "lazygit (no theme file)"
    fi
}

apply_gitui() {
    local theme="$1"
    if copy_to_current "$theme" "gitui.ron"; then
        report_ok "gitui"
    else
        report_skip "gitui (no theme file)"
    fi
}

apply_btop() {
    local theme="$1"
    if copy_to_current "$theme" "btop.theme"; then
        report_ok "btop"
    else
        report_skip "btop (no theme file)"
    fi
}

apply_ranger() {
    local theme="$1"
    if copy_to_current "$theme" "ranger.py"; then
        report_ok "ranger"
    else
        report_skip "ranger (no theme file)"
    fi
}

apply_glow() {
    local theme="$1"
    if copy_to_current "$theme" "glow.json"; then
        report_ok "glow"
    else
        report_skip "glow (no theme file)"
    fi
}

apply_youtube_tui() {
    local theme="$1"
    if copy_to_current "$theme" "youtube-tui.yml"; then
        report_ok "youtube-tui"
    else
        report_skip "youtube-tui (no theme file)"
    fi
}

apply_sptlrx() {
    local theme="$1"
    if copy_to_current "$theme" "sptlrx.yaml"; then
        report_ok "sptlrx"
    else
        report_skip "sptlrx (no theme file)"
    fi
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

apply_fastfetch() {
    local theme="$1"
    if copy_to_current "$theme" "fastfetch.jsonc"; then
        report_ok "fastfetch"
    else
        report_skip "fastfetch (no theme file)"
    fi
}
