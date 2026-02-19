#!/bin/bash
# Theme system configuration

THEMES_DIR="$HOME/.config/themes"
GENERATED_DIR="$THEMES_DIR/generated"
PALETTES_DIR="$THEMES_DIR/palettes"
TEMPLATES_DIR="$THEMES_DIR/templates"
CURRENT_DIR="$THEMES_DIR/current"
CURRENT_THEME_FILE="$THEMES_DIR/.current"
SCRIPTS_DIR="$THEMES_DIR/scripts"
LIB_DIR="$THEMES_DIR/lib"
APPS_DIR="$LIB_DIR/apps"

# Luminance threshold for light/dark detection
LUMINANCE_THRESHOLD=140

# Output colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'
