# vim:ft=zsh

bindkey -v

source "$ZDOTDIR/env.zsh"
[[ -f "$ZDOTDIR/secrets.zsh" ]] && source "$ZDOTDIR/secrets.zsh"
source "$ZDOTDIR/options.zsh"
source "$ZDOTDIR/history.zsh"
source "$ZDOTDIR/theme.zsh"
source "$ZDOTDIR/completions.zsh"
source "$ZDOTDIR/plugins.zsh"
source "$ZDOTDIR/prompt.zsh"
source "$ZDOTDIR/alias.zsh"
source "$ZDOTDIR/functions.zsh"
source "$ZDOTDIR/finders.zsh"
source "$ZDOTDIR/keybinds.zsh"


#source "$ZDOTDIR/diy.zsh"
