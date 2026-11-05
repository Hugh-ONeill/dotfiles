-- Animated loading screen: a wave of theme-gradient bars plus the title,
-- drawn from file start until the first frame (or audio) is up.
-- Usage: loaded automatically from ~~/scripts; colors come from the
-- theme's script-opts (loading-gradient), falling back to osd-selected-color

local options = require "mp.options"

local opts = {
    gradient = "",  -- space-separated #RRGGBB list, set by the theme
    bars = 0,       -- 0 = one bar per gradient color (min 10)
    fps = 60,
}
options.read_options(opts, "loading")

local overlay = mp.create_osd_overlay("ass-events")
local timer, t0, colors

-- ============================================================
-- COLORS
-- ============================================================

local function parse_hex(hex)
    hex = hex:gsub("^#", "")
    if #hex == 8 then hex = hex:sub(3) end  -- drop mpv's alpha byte
    return {
        tonumber(hex:sub(1, 2), 16) or 255,
        tonumber(hex:sub(3, 4), 16) or 255,
        tonumber(hex:sub(5, 6), 16) or 255,
    }
end

local function load_colors()
    local cols = {}
    for c in opts.gradient:gmatch("#%x%x%x%x%x%x") do
        cols[#cols + 1] = parse_hex(c)
    end
    if #cols == 0 then
        cols[1] = parse_hex(mp.get_property("osd-selected-color") or "#FFFABD2F")
    end
    return cols
end

-- smooth position along the gradient (wraps), as an ASS BBGGRR string
local function color_at(pos)
    local n = #colors
    pos = (pos % 1) * n
    local i = math.floor(pos)
    local f = pos - i
    local a, b = colors[i + 1], colors[(i + 1) % n + 1]
    local function mix(k) return math.floor(a[k] + (b[k] - a[k]) * f + 0.5) end
    return string.format("%02X%02X%02X", mix(3), mix(2), mix(1))
end

-- ============================================================
-- DRAWING
-- ============================================================

-- rounded rectangle as an ASS vector path, origin top-left
local function rrect(w, h, r)
    r = math.min(r, w / 2, h / 2)
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

local function ass_escape(s)
    return (s:gsub("\\", "\\\226\129\160"):gsub("{", "\\{"):gsub("\n", " "))
end

local function draw()
    local w, h = mp.get_osd_size()
    if not w or w == 0 or h == 0 then return end
    local t = mp.get_time() - t0
    local n = opts.bars > 0 and opts.bars or math.max(#colors, 10)

    local unit = math.min(w, h) / 40
    local bw, gap = unit * 1.3, unit * 0.8
    local maxh = unit * 10
    local x0 = (w - (n * bw + (n - 1) * gap)) / 2
    local cy = h / 2 - unit * 2

    local ass = {}
    for i = 0, n - 1 do
        -- a travelling wave with a slower cross-wave so it never looks periodic
        local s1 = 0.5 + 0.5 * math.sin(t * 5.0 - i * 0.6)
        local s2 = 0.5 + 0.5 * math.sin(t * 3.1 + i * 1.3)
        local bh = maxh * (0.12 + 0.88 * (0.7 * s1 + 0.3 * s2))
        ass[#ass + 1] = string.format(
            "{\\an7\\pos(%.1f,%.1f)\\bord0\\shad0\\1c&H%s&\\p1}%s{\\p0}",
            x0 + i * (bw + gap), cy - bh / 2,
            color_at(i / n - t * 0.2), rrect(bw, bh, bw / 2))
    end

    local title = mp.get_property("media-title") or ""
    if #title > 90 then title = title:sub(1, 87) .. "…" end
    local fg = parse_hex(mp.get_property("osd-color") or "#FFFFFFFF")
    ass[#ass + 1] = string.format(
        "{\\an8\\pos(%.1f,%.1f)\\fs%.1f\\bord0\\shad0\\1c&H%02X%02X%02X&}%s",
        w / 2, cy + maxh / 2 + unit * 2, unit * 1.6,
        fg[3], fg[2], fg[1], ass_escape(title))

    overlay.res_x, overlay.res_y = w, h
    overlay.data = table.concat(ass, "\n")
    overlay:update()
end

-- ============================================================
-- LIFECYCLE
-- ============================================================

local function hide()
    if timer then timer:kill(); timer = nil end
    overlay:remove()
end

local function show()
    hide()
    colors = load_colors()
    t0 = mp.get_time()
    timer = mp.add_periodic_timer(1 / opts.fps, draw)
    draw()
end

mp.register_event("start-file", show)
mp.register_event("playback-restart", hide)
mp.register_event("end-file", hide)
