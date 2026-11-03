-- Which machine this config is running on.
--
-- The config is shared between the laptop (HP ZBook 15 G5: Intel UHD 630 +
-- Quadro P2000, eDP-1) and the desktop (9900X iGPU + R9700). Hostnames match
-- on both, so key off DMI chassis_type instead: 8/9/10/14 are the SMBIOS
-- portable/laptop/notebook/sub-notebook types.

local M = {}

local function read(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local s = f:read("*l")
    f:close()
    return s
end

local LAPTOP_CHASSIS = { ["8"] = true, ["9"] = true, ["10"] = true, ["14"] = true }

M.laptop  = LAPTOP_CHASSIS[read("/sys/class/dmi/id/chassis_type") or ""] == true
M.desktop = not M.laptop

-- Resolve a /dev/dri/by-path link to its /dev/dri/cardN node. by-path names
-- can't go into AQ_DRM_DEVICES directly (aquamarine splits on ':', which
-- shreds the PCI address), and cardN numbering isn't stable across boots.
function M.drm_card(pci)
    local p = io.popen("readlink -f /dev/dri/by-path/pci-" .. pci .. "-card 2>/dev/null")
    if not p then
        return nil
    end
    local node = p:read("*l")
    p:close()
    if node and node:match("^/dev/dri/card%d+$") then
        return node
    end
    return nil
end

return M
