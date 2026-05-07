#!/bin/bash

source "$HOME/.config/themes/current/waybar-script-colors.sh" 2>/dev/null
: "${COLOR_ERR:=#f38ba8}"
: "${COLOR_WARN:=#f9e2af}"

HWMON=""
for d in /sys/class/hwmon/hwmon*; do
	[[ -f "$d/name" && "$(cat "$d/name")" == "nct6687" ]] && { HWMON=$d; break; }
done

if [[ -z "$HWMON" ]]; then
	printf '{"text": "<span color=\\"%s\\">N/A</span>", "tooltip": "nct6687 hwmon not found — is the module loaded?"}\n' "$COLOR_ERR"
	exit 0
fi

# Primary display: CPU Fan PWM%
cpu_pwm_raw=$(cat "$HWMON/pwm1" 2>/dev/null)
if [[ -z "$cpu_pwm_raw" ]]; then
	printf '{"text": "<span color=\\"%s\\">N/A</span>", "tooltip": "pwm1 unreadable"}\n' "$COLOR_ERR"
	exit 0
fi
cpu_pct=$(( cpu_pwm_raw * 100 / 255 ))

if (( cpu_pct >= 80 )); then
	color="$COLOR_ERR"
elif (( cpu_pct >= 60 )); then
	color="$COLOR_WARN"
else
	color=""
fi

if [[ -n "$color" ]]; then
	text=$(printf "<span color='%s'>%3d%%</span>" "$color" "$cpu_pct")
else
	text=$(printf "%3d%%" "$cpu_pct")
fi

# Tooltip: every labeled fan, PWM% + RPM
tooltip="Fans (PWM% / RPM)"
for i in 1 2 3 4 5 6 7 8; do
	label=$(cat "$HWMON/fan${i}_label" 2>/dev/null) || continue
	rpm=$(cat "$HWMON/fan${i}_input" 2>/dev/null)
	pwm=$(cat "$HWMON/pwm${i}" 2>/dev/null)
	[[ -z "$rpm" || -z "$pwm" ]] && continue
	# Skip fans that are both idle and driven at 0 — empty headers report pwm=255 at 0 rpm,
	# so filter on rpm=0 instead.
	(( rpm == 0 )) && continue
	pct=$(( pwm * 100 / 255 ))
	tooltip+=$'\n'"$(printf '  %-14s %3d%%  (%d RPM)' "$label" "$pct" "$rpm")"
done

tooltip_json=${tooltip//$'\n'/\\n}
printf '{"text": "%s", "tooltip": "%s"}\n' "$text" "$tooltip_json"
