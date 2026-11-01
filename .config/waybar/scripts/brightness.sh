#!/bin/bash

CACHE="${XDG_RUNTIME_DIR:-/tmp}/ddc-brightness"
ICONS=(󱩎 󱩏 󱩐 󱩑 󱩒 󱩓 󱩔 󱩕 󱩖)
DDC_OPTS=(--sleep-multiplier 0.1 --noverify)

# only talk to the i2c bus behind a connected monitor. probing every bus
# (the r9700 alone owns seven) wakes the idle card and has been seen to drop
# it off the pcie link.
ddc_bus() {
  local c a
  for c in /sys/class/drm/card*-*; do
    [[ -r $c/status && $(<"$c/status") == connected ]] || continue
    # displayport: ddc/ci rides the aux channel, exposed as an i2c adapter under the connector
    for a in "$c"/i2c-*; do
      [[ -d $a ]] && { basename "$a" | sed "s/^i2c-//"; return 0; }
    done
    [[ -L $c/ddc ]] && { basename "$(readlink -f "$c/ddc")" | sed "s/^i2c-//"; return 0; }
  done
  return 1
}

fetch_ddc() {
  local out bus
  bus=$(ddc_bus) || return 1
  out=$(ddcutil "${DDC_OPTS[@]}" --bus "$bus" getvcp 10 2>/dev/null) || return 1
  [[ $out =~ current\ value\ =\ +([0-9]+) ]] && echo "${BASH_REMATCH[1]}"
}

# True when nothing is awake to talk to: every monitor is dpms-off, or
# Hyprland reports no outputs at all (link down mid-retrain).
monitor_asleep() {
  local mons
  mons=$(hyprctl monitors -j 2>/dev/null) || return 1
  jq -e 'length == 0 or all(.[]; .dpmsStatus == false)' <<<"$mons" >/dev/null 2>&1
}

read_value() {
  local now age val
  now=$(date +%s)
  if [[ -f "$CACHE" ]]; then
    age=$(( now - $(stat -c %Y "$CACHE") ))
    val=$(cat "$CACHE")
    if [[ -n "$val" ]] && { (( age < 60 )) || monitor_asleep; }; then
      echo "$val"
      return
    fi
  fi
  # Never probe a sleeping panel. DDC/CI traffic to a monitor in DPMS standby
  # can drop the DP link; Hyprland then recycles the wl_output global and every
  # client bound to it dies (hyprlock, waybar, awww, the portals).
  monitor_asleep && return 1
  val=$(fetch_ddc) || return 1
  echo "$val" > "$CACHE"
  echo "$val"
}

val=$(read_value) || {
  printf '{"text": "N/A", "tooltip": "DDC unavailable"}\n'
  exit 0
}

idx=$(( val * ${#ICONS[@]} / 101 ))
(( idx >= ${#ICONS[@]} )) && idx=$(( ${#ICONS[@]} - 1 ))

printf '{"text": "%s %d%%", "tooltip": "Monitor brightness: %d%%"}\n' \
  "${ICONS[$idx]}" "$val" "$val"
