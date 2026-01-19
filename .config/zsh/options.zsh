# vim:ft=zsh

# ══════════════════════════════════════════════════════════════════════════════
# Directories
# ══════════════════════════════════════════════════════════════════════════════

setopt AUTO_CD               # cd to directory if command is invalid but is a directory
setopt AUTO_PUSHD            # Make cd push old directory to stack
setopt CD_SILENT             # Don't print working directory after cd
setopt PUSHD_IGNORE_DUPS     # Don't push duplicates to stack
setopt PUSHD_SILENT          # Don't print stack after pushd/popd
setopt PUSHD_TO_HOME         # pushd with no args goes to home
DIRSTACKSIZE=20

# ══════════════════════════════════════════════════════════════════════════════
# Globbing
# ══════════════════════════════════════════════════════════════════════════════

setopt EXTENDED_GLOB         # Treat #, ~, ^ as patterns
setopt NO_CASE_GLOB          # Case-insensitive globbing
setopt NUMERIC_GLOB_SORT     # Sort numerically (file1, file2, file10)
setopt NULL_GLOB             # No error on failed globs

# ══════════════════════════════════════════════════════════════════════════════
# I/O
# ══════════════════════════════════════════════════════════════════════════════

setopt INTERACTIVE_COMMENTS  # Allow comments in interactive shell
setopt NO_CLOBBER            # Don't overwrite with >; use >| or >!
setopt MULTIOS               # Allow multiple redirections
setopt RC_QUOTES             # '' inside '' becomes single '

# ══════════════════════════════════════════════════════════════════════════════
# Correction
# ══════════════════════════════════════════════════════════════════════════════

setopt CORRECT               # Try to correct command spelling
unsetopt CORRECT_ALL         # Don't correct arguments

# ══════════════════════════════════════════════════════════════════════════════
# Jobs
# ══════════════════════════════════════════════════════════════════════════════

setopt LONG_LIST_JOBS        # List jobs in verbose format
setopt NO_BG_NICE            # Don't lower priority of background jobs
setopt NO_CHECK_JOBS         # Don't report job status on exit
setopt NO_HUP                # Don't SIGHUP jobs on exit
setopt NOTIFY                # Report job status immediately

# ══════════════════════════════════════════════════════════════════════════════
# Misc
# ══════════════════════════════════════════════════════════════════════════════

setopt COMBINING_CHARS       # Combine zero-width chars with base
setopt SHORT_LOOPS           # Allow short forms of for/repeat/select/if
setopt NO_BEEP               # Don't beep on errors
setopt AUTO_CONTINUE         # Send SIGCONT to disowned jobs
