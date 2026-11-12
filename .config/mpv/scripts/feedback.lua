-- Themed on-screen feedback in place of mpv's plain OSD text: a pill with a
-- gradient bar for volume and seeks, a play/pause flash in the centre, and
-- short toasts other scripts can send (SponsorBlock skips).
-- Usage: loaded automatically from ~~/scripts. Volume and pause are picked up
-- on their own; seeks and toasts arrive as script messages, which input.conf
-- sends next to its no-osd seek bindings:
--   script-message-to feedback seek <seconds>
--   script-message-to feedback toast <text> [seconds]

local mp = require "mp"
local options = require "mp.options"
-- shared helpers live in ~~/script-modules, which mpv does not search by itself
package.path = mp.command_native({ "expand-path", "~~/script-modules/?.lua" }) .. ";" .. package.path
local draw = require "themedraw"

local opts = {
    pill_time = 1.2,     -- seconds the volume/seek pill stays up
    toast_time = 2.5,
    flash_time = 0.5,    -- length of the play/pause flash
    fade = 0.25,         -- seconds of fade-out at the end of pill and toast
    back_alpha = 96,     -- backing alpha, 0 opaque .. 255 invisible
    fps = 60,
}
options.read_options(opts, "feedback")

local overlay = mp.create_osd_overlay("ass-events")
local measure = mp.create_osd_overlay("ass-events")
measure.hidden, measure.compute_bounds = true, true

local timer, colors
local pill, toast, flash   -- what is on screen right now, nil when nothing
local playing = false      -- between the first frame and the end of a file
local armed = false        -- false while the startup property values arrive

-- ============================================================
-- DRAWING
-- ============================================================

-- opacity multiplier for something that ends at `till` and fades out before it
local function fade_at(now, till)
    return math.max(0, math.min(1, (till - now) / opts.fade))
end

-- alpha byte for a base alpha (0 opaque .. 255) faded by visibility 0..1
local function faded(base, vis)
    return draw.alpha(255 - (255 - base) * vis)
end

-- horizontal bar: dim track, gradient fill up to frac, optional tick mark
local function bar(ass, x, y, w, h, frac, tick, vis, dim)
    local fg = draw.option_bgr("osd-color")
    ass[#ass + 1] = draw.shape(x, y, fg, faded(200, vis), draw.rrect(w, h, h / 2))
    local fill = w * math.max(0, math.min(1, frac))
    local slices = 40
    local sw = w / slices
    for i = 0, slices - 1 do
        local a, b = i * sw, math.min((i + 1) * sw + 0.5, fill)
        if b <= a then break end
        ass[#ass + 1] = draw.shape(x + a, y,
            draw.color_at(colors, (i + 0.5) / slices), faded(dim and 150 or 0, vis),
            string.format("m 0 0 l %.1f 0 %.1f %.1f 0 %.1f", b - a, b - a, h, h))
    end
    if tick then
        ass[#ass + 1] = draw.shape(x + w * tick - h * 0.1, y - h * 0.5, fg, faded(60, vis),
            string.format("m 0 0 l %.1f 0 %.1f %.1f 0 %.1f", h * 0.2, h * 0.2, h * 2, h * 2))
    end
end

local function back(ass, x, y, w, h, r, vis)
    ass[#ass + 1] = draw.shape(x, y, draw.option_bgr("background-color", "#FF000000"),
        faded(opts.back_alpha, vis), draw.rrect(w, h, r))
end

local function draw_pill(ass, now, w, h)
    local u = math.min(w, h) / 100
    local vis = fade_at(now, pill.till)
    local pw, ph = u * 34, u * 9.5
    local x, y = (w - pw) / 2, u * 6
    back(ass, x, y, pw, ph, u * 2.5, vis)

    local label, frac, tick, dim = pill.label, pill.frac, pill.tick, pill.dim
    if pill.kind == "seek" then
        -- follow the position while the seek settles
        local pos, dur = mp.get_property_number("time-pos"), mp.get_property_number("duration")
        if pos and dur and dur > 0 then
            frac = pos / dur
            label = label .. "   " .. mp.format_time(pos, pos >= 3600 and "%H:%M:%S" or "%M:%S")
        end
    end
    ass[#ass + 1] = draw.text(w / 2, y + u * 1.6, 8, u * 3.2,
        draw.option_bgr("osd-color"), faded(0, vis), label)
    bar(ass, x + u * 3, y + ph - u * 3, pw - u * 6, u * 1.1, frac or 0, tick, vis, dim)
end

local function draw_toast(ass, now, w, h)
    local u = math.min(w, h) / 100
    local vis = fade_at(now, toast.till)
    local size = u * 3
    if toast.width_for ~= w then
        -- measure the text once per window size so the pill fits it
        measure.res_x, measure.res_y = w, h
        measure.data = draw.text(0, 0, 7, size, "FFFFFF", "00", toast.text)
        local box = measure:update() or {}
        toast.width = (box.x1 and box.x1 - box.x0) or #toast.text * size * 0.5
        toast.width_for = w
    end
    local pw, ph = toast.width + u * 5, size + u * 3.4
    local x, y = w - pw - u * 5, u * 6
    back(ass, x, y, pw, ph, ph / 2, vis)
    ass[#ass + 1] = draw.text(x + pw / 2, y + ph / 2, 5, size,
        draw.option_bgr("osd-color"), faded(0, vis), toast.text)
end

-- a disc with a play or pause glyph that grows and fades
local function draw_flash(ass, now, w, h)
    local u = math.min(w, h) / 100
    local p = (now - flash.start) / opts.flash_time
    local vis = 1 - p
    local r = u * (7 + 3 * p)
    local cx, cy = w / 2, h / 2
    back(ass, cx - r, cy - r, r * 2, r * 2, r, vis)
    local color = draw.option_bgr("osd-selected-color", "#FFFFFFFF")
    local g = r * 0.42  -- half-size of the glyph
    if flash.glyph == "pause" then
        local bw = g * 0.62
        for _, side in ipairs({ -1, 1 }) do
            ass[#ass + 1] = draw.shape(cx + side * g * 0.55 - bw / 2, cy - g, color,
                faded(0, vis), draw.rrect(bw, g * 2, bw * 0.25))
        end
    else
        ass[#ass + 1] = draw.shape(cx - g * 0.7, cy - g, color, faded(0, vis),
            string.format("m 0 0 l %.1f %.1f 0 %.1f", g * 1.8, g, g * 2))
    end
end

-- ============================================================
-- LIFECYCLE
-- ============================================================

local function tick()
    local now = mp.get_time()
    if pill and now >= pill.till then pill = nil end
    if toast and now >= toast.till then toast = nil end
    if flash and now >= flash.start + opts.flash_time then flash = nil end

    local w, h = mp.get_osd_size()
    if not (pill or toast or flash) or not w or w == 0 or h == 0 then
        if timer and not (pill or toast or flash) then timer:kill(); timer = nil end
        overlay:remove()
        return
    end
    local ass = {}
    if flash then draw_flash(ass, now, w, h) end
    if pill then draw_pill(ass, now, w, h) end
    if toast then draw_toast(ass, now, w, h) end
    overlay.res_x, overlay.res_y = w, h
    overlay.data = table.concat(ass, "\n")
    overlay:update()
end

local function show()
    colors = colors or draw.gradient()
    if not timer then timer = mp.add_periodic_timer(1 / opts.fps, tick) end
    tick()
end

-- ============================================================
-- SOURCES
-- ============================================================

local function show_volume()
    if not armed then return end
    local vol = mp.get_property_number("volume")
    if not vol then return end
    local max = mp.get_property_number("volume-max") or 100
    local muted = mp.get_property_native("mute")
    pill = {
        kind = "volume",
        label = muted and "muted" or string.format("volume %d%%", math.floor(vol + 0.5)),
        frac = vol / max,
        tick = max > 100 and 100 / max or nil,
        dim = muted,
        till = mp.get_time() + opts.pill_time,
    }
    show()
end

local function fmt_delta(secs)
    local sign = secs < 0 and "−" or "+"
    secs = math.abs(secs)
    if secs >= 60 then
        return string.format("%s%d:%02d", sign, math.floor(secs / 60), math.floor(secs % 60))
    end
    return string.format(secs % 1 == 0 and "%s%ds" or "%s%.1fs", sign, secs)
end

-- repeated presses add up while the pill is still on screen
local function show_seek(secs)
    secs = tonumber(secs)
    if not secs or not mp.get_property_number("duration") then return end
    local total = secs
    if pill and pill.kind == "seek" and (pill.total < 0) == (secs < 0) then
        total = pill.total + secs
    end
    pill = {
        kind = "seek",
        total = total,
        label = (total < 0 and "«  " or "»  ") .. fmt_delta(total),
        till = mp.get_time() + opts.pill_time,
    }
    show()
end

local function show_toast(text, secs)
    if not text or text == "" then return end
    toast = { text = text, till = mp.get_time() + (tonumber(secs) or opts.toast_time) }
    show()
end

local function show_flash(_, paused)
    -- only for a pause the viewer caused, not the ones around loading a file
    if not armed or not playing or paused == nil then return end
    flash = { glyph = paused and "pause" or "play", start = mp.get_time() }
    show()
end

mp.register_event("start-file", function()
    playing = false
    colors = draw.gradient()  -- pick up a theme change between files
end)
mp.register_event("playback-restart", function() playing = true end)
mp.register_event("end-file", function() playing = false end)

mp.observe_property("volume", "number", show_volume)
mp.observe_property("mute", "bool", show_volume)
mp.observe_property("pause", "bool", show_flash)
mp.add_timeout(0.5, function() armed = true end)

mp.register_script_message("seek", show_seek)
mp.register_script_message("toast", show_toast)
