# vim:ft=zsh

# ---- Linux console ----
# No Nerd Font glyphs there, so use the plain ASCII prompt, and load the
# theme's 16 colors into the console palette (OSC P). The console has no
# separate background/foreground, so those replace color0 and color7.
# Run `tty-theme` again after `theme set` to recolor an open console.
tty-theme() {
  [[ $TERM == linux ]] || { print -u2 "tty-theme: only for the Linux console"; return 1; }
  setopt local_options extended_glob
  local f="$XDG_CONFIG_HOME/themes/current/kitty.conf" k v i
  [[ -r $f ]] || return 1
  local -A c
  while read -r k v _; do
    [[ $k == (color<0-15>|foreground|background) && $v == \#[[:xdigit:]](#c6) ]] && c[$k]=${v#\#}
  done < "$f"
  [[ -n ${c[background]} ]] && c[color0]=${c[background]}
  [[ -n ${c[foreground]} ]] && c[color7]=${c[foreground]}
  for i in {0..15}; do
    [[ -n ${c[color$i]} ]] && printf '\e]P%X%s' $i ${c[color$i]}
  done
  clear
}
if [[ $TERM == linux ]]; then
  export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship/tty.toml"
  tty-theme
fi

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
