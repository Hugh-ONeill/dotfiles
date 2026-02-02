# vim:ft=zsh

autoload -U colors && colors

# Source current theme's shell colors (LS_COLORS, EZA_COLORS, GREP_COLORS, THEME_COLORS)
[[ -f "$HOME/.config/themes/current/shell-colors.sh" ]] && source "$HOME/.config/themes/current/shell-colors.sh"
