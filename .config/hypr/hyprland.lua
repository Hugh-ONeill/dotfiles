-- Hyprland config (Lua, 0.57+).
--
-- hyprlang is gone in 0.57: hyprland.conf and the environment/*.conf and
-- appearance/*.conf files beside this one are dead and only kept until this
-- file has survived a login. Delete them after that.
--
-- Modules resolve through package.path = ~/.config/hypr/?.lua, so
-- require("environment.env") is environment/env.lua. The whole config re-runs
-- on every reload in a fresh Lua state (binds, rules, events, timers and
-- plugin registrations are all cleared first), so nothing here needs to be
-- idempotent.
--
-- API reference for the installed version:
--   /usr/share/hypr/stubs/hl.meta.lua   typed stubs (every hl.* call, every
--                                       hl.config key and rule field)
--   /usr/share/hypr/hyprland.lua        the shipped example config

require("environment.env")
require("environment.monitors")
require("environment.execs")
require("environment.general")
require("environment.rules")
require("environment.theme")
require("environment.keybinds")
