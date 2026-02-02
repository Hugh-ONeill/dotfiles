# vim:ft=zsh

# ══════════════════════════════════════════════════════════════════════════════
# Completions (immediate)
# ══════════════════════════════════════════════════════════════════════════════

zinit light-mode for \
    blockf atpull'zinit creinstall -q .' \
  zsh-users/zsh-completions

zinit light kazhala/dotbare

# ══════════════════════════════════════════════════════════════════════════════
# Deferred Plugins
# ══════════════════════════════════════════════════════════════════════════════

# Compinit and fzf-tab (sync load for immediate completions)
zinit ice atinit"zicompinit; zicdreplay" atload"_register_completions"
zinit light Aloxaf/fzf-tab

# fzf keybindings
zinit ice wait lucid atload'source <(fzf --zsh)'
zinit light zdharma-continuum/null

# History substring search
zinit ice wait lucid
zinit light zsh-users/zsh-history-substring-search

# Autosuggestions - load AFTER other plugins, no widget wrapping
zinit ice wait'1' lucid atload'!_zsh_autosuggest_start'
zinit light zsh-users/zsh-autosuggestions

# Syntax highlighting - MUST be absolute last
zinit ice wait'2' lucid
zinit light zdharma-continuum/fast-syntax-highlighting
