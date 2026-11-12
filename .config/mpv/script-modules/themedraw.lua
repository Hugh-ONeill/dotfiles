-- Shared drawing helpers for the themed overlays: the theme gradient, ASS
-- vector shapes and color conversion.
-- Usage: local draw = require "themedraw", after the script has added
-- ~~/script-modules/?.lua to package.path; the gradient comes from the theme's
-- script-opts (theme-gradient)

local mp = require "mp"
local options = require "mp.options"

local M = {}

local opts = {
    gradient = "",  -- space-separated #RRGGBB list, set by the theme
}
options.read_options(opts, "theme")

-- ============================================================
-- COLORS
-- ============================================================

-- "#RRGGBB" or mpv's "#AARRGGBB" -> { r, g, b }
function M.parse_hex(hex)
    hex = hex:gsub("^#", "")
    if #hex == 8 then hex = hex:sub(3) end
    return {
        tonumber(hex:sub(1, 2), 16) or 255,
        tonumber(hex:sub(3, 4), 16) or 255,
        tonumber(hex:sub(5, 6), 16) or 255,
    }
end

-- { r, g, b } -> ASS "BBGGRR"
function M.bgr(c)
    return string.format("%02X%02X%02X", c[3], c[2], c[1])
end

-- an mpv color option (osd-color, background-color, ...) as ASS "BBGGRR"
function M.option_bgr(name, fallback)
    return M.bgr(M.parse_hex(mp.get_property(name) or fallback or "#FFFFFFFF"))
end

-- the theme gradient as a list of { r, g, b }; one accent color without a theme
function M.gradient()
    local cols = {}
    for c in opts.gradient:gmatch("#%x%x%x%x%x%x") do
        cols[#cols + 1] = M.parse_hex(c)
    end
    if #cols == 0 then
        cols[1] = M.parse_hex(mp.get_property("osd-selected-color") or "#FFFABD2F")
    end
    return cols
end

-- position 0..1 along the gradient as ASS "BBGGRR". wrap=true joins the last
-- color back to the first, for animations that cycle
function M.color_at(cols, pos, wrap)
    local n = #cols
    if n == 1 then return M.bgr(cols[1]) end
    local a, b, f
    if wrap then
        pos = (pos % 1) * n
        local i = math.floor(pos)
        a, b, f = cols[i + 1], cols[(i + 1) % n + 1], pos - i
    else
        pos = math.max(0, math.min(1, pos)) * (n - 1)
        local i = math.min(math.floor(pos), n - 2)
        a, b, f = cols[i + 1], cols[i + 2], pos - i
    end
    local function mix(k) return math.floor(a[k] + (b[k] - a[k]) * f + 0.5) end
    return string.format("%02X%02X%02X", mix(3), mix(2), mix(1))
end

-- ============================================================
-- SHAPES
-- ============================================================

-- rounded rectangle as an ASS vector path, origin top-left
function M.rrect(w, h, r)
    r = math.max(0, math.min(r, w / 2, h / 2))
    local k = r * 0.5523  -- bezier circle constant
    return string.format(
        "m %.1f 0 l %.1f 0 b %.1f 0 %.1f %.1f %.1f %.1f " ..
        "l %.1f %.1f b %.1f %.1f %.1f %.1f %.1f %.1f " ..
        "l %.1f %.1f b %.1f %.1f %.1f %.1f %.1f %.1f " ..
        "l %.1f %.1f b %.1f %.1f %.1f %.1f %.1f %.1f",
        r, w - r, w - r + k, w, r - k, w, r,
        w, h - r, w, h - r + k, w - r + k, h, w - r, h,
        r, h, r - k, h, 0, h - r + k, 0, h - r,
        0, r, 0, r - k, r - k, 0, r, 0)
end

-- one ASS event: a filled path with its top-left origin at (x, y).
-- color is "BBGGRR", alpha "00" (opaque) .. "FF" (invisible)
function M.shape(x, y, color, alpha, path)
    return string.format(
        "{\\an7\\pos(%.1f,%.1f)\\bord0\\shad0\\blur0\\1c&H%s&\\1a&H%s&\\p1}%s{\\p0}",
        x, y, color, alpha or "00", path)
end

-- one ASS event: plain text anchored at (x, y) with numpad alignment `an`
function M.text(x, y, an, size, color, alpha, text)
    return string.format(
        "{\\an%d\\pos(%.1f,%.1f)\\fs%.1f\\bord0\\shad0\\1c&H%s&\\1a&H%s&}%s",
        an, x, y, size, color, alpha or "00", M.escape(text))
end

function M.escape(s)
    return (s:gsub("\\", "\\\226\129\160"):gsub("{", "\\{"):gsub("\n", " "))
end

-- 0..255 -> ASS alpha byte, where 0 is opaque
function M.alpha(a)
    return string.format("%02X", math.max(0, math.min(255, math.floor(a + 0.5))))
end

return M
