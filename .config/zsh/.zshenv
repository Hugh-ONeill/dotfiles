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
# lives here (not env.zsh) so Hyprland, GUI apps, and non-interactive ssh see it
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export GNUPGHOME="$XDG_CONFIG_HOME/gnupg"

export ANDROID_HOME="$XDG_DATA_HOME/android-sdk"
export BOOKMARKS_FILE="$XDG_DATA_HOME/bookmarks"
export BUN_INSTALL="$XDG_DATA_HOME/bun"
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
export CUDA_CACHE_PATH="$XDG_CACHE_HOME/nv"
export DOCKER_CONFIG="$XDG_CONFIG_HOME/docker"
export DOTBARE_DIR="$HOME/.dotfiles"
export DOTBARE_TREE="$HOME"
export GDBHISTFILE="$XDG_DATA_HOME/gdb/history"
export GOPATH="$XDG_DATA_HOME/go"
export GOCACHE="$XDG_CACHE_HOME/go-build"
export GOMODCACHE="$XDG_CACHE_HOME/go/mod"
export GRADLE_USER_HOME="$XDG_DATA_HOME/gradle"
export GTK_RC_FILES="$XDG_CONFIG_HOME/gtk-1.0/gtkrc"
export GTK2_RC_FILES="$XDG_CONFIG_HOME/gtk-2.0/gtkrc:$XDG_CONFIG_HOME/gtk-2.0/gtkrc.mine"
export _JAVA_OPTIONS=-Djava.util.prefs.userRoot="$XDG_CONFIG_HOME"/java
export LG_CONFIG_FILE="$XDG_CONFIG_HOME/lazygit/config.yml"
export LYNX_CFG="$XDG_CONFIG_HOME/lynx.cfg"
export MYPY_CACHE_DIR="$XDG_CACHE_HOME/mypy"
export NODE_REPL_HISTORY="$XDG_DATA_HOME/node_repl_history"
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export NVM_DIR="$XDG_DATA_HOME/nvm"
export PARALLEL_HOME="$XDG_CONFIG_HOME/parallel"
export PSQLRC="$XDG_CONFIG_HOME/pg/psqlrc"
export PSQL_HISTORY="$XDG_STATE_HOME/psql_history"
export PGPASSFILE="$XDG_CONFIG_HOME/pg/pgpass"
export PGSERVICEFILE="$XDG_CONFIG_HOME/pg/pg_service.conf"
export PYENV_ROOT="$XDG_DATA_HOME/pyenv"
export PYTHON_EGG_CACHE="$XDG_CACHE_HOME/python-eggs"
export PYTHON_HISTORY="$XDG_STATE_HOME/python/history"
export PYTHONPYCACHEPREFIX="$XDG_CACHE_HOME/python"
export PYTHONUSERBASE="$XDG_DATA_HOME/python"
export SQLITE_HISTORY="$XDG_STATE_HOME/sqlite_history"
export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship/starship.toml"
export STARSHIP_CACHE="$XDG_CACHE_HOME/starship"
export TEXMFHOME="$XDG_DATA_HOME/texmf"
export TEXMFVAR="$XDG_CACHE_HOME/texlive/texmf-var"
export TEXMFCONFIG="$XDG_CONFIG_HOME/texlive/texmf-config"
export TRITON_HOME="$XDG_CACHE_HOME/triton"
export WGETRC="$XDG_CONFIG_HOME/wgetrc"
export _ZO_DATA_DIR="$XDG_DATA_HOME/zoxide"
export CLAUDE_CONFIG_DIR="$XDG_CONFIG_HOME/claude"
