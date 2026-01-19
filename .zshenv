# vim:ft=zsh

# Locale/Language
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LESSCHARSET=utf-8

# XDG Base Directories
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_SCRIPT_HOME="$HOME/.local/bin"

# XDG User Directories
export XDG_DESKTOP_DIR="$HOME/Desktop"
export XDG_DOWNLOAD_DIR="$HOME/Downloads"
export XDG_TEMPLATES_DIR="$HOME/Templates"
export XDG_PUBLICSHARE_DIR="$HOME/Public"
export XDG_DOCUMENTS_DIR="$HOME/Documents"
export XDG_DEVELOPER_DIR="$HOME/Developer"
export XDG_MUSIC_DIR="$XDG_DOCUMENTS_DIR/Music"
export XDG_PICTURES_DIR="$XDG_DOCUMENTS_DIR/Pictures"
export XDG_VIDEOS_DIR="$XDG_DOCUMENTS_DIR/Videos"
export XDG_SCREENSHOTS_DIR="$XDG_PICTURES_DIR/Screenshots"
export XDG_SCREENCAPS_DIR="$XDG_VIDEOS_DIR/Screencaps"
export XDG_TRASH_DIR="$XDG_DATA_HOME/Trash"

# Package Path Corrections
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export GNUPGHOME="$XDG_CONFIG_HOME/gnupg"
