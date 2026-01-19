# vim:ft=zsh

# ══════════════════════════════════════════════════════════════════════════════
# Basic Keybinds
# ══════════════════════════════════════════════════════════════════════════════

bindkey '^H' backward-kill-word
bindkey '^Z' undo

# ══════════════════════════════════════════════════════════════════════════════
# Custom Widgets
# ══════════════════════════════════════════════════════════════════════════════

# Prefix current/previous command with sudo (ESC ESC)
sudo-command-line() {
  [[ -z $BUFFER ]] && zle up-history
  if [[ $BUFFER == sudo\ * ]]; then
    LBUFFER="${LBUFFER#sudo }"
  else
    LBUFFER="sudo $LBUFFER"
  fi
}
zle -N sudo-command-line
bindkey '\e\e' sudo-command-line

# Copy current command line to clipboard
copy-line-to-clipboard() {
  echo -n "$BUFFER" | wl-copy
  zle -M "Copied to clipboard"
}
zle -N copy-line-to-clipboard
bindkey '^Y' copy-line-to-clipboard

# Open file manager in current directory
open-file-manager() {
  dolphin . &>/dev/null &
  disown
}
zle -N open-file-manager
bindkey '^O' open-file-manager

# Quick git status
git-status-widget() {
  zle -I
  git status -sb 2>/dev/null || echo "Not a git repo"
  zle reset-prompt
}
zle -N git-status-widget
bindkey '^G' git-status-widget

# Help for current command (Alt+H)
run-help-widget() {
  zle -I
  man "${BUFFER%% *}" 2>/dev/null || "${BUFFER%% *}" --help 2>&1 | bat -l help
  zle reset-prompt
}
zle -N run-help-widget
bindkey '\eh' run-help-widget

# Accept autosuggestion word by word (Alt+F)
bindkey '\ef' forward-word

# Clear screen but keep buffer
clear-screen-keep-buffer() {
  clear
  zle reset-prompt
}
zle -N clear-screen-keep-buffer
bindkey '^L' clear-screen-keep-buffer

# Quick calculator (Ctrl+X =)
calc-widget() {
  LBUFFER+="$(echo '' | fzf --print-query --prompt='calc: ' --preview='echo {} | bc -l 2>/dev/null' | tail -1 | bc -l 2>/dev/null)"
}
zle -N calc-widget
bindkey '^X=' calc-widget

# Jump to parent directory (Alt+Up)
cd-parent() {
  cd ..
  zle reset-prompt
}
zle -N cd-parent
bindkey '\e[1;3A' cd-parent

# Go back (Alt+Left)
cd-back() {
  cd -
  zle reset-prompt
}
zle -N cd-back
bindkey '\e[1;3D' cd-back

# Toggle comment on current line (Alt+#)
toggle-comment() {
  if [[ $BUFFER == '#'* ]]; then
    BUFFER="${BUFFER#\#}"
  else
    BUFFER="#$BUFFER"
  fi
}
zle -N toggle-comment
bindkey '\e#' toggle-comment


# ══════════════════════════════════════════════════════════════════════════════
# History Substring Search
# ══════════════════════════════════════════════════════════════════════════════

bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^P' history-substring-search-up
bindkey '^N' history-substring-search-down

# ══════════════════════════════════════════════════════════════════════════════
# Terminal Keybinds
# ══════════════════════════════════════════════════════════════════════════════

[[ ${TERM} != dumb ]] && () {
  zmodload -F zsh/terminfo +b:echoti +p:terminfo
  typeset -gA key_info
  key_info=(
    Control      '\C-'
    ControlLeft  '\e[1;5D \e[5D \e\e[D \eOd \eOD'
    ControlRight '\e[1;5C \e[5C \e\e[C \eOc \eOC'
    Escape       '\e'
    Meta         '\M-'
    Backspace    '^?'
    Delete       '^[[3~'
    BackTab      "${terminfo[kcbt]}"
    Left         "${terminfo[kcub1]}"
    Down         "${terminfo[kcud1]}"
    Right        "${terminfo[kcuf1]}"
    Up           "${terminfo[kcuu1]}"
    End          "${terminfo[kend]}"
    F1           "${terminfo[kf1]}"
    F2           "${terminfo[kf2]}"
    F3           "${terminfo[kf3]}"
    F4           "${terminfo[kf4]}"
    F5           "${terminfo[kf5]}"
    F6           "${terminfo[kf6]}"
    F7           "${terminfo[kf7]}"
    F8           "${terminfo[kf8]}"
    F9           "${terminfo[kf9]}"
    F10          "${terminfo[kf10]}"
    F11          "${terminfo[kf11]}"
    F12          "${terminfo[kf12]}"
    Home         "${terminfo[khome]}"
    Insert       "${terminfo[kich1]}"
    PageDown     "${terminfo[knp]}"
    PageUp       "${terminfo[kpp]}"
  )

  local key
  for key (${(s: :)key_info[ControlLeft]}) bindkey ${key} backward-word
  for key (${(s: :)key_info[ControlRight]}) bindkey ${key} forward-word

  bindkey ${key_info[Backspace]} backward-delete-char
  bindkey ${key_info[Delete]} delete-char

  [[ -n ${key_info[Home]} ]] && bindkey ${key_info[Home]} beginning-of-line
  [[ -n ${key_info[End]} ]] && bindkey ${key_info[End]} end-of-line
  [[ -n ${key_info[PageUp]} ]] && bindkey ${key_info[PageUp]} up-line-or-history
  [[ -n ${key_info[PageDown]} ]] && bindkey ${key_info[PageDown]} down-line-or-history
  [[ -n ${key_info[Insert]} ]] && bindkey ${key_info[Insert]} overwrite-mode
  [[ -n ${key_info[Left]} ]] && bindkey ${key_info[Left]} backward-char
  [[ -n ${key_info[Right]} ]] && bindkey ${key_info[Right]} forward-char
  [[ -n ${key_info[BackTab]} ]] && bindkey ${key_info[BackTab]} reverse-menu-complete

  # Expand alias with space
  bindkey ' ' magic-space

  # Insert last word (Alt+. or Alt+_)
  bindkey "${key_info[Escape]}." insert-last-word
  bindkey "${key_info[Escape]}_" insert-last-word

  # Edit command line in $EDITOR (Ctrl+X Ctrl+E)
  autoload -Uz edit-command-line && zle -N edit-command-line && \
    bindkey "${key_info[Control]}x${key_info[Control]}e" edit-command-line

  # Smart URL pasting
  autoload -Uz bracketed-paste-url-magic && zle -N bracketed-paste bracketed-paste-url-magic
  autoload -Uz url-quote-magic && zle -N self-insert url-quote-magic
}
