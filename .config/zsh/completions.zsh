# vim:ft=zsh

# ══════════════════════════════════════════════════════════════════════════════
# Completion Options
# ══════════════════════════════════════════════════════════════════════════════

setopt COMPLETE_IN_WORD
setopt EXTENDED_GLOB
setopt PATH_DIRS
setopt AUTO_MENU
setopt AUTO_LIST
setopt ALWAYS_TO_END
setopt AUTO_PARAM_SLASH
setopt NO_LIST_BEEP
unsetopt MENU_COMPLETE
unsetopt COMPLETE_ALIASES
unsetopt CASE_GLOB

# ══════════════════════════════════════════════════════════════════════════════
# Completion Styling
# ══════════════════════════════════════════════════════════════════════════════

zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/.zcompcache"
zstyle ':completion:*' word true
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*:match:*' original only
zstyle ':completion:*' group-name ''
zstyle ':completion:*' verbose yes
zstyle ':completion:*' extra-verbose true
zstyle ':completion:*' option-stacking true
zstyle ':completion:*:matches' group 'yes'
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*' file-sort modification
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu select

# ══════════════════════════════════════════════════════════════════════════════
# Matching & Sorting
# ══════════════════════════════════════════════════════════════════════════════

zstyle ':completion:*:*:*:*:processes' command 'ps -u $USER -o pid,user,comm -w'
zstyle -e ':completion:*:approximate:*' max-errors 'reply=($((($#PREFIX+$#SUFFIX)/3))numeric)'
zstyle ':completion:*:functions' ignored-patterns '(_*|pre(cmd|exec))'
zstyle ':completion:*:cd:*' ignore-parents parent pwd

# ══════════════════════════════════════════════════════════════════════════════
# SSH/SCP/Rsync
# ══════════════════════════════════════════════════════════════════════════════

zstyle ':completion:*:ssh:*' hosts $(awk '/^Host / && !/\*/{print $2}' ~/.ssh/config 2>/dev/null)
zstyle ':completion:*:scp:*' hosts $(awk '/^Host / && !/\*/{print $2}' ~/.ssh/config 2>/dev/null)
zstyle ':completion:*:(ssh|scp|rsync):*' tag-order 'hosts:-host:host hosts:-domain:domain hosts:-ipaddr:ip\ address *'

# ══════════════════════════════════════════════════════════════════════════════
# fzf-tab Styling
# ══════════════════════════════════════════════════════════════════════════════

zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*:messages' format '%d'
zstyle ':completion:*:warnings' format 'No matches for: %d'
zstyle ':completion:*:corrections' format '%D%d (errors: %e)%b'
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;36=0=01'
zstyle ':fzf-tab:*' fzf-min-height 50
zstyle ':fzf-tab:*' fzf-pad 4
zstyle ':fzf-tab:*' switch-group ',' '.'
zstyle ':fzf-tab:*' use-fzf-default-opts no
zstyle ':fzf-tab:*' fzf-bindings 'ctrl-space:toggle-preview' 'ctrl-/:change-preview-window(down,70%,wrap,border-top|hidden|right,50%,nowrap)'
zstyle ':fzf-tab:*' fzf-flags \
  '--preview-window=right,50%,nowrap' \
  '--color=fg:#BAC2DE,fg+:#CDD6F4,bg:#1e1e2e,bg+:#45475A' \
  '--color=hl:#CBA6F7,hl+:#74C7EC,info:#94E2D5,marker:#A6E3A1' \
  '--color=prompt:#74C7EC,spinner:#94E2D5,pointer:#F5C2E7,header:#B4BEFE' \
  '--color=gutter:#313244,border:#CBA6F7,separator:#94E2D5,scrollbar:#F9E2AF' \
  '--color=preview-fg:#BAC2DE,preview-bg:#181825,preview-border:#F5C2E7,preview-scrollbar:#F9E2AF' \
  '--border=rounded' '--reverse' '--height=90%' \
  "--prompt=☠ " "--marker=❯" "--pointer=" "--separator=🭷" "--scrollbar=▌"
zstyle ':fzf-tab:*' continuous-trigger '/'
zstyle ':fzf-tab:*' accept-line ctrl-x

# ══════════════════════════════════════════════════════════════════════════════
# fzf-tab Previews
# ══════════════════════════════════════════════════════════════════════════════

# Commands
zstyle ':fzf-tab:complete:-command-:*' fzf-preview '(out=$(zsh -c "source ~/.config/zsh/alias.zsh 2>/dev/null; alias $word" 2>/dev/null) && echo $out) || (out=$(zsh -c "source ~/.config/zsh/functions.zsh 2>/dev/null; whence -f $word" 2>/dev/null) && [[ -n "$out" ]] && echo "$out" | bat --color=always -l zsh --style=plain) || (out=$(tldr --color "$word") 2>/dev/null && echo $out) || (out=$(MANWIDTH=$FZF_PREVIEW_COLUMNS man "$word") 2>/dev/null && echo $out) || (out=$(which "$word") && echo $out) || echo "${(P)word}"'
zstyle ':fzf-tab:complete:(-command-|-parameter-|-brace-parameter-|export|unset|expand):*' fzf-preview 'echo ${(P)word}'
zstyle ':fzf-tab:complete:alias:*' fzf-preview 'zsh -c "source ~/.config/zsh/alias.zsh 2>/dev/null; alias $word" 2>/dev/null'

# Systemd
zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'systemctl status $word'

# Git
zstyle ':fzf-tab:complete:git-(add|diff|restore|checkout):*' fzf-preview 'git diff --color=always $word 2>/dev/null || git diff --color=always --staged $word 2>/dev/null || bat --color=always $word 2>/dev/null'
zstyle ':fzf-tab:complete:git-log:*' fzf-preview 'git log --oneline --graph --color=always $word'
zstyle ':fzf-tab:complete:git-show:*' fzf-preview 'git show --color=always $word'
zstyle ':fzf-tab:complete:git-checkout:*' fzf-preview 'case $group in
  "[branch]") git log --oneline --graph --color=always $word ;;
  "[tag]") git show --color=always $word ;;
  *) git diff --color=always $word 2>/dev/null || bat --color=always $word ;;
esac'
zstyle ':fzf-tab:complete:git-branch:*' fzf-preview 'git log --oneline --graph --color=always $word | head -50'
zstyle ':fzf-tab:complete:git-stash:*' fzf-preview 'git stash show -p $word --color=always'

# Docker
zstyle ':fzf-tab:complete:docker-container:*' fzf-preview 'docker container inspect $word | bat --color=always -l json'
zstyle ':fzf-tab:complete:docker-image:*' fzf-preview 'docker image inspect $word | bat --color=always -l json'
zstyle ':fzf-tab:complete:docker-logs:*' fzf-preview 'docker logs --tail 50 $word'
zstyle ':fzf-tab:complete:docker-(run|exec):*' fzf-preview 'docker inspect $word | bat --color=always -l json'

# Processes
zstyle ':fzf-tab:complete:kill:*' fzf-preview 'ps -p $word -o pid,user,%cpu,%mem,stat,start,command --no-headers | fold -w $FZF_PREVIEW_COLUMNS'
zstyle ':fzf-tab:complete:kill:argument-rest' fzf-preview 'ps --pid=$word -o cmd --no-headers'

# Packages
zstyle ':fzf-tab:complete:paru:*' fzf-preview 'paru -Si $word 2>/dev/null || paru -Qi $word 2>/dev/null'
zstyle ':fzf-tab:complete:pacman:*' fzf-preview 'pacman -Si $word 2>/dev/null || pacman -Qi $word 2>/dev/null'

# SSH
zstyle ':fzf-tab:complete:ssh:*' fzf-preview 'grep -A5 "Host $word" ~/.ssh/config 2>/dev/null || echo "No config for $word"'
zstyle ':fzf-tab:complete:scp:*' fzf-preview 'grep -A5 "Host $word" ~/.ssh/config 2>/dev/null || echo "No config for $word"'

# Make
zstyle ':fzf-tab:complete:make:*' fzf-preview 'make -n $word 2>/dev/null | bat --color=always -l bash'

# Man/Tldr
zstyle ':fzf-tab:complete:man:*' fzf-preview 'man -P cat $word 2>/dev/null | head -100'
zstyle ':fzf-tab:complete:tldr:argument-1' fzf-preview 'tldr $word'

# Env
zstyle ':fzf-tab:complete:printenv:*' fzf-preview 'echo $word=${(P)word}'

# npm/yarn
zstyle ':fzf-tab:complete:npm:*' fzf-preview 'npm info $word 2>/dev/null | head -50'
zstyle ':fzf-tab:complete:yarn:*' fzf-preview 'npm info $word 2>/dev/null | head -50'

# Directories
zstyle ':fzf-tab:complete:cd:*' tag-order local-directories directory-stack path-directories
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --color=always --all --group-directories-first --tree --level=2 $realpath'
zstyle ':fzf-tab:complete:z:*' fzf-preview 'eza --color=always --all --group-directories-first --tree --level=2 $realpath'
zstyle ':fzf-tab:complete:pushd:*' fzf-preview 'eza --color=always --all --group-directories-first --tree --level=2 $realpath'

# Generic fallback
zstyle ':fzf-tab:complete:*:*' fzf-preview 'if [[ -d $realpath ]]; then eza --color=always --all --group-directories-first --tree --level=2 $realpath; elif [[ -f $realpath ]]; then bat --color=always --line-range :100 $realpath 2>/dev/null || file $realpath; fi'
