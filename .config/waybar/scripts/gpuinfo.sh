#!/bin/bash
# gpuinfo.sh: waybar custom/gpu module for amdgpu, read straight from sysfs (no root, no smi tool).
# Picks the amdgpu card with the most VRAM (the R9700, not the iGPU) unless GPU_PCI=0000:03:00.0 is set.
# Text colour keys off the HOTSPOT (junction) temp, which is what RDNA throttles on (~110°C);
# falls back to edge temp with the old 70/80 thresholds if the card has no junction sensor.

# source theme colors (fallback to defaults)
source "$HOME/.config/themes/current/waybar-script-colors.sh" 2>/dev/null
COLOR_ERR="${COLOR_ERR:-#ff5555}"
COLOR_WARN="${COLOR_WARN:-#f1fa8c}"

err() { echo "{\"text\": \"<span color='${COLOR_ERR}'>󰾲 $1</span>\", \"tooltip\": \"$2\"}"; exit 0; }

# --- locate the card ---
dev=""
if [[ -n ${GPU_PCI:-} && -d /sys/bus/pci/devices/$GPU_PCI ]]; then
	dev="/sys/bus/pci/devices/$GPU_PCI"
else
	best=0
	for d in /sys/class/drm/card*/device; do
		[[ -r $d/mem_info_vram_total ]] || continue
		[[ $(basename "$(readlink -f "$d/driver" 2>/dev/null)") == amdgpu ]] || continue
		v=$(<"$d/mem_info_vram_total")
		(( v > best )) && { best=$v; dev=$d; }
	done
fi
[[ -n $dev ]] || err "N/A" "no amdgpu device found"

hw=$(ls -d "$dev"/hwmon/hwmon* 2>/dev/null | head -1)
rd()  { [[ -r $dev/$1 ]] && tr -d '\n' <"$dev/$1"; }
hrd() { [[ -n $hw && -r $hw/$1 ]] && tr -d '\n' <"$hw/$1"; }

gpu_util=$(rd gpu_busy_percent)
[[ $gpu_util =~ ^[0-9]+$ ]] || err "ERR" "gpu_busy_percent unreadable"

vram_used=$(rd mem_info_vram_used); vram_total=$(rd mem_info_vram_total)
[[ $vram_used =~ ^[0-9]+$ ]] || vram_used=0
[[ $vram_total =~ ^[0-9]+$ && $vram_total -gt 0 ]] || vram_total=1
gpu_mem_percent=$(( vram_used * 100 / vram_total ))
gpu_mem_used_gb=$(awk "BEGIN {printf \"%.1f\", $vram_used / 1073741824}")
gpu_mem_total_gb=$(awk "BEGIN {printf \"%.1f\", $vram_total / 1073741824}")

# temps (millidegrees): temp1 = edge, temp2 = junction/hotspot, temp3 = memory
t_edge=$(hrd temp1_input); t_junc=$(hrd temp2_input); t_mem=$(hrd temp3_input)
[[ $t_edge =~ ^[0-9]+$ ]] && gpu_temp=$(( t_edge / 1000 )) || gpu_temp=0
[[ $t_junc =~ ^[0-9]+$ ]] && hot_temp=$(( t_junc / 1000 )) || hot_temp=""

power=$(hrd power1_average); [[ $power =~ ^[0-9]+$ ]] || power=$(hrd power1_input)
power_cap=$(hrd power1_cap)
fan_rpm=$(hrd fan1_input)
pwm=$(hrd pwm1); [[ $pwm =~ ^[0-9]+$ ]] && fan_pct=$(( pwm * 100 / 255 ))

# clocks: hwmon freq1/freq2 are Hz; fall back to the '*'-marked pp_dpm level
f1=$(hrd freq1_input); f2=$(hrd freq2_input)
cur_clk() { awk '/\*/ {gsub(/[^0-9]/,"",$2); print $2; exit}' "$dev/$1" 2>/dev/null; }
[[ $f1 =~ ^[0-9]+$ ]] && gpu_clock=$(( f1 / 1000000 )) || gpu_clock=$(cur_clk pp_dpm_sclk)
[[ $f2 =~ ^[0-9]+$ ]] && gpu_mem_clock=$(( f2 / 1000000 )) || gpu_mem_clock=$(cur_clk pp_dpm_mclk)

# name: last [bracketed] token of the lspci line, e.g. [Radeon AI PRO R9700]
pci=$(basename "$(readlink -f "$dev")")
gpu_name=$(lspci -s "$pci" 2>/dev/null | grep -oE '\[[^]]*\]' | tail -1 | tr -d '[]')
: "${gpu_name:=AMD GPU}"

# text colour
if [[ -n $hot_temp ]]; then warn=90; crit=100; key=$hot_temp; else warn=70; crit=80; key=$gpu_temp; fi
if (( key >= crit )); then
	text_output="<span color='${COLOR_ERR}'>󰾲 ${gpu_util}%</span>"
elif (( key >= warn )); then
	text_output="<span color='${COLOR_WARN}'>󰾲 ${gpu_util}%</span>"
else
	text_output="󰾲 ${gpu_util}%"
fi

tooltip="${gpu_name} (${pci#0000:})\n"
tooltip+="\nUtilization: ${gpu_util}%"
tooltip+="\nTemperature: ${gpu_temp}°C edge"
[[ -n $hot_temp ]] && tooltip+=" / ${hot_temp}°C hotspot"
[[ $t_mem =~ ^[0-9]+$ ]] && tooltip+=" / $(( t_mem / 1000 ))°C mem"
tooltip+="\nMemory:      ${gpu_mem_used_gb} / ${gpu_mem_total_gb} GiB (${gpu_mem_percent}%)"
if [[ $power =~ ^[0-9]+$ ]]; then
	tooltip+="\nPower:       $(( power / 1000000 )) W"
	[[ $power_cap =~ ^[0-9]+$ ]] && tooltip+=" / $(( power_cap / 1000000 )) W cap"
fi
if [[ $fan_rpm =~ ^[0-9]+$ ]]; then
	tooltip+="\nFan:         ${fan_rpm} rpm"
	[[ -n ${fan_pct:-} ]] && tooltip+=" (${fan_pct}%)"
fi
[[ -n $gpu_clock ]] && tooltip+="\nGPU Clock:   ${gpu_clock} MHz"
[[ -n $gpu_mem_clock ]] && tooltip+="\nMem Clock:   ${gpu_mem_clock} MHz"

echo "{\"text\": \"$text_output\", \"tooltip\": \"$tooltip\"}"
