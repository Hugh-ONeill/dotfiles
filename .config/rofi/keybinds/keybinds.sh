#!/usr/bin/env bash
# vim:ft=bash

# ══════════════════════════════════════════════════════════════════════════════
# Rofi Keybinds Cheatsheet
# Parses hyprland keybinds.conf and displays in rofi
# ══════════════════════════════════════════════════════════════════════════════
DIR="$(dirname "$0")"
CONF="$HOME/.config/hypr/environment/keybinds.conf"
ACCENT=$(grep 'g7:' "$DIR/../shared/colors.rasi" | grep -oP '#[0-9a-fA-F]+')

generate_entries() {
    local section="" saw_divider=0
    while IFS= read -r line; do
        # Track ═══ divider lines
        if [[ "$line" =~ ^#\ ═ ]]; then
            saw_divider=1
            continue
        fi

        # Section headers: only after ═══ divider
        if (( saw_divider )) && [[ "$line" =~ ^#\ ([A-Za-z].+) ]]; then
            section="${BASH_REMATCH[1]}"
            saw_divider=0
            [[ "$section" == "PROGRAMS" || "$section" == "Launchers" ]] && continue
            echo "<span background='${ACCENT}' color='#000000'>  ${section//&/&amp;}  </span>"
            continue
        fi
        saw_divider=0

        # Skip comments, empty lines, non-bind lines, config blocks
        [[ "$line" =~ ^# ]] && continue
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^(\$|binds|}) ]] && continue
        [[ ! "$line" =~ ^bind[eml]*\ = ]] && continue

        # Parse: bind[flags] = MODS, KEY, DISPATCHER, ARGS
        local rhs="${line#*= }"
        IFS=',' read -r mods key dispatcher args <<< "$rhs"

        # Clean up whitespace
        mods="${mods## }"; mods="${mods%% }"
        key="${key## }"; key="${key%% }"
        dispatcher="${dispatcher## }"; dispatcher="${dispatcher%% }"
        args="${args## }"; args="${args%% }"

        # Translate key names
        case "$key" in
            mouse:272)  key="LMB" ;;
            mouse:273)  key="RMB" ;;
            mouse:274)  key="MMB" ;;
            mouse_up)   key="Scroll Up" ;;
            mouse_down) key="Scroll Down" ;;
            XF86AudioRaiseVolume)  key="Vol+" ;;
            XF86AudioLowerVolume)  key="Vol-" ;;
            XF86AudioMute)         key="Mute" ;;
            XF86AudioMicMute)      key="Mic Mute" ;;
            XF86MonBrightnessUp)   key="Bright+" ;;
            XF86MonBrightnessDown) key="Bright-" ;;
        esac

        # Format modifier + key
        local combo=""
        if [[ -z "$mods" ]]; then
            combo="$key"
        else
            combo="${mods} + ${key}"
        fi

        # Format action description
        local desc=""
        case "$dispatcher" in
            exec)
                # Clean up exec targets
                desc="$args"
                # Resolve variables
                desc="${desc/\$TERMINAL/Terminal}"
                desc="${desc/\$BROWSER/Browser}"
                desc="${desc/\$LAUNCHER/App Launcher}"
                desc="${desc/\$POWERMENU/Power Menu}"
                desc="${desc/\$SCREENSHOT/Screenshot Menu}"
                desc="${desc/\$NERDFONTS/Nerd Fonts Picker}"
                desc="${desc/\$CALENDAR/Calendar}"
                desc="${desc/\$BLUETOOTH/Bluetooth}"
                desc="${desc/\$NOTES/Notes}"
                desc="${desc/\$TODO/Todo}"
                desc="${desc/\$NETWORK/Network}"
                desc="${desc/\$WALLPAPER/Wallpaper Picker}"
                # Strip pkill prefixes
                desc="${desc#pkill -x rofi || }"
                # Shorten paths
                desc="${desc/#*volumecontrol -o i/Volume Up}"
                desc="${desc/#*volumecontrol -o d/Volume Down}"
                desc="${desc/#*volumecontrol -o m/Volume Mute}"
                desc="${desc/#*brightnesscontrol i/Brightness Up}"
                desc="${desc/#*brightnesscontrol d/Brightness Down}"
                desc="${desc/#*screenshot /Screenshot: }"
                desc="${desc/#*workspace-scroll.sh up/Workspace Prev}"
                desc="${desc/#*workspace-scroll.sh down/Workspace Next}"
                desc="${desc/#*snap-half.sh /Snap }"
                desc="${desc/#*clipse/Clipboard}"
                desc="${desc/#hyprpicker -a/Color Picker}"
                desc="${desc/#*music/Music Dashboard}"
                desc="${desc/#*wpctl set-mute*/Mic Mute}"
                desc="${desc/#dolphin/File Manager}"
                desc="${desc/#hyprlock/Lock Screen}"
                desc="${desc/#pkill -x wlogout || wlogout/Logout Menu}"
                desc="${desc/\$THEMEPICKER/Theme Picker}"
                desc="${desc/\$KEYBINDS/Keybinds}"
                ;;
            killactive)    desc="Kill Window" ;;
            fullscreen)
                [[ "$args" == "1" ]] && desc="Fullscreen (maximize)" || desc="Fullscreen (true)"
                ;;
            togglefloating) desc="Toggle Floating" ;;
            pseudo)         desc="Toggle Pseudo-tile" ;;
            togglesplit)    desc="Toggle Split" ;;
            exit)           desc="Exit Hyprland" ;;
            movefocus)      desc="Focus ${args}" ;;
            movewindow)     desc="Move Window${args:+ ${args}}" ;;
            resizewindow)   desc="Resize Window${args:+ ${args}}" ;;
            workspace)      desc="Workspace ${args}" ;;
            movetoworkspace)
                [[ "$args" == *"scratchpad"* ]] && desc="Move to Scratchpad" || desc="Move to Workspace ${args}"
                ;;
            togglespecialworkspace) desc="Toggle Scratchpad" ;;
            layoutmsg)      desc="Layout: ${args}" ;;
            resizeactive)   desc="Resize ${args}" ;;
            togglegroup)    desc="Toggle Group" ;;
            moveoutofgroup) desc="Move Out of Group" ;;
            changegroupactive) [[ "$args" == "b" ]] && desc="Prev in Group" || desc="Next in Group" ;;
            moveintogroup)  desc="Move into Group ${args}" ;;
            *)              desc="${dispatcher} ${args}" ;;
        esac

        printf "%-24s  %s\n" "$combo" "$desc"
    done < "$CONF"
}

generate_entries | rofi -dmenu -i -markup-rows -p "Keybinds" -theme "${DIR}/style.rasi"
