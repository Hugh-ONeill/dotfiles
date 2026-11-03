#!/bin/bash
# Toggle "gamemode": strip animations, blur, shader, opacity, gaps and rounding
# for the current session; a second run restores the config with a reload.
#
# Hyprland 0.57+: `hyprctl keyword` is gone. Runtime config changes go through
# `hyprctl eval` with the same hl.* calls the config uses; `hyprctl reload`
# re-runs the config and puts everything (plugin options included) back.

if [ -f ~/.cache/gamemode ]; then
  hyprctl reload
  rm ~/.cache/gamemode
  notify-send -a "gamemode.sh" -r 3 -t 800 "Gamemode: deactivated" "animations and blur enabled"
else
  hyprctl -q eval 'hl.config({
    animations = { enabled = false },
    decoration = {
      shadow = { enabled = false },
      blur = { enabled = false },
      dim_inactive = false,
      screen_shader = "",
      active_opacity = 1,
      inactive_opacity = 1,
      fullscreen_opacity = 1,
      rounding = 0,
    },
    general = { gaps_in = 0, gaps_out = 0, border_size = 1 },
    render = { direct_scanout = 1 },
  })'
  hyprctl -q eval 'for _, ns in ipairs({ "waybar", "swaync-notification-window", "awww-daemon", "rofi" }) do
    hl.layer_rule({ name = "gamemode-noanim-" .. ns, match = { namespace = ns }, no_anim = true })
  end'
  hyprctl -q eval 'hl.window_rule({ name = "gamemode-opaque", match = { class = "(.*)" }, opaque = true })'
  # Title bars off while gaming if the theme runs hyprbars (option only exists while it is loaded)
  hyprctl -q eval 'if hl.get_config("plugin.hyprbars.enabled") ~= nil then hl.config({ plugin = { hyprbars = { enabled = false } } }) end'
  touch ~/.cache/gamemode
  notify-send -a "gamemode.sh" -r 3 -t 800 "Gamemode: activated" "animations, blur, shader disabled"
fi
