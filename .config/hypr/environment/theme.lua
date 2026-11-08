-------------
--- THEME ---
-------------
-- Toolkit env, colors/decoration from the active theme, plugins, animations.
--
-- appearance/colors.lua is a symlink into ~/.config/themes/current/, written
-- by the theme switcher from templates/hypr-colors.lua.tmpl (or a per-theme
-- override). It is pure data: palette strings, style numbers, and optional
-- `window_rules` / `hyprbars` blocks that this file applies. No hl.* calls
-- live in there, so a theme can never half-apply.

local plugins = require("lib.plugins")
local c       = require("appearance.colors")

local function expand(path)
    return (path:gsub("^~", os.getenv("HOME") or "~"))
end

-- Toolkit theme. GTK_THEME deliberately not set: gsettings gtk-theme handles
-- it dynamically (apply_gtk in themes/lib/apps/desktop.sh updates gsettings
-- on theme switch). A hardcoded env var would override gsettings and pin
-- every GTK app to one theme.
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_STYLE_OVERRIDE", "kvantum")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

-- Cursor. Covers XWayland and Qt apps, which read the env. GTK apps ignore
-- this and use the gsettings keys that scripts/set-cursor.sh writes; the
-- compositor's own cursor comes from `hyprctl setcursor` in that same script.
hl.env("XCURSOR_THEME",    c.cursor_theme)
hl.env("XCURSOR_SIZE",     tostring(c.cursor_size))
hl.env("HYPRCURSOR_THEME", c.cursor_theme)
hl.env("HYPRCURSOR_SIZE",  tostring(c.cursor_size))

------------------
--- APPEARANCE ---
------------------

local rainbow_border = {
    colors = {
        "rgb(ff0000)", "rgb(ff8000)", "rgb(ffff00)", "rgb(00ff00)",
        "rgb(00ffff)", "rgb(0080ff)", "rgb(8000ff)", "rgb(ff00ff)",
    },
    angle = 45,
}

hl.config({
    general = {
        border_size     = c.theme_border_size,
        gaps_in         = c.theme_gaps_in,
        gaps_out        = c.theme_gaps_out,
        gaps_workspaces = 0,
        col = {
            active_border   = c.theme_active_border,
            inactive_border = c.theme_inactive_border,
            -- Windows that refuse grouping use these instead; in practice
            -- that is only the pyprland scratchpads. Fixed across themes.
            nogroup_border        = rainbow_border,
            nogroup_border_active = rainbow_border,
        },
    },

    decoration = {
        rounding      = c.theme_rounding,
        screen_shader = expand(c.theme_screen_shader or ""),

        active_opacity     = c.theme_active_opacity,
        inactive_opacity   = c.theme_inactive_opacity,
        fullscreen_opacity = 1.0,

        dim_inactive = c.theme_dim_inactive,
        dim_strength = c.theme_dim_strength,
        dim_special  = 0.3,
        dim_around   = 0.4,

        blur = {
            enabled           = c.theme_blur_enabled,
            size              = c.theme_blur_size,
            passes            = c.theme_blur_passes,
            ignore_opacity    = false,
            xray              = false,
            noise             = 0.0,
            contrast          = 1.0,
            brightness        = 0.95,
            vibrancy          = 0.15,
            vibrancy_darkness = 0.0,
            popups            = true,
            popups_ignorealpha = 0.6,
            special           = true,
        },

        shadow = {
            enabled        = c.theme_shadow_enabled,
            range          = 20,
            render_power   = 3,
            sharp          = false,
            color          = "rgba(" .. c.crustAlpha .. "ee)",
            color_inactive = "rgba(" .. c.crustAlpha .. "99)",
            offset         = "0 5",
            scale          = 1.0,
        },
    },

    misc = {
        background_color = "rgba(" .. c.baseAlpha .. "FF)",
    },

    animations = {
        enabled = true,
    },
})

---------------
--- PLUGINS ---
---------------
-- plugins.want() registers the .so for this pass; the plugin's options only
-- exist once Hyprland has loaded it, which happens after the pass and is
-- followed by an automatic reload. plugins.loaded() keeps the first pass from
-- erroring on keys that are not registered yet. Plugin key paths are the
-- hyprlang ones with ':' -> '.' and '-' -> '_'.

if plugins.want("borders-plus-plus") and plugins.loaded("borders-plus-plus") then
    hl.config({
        plugin = {
            borders_plus_plus = {
                add_borders      = c.theme_add_borders,
                border_size_1    = c.theme_bpp_border_size_1,
                border_size_2    = c.theme_bpp_border_size_2,
                natural_rounding = true,
                col = {
                    border_1 = "rgba(" .. c.bpp1Alpha .. "FF)",
                    border_2 = "rgba(" .. c.accentAlpha .. "FF)",
                },
            },
        },
    })
end

-- Theme-specific extras: extra window rules (win98/win99 float everything)
-- and hyprbars title bars. A theme without them leaves these nil, and a
-- reload that drops `hyprbars` unloads the plugin again.
for _, r in ipairs(c.window_rules or {}) do
    hl.window_rule(r)
end

if c.hyprbars then
    if plugins.want("hyprbars") and plugins.loaded("hyprbars") then
        hl.config({ plugin = { hyprbars = c.hyprbars.config or {} } })
        if hl.plugin.hyprbars and hl.plugin.hyprbars.add_button then
            for _, button in ipairs(c.hyprbars.buttons or {}) do
                hl.plugin.hyprbars.add_button(button)
            end
        end
    end
end

------------------
--- ANIMATIONS ---
------------------

require("appearance.animations")
