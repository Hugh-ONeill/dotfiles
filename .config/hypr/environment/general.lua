---------------------
--- LOOK AND FEEL ---
---------------------
-- Sizes, gaps, colors, opacity, blur and shadows live in environment/theme.lua
-- because the active theme sets them.

hl.config({
    general = {
        layout                 = "dwindle",
        no_focus_fallback      = false,
        resize_on_border       = true,
        extend_border_grab_area = 15,
        hover_icon_on_border   = true,
        allow_tearing          = false,
        resize_corner          = 0,

        snap = {
            enabled        = true,
            window_gap     = 10,
            monitor_gap    = 10,
            border_overlap = false,
        },
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        vrr                      = 1,
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        animate_manual_resizes   = true,
        animate_mouse_windowdragging = true,
        -- let a fresh hyprlock take over the session if the old one crashes
        allow_session_lock_restore = true,
        -- any input wakes the display; without these a dpms-off screen stays black
        key_press_enables_dpms  = true,
        mouse_move_enables_dpms = true,
    },

    group = {
        groupbar = {
            middle_click_close = true,
        },
    },

    debug = {
        disable_logs       = true,
        disable_time       = true,
        enable_stdout_logs = false,
        vfr                = true,
    },

    xwayland = {
        force_zero_scaling = true,
    },

    -------------
    --- INPUT ---
    -------------
    input = {
        kb_layout  = "us",
        kb_options = "caps:swapescape",

        repeat_rate  = 25,
        repeat_delay = 500,

        sensitivity  = 0,
        follow_mouse = 1,

        touchpad = {
            disable_while_typing = true,
            natural_scroll       = false,
            tap_to_click         = false,
        },
    },

    cursor = {
        no_hardware_cursors = true,
    },
})

-- Special workspace styling (scratchpad).
-- Only workspace rules work here - window rules don't apply to special workspaces.
hl.workspace_rule({
    workspace   = "special:scratchpad",
    gaps_out    = 100,
    gaps_in     = 40,
    border_size = 4,
    decorate    = true,
})
