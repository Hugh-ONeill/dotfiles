-- YouTube-style auto captions: words appear as they are spoken, on two
-- rolling lines, white on a translucent black box.
-- Fetches the word-timed json3 auto captions with yt-dlp and turns them into
-- an ASS track; skipped when the video already has real English subtitles.
-- Usage: loaded automatically from ~~/scripts; `v` toggles, `j` cycles tracks

local mp = require "mp"
local utils = require "mp.utils"
local options = require "mp.options"

local opts = {
    lang = "en",
    cookies = "firefox",  -- yt-dlp --cookies-from-browser; youtube 429s without
    max_chars = 42,       -- wrap width per line
    hold = 3,             -- seconds the last words stay up after speech stops
    font = "Noto Sans",
    font_size = 34,       -- at 720 lines of script resolution
    box_alpha = "40",     -- ASS alpha of the box, 00 opaque .. FF invisible
}
options.read_options(opts, "ytcaptions")

-- ============================================================
-- HELPERS
-- ============================================================

local function video_id(path)
    if not path then return nil end
    return path:match("youtube%.com/watch%?.*v=([%w_-]+)")
        or path:match("youtu%.be/([%w_-]+)")
        or path:match("youtube%.com/shorts/([%w_-]+)")
        or path:match("^ytdl://([%w_-]+)$")
end

local function has_real_english()
    for _, t in ipairs(mp.get_property_native("track-list") or {}) do
        if t.type == "sub" and t.lang and t.lang:sub(1, 2) == opts.lang then
            return true
        end
    end
    return false
end

local function ass_time(ms)
    local cs = math.floor(ms / 10 + 0.5)
    return string.format("%d:%02d:%02d.%02d", math.floor(cs / 360000),
        math.floor(cs / 6000) % 60, math.floor(cs / 100) % 60, cs % 100)
end

local function ass_escape(s)
    return (s:gsub("\\", "\\\226\129\160"):gsub("{", "\\{"):gsub("}", "\\}"))
end

-- ============================================================
-- JSON3 -> ASS
-- ============================================================

-- flat, time-ordered word list from youtube's json3 events
local function words_from(json)
    local words = {}
    for _, ev in ipairs(json.events or {}) do
        for _, seg in ipairs(ev.segs or {}) do
            local w = (seg.utf8 or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if w ~= "" then
                words[#words + 1] = {
                    t = (ev.tStartMs or 0) + (seg.tOffsetMs or 0),
                    w = w,
                }
            end
        end
    end
    table.sort(words, function(a, b) return a.t < b.t end)
    return words
end

local function build_ass(words)
    local hold = opts.hold * 1000
    local out = {
        "[Script Info]",
        "ScriptType: v4.00+",
        "PlayResX: 1280",
        "PlayResY: 720",
        "WrapStyle: 2",
        "",
        "[V4+ Styles]",
        "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, " ..
            "OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, " ..
            "ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, " ..
            "Alignment, MarginL, MarginR, MarginV, Encoding",
        string.format("Style: CC,%s,%d,&H00FFFFFF,&H00FFFFFF,&H%s000000," ..
            "&H%s000000,0,0,0,0,100,100,0,0,3,5,0,2,40,40,36,1",
            opts.font, opts.font_size, opts.box_alpha, opts.box_alpha),
        "",
        "[Events]",
        "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text",
    }

    local prev, cur = nil, {}  -- finished line above, words of the line in progress
    local len = 0
    for i, word in ipairs(words) do
        local nxt = words[i + 1]
        local w = ass_escape(word.w)
        if #cur > 0 and len + 1 + #word.w > opts.max_chars then
            prev, cur, len = table.concat(cur, " "), {}, 0
        end
        cur[#cur + 1] = w
        len = len + (len > 0 and 1 or 0) + #word.w

        -- this state lasts until the next word, or `hold` into a pause
        local stop = word.t + hold
        local pause = not nxt or nxt.t - word.t > hold
        if not pause then stop = nxt.t end
        local text = table.concat(cur, " ")
        if prev then text = prev .. "\\N" .. text end
        out[#out + 1] = string.format("Dialogue: 0,%s,%s,CC,,0,0,0,,%s",
            ass_time(word.t), ass_time(stop), text)

        -- a long pause clears the screen, like youtube does
        if pause then prev, cur, len = nil, {}, 0 end
    end
    return table.concat(out, "\n") .. "\n"
end

-- ============================================================
-- LOADING
-- ============================================================

-- the fetch starts at file start, in parallel with mpv's own yt-dlp run; the
-- track is added once both the file and the captions are ready
local state = {}

local function finish()
    if not (state.loaded and state.ass) then return end
    local ass = state.ass
    state.ass = nil
    if has_real_english() then return end  -- uploaded subs win
    mp.commandv("sub-add", "memory://" .. ass, "select", "English (auto)", opts.lang)
end

local function fetch_captions()
    state = {}
    local id = video_id(mp.get_property("path"))
    if not id then return end
    local my_state = state

    local dir = utils.join_path(os.getenv("XDG_RUNTIME_DIR") or "/tmp",
                                "mpv-ytcaptions")
    local base = utils.join_path(dir, id)
    local json_path = base .. "." .. opts.lang .. ".json3"
    local args = { "yt-dlp", "--quiet", "--no-warnings", "--skip-download",
        "--write-auto-subs", "--sub-langs", opts.lang, "--sub-format", "json3",
        "-o", base .. ".%(ext)s" }
    if opts.cookies ~= "" then
        table.insert(args, "--cookies-from-browser")
        table.insert(args, opts.cookies)
    end
    table.insert(args, "--")
    table.insert(args, "https://www.youtube.com/watch?v=" .. id)

    mp.command_native({ name = "subprocess", args = { "mkdir", "-p", dir },
                        playback_only = false })
    mp.command_native_async({ name = "subprocess", args = args,
                              playback_only = true, capture_stderr = true },
        function(_, res)
            if state ~= my_state then return end  -- a newer file took over
            local f = io.open(json_path, "r")
            if not f then
                mp.msg.verbose("no auto captions: " .. ((res or {}).stderr or ""))
                return
            end
            local json = utils.parse_json(f:read("*a"))
            f:close()
            os.remove(json_path)
            if not json then return end
            local words = words_from(json)
            if #words == 0 then return end
            state.ass = build_ass(words)
            finish()
        end)
end

mp.register_event("start-file", fetch_captions)
mp.register_event("file-loaded", function()
    state.loaded = true
    finish()
end)
