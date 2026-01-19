# vim:ft=zsh

zinit lucid for \
  as"command" \
  from"gh-r" \
  atload'
    eval "$(starship init zsh)"
    function zle-keymap-select { STARSHIP_KEYMAP=$KEYMAP; zle reset-prompt }
    zle -N zle-keymap-select
    setopt promptsubst
  ' \
  starship/starship
