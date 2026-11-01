----------------
--- PROGRAMS ---
----------------

local terminal = "kitty"
local browser  = "firefox"

-- Launchers
local launcher    = "~/.config/rofi/launcher/launcher.sh"
local powermenu   = "~/.config/rofi/powermenu/powermenu.sh"
local screenshot  = "~/.config/rofi/screenshot/screenshot.sh"
local nerdfonts   = "~/.config/rofi/nerdfonts/nerdfonts.sh"
local calendar    = "~/.config/rofi/calendar/calendar.sh"
local bluetooth   = "~/.config/rofi/bluetooth/bluetooth.sh"
local notes       = "~/.config/rofi/notes/notes.sh"
local todo        = "~/.config/rofi/todo/todo.sh"
local network     = "~/.config/rofi/network/network.sh"
local wallpaper   = "~/.config/rofi/wallpaper/wallpaper.sh"
local themepicker = "~/.local/bin/theme rofi"
local keybinds    = "~/.config/rofi/keybinds/keybinds.sh"

-------------------
--- KEYBINDINGS ---
-------------------
-- Key strings are "MOD + MOD + key"; an empty-mod bind is just "key".
-- Old flag suffixes map to the options table:
--   binde -> { repeating = true }   bindl -> { locked = true }
--   bindel -> { locked = true, repeating = true }   bindm -> { mouse = true }
-- Dispatchers are hl.dsp.* calls (see HL.DspNamespace in the stubs); the old
-- names are gone, including from `hyprctl dispatch`, which now takes the
-- same Lua expression.

hl.config({
    binds = {
        pass_mouse_when_bound     = false,
        scroll_event_delay        = 300,
        workspace_back_and_forth  = true,
        allow_workspace_cycles    = true,
        workspace_center_on       = 0,
        focus_preferred_method    = 0,
        ignore_group_lock         = false,
        movefocus_cycles_fullscreen = true,
        movefocus_cycles_groupfirst = false,
        disable_keybind_grabbing  = false,
        window_direction_monitor_fallback = true,
        allow_pin_fullscreen      = false,
    },
})

local mod = "SUPER"

local bind = hl.bind
local exec = hl.dsp.exec_cmd
local dsp  = hl.dsp

-- rofi menus toggle: a second press closes the open one
local function rofi(script)
    return exec("pkill -x rofi || " .. script)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Launch applications
-- ═══════════════════════════════════════════════════════════════════════════

bind(mod .. " + Q", exec(terminal))
bind(mod .. " + E", exec(browser))
bind(mod .. " + D", exec("dolphin"))
bind(mod .. " + A", rofi(launcher))

-- ═══════════════════════════════════════════════════════════════════════════
-- Menus & utilities
-- ═══════════════════════════════════════════════════════════════════════════

bind(mod .. " + X",      rofi(powermenu))
bind(mod .. " + V",      exec("kitty --class clipse -e clipse"))
bind(mod .. " + period", rofi(nerdfonts))
bind(mod .. " + Print",  rofi(screenshot))

bind(mod .. " + R",         rofi(themepicker))
bind(mod .. " + W",         rofi(wallpaper))
bind(mod .. " + N",         rofi(notes))
bind(mod .. " + C",         rofi(calendar))
bind(mod .. " + B",         rofi(bluetooth))
bind(mod .. " + backslash", rofi(network))
bind(mod .. " + slash",     rofi(todo))

-- ═══════════════════════════════════════════════════════════════════════════
-- Window management
-- ═══════════════════════════════════════════════════════════════════════════

bind(mod .. " + escape",      dsp.window.close())
bind(mod .. " + BACKSPACE",   exec("pkill -x wlogout || ~/.local/bin/logoutlaunch.sh"))
bind(mod .. " + F",           dsp.window.fullscreen({ mode = "maximized" }))
bind(mod .. " + SHIFT + F",   dsp.window.fullscreen({ mode = "fullscreen" }))
bind(mod .. " + T",           dsp.window.float())
bind(mod .. " + P",           dsp.window.pseudo())
bind(mod .. " + O",           dsp.layout("togglesplit"))

-- ═══════════════════════════════════════════════════════════════════════════
-- Session
-- ═══════════════════════════════════════════════════════════════════════════

bind(mod .. " + DELETE",         exec("hyprlock"))
bind(mod .. " + SHIFT + DELETE", dsp.exit())

-- ═══════════════════════════════════════════════════════════════════════════
-- Move focus (vim-style: h=left, j=down, k=up, l=right)
-- ═══════════════════════════════════════════════════════════════════════════

local vim = { H = "left", J = "down", K = "up", L = "right" }

for key, direction in pairs(vim) do
    bind(mod .. " + " .. key,            dsp.focus({ direction = direction }))
    bind(mod .. " + SHIFT + " .. key,    dsp.window.move({ direction = direction }))
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Workspaces
-- ═══════════════════════════════════════════════════════════════════════════

for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    bind(mod .. " + " .. key,            dsp.focus({ workspace = i }))
    bind(mod .. " + SHIFT + " .. key,    dsp.window.move({ workspace = i }))
end

-- Scroll workspaces
bind(mod .. " + mouse_down", exec("~/.config/waybar/scripts/workspace-scroll.sh down"))
bind(mod .. " + mouse_up",   exec("~/.config/waybar/scripts/workspace-scroll.sh up"))

-- Special workspace (scratchpad)
bind(mod .. " + S",         dsp.workspace.toggle_special("scratchpad"))
bind(mod .. " + SHIFT + S", dsp.window.move({ workspace = "special:scratchpad" }))

-- ═══════════════════════════════════════════════════════════════════════════
-- Layout
-- ═══════════════════════════════════════════════════════════════════════════

bind(mod .. " + UP",           dsp.layout("cyclenext"))
bind(mod .. " + DOWN",         dsp.layout("cycleprev"))
bind(mod .. " + SHIFT + UP",   dsp.layout("swapnext"))
bind(mod .. " + SHIFT + DOWN", dsp.layout("swapprev"))
bind(mod .. " + grave",        dsp.layout("orientationcycle left right bottom top"))

-- Resize
local repeating = { repeating = true }
bind(mod .. " + CTRL + H", dsp.window.resize({ x = -50, y = 0,   relative = true }), repeating)
bind(mod .. " + CTRL + L", dsp.window.resize({ x = 50,  y = 0,   relative = true }), repeating)
bind(mod .. " + CTRL + K", dsp.window.resize({ x = 0,   y = -50, relative = true }), repeating)
bind(mod .. " + CTRL + J", dsp.window.resize({ x = 0,   y = 50,  relative = true }), repeating)

-- ═══════════════════════════════════════════════════════════════════════════
-- Groups
-- ═══════════════════════════════════════════════════════════════════════════

bind(mod .. " + G",         dsp.group.toggle())
bind(mod .. " + ALT + G",   dsp.window.move({ out_of_group = true }))
bind(mod .. " + U",         dsp.group.prev())
bind(mod .. " + I",         dsp.group.next())
bind(mod .. " + SHIFT + Y", dsp.window.move({ into_group = "left" }))
bind(mod .. " + SHIFT + U", dsp.window.move({ into_group = "down" }))
bind(mod .. " + SHIFT + I", dsp.window.move({ into_group = "up" }))
bind(mod .. " + SHIFT + O", dsp.window.move({ into_group = "right" }))

-- ═══════════════════════════════════════════════════════════════════════════
-- Snap to screen halves
-- ═══════════════════════════════════════════════════════════════════════════

bind(mod .. " + ALT + H", exec("~/.config/hypr/scripts/snap-half.sh left"))
bind(mod .. " + ALT + L", exec("~/.config/hypr/scripts/snap-half.sh right"))
bind(mod .. " + ALT + K", exec("~/.config/hypr/scripts/snap-half.sh top"))
bind(mod .. " + ALT + J", exec("~/.config/hypr/scripts/snap-half.sh bottom"))

-- ═══════════════════════════════════════════════════════════════════════════
-- Mouse
-- ═══════════════════════════════════════════════════════════════════════════

bind(mod .. " + mouse:272", dsp.window.drag(),   { mouse = true })
bind(mod .. " + mouse:273", dsp.window.resize(), { mouse = true })

-- ═══════════════════════════════════════════════════════════════════════════
-- Media & hardware
-- ═══════════════════════════════════════════════════════════════════════════

local locked_repeat = { locked = true, repeating = true }
local locked        = { locked = true }

-- Volume
bind("XF86AudioRaiseVolume", exec("~/.local/bin/volumecontrol -o i"), locked_repeat)
bind("XF86AudioLowerVolume", exec("~/.local/bin/volumecontrol -o d"), locked_repeat)
bind("XF86AudioMute",        exec("~/.local/bin/volumecontrol -o m"), locked)
bind("XF86AudioMicMute",     exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), locked)

-- Brightness
bind("XF86MonBrightnessUp",   exec("~/.local/bin/brightnesscontrol i"), locked_repeat)
bind("XF86MonBrightnessDown", exec("~/.local/bin/brightnesscontrol d"), locked_repeat)

-- ═══════════════════════════════════════════════════════════════════════════
-- Screenshots (direct) - saves to file and copies to clipboard
-- ═══════════════════════════════════════════════════════════════════════════

bind("Print",          exec("~/.local/bin/screenshot output"))
bind("ALT + Print",    exec("~/.local/bin/screenshot region"))
bind("CTRL + Print",   exec("~/.local/bin/screenshot window"))

-- ═══════════════════════════════════════════════════════════════════════════
-- Utilities
-- ═══════════════════════════════════════════════════════════════════════════

bind(mod .. " + M",             exec("~/.local/bin/music"))
bind(mod .. " + SHIFT + P",     exec("hyprpicker -a"))
bind(mod .. " + SHIFT + slash", rofi(keybinds))
