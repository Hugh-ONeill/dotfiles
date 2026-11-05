-- SponsorBlock segment skipping for YouTube videos
-- Usage: auto-loaded by mpv; options in script-opts/sponsorblock.conf, B toggles skipping

local mp = require "mp"
local utils = require "mp.utils"
local options = require "mp.options"

local o = {
    -- comma-separated: sponsor,selfpromo,interaction,intro,outro,preview,filler,music_offtopic
    categories = "sponsor,selfpromo,interaction",
    server = "https://sponsor.ajay.app",
    -- ignore segments shorter than this many seconds
    min_length = 1,
}
options.read_options(o, "sponsorblock")

local segments = {}
local skipped = {}
local enabled = true

-- ---------------------- Helpers ----------------------

local function youtube_id(path)
    if not path then return nil end
    for _, pat in ipairs({ "[?&]v=([%w_-]+)", "youtu%.be/([%w_-]+)", "/shorts/([%w_-]+)",
                           "/live/([%w_-]+)", "/embed/([%w_-]+)" }) do
        local id = path:match(pat)
        if id and #id == 11 then return id end
    end
end

local function categories_param()
    local parts = {}
    for cat in o.categories:gmatch("[^,%s]+") do
        parts[#parts + 1] = "%22" .. cat .. "%22"
    end
    return "%5B" .. table.concat(parts, "%2C") .. "%5D"
end

local function fmt_secs(s)
    s = math.floor(s + 0.5)
    if s >= 60 then return string.format("%d:%02d", math.floor(s / 60), s % 60) end
    return s .. "s"
end

-- ---------------------- Fetch ----------------------

-- k-anonymity lookup: only the first 4 hex chars of sha256(video id) leave the machine
local function fetch(id)
    local hash = mp.command_native({
        name = "subprocess", args = { "sha256sum" }, stdin_data = id,
        capture_stdout = true, playback_only = false,
    })
    if not hash or hash.status ~= 0 then return end
    local prefix = hash.stdout:sub(1, 4)
    local url = string.format("%s/api/skipSegments/%s?categories=%s", o.server, prefix, categories_param())

    mp.command_native_async({
        name = "subprocess", args = { "curl", "-sfL", "--max-time", "8", url },
        capture_stdout = true, playback_only = false,
    }, function(ok, res)
        -- 404 = no segments for any video under this prefix
        if not ok or res.status ~= 0 or res.stdout == "" then return end
        local data = utils.parse_json(res.stdout)
        if type(data) ~= "table" then return end
        for _, video in ipairs(data) do
            if video.videoID == id then
                for _, seg in ipairs(video.segments or {}) do
                    local s, e = seg.segment[1], seg.segment[2]
                    if (seg.actionType or "skip") == "skip" and e - s >= o.min_length then
                        segments[#segments + 1] = { s = s, e = e, cat = seg.category, uuid = seg.UUID }
                    end
                end
            end
        end
        if #segments > 0 then
            mp.msg.info(string.format("%d segment(s) to skip", #segments))
        end
    end)
end

-- ---------------------- Skipping ----------------------

local function on_time(_, t)
    if not enabled or not t then return end
    for _, seg in ipairs(segments) do
        -- each segment skips once, so seeking back into it lets you watch it
        if not skipped[seg.uuid] and t >= seg.s and t < seg.e - 0.3 then
            -- chain through overlapping segments so they skip as one jump
            local target, cats, chained = seg.e, { (seg.cat:gsub("_", " ")) }, true
            skipped[seg.uuid] = true
            while chained do
                chained = false
                for _, other in ipairs(segments) do
                    if not skipped[other.uuid] and other.s <= target + 0.3 and other.e > target then
                        skipped[other.uuid] = true
                        target = other.e
                        cats[#cats + 1] = (other.cat:gsub("_", " "))
                        chained = true
                    end
                end
            end
            mp.set_property_number("time-pos", target)
            mp.osd_message(string.format("▷ skipped %s (%s)", table.concat(cats, " + "),
                                         fmt_secs(target - t)), 2)
            mp.msg.info(string.format("skipped %s %.1f-%.1f", table.concat(cats, "+"), t, target))
            return
        end
    end
end

mp.register_event("file-loaded", function()
    segments, skipped = {}, {}
    local id = youtube_id(mp.get_property("path"))
    if id then fetch(id) end
end)

mp.observe_property("time-pos", "number", on_time)

mp.add_key_binding("B", "toggle", function()
    enabled = not enabled
    mp.osd_message("SponsorBlock " .. (enabled and "on" or "off"), 1.5)
end)
