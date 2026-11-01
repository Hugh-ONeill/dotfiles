-- Plugin helpers for the config.
--
-- hl.plugin.load(path) only REGISTERS a .so with the current config pass;
-- Hyprland loads it after the pass finishes and then reloads the config, so
-- the plugin's own options (plugin.<name>.*) exist from the second pass on.
-- plugins.loaded() is the guard that keeps hl.config() from erroring on those
-- keys during the first pass. Plugins that drop out of the config are
-- unloaded on reload, so a theme can bring its own plugin along.
--
-- The .so files come from hyprpm (/var/cache/hyprpm/<user>/...). They are
-- built against one Hyprland API version; after a Hyprland upgrade run
-- `hyprpm update` or every load fails with a version-mismatch notification.

local M = {}

M.dir = "/var/cache/hyprpm/" .. (os.getenv("USER") or "wiz") .. "/hyprland-plugins"

local function exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

function M.path(name)
    return M.dir .. "/" .. name .. ".so"
end

-- True once Hyprland has actually loaded the plugin (by its PLUGIN_INIT name).
function M.loaded(name)
    for _, p in ipairs(hl.get_loaded_plugins()) do
        if p.name == name then
            return true
        end
    end
    return false
end

-- Register the plugin with this config pass. Returns false (and does nothing)
-- when the .so is not on disk, so a machine without hyprpm builds still boots.
function M.want(name)
    local path = M.path(name)
    if not exists(path) then
        return false
    end
    hl.plugin.load(path)
    return true
end

return M
