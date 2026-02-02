# vim:ft=zsh

# ══════════════════════════════════════════════════════════════════════════════
# Ripgrep
# ══════════════════════════════════════════════════════════════════════════════

export RIPGREP_CONFIG_PATH="$XDG_CONFIG_HOME/ripgrep/ripgreprc"

# ══════════════════════════════════════════════════════════════════════════════
# FZF Configuration
# ══════════════════════════════════════════════════════════════════════════════

# Source theme colors
[[ -f "$HOME/.config/themes/current/fzf.sh" ]] && source "$HOME/.config/themes/current/fzf.sh"

export FZF_DEFAULT_OPTS="\
--ansi --multi --exact --reverse --cycle --height=90% \
${FZF_COLORS:-} \
--border='rounded' --border-label-pos='0' \
--preview-window='right,40%' \
--bind='ctrl-/:change-preview-window(down,70%,wrap,border-top|hidden|right,40%)' \
--padding='0' --margin='0' --prompt='☠ ' --marker='❯' \
--pointer='' --separator='🭷' --scrollbar='▌'"

# ══════════════════════════════════════════════════════════════════════════════
# FZF Commands (bfd hybrid: bfs for shallow, fd for deep)
# ══════════════════════════════════════════════════════════════════════════════

export FZF_DEFAULT_COMMAND="bfd -c always"
export FZF_ALT_C_COMMAND="fd --type d --color=always"
export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND

_fzf_compgen_path() {
  bfd -c always "${1}"
}

_fzf_compgen_dir() {
  fd --type d --color=always . "${1}"
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

