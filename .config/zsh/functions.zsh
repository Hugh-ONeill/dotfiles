# vim:ft=zsh

# ══════════════════════════════════════════════════════════════════════════════
# Display
# ══════════════════════════════════════════════════════════════════════════════

flip() { echo -n "（╯°□°）╯ ┻━┻" }

palette() {
  local -a colors
  for i in {000..255}; do
    colors+=("%F{$i}$i%f")
  done
  print -cP $colors
}

printc() {
  local color="%F{$1}"
  echo -E ${(qqqq)${(%)color}}
}

# ══════════════════════════════════════════════════════════════════════════════
# Directory & Navigation
# ══════════════════════════════════════════════════════════════════════════════

mkcd() { mkdir -p "$1" && cd "$1" }

up() {
  local d=""
  local limit="${1:-1}"
  for ((i=1; i<=limit; i++)); do d="../$d"; done
  cd "$d"
}

take() { mkdir -p "$1" && cd "$1" }

# ══════════════════════════════════════════════════════════════════════════════
# File Operations
# ══════════════════════════════════════════════════════════════════════════════

bak() { cp -a "$1" "${1}.bak.$(date +%Y%m%d_%H%M%S)" }

sizeof() { du -sh "${1:-.}" | cut -f1 }

# ══════════════════════════════════════════════════════════════════════════════
# Network & Web
# ══════════════════════════════════════════════════════════════════════════════

myip() { curl -s ifconfig.me }

port() { lsof -i ":${1:-80}" }

serve() { python -m http.server "${1:-8000}" }

transfer() {
  if [[ $# -eq 0 ]]; then echo "Usage: transfer <file>" && return 1; fi
  curl --progress-bar --upload-file "$1" "https://transfer.sh/$(basename "$1")" | tee /dev/null
  echo
}

weather() { curl -s "wttr.in/${1:-}" | head -37 }

# ══════════════════════════════════════════════════════════════════════════════
# Development
# ══════════════════════════════════════════════════════════════════════════════

json() {
  if [[ -t 0 ]]; then
    cat "$1" | python -m json.tool | bat -l json
  else
    python -m json.tool | bat -l json
  fi
}

gitignore() { curl -sL "https://www.toptal.com/developers/gitignore/api/$*" }

gclone() { git clone "$1" && cd "$(basename "$1" .git)" }

gitstats() {
  echo "Commits by author:"
  git shortlog -sn --all
  echo "\nLines by author:"
  git ls-files | xargs -n1 git blame --line-porcelain | grep "^author " | sort | uniq -c | sort -rn | head -20
}

# ══════════════════════════════════════════════════════════════════════════════
# System
# ══════════════════════════════════════════════════════════════════════════════

topmem() { ps aux --sort=-%mem | head -11 }

topcpu() { ps aux --sort=-%cpu | head -11 }

sysinfo() {
  echo "Hostname: $(hostname)"
  echo "Kernel:   $(uname -r)"
  echo "Uptime:  $(uptime -p)"
  echo "Memory:   $(free -h | awk '/^Mem:/{print $3"/"$2}')"
  echo "Disk:     $(df -h / | awk 'NR==2{print $3"/"$2" ("$5")"}')"
}

findlarge() {
  local size="${1:-100M}"
  fd --type f --size "+$size" --exec ls -lh {} \; | sort -k5 -h -r | head -20
}

findrecent() {
  local days="${1:-1}"
  fd --type f --changed-within "${days}d"
}

# ══════════════════════════════════════════════════════════════════════════════
# History
# ══════════════════════════════════════════════════════════════════════════════

histats() {
  fc -l 1 | awk '{CMD[$2]++;count++;}END { for (a in CMD)print CMD[a] " " CMD[a]/count*100 "% " a;}' | grep -v "./" | column -c3 -s " " -t | sort -nr | nl | head -${1:-25}
}

fhist() {
  local cmd
  cmd=$(fc -rln 1 | fzf --no-sort --exact \
    --header="enter:execute | ctrl-y:copy | ctrl-e:edit" \
    --bind="ctrl-y:execute-silent(echo -n {} | wl-copy)+abort" \
    --bind="ctrl-e:execute($EDITOR =(echo {}))")
  [[ -n "$cmd" ]] && print -z "$cmd"
}

# ══════════════════════════════════════════════════════════════════════════════
# FZF Utilities
# ══════════════════════════════════════════════════════════════════════════════

# Browse files owned by a package
paru_files() {
  [[ -z "$1" ]] && return 1
  paru -Ql "$1" | awk '{print $2}' | fzf --preview="preview {}"
}

fzf_colorize() {
  # Colorize lines from stdin based on membership in lists
  # Usage: command | fzf_colorize <color> <(list)> [<color> <(list)>] ...
  # Example: paru -Slq | fzf_colorize green <(paru -Qqe) yellow <(paru -Qqd) | fzf --ansi
  # Colors: Named Catppuccin colors (from CATPPUCCIN array), R;G;B for truecolor, or number for 256/ANSI

  local -a colors files
  colors=()
  files=()
  while [[ $# -ge 2 ]]; do
    # Use CATPPUCCIN array if color name exists, otherwise use raw value
    if [[ -n "${CATPPUCCIN[$1]}" ]]; then
      colors+=("${CATPPUCCIN[$1]}")
    elif [[ "$1" == "purple" && -n "${CATPPUCCIN[mauve]}" ]]; then
      colors+=("${CATPPUCCIN[mauve]}")
    else
      colors+=("$1")
    fi
    files+=("$2")
    shift 2
  done

  [[ ${#colors[@]} -eq 0 ]] && { cat; return; }

  # Pass colors as env var, let awk handle the logic
  COLORIZE_COLORS="${(j:|:)colors}" awk '
    BEGIN {
      n = split(ENVIRON["COLORIZE_COLORS"], clr, "|")
    }
    FNR == 1 { file++ }
    file <= n { lists[file][$0]; next }
    {
      for (i = 1; i <= n; i++) {
        if ($0 in lists[i]) {
          if (index(clr[i], ";")) printf "\033[38;2;%sm%s\033[0m\n", clr[i], $0
          else if (clr[i] > 15) printf "\033[38;5;%sm%s\033[0m\n", clr[i], $0
          else printf "\033[%sm%s\033[0m\n", clr[i], $0
          next
        }
      }
      print
    }
  ' "${files[@]}" -
}

# ══════════════════════════════════════════════════════════════════════════════
# FZF Finders
# ══════════════════════════════════════════════════════════════════════════════

fe() {
  local file
  file=$(fd --hidden --no-ignore-vcs --exclude .git -tf | fzf \
    --preview="bat --color=always --line-range :500 {}" \
    --header="enter:edit")
  [[ -n "$file" ]] && $EDITOR "$file"
}

fo() {
  local file
  file=$(fd --hidden --no-ignore-vcs --exclude .git -tf | fzf \
    --preview="bat --color=always --line-range :500 {} 2>/dev/null || file {}" \
    --header="enter:open")
  [[ -n "$file" ]] && xdg-open "$file" 2>/dev/null
}

fcd() {
  local dir
  dir=$(fd --hidden --no-ignore-vcs --exclude .git -td | fzf \
    --preview="eza --color=always --all --group-directories-first --tree --level=2 {}" \
    --header="enter:cd")
  [[ -n "$dir" ]] && cd "$dir"
}

frg() {
  local file line
  read -r file line <<<"$(
    rg --color=always --line-number --no-heading --smart-case "${*:-}" |
    fzf --ansi \
        --delimiter=: \
        --preview='bat --color=always --highlight-line {2} {1}' \
        --preview-window='right,50%,+{2}-10' \
        --header='enter:open at line' |
    awk -F: '{print $1, $2}'
  )"
  [[ -n "$file" ]] && $EDITOR "$file" +$line
}

frgi() {
  local RG_PREFIX="rg --column --line-number --no-heading --color=always --smart-case"
  fzf --ansi --disabled --query "$1" \
      --bind "start:reload:$RG_PREFIX {q}" \
      --bind "change:reload:sleep 0.1; $RG_PREFIX {q} || true" \
      --delimiter=: \
      --preview='bat --color=always --highlight-line {2} {1}' \
      --preview-window='right,50%,+{2}-10' \
      --header='type to search | enter:open at line' \
      --bind='enter:become($EDITOR {1} +{2})'
}

fman() {
  man -k . 2>/dev/null | fzf \
    --preview="echo {} | awk '{print \$1}' | xargs man 2>/dev/null | bat --color=always -l man" \
    --header="enter:view man page" \
    --bind="enter:execute(echo {} | awk '{print \$1}' | xargs man)"
}

fenv() {
  printenv | sort | fzf \
    --preview='echo {} | cut -d= -f2-' \
    --header='ctrl-y:copy value' \
    --bind='ctrl-y:execute-silent(echo {} | cut -d= -f2- | wl-copy)+abort'
}

fpath() {
  echo $PATH | tr ':' '\n' | fzf \
    --preview='eza --color=always {} 2>/dev/null || ls {}' \
    --header='enter:cd | ctrl-y:copy' \
    --bind='enter:execute(cd {} && $SHELL)' \
    --bind='ctrl-y:execute-silent(echo -n {} | wl-copy)+abort'
}

fssh() {
  local host
  host=$(grep -E "^Host\s+" ~/.ssh/config 2>/dev/null | awk '{print $2}' | grep -v '*' | fzf \
    --preview="grep -A5 'Host {}$' ~/.ssh/config" \
    --header="enter:connect")
  [[ -n "$host" ]] && ssh "$host"
}

fz() {
  local dir
  dir=$(zoxide query -l | fzf \
    --preview="eza --color=always --all --group-directories-first --tree --level=2 {}" \
    --header="enter:cd | ctrl-x:remove from zoxide" \
    --bind="ctrl-x:execute(zoxide remove {})+reload(zoxide query -l)")
  [[ -n "$dir" ]] && cd "$dir"
}

fbm() {
  [[ ! -f "$BOOKMARKS_FILE" ]] && touch "$BOOKMARKS_FILE"
  local dir
  dir=$(cat "$BOOKMARKS_FILE" | fzf \
    --preview="eza --color=always --all --group-directories-first --tree --level=2 {}" \
    --header="enter:cd | ctrl-a:add cwd | ctrl-d:delete" \
    --bind="ctrl-a:execute(echo $PWD >> $BOOKMARKS_FILE)+reload(cat $BOOKMARKS_FILE)" \
    --bind="ctrl-d:execute(grep -v {} $BOOKMARKS_FILE > /tmp/bm && mv /tmp/bm $BOOKMARKS_FILE)+reload(cat $BOOKMARKS_FILE)")
  [[ -n "$dir" ]] && cd "$dir"
}

fnotes() {
  local NOTES_DIR="${NOTES_DIR:-$HOME/Documents/notes}"
  local file
  file=$(fd -tf -e md . "$NOTES_DIR" 2>/dev/null | fzf \
    --preview="bat --color=always {}" \
    --header="enter:edit | ctrl-n:new note" \
    --bind="ctrl-n:execute($EDITOR $NOTES_DIR/$(date +%Y-%m-%d)-note.md)+abort")
  [[ -n "$file" ]] && $EDITOR "$file"
}

# ══════════════════════════════════════════════════════════════════════════════
# Misc
# ══════════════════════════════════════════════════════════════════════════════

qr() { echo "$1" | curl -s -F-=\<- qrenco.de }

# ══════════════════════════════════════════════════════════════════════════════
# Systemd
# ══════════════════════════════════════════════════════════════════════════════

slist() {
  systemctl list-units --type=service --all | awk 'NR<=1 {print; next}
    / running / {printf "\033[38;2;166;227;161m%s\033[0m\n", $0; next}
    / exited / {printf "\033[38;2;249;226;175m%s\033[0m\n", $0; next}
    / failed / {printf "\033[38;2;243;139;168m%s\033[0m\n", $0; next}
    {print}' | fzf --ansi --multi \
    --header="ctrl-s:start | ctrl-t:stop | ctrl-r:restart | ctrl-e:enable | ctrl-d:disable | green=running | yellow=exited | red=failed" \
    --preview="systemctl status {1}" \
    --bind="ctrl-s:execute(sudo systemctl start {1})+reload(systemctl list-units --type=service --all)" \
    --bind="ctrl-t:execute(sudo systemctl stop {1})+reload(systemctl list-units --type=service --all)" \
    --bind="ctrl-r:execute(sudo systemctl restart {1})+reload(systemctl list-units --type=service --all)" \
    --bind="ctrl-e:execute(sudo systemctl enable {1})" \
    --bind="ctrl-d:execute(sudo systemctl disable {1})"
}

sfailed() {
  systemctl list-units --state=failed | awk 'NR<=1 {print; next}
    {printf "\033[38;2;243;139;168m%s\033[0m\n", $0}' | fzf --ansi \
    --preview="systemctl status {1}; echo '---LOGS---'; journalctl -u {1} --no-pager -n 30"
}

jfu() {
  systemctl list-units --type=service --all --no-legend | awk '{
    name = ($1 ~ /●/) ? $2 : $1
    sub_status = ($1 ~ /●/) ? $5 : $4
    if (sub_status == "running") printf "\033[38;2;166;227;161m%s\033[0m\n", name
    else if (sub_status == "failed") printf "\033[38;2;243;139;168m%s\033[0m\n", name
    else print name
  }' | fzf --ansi \
    --preview="journalctl -u {1} --no-pager -n 50" \
    --header="enter:full logs | ctrl-f:follow | green=running | red=failed" \
    --bind="enter:execute(journalctl -u {1} | bat --color=always -l log)" \
    --bind="ctrl-f:execute(journalctl -u {1} -f)"
}

# ══════════════════════════════════════════════════════════════════════════════
# Paru/Pacman
# ══════════════════════════════════════════════════════════════════════════════

parup() {
  paru -Syy && paru -Quq | fzf_colorize mauve <(paru -Qqm) | fzf --ansi --multi \
    --preview="paru -Si {1}" \
    --header="enter:update selected | ctrl-a:select all | ctrl-u:update all | mauve=AUR" \
    --bind="ctrl-a:select-all" \
    --bind="ctrl-u:execute(paru -Su)+abort" \
    --bind="enter:execute(paru -S {+})+abort"
}

parebuild() {
  checkrebuild 2>/dev/null | awk '{print $2}' | fzf_colorize mauve <(paru -Qqm) | fzf --ansi --multi \
    --preview="paru -Qi {1}" \
    --header="enter:rebuild selected | ctrl-a:select all | ctrl-r:rebuild all | mauve=AUR" \
    --bind="ctrl-a:select-all" \
    --bind="ctrl-r:execute(checkrebuild 2>/dev/null | awk '{print \$2}' | xargs paru -S --rebuild)+abort" \
    --bind="enter:execute(paru -S --rebuild {+})+abort"
}

pinl() {
  paru -Qq | fzf_colorize mauve <(paru -Qqm) | fzf --ansi --multi \
    --preview="paru -Qii {1}" \
    --header="ctrl-r:remove | ctrl-d:asdeps | ctrl-e:asexplicit | ctrl-o:files | mauve=AUR" \
    --bind="ctrl-r:execute(paru -Rns {+})+reload(paru -Qq)" \
    --bind="ctrl-d:execute(sudo pacman -D --asdeps {+})+reload(paru -Qq)" \
    --bind="ctrl-e:execute(sudo pacman -D --asexplicit {+})+reload(paru -Qq)" \
    --bind="ctrl-o:execute(zsh -ic 'paru_files {1}')"
}

pinle() {
  paru -Qqe | fzf_colorize mauve <(paru -Qqm) | fzf --ansi --multi \
    --preview="paru -Qii {1}" \
    --header="ctrl-r:remove | ctrl-d:asdeps | ctrl-o:files | mauve=AUR" \
    --bind="ctrl-r:execute(paru -Rns {+})+reload(paru -Qqe)" \
    --bind="ctrl-d:execute(sudo pacman -D --asdeps {+})+reload(paru -Qqe)" \
    --bind="ctrl-o:execute(zsh -ic 'paru_files {1}')"
}

pinld() {
  paru -Qqd | fzf_colorize mauve <(paru -Qqm) | fzf --ansi --multi \
    --preview="paru -Qii {1}" \
    --header="ctrl-r:remove | ctrl-e:asexplicit | ctrl-o:files | mauve=AUR" \
    --bind="ctrl-r:execute(paru -Rns {+})+reload(paru -Qqd)" \
    --bind="ctrl-e:execute(sudo pacman -D --asexplicit {+})+reload(paru -Qqd)" \
    --bind="ctrl-o:execute(zsh -ic 'paru_files {1}')"
}

pclean() {
  paru -Qdtq | fzf_colorize mauve <(paru -Qqm) | fzf --ansi --multi \
    --preview="paru -Qii {1}" \
    --header="enter:remove selected | ctrl-a:select all | mauve=AUR" \
    --bind="ctrl-a:select-all" \
    --bind="enter:execute(paru -Rns {+})+abort"
}

psearch() {
  paru -Slq | fzf_colorize green <(paru -Qqe) yellow <(paru -Qqd) | fzf --ansi --multi \
    --preview="paru -Si {1} 2>/dev/null || paru -Gp {1}" \
    --header="enter:install | ctrl-p:view PKGBUILD | green=explicit | yellow=dependency" \
    --bind="enter:execute(paru -S {+})+abort" \
    --bind="ctrl-p:execute(paru -Gp {1} | bat --language=bash)"
}

parown() {
  paru -Qq | fzf_colorize mauve <(paru -Qqm) | fzf --ansi \
    --preview="paru -Ql {1} | tail -50" \
    --header="enter:browse files | mauve=AUR" \
    --bind="enter:execute(zsh -ic 'paru_files {1}')"
}

pwhich() {
  fzf --preview="pacman -Qo {} 2>/dev/null && pacman -Qi \$(pacman -Qo {} 2>/dev/null | awk '{print \$5}')"
}

# ══════════════════════════════════════════════════════════════════════════════
# Processes
# ══════════════════════════════════════════════════════════════════════════════

pskill() {
  ps aux | fzf --multi --header-lines=1 \
    --preview="echo {}; echo; pstree -p {2}" \
    --header="enter:TERM | ctrl-k:KILL" \
    --bind="enter:execute(kill {+2})+reload(ps aux)" \
    --bind="ctrl-k:execute(kill -9 {+2})+reload(ps aux)"
}

# ══════════════════════════════════════════════════════════════════════════════
# Git (FZF)
# ══════════════════════════════════════════════════════════════════════════════

gco() {
  git branch -a | sed "s/^[\* ]*//" | fzf_colorize green <(git branch --show-current) blue <(git branch -r --format="%(refname:short)") | fzf --ansi \
    --preview="git log --oneline --graph --color=always {1} | head -50" \
    --header="enter:checkout | green=current | blue=remote" \
    --bind="enter:execute(git checkout {1})+abort"
}

gflog() {
  git log --oneline --color=always | fzf --ansi --no-sort \
    --preview="git show --color=always {1}" \
    --header="enter:show | ctrl-y:copy hash | ctrl-r:revert" \
    --bind="enter:execute(git show {1} | bat --color=always -l diff)" \
    --bind="ctrl-y:execute-silent(echo -n {1} | wl-copy)+abort" \
    --bind="ctrl-r:execute(git revert {1})"
}

gadd() {
  git status -s | awk '{
    if ($1 ~ /M/) printf "\033[38;2;249;226;175m%s\033[0m\n", $0
    else if ($1 ~ /A/) printf "\033[38;2;166;227;161m%s\033[0m\n", $0
    else if ($1 ~ /D/) printf "\033[38;2;243;139;168m%s\033[0m\n", $0
    else if ($1 ~ /R/) printf "\033[38;2;137;180;250m%s\033[0m\n", $0
    else if ($1 ~ /\?/) printf "\033[38;2;180;190;254m%s\033[0m\n", $0
    else print
  }' | fzf --ansi --multi --preview="git diff --color=always {2}" \
    --header="tab:select | enter:stage | yellow=modified | green=added | red=deleted | blue=renamed | lavender=untracked" \
    --bind="enter:execute(git add {+2})+reload(git status -s)"
}

gstash() {
  git stash list | fzf \
    --preview="git stash show -p {1} --color=always" \
    --header="enter:apply | ctrl-d:drop | ctrl-p:pop" \
    --bind="enter:execute(git stash apply {1})+abort" \
    --bind="ctrl-d:execute(git stash drop {1})+reload(git stash list)" \
    --bind="ctrl-p:execute(git stash pop {1})+abort"
}

# ══════════════════════════════════════════════════════════════════════════════
# Docker
# ══════════════════════════════════════════════════════════════════════════════

dps() {
  docker ps -a | awk 'NR==1 {print; next}
    /Up / {printf "\033[38;2;166;227;161m%s\033[0m\n", $0; next}
    /Exited / {printf "\033[38;2;243;139;168m%s\033[0m\n", $0; next}
    {print}' | fzf --ansi --multi --header-lines=1 \
    --preview="docker logs --tail 30 {1}" \
    --header="ctrl-s:start | ctrl-t:stop | ctrl-r:rm | ctrl-l:logs | green=running | red=exited" \
    --bind="ctrl-s:execute(docker start {+1})+reload(docker ps -a)" \
    --bind="ctrl-t:execute(docker stop {+1})+reload(docker ps -a)" \
    --bind="ctrl-r:execute(docker rm {+1})+reload(docker ps -a)" \
    --bind="ctrl-l:execute(docker logs -f {1})"
}

dim() {
  docker images | awk 'NR==1 {print; next}
    /<none>/ {printf "\033[38;2;243;139;168m%s\033[0m\n", $0; next}
    {print}' | fzf --ansi --multi --header-lines=1 \
    --header="ctrl-r:remove | red=dangling" \
    --bind="ctrl-r:execute(docker rmi {+3})+reload(docker images)"
}

# ══════════════════════════════════════════════════════════════════════════════
# Trash
# ══════════════════════════════════════════════════════════════════════════════

tls() {
  trash-list | fzf --multi \
    --header="enter:restore | ctrl-d:delete permanently" \
    --bind="enter:execute(trash-restore {+})" \
    --bind="ctrl-d:execute(trash-rm {+})+reload(trash-list)"
}
