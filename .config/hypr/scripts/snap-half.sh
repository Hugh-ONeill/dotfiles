#!/bin/bash
# Snap active window to left/right/top/bottom half of the focused monitor
# Usage: snap-half.sh left|right|top|bottom

direction="$1"

# Get focused monitor geometry
eval "$(hyprctl monitors -j | jq -r '.[] | select(.focused) |
  "MON_X=\(.x) MON_Y=\(.y) MON_W=\(.width) MON_H=\(.height) RSV_TOP=\(.reserved[1]) RSV_BOT=\(.reserved[3])"')"

# Get decoration sizes (only query plugins that are loaded)
PLUGINS=$(hyprctl plugins list)
BAR_H=0
BORDER=$(hyprctl getoption general:border_size -j | jq '.int')

[[ "$PLUGINS" == *"hyprbars"* ]] && \
  BAR_H=$(hyprctl getoption plugin:hyprbars:bar_height -j | jq '.int')

[[ "$PLUGINS" == *"borders-plus-plus"* ]] && \
  BORDER=$((BORDER + $(hyprctl getoption plugin:borders-plus-plus:border_size_1 -j | jq '.int')))

AREA_Y=$((MON_Y + RSV_TOP))
AREA_H=$((MON_H - RSV_TOP - RSV_BOT))

case "$direction" in
  left)
    WIN_X=$((MON_X + BORDER))
    WIN_Y=$((AREA_Y + BAR_H + BORDER))
    WIN_W=$((MON_W / 2 - 2 * BORDER))
    WIN_H=$((AREA_H - BAR_H - 2 * BORDER))
    ;;
  right)
    WIN_X=$((MON_X + MON_W / 2 + BORDER))
    WIN_Y=$((AREA_Y + BAR_H + BORDER))
    WIN_W=$((MON_W / 2 - 2 * BORDER))
    WIN_H=$((AREA_H - BAR_H - 2 * BORDER))
    ;;
  top)
    WIN_X=$((MON_X + BORDER))
    WIN_Y=$((AREA_Y + BAR_H + BORDER))
    WIN_W=$((MON_W - 2 * BORDER))
    WIN_H=$((AREA_H / 2 - BAR_H - 2 * BORDER))
    ;;
  bottom)
    WIN_X=$((MON_X + BORDER))
    WIN_Y=$((AREA_Y + AREA_H / 2 + BAR_H + BORDER))
    WIN_W=$((MON_W - 2 * BORDER))
    WIN_H=$((AREA_H / 2 - BAR_H - 2 * BORDER))
    ;;
  *) exit 1 ;;
esac

hyprctl dispatch movewindowpixel "exact ${WIN_X} ${WIN_Y},activewindow"
hyprctl dispatch resizewindowpixel "exact ${WIN_W} ${WIN_H},activewindow"
