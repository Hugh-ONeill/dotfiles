#!/bin/bash
# Build Kvantum theme — wrapper for build-catppuccin-retheme.sh
# Usage: ./build-kvantum-theme.sh <theme-name> [--all]
exec "$(dirname "$0")/build-catppuccin-retheme.sh" --kvantum "$@"
