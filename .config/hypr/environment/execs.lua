-----------------
--- AUTOSTART ---
-----------------
-- hl.on("hyprland.start") fires once after the first config pass and never on
-- reload: the Lua equivalent of exec-once. Each command runs through
-- /bin/sh -c, all of them concurrently, not in list order.
--
-- Plugins are not started from here any more (`hyprpm reload` is gone):
-- environment/theme.lua registers them with hl.plugin.load().

local once = {
    -- Portal and environment setup.
    -- Export first, reset second: xdg-desktop-portal-hyprland.service has
    -- ConditionEnvironment=WAYLAND_DISPLAY. The reset script waits for the
    -- variable rather than trusting the order -- keep the order anyway, it
    -- documents the dependency. Under uwsm the two exports are redundant
    -- (uwsm populates the activation environment itself) but harmless, and
    -- they keep a plain hyprland.desktop session working.
    "dbus-update-activation-environment --systemd --all",
    "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP",
    "~/.config/hypr/scripts/xdg-desktop-portal-reset.sh",

    -- Services
    "systemctl --user start hyprpolkitagent",
    "systemctl --user restart dunst",
    "hypridle",

    -- UI
    -- waybar runs under waybar.service (supervised, so a wl_output teardown
    -- can't leave the bar gone). It is wanted by graphical-session.target, so
    -- it is already up by now; this applies the theme and restarts it to pick
    -- the fresh config up. reset-failed first: if it ever trips its start
    -- limit, a plain restart is refused.
    "~/.local/bin/theme set catppuccin && systemctl --user reset-failed waybar.service; systemctl --user restart waybar.service",
    "~/.config/hypr/scripts/handle-monitors.sh --listen",
    -- Wallpaper: awww-daemon runs under awww-daemon.service; wallpaper-init
    -- just starts it and restores the image (handles animated GIFs).
    "~/.local/bin/wallpaper-init",
    "~/.config/hypr/scripts/set-cursor.sh",

    -- Utilities
    "clipse -listen",
    "pypr",
    "udiskie",
}

hl.on("hyprland.start", function()
    for _, cmd in ipairs(once) do
        hl.exec_cmd(cmd)
    end
end)
