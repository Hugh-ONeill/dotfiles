-- Animated loading screen and buffering spinner in theme-gradient bars.
-- Loading: a wave of bars plus the title, from file start until the first
-- frame (or audio) is up. Buffering: a small, translucent wave in the
-- bottom-right corner while playback stalls on the network or a seek.
-- Usage: loaded automatically from ~~/scripts; colors come from the
-- theme gradient (script-modules/themedraw.lua)

local options = require "mp.options"
-- shared helpers live in ~~/script-modules, which mpv does not search by itself
package.path = mp.command_native({ "expand-path", "~~/script-modules/?.lua" }) .. ";" .. package.path
local draw = require "themedraw"

local opts = {
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
-- DRAWING
-- ============================================================

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
        ass[#ass + 1] = draw.shape(x0 + i * (bw + gap), cy - bh / 2,
            draw.color_at(colors, i / n * spread - t * 0.2, true), alpha,
            draw.rrect(bw, bh, bw / 2))
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
    ass[#ass + 1] = draw.text(w / 2, cy + maxh / 2 + unit * 2, 8, unit * 1.6,
        draw.option_bgr("osd-color"), "00", title)
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
    ass[#ass + 1] = draw.shape(cx - pw / 2, cy - ph / 2,
        draw.option_bgr("background-color", "#FF000000"), opts.buffer_alpha,
        draw.rrect(pw, ph, unit * 2.5))
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
            colors = colors or draw.gradient()
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
    colors = draw.gradient()  -- pick up a theme change between files
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
