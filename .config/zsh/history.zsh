# vim:ft=zsh

# ══════════════════════════════════════════════════════════════════════════════
# History Configuration
# ══════════════════════════════════════════════════════════════════════════════

typeset -g HISTFILE=$XDG_CACHE_HOME/zsh/zhistory
HISTSIZE=100000
SAVEHIST=50000

# ══════════════════════════════════════════════════════════════════════════════
# History Options
# ══════════════════════════════════════════════════════════════════════════════

setopt EXTENDED_HISTORY          # Write in ':start:elapsed;command' format
setopt SHARE_HISTORY             # Share history between all sessions
setopt HIST_EXPIRE_DUPS_FIRST    # Expire duplicate first when trimming
setopt HIST_IGNORE_ALL_DUPS      # Delete old event if new is duplicate
setopt HIST_FIND_NO_DUPS         # Don't display previously found event
setopt HIST_IGNORE_SPACE         # Don't record events starting with space
setopt HIST_SAVE_NO_DUPS         # Don't write duplicate events
setopt HIST_VERIFY               # Don't execute immediately on expansion
setopt APPEND_HISTORY            # Append to history file
setopt HIST_NO_STORE             # Don't store history command
setopt HIST_REDUCE_BLANKS        # Remove superfluous blanks
setopt INC_APPEND_HISTORY_TIME   # Add commands immediately with timestamps
