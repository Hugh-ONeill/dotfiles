# vim:ft=zsh

# ══════════════════════════════════════════════════════════════════════════════
# Defaults
# ══════════════════════════════════════════════════════════════════════════════

export FUNCNEST=100
export TERMINAL=kitty
export BROWSER=firefox
export VISUAL=nvim
export EDITOR=nvim
export SUDO_EDITOR=nvim
export SUDO_ASKPASS="$HOME/.local/bin/sudo-askpass"   # graphical prompt when sudo has no terminal (Claude ! commands)
export LESS="-Ss~ --ignore-case --LONG-PROMPT --quit-if-one-screen --RAW-CONTROL-CHARS --use-color"

# ══════════════════════════════════════════════════════════════════════════════
# Shell-only Settings
# ══════════════════════════════════════════════════════════════════════════════

# path corrections live in ~/.zshenv so GUI apps and ssh see them too

# Bat (theme managed by ~/.config/bat/config via theme-switcher)
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export MANROFFOPT="-c"

# Buku
export BUKU_COLORS='hEhhf'

# GnuPG
export GPG_TTY=$(tty)

# NNN
export NNN_FIFO='/tmp/nnn.fifo'
export NNN_TRASH=1
export NNN_COLORS='4652'
export NNN_FCOLORS='0203040a000d0608090b0501'
export NNN_PLUG='p:preview-tui;o:launch'
export NNN_OPTS='deEPrUx'

# Ruby (needs a subshell, too slow for .zshenv)
export GEM_HOME=$(gem env user_gemhome)

# Zoxide
export _ZO_FZF_OPTS="+m"
#export _ZO_EXCLUDE_DIRS="$HOME/.cache:$HOME/.local"

# Eza (uncomment to customize)
#export EZA_COLORS='da=1;34:gm=1;34:Su=1;34'

# ══════════════════════════════════════════════════════════════════════════════
# Plugin Configuration
# ══════════════════════════════════════════════════════════════════════════════

# ZSH history substring search
HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1
HISTORY_SUBSTRING_SEARCH_FUZZY=1

# ZSH Autosuggestion (highlight style set in theme's shell-colors.sh)
typeset -ga ZSH_AUTOSUGGEST_STRATEGY
ZSH_AUTOSUGGEST_STRATEGY=(match_prev_cmd history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=30

# ══════════════════════════════════════════════════════════════════════════════
# Path & Initialization
# ══════════════════════════════════════════════════════════════════════════════

# Zoxide
eval "$(zoxide init zsh --cmd cd)"

# GoWall (uncomment if using)
#source <(gowall completion zsh)

# Path (typeset -U removes duplicates)
typeset -U path PATH
path=(
  "$XDG_SCRIPT_HOME"
  "$BUN_INSTALL/bin"
  "$GEM_HOME/bin"
  "$ANDROID_HOME/platform-tools"
  "$ANDROID_HOME/emulator"
  $path
  /opt/rocm/bin  # rocminfo, rocm-smi; /etc/profile.d/rocm.sh only reaches login shells
)
export PATH

# Zinit
ZINIT_HOME="$XDG_DATA_HOME/zinit/zinit.git"
ZCOMPDUMP="$XDG_CACHE_HOME/zsh/.zcompdump"
source "$ZINIT_HOME/zinit.zsh"

# Claude Code config location (also in ~/.zshenv; repeated here because
# shells that inherit ZDOTDIR skip ~/.zshenv)
export CLAUDE_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/claude"
