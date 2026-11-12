-- Audio visualizer for playback without a picture: theme-gradient bars that
-- follow the music, with the title underneath.
-- Levels come from an audio filter that splits the signal into bands and
-- reports each band's loudness as metadata; what you hear is passed through
-- untouched. The filter is only in the chain while the visualizer is showing.
-- Usage: loaded automatically from ~~/scripts; shows whenever a file plays
-- with no video track (ytb's audio-only mode, music files without cover art)

local mp = require "mp"
local options = require "mp.options"
-- shared helpers live in ~~/script-modules, which mpv does not search by itself
package.path = mp.command_native({ "expand-path", "~~/script-modules/?.lua" }) .. ";" .. package.path
local draw = require "themedraw"

local opts = {
    bands = 24,
    low = 50,          -- Hz, centre of the first band
    high = 14000,      -- Hz, centre of the last band
    range = 26,        -- dB below a band's recent peak that maps to an empty bar
    delay = 0.2,       -- seconds the picture waits, to line up with the audio buffer
    gravity = 3.2,     -- how fast bars fall, in bar heights per second squared
    always = false,    -- show over video too
    fps = 60,
}
options.read_options(opts, "audiovis")

local LABEL = "audiovis"
local overlay = mp.create_osd_overlay("ass-events")
local timer, colors
local active = false
local loaded = false     -- between the first audio of a file and its end
local queue = {}         -- { time, levels } waiting out the delay
local target = {}        -- latest levels, 0..1 per band
local shown, speed, peak = {}, {}, {}
local last_tick

-- ============================================================
-- FILTER
-- ============================================================

-- stereo in, stereo out. a mono copy is split into band-passed channels that ride
-- alongside the original through astats, then get dropped again by the last pan
local function build_graph()
    local n = opts.bands
    local g = { string.format(
        "aformat=channel_layouts=stereo,asetnsamples=n=1024:p=0,asplit=2[o][m];" ..
        "[m]pan=mono|c0=0.5*c0+0.5*c1,asplit=%d", n) }
    local ins = "[o]"
    for i = 1, n do g[1] = g[1] .. "[s" .. i .. "]" end
    local step = math.log(opts.high / opts.low) / math.log(2) / (n - 1)  -- octaves
    for i = 1, n do
        local f = opts.low * 2 ^ ((i - 1) * step)
        g[#g + 1] = string.format("[s%d]bandpass=f=%.0f:width_type=o:w=%.2f[b%d]",
                                  i, f, math.max(step, 0.3), i)
        ins = ins .. "[b" .. i .. "]"
    end
    g[#g + 1] = ins .. string.format(
        "amerge=inputs=%d,astats=metadata=1:reset=1:measure_perchannel=RMS_level:" ..
        "measure_overall=none,pan=stereo|c0=c0|c1=c1", n + 1)
    return table.concat(g, ";")
end

local function set_filter(on)
    if on then
        local graph = build_graph()
        mp.command_native({ "af", "add",
            string.format("@%s:lavfi=graph=%%%d%%%s", LABEL, #graph, graph) })
    else
        mp.command_native({ "af", "remove", "@" .. LABEL })
    end
end

-- ============================================================
-- LEVELS
-- ============================================================

local function reset_levels()
    queue = {}
    for i = 1, opts.bands do
        target[i], shown[i], speed[i] = 0, shown[i] or 0, 0
        peak[i] = -30
    end
end

-- each band is scaled against its own recent peak, so quiet high bands move
-- as much as the bass does
local function on_metadata(_, meta)
    if not active or not meta then return end
    local levels = {}
    for i = 1, opts.bands do
        -- channels 1 and 2 are the untouched stereo pair
        local db = tonumber(meta[string.format("lavfi.astats.%d.RMS_level", i + 2)])
        if not db or db ~= db or db < -90 then db = -90 end
        peak[i] = math.max(db, peak[i] - 0.06, -55)
        local v = (db - (peak[i] - opts.range)) / opts.range
        levels[i] = math.max(0, math.min(1, v)) ^ 1.4
    end
    queue[#queue + 1] = { time = mp.get_time(), levels = levels }
end

-- ============================================================
-- DRAWING
-- ============================================================

local function tick()
    local w, h = mp.get_osd_size()
    if not w or w == 0 or h == 0 then return end
    local now = mp.get_time()
    local dt = math.min(now - (last_tick or now), 0.1)
    last_tick = now

    while queue[1] and queue[1].time <= now - opts.delay do
        target = table.remove(queue, 1).levels
    end
    local paused = mp.get_property_native("pause") or mp.get_property_native("paused-for-cache")

    local n = opts.bands
    local unit = math.min(w, h) / 64
    local bw, gap = unit * 1.3, unit * 0.8
    local maxh = unit * 18
    local cy = h / 2 - unit * 3
    local x0 = w / 2 - (n * bw + (n - 1) * gap) / 2
    local ass = {}
    for i = 1, n do
        -- rise at once, fall under gravity
        local goal = paused and 0 or (target[i] or 0)
        if goal >= shown[i] then
            shown[i], speed[i] = shown[i] + (goal - shown[i]) * math.min(1, dt * 30), 0
        else
            speed[i] = speed[i] + opts.gravity * dt
            shown[i] = math.max(goal, shown[i] - speed[i] * dt)
        end
        local bh = bw + (maxh - bw) * shown[i]
        ass[#ass + 1] = draw.shape(x0 + (i - 1) * (bw + gap), cy - bh / 2,
            draw.color_at(colors, (i - 1) / n - now * 0.03, true), "00",
            draw.rrect(bw, bh, bw / 2))
    end

    local title = mp.get_property("media-title") or ""
    if #title > 90 then title = title:sub(1, 87) .. "…" end
    local ty = cy + maxh / 2 + unit * 2.5
    ass[#ass + 1] = draw.text(w / 2, ty, 8, unit * 2.2, draw.option_bgr("osd-color"), "00", title)
    local chapter = mp.get_property("chapter-metadata/title")
    if chapter and chapter ~= "" then
        ass[#ass + 1] = draw.text(w / 2, ty + unit * 3.4, 8, unit * 1.7,
            draw.option_bgr("osd-color"), "70", chapter)
    end

    overlay.res_x, overlay.res_y = w, h
    overlay.data = table.concat(ass, "\n")
    overlay:update()
end

-- ============================================================
-- LIFECYCLE
-- ============================================================

local function update()
    local audio = mp.get_property_native("current-tracks/audio")
    local video = mp.get_property_native("current-tracks/video")
    local want = loaded and audio ~= nil and (video == nil or opts.always)
    if want == active then return end
    active = want
    if active then
        colors = draw.gradient()
        reset_levels()
        last_tick = nil
        set_filter(true)
        timer = mp.add_periodic_timer(1 / opts.fps, tick)
    else
        if timer then timer:kill(); timer = nil end
        overlay:remove()
        set_filter(false)
    end
end

mp.register_event("playback-restart", function()
    loaded = true
    update()
end)
mp.register_event("end-file", function()
    loaded = false
    update()
end)
mp.register_event("shutdown", function()
    if active then set_filter(false) end
end)
mp.observe_property("current-tracks/video", "native", update)
mp.observe_property("af-metadata/" .. LABEL, "native", on_metadata)
