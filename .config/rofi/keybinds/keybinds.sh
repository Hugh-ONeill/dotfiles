#!/usr/bin/env bash
# vim:ft=bash

# ══════════════════════════════════════════════════════════════════════════════
# Rofi Keybinds Cheatsheet
# Parses hyprland keybinds.lua and displays in rofi
# ══════════════════════════════════════════════════════════════════════════════
DIR="$(dirname "$0")"
CONF="$HOME/.config/hypr/environment/keybinds.lua"
ACCENT=$(grep 'g7:' "$DIR/../shared/colors.rasi" | grep -oP '#[0-9a-fA-F]+')

# Turn the first argument of bind() into "SUPER + SHIFT + F"
format_combo() {
    local expr="$1" loop="$2" combo key
    expr="${expr/#mod/SUPER}"
    expr="${expr// .. /}"
    combo="${expr//\"/}"

    # The two bind loops use a variable for the key; show the whole range
    if [[ "$combo" == *key ]]; then
        case "$loop" in
            vim)        combo="${combo%key}H/J/K/L" ;;
            workspaces) combo="${combo%key}1-0" ;;
        esac
    fi

    key="${combo##* + }"
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

    if [[ "$combo" == *" + "* ]]; then
        echo "${combo% + *} + ${key}"
    else
        echo "$key"
    fi
}

# Describe a shell command passed to exec()
describe_command() {
    local cmd="$1"
    case "$cmd" in
        *volumecontrol\ -o\ i)     echo "Volume Up" ;;
        *volumecontrol\ -o\ d)     echo "Volume Down" ;;
        *volumecontrol\ -o\ m)     echo "Volume Mute" ;;
        *brightnesscontrol\ i)     echo "Brightness Up" ;;
        *brightnesscontrol\ d)     echo "Brightness Down" ;;
        *screenshot\ *)            echo "Screenshot: ${cmd##* }" ;;
        *workspace-scroll.sh\ up)  echo "Workspace Prev" ;;
        *workspace-scroll.sh\ down) echo "Workspace Next" ;;
        *snap-half.sh\ *)          echo "Snap ${cmd##* }" ;;
        *clipse*)                  echo "Clipboard" ;;
        hyprpicker\ -a)            echo "Color Picker" ;;
        "pypr toggle music")       echo "Music Dashboard" ;;
        "pypr toggle term")        echo "Drop-down Terminal" ;;
        *wpctl\ set-mute*)         echo "Mic Mute" ;;
        dolphin)                   echo "File Manager" ;;
        hyprlock)                  echo "Lock Screen" ;;
        *logoutlaunch*)            echo "Logout Menu" ;;
        *)                         echo "$cmd" ;;
    esac
}

# Describe the second argument of bind()
describe_action() {
    local action="$1" inner
    case "$action" in
        exec\(terminal\)*) echo "Terminal" ;;
        exec\(browser\)*)  echo "Browser" ;;
        exec\(\"*)
            inner="${action#exec(\"}"
            describe_command "${inner%%\")*}"
            ;;
        rofi\(*)
            inner="${action#rofi(}"
            case "${inner%%)*}" in
                launcher)    echo "App Launcher" ;;
                powermenu)   echo "Power Menu" ;;
                screenshot)  echo "Screenshot Menu" ;;
                nerdfonts)   echo "Nerd Fonts Picker" ;;
                calendar)    echo "Calendar" ;;
                bluetooth)   echo "Bluetooth" ;;
                notes)       echo "Notes" ;;
                todo)        echo "Todo" ;;
                network)     echo "Network" ;;
                wallpaper)   echo "Wallpaper Picker" ;;
                themepicker) echo "Theme Picker" ;;
                keybinds)    echo "Keybinds" ;;
                *)           echo "${inner%%)*}" ;;
            esac
            ;;
        dsp.window.close*)      echo "Close Window" ;;
        *mode\ =\ \"maximized*) echo "Fullscreen (maximize)" ;;
        *mode\ =\ \"fullscreen*) echo "Fullscreen (true)" ;;
        dsp.window.float*)      echo "Toggle Floating" ;;
        dsp.window.pseudo*)     echo "Toggle Pseudo-tile" ;;
        dsp.exit*)              echo "Exit Hyprland" ;;
        dsp.focus*workspace*)   echo "Go to Workspace" ;;
        dsp.focus*direction*)   echo "Move Focus" ;;
        *special:scratchpad*)   echo "Move to Scratchpad" ;;
        dsp.workspace.toggle_special*) echo "Toggle Scratchpad" ;;
        dsp.window.move*out_of_group*) echo "Move Out of Group" ;;
        dsp.window.move*into_group*)
            inner="${action#*into_group = \"}"
            echo "Move into Group ${inner%%\"*}"
            ;;
        dsp.window.move*workspace*) echo "Move to Workspace" ;;
        dsp.window.move*direction*) echo "Move Window" ;;
        dsp.window.drag*)       echo "Move Window" ;;
        *x\ =\ -*)              echo "Resize Left" ;;
        *x\ =\ [1-9]*)          echo "Resize Right" ;;
        *y\ =\ -*)              echo "Resize Up" ;;
        *y\ =\ [1-9]*)          echo "Resize Down" ;;
        dsp.window.resize*)     echo "Resize Window" ;;
        dsp.group.toggle*)      echo "Toggle Group" ;;
        dsp.group.prev*)        echo "Prev in Group" ;;
        dsp.group.next*)        echo "Next in Group" ;;
        *togglesplit*)          echo "Toggle Split" ;;
        dsp.layout\(\"*)
            inner="${action#dsp.layout(\"}"
            echo "Layout: ${inner%%\"*}"
            ;;
        *)                      echo "$action" ;;
    esac
}

generate_entries() {
    local section="" saw_divider=0 loop="" line combo desc
    local divider='^-- ═'
    local header='^-- ([A-Za-z].+)'
    local bind_call='^bind\(([^,]+),[[:space:]]*(.+)\)$'

    while IFS= read -r line; do
        # Bind loops are indented; everything else is flush left
        line="${line#"${line%%[![:space:]]*}"}"

        # Track ═══ divider lines
        if [[ "$line" =~ $divider ]]; then
            saw_divider=1
            continue
        fi

        # Section headers: only after ═══ divider
        if (( saw_divider )) && [[ "$line" =~ $header ]]; then
            section="${BASH_REMATCH[1]}"
            section="${section%% - *}"
            saw_divider=0
            echo "<span background='${ACCENT}' color='#000000'>  ${section//&/&amp;}  </span>"
            continue
        fi
        saw_divider=0

        # Remember which loop the following binds belong to
        case "$line" in
            "for key, direction in pairs(vim)"*) loop="vim"; continue ;;
            "for i = 1, 10"*)                    loop="workspaces"; continue ;;
            end)                                 loop=""; continue ;;
        esac

        [[ "$line" =~ $bind_call ]] || continue
        combo="$(format_combo "${BASH_REMATCH[1]}" "$loop")"
        desc="$(describe_action "${BASH_REMATCH[2]}")"

        printf "%-30s  %s\n" "$combo" "$desc"
    done < "$CONF"
}

generate_entries | rofi -dmenu -i -markup-rows -p "Keybinds" -theme "${DIR}/style.rasi"
