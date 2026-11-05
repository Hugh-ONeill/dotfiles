-- Animated loading screen and buffering spinner in theme-gradient bars.
-- Loading: a wave of bars plus the title, from file start until the first
-- frame (or audio) is up. Buffering: a small, translucent wave in the
-- bottom-right corner while playback stalls on the network or a seek.
-- Usage: loaded automatically from ~~/scripts; colors come from the
-- theme's script-opts (loading-gradient), falling back to osd-selected-color

local options = require "mp.options"

local opts = {
    gradient = "",        -- space-separated #RRGGBB list, set by the theme
    bars = 0,             -- loading bars; 0 = one per gradient color (min 10)
    buffer_bars = 5,
    buffer_delay = 0.3,   -- seconds a stall lasts before the spinner shows
    buffer_alpha = "60",  -- backing pill alpha, 00 opaque .. FF invisible
    fps = 60,
}
options.read_options(opts, "loading")

local overlay = mp.create_osd_overlay("ass-events")
local timer, t0, colors
local loading = false
local stall_since = nil

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

-- n bars centred on (cx, cy); unit scales everything; spread is how much of
-- the gradient the row covers at once
local function bars(ass, t, n, unit, cx, cy, spread, alpha)
    local bw, gap = unit * 1.3, unit * 0.8
    local maxh = unit * 10
    local x0 = cx - (n * bw + (n - 1) * gap) / 2
    for i = 0, n - 1 do
        -- a travelling wave with a slower cross-wave so it never looks periodic
        local s1 = 0.5 + 0.5 * math.sin(t * 5.0 - i * 0.6)
        local s2 = 0.5 + 0.5 * math.sin(t * 3.1 + i * 1.3)
        local bh = maxh * (0.12 + 0.88 * (0.7 * s1 + 0.3 * s2))
        ass[#ass + 1] = string.format(
            "{\\an7\\pos(%.1f,%.1f)\\bord0\\shad0\\1c&H%s&\\1a&H%s&\\p1}%s{\\p0}",
            x0 + i * (bw + gap), cy - bh / 2,
            color_at(i / n * spread - t * 0.2), alpha, rrect(bw, bh, bw / 2))
    end
    return maxh
end

local function draw_loading(ass, t, w, h)
    local n = opts.bars > 0 and opts.bars or math.max(#colors, 10)
    local unit = math.min(w, h) / 40
    local cy = h / 2 - unit * 2
    local maxh = bars(ass, t, n, unit, w / 2, cy, 1, "00")

    local title = mp.get_property("media-title") or ""
    if #title > 90 then title = title:sub(1, 87) .. "…" end
    local fg = parse_hex(mp.get_property("osd-color") or "#FFFFFFFF")
    ass[#ass + 1] = string.format(
        "{\\an8\\pos(%.1f,%.1f)\\fs%.1f\\bord0\\shad0\\1c&H%02X%02X%02X&}%s",
        w / 2, cy + maxh / 2 + unit * 2, unit * 1.6,
        fg[3], fg[2], fg[1], ass_escape(title))
end

local function draw_buffering(ass, t, w, h)
    local n = opts.buffer_bars
    local unit = math.min(w, h) / 100
    local width = n * unit * 1.3 + (n - 1) * unit * 0.8
    local margin = unit * 5
    local pad = unit * 2.5
    local pw, ph = width + pad * 2, unit * 10 + pad * 2
    local cx, cy = w - margin - pw / 2, h - margin - ph / 2

    -- dark pill behind the bars so they read on any frame
    local bg = parse_hex(mp.get_property("background-color") or "#FF000000")
    ass[#ass + 1] = string.format(
        "{\\an7\\pos(%.1f,%.1f)\\bord0\\shad0\\1c&H%02X%02X%02X&\\1a&H%s&\\p1}%s{\\p0}",
        cx - pw / 2, cy - ph / 2, bg[3], bg[2], bg[1], opts.buffer_alpha,
        rrect(pw, ph, unit * 2.5))
    bars(ass, t, n, unit, cx, cy, 0.5, "00")
end

-- ============================================================
-- LIFECYCLE
-- ============================================================

local function tick()
    local w, h = mp.get_osd_size()
    if not w or w == 0 or h == 0 then return end
    local now = mp.get_time()
    local ass = {}
    if loading then
        draw_loading(ass, now - t0, w, h)
    elseif stall_since and now - stall_since >= opts.buffer_delay then
        draw_buffering(ass, now - t0, w, h)
    end
    if #ass == 0 then
        overlay:remove()
        return
    end
    overlay.res_x, overlay.res_y = w, h
    overlay.data = table.concat(ass, "\n")
    overlay:update()
end

-- run the frame timer only while there is something to animate
local function refresh()
    if loading or stall_since then
        if not timer then
            colors = colors or load_colors()
            t0 = t0 or mp.get_time()
            timer = mp.add_periodic_timer(1 / opts.fps, tick)
        end
        tick()
    else
        if timer then timer:kill(); timer = nil end
        overlay:remove()
    end
end

local function update_stall()
    local stalled = mp.get_property_native("paused-for-cache")
        or mp.get_property_native("seeking")
    if stalled and not loading then
        stall_since = stall_since or mp.get_time()
    elseif not stalled then
        stall_since = nil
    end
    refresh()
end

mp.register_event("start-file", function()
    colors = load_colors()  -- pick up a theme change between files
    t0 = mp.get_time()
    loading, stall_since = true, nil
    refresh()
end)

mp.register_event("playback-restart", function()
    loading = false
    update_stall()
end)

mp.register_event("end-file", function()
    loading, stall_since = false, nil
    refresh()
end)

mp.observe_property("paused-for-cache", "bool", update_stall)
mp.observe_property("seeking", "bool", update_stall)
