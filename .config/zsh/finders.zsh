# vim:ft=zsh

# ══════════════════════════════════════════════════════════════════════════════
# Ripgrep
# ══════════════════════════════════════════════════════════════════════════════

export RIPGREP_CONFIG_PATH="$XDG_CONFIG_HOME/ripgrep/ripgreprc"

# ══════════════════════════════════════════════════════════════════════════════
# FZF Configuration
# ══════════════════════════════════════════════════════════════════════════════

export FZF_DEFAULT_OPTS="\
--multi --exact --reverse --cycle --height=90% \
--color=fg:#BAC2DE,fg+:#CDD6F4,bg:#1e1e2e,bg+:#45475A \
--color=hl:#CBA6F7,hl+:#74C7EC,info:#94E2D5,marker:#A6E3A1 \
--color=prompt:#74C7EC,spinner:#94E2D5,pointer:#F5C2E7,header:#B4BEFE \
--color=gutter:#313244,border:#CBA6F7,separator:#94E2D5,scrollbar:#F9E2AF \
--color=preview-fg:#BAC2DE,preview-bg:#181825,preview-border:#F5C2E7,preview-scrollbar:#F9E2AF \
--color=preview-label:#A6E3A1,label:#A6E3A1,query:#BAC2DE,disabled:#585B70 \
--border='rounded' --border-label-pos='0' \
--preview-window='right,40%' \
--bind='ctrl-/:change-preview-window(down,70%,wrap,border-top|hidden|right,40%)' \
--padding='0' --margin='0' --prompt='☠ ' --marker='❯' \
--pointer='' --separator='🭷' --scrollbar='▌'"

# ══════════════════════════════════════════════════════════════════════════════
# FZF Commands (bfs-based)
# ══════════════════════════════════════════════════════════════════════════════

export FZF_DEFAULT_COMMAND="command bfs -name '.git' -prune -o -print"
export FZF_ALT_C_COMMAND="command bfs -type d -name '.git' -prune -o -type d -print"
export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND

_fzf_compgen_path() {
  command bfs ${1} -name '.git' -prune -o -print
}

_fzf_compgen_dir() {
  command bfs ${1} -name '.git' -prune -o -type d -print
}

# ══════════════════════════════════════════════════════════════════════════════
# FZF Keybind Options
# ══════════════════════════════════════════════════════════════════════════════

export FZF_CTRL_T_OPTS="\
  --bind='ctrl-e:execute($EDITOR {})' \
  --bind='ctrl-y:execute-silent(echo -n {} | wl-copy)+abort' \
  --bind='ctrl-o:execute(xdg-open {} 2>/dev/null)' \
  --header='ctrl-e:edit | ctrl-y:copy | ctrl-o:open | ctrl-/:toggle preview' \
  --preview='bat --color=always --line-range :500 {} 2>/dev/null || eza -la --color=always {}'"

export FZF_ALT_C_OPTS="\
  --bind='ctrl-y:execute-silent(echo -n {} | wl-copy)+abort' \
  --header='enter:cd | ctrl-y:copy path | ctrl-/:toggle preview' \
  --preview='eza -F --color=always --all --group-directories-first --tree --level=2 {}'"

export FZF_CTRL_R_OPTS="\
  --bind='ctrl-y:execute-silent(echo -n {2..} | wl-copy)+abort' \
  --header='enter:execute | ctrl-y:copy' \
  --preview='echo {}' --preview-window=down:3:wrap"

