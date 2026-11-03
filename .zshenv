# vim:ft=zsh

# Bootstrap: point zsh at ZDOTDIR, then load the real env from there
# zsh only reads this file when ZDOTDIR is not already exported (tty login, ssh);
# shells spawned from the session read $ZDOTDIR/.zshenv directly
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
source "$ZDOTDIR/.zshenv"
