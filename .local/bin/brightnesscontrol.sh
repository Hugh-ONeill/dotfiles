#!/usr/bin/env bash

print_usage() {
  cat <<EOF
Usage: $(basename "${0}") <action> [step] 

Actions:
    i    <i>ncrease brightness [+5%]
    d    <d>ecrease brightness [-5%]

Optional:
    step  brightness change step [default: 5]


Examples:
    $(basename "${0}") i 10    # Increase brightness by 10%
    $(basename "${0}") d       # Decrease brightness by default step (5%)
EOF
  exit 1
}

send_notification() {
  local delta=$1
  brightness=$(brightnessctl info | grep -oP "(?<=\()\d+(?=%)" | cat)
  brightness_level=$((brightness / 15 + 1))
  ico="$HOME/.config/dunst/icons/brightness-${brightness_level:-4}.svg"
  notify-send -a "brightnesscontrol.sh" -r 1 -t 800 -h int:value:"${brightness}" -i "${ico}" "Brightness" "${brightness} (${delta})"
}

get_brightness() {
  brightnessctl -m | grep -o '[0-9]\+%' | head -c-2
}

step="${2:-5}"

case $1 in
i | -i)
  brightness=$(get_brightness)

  if [[ brightness -ge 100 ]]; then
    # do nothing
    delta="..."
  else
    # increase the backlight by 1% if less than 10%
    [ "${brightness}" -lt 10 ] && step=1

    brightnessctl set "${step}"%+
    delta="+${step}%"
  fi

  send_notification "$delta"
  ;;
d | -d)
  brightness=$(get_brightness)

  if [[ brightness -le 1 ]]; then
    # do nothing
    delta="..."
  else
    # decrease the backlight by 1% if less than 10%
    [ "${brightness}" -le 10 ] && step=1

    brightnessctl set "${step}"%-
    # escape "-"
    delta="\-${step}%"
  fi

  send_notification "$delta"
  ;;
*)
  print_usage
  ;;
esac
