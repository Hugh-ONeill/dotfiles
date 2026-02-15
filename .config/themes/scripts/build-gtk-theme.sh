#!/bin/bash
# Build GTK theme — wrapper for build-catppuccin-retheme.sh
# Usage: ./build-gtk-theme.sh <theme-name> [--all]
exec "$(dirname "$0")/build-catppuccin-retheme.sh" --gtk "$@"
