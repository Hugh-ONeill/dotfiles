----------------
--- MONITORS ---
----------------
-- Rules are keyed by output name. The "" rule is Hyprland's fallback: it
-- applies only to outputs that match no named rule, so it never overrides the
-- ones above it. Config is shared between the laptop and the desktop, hence
-- rules for both.

-- Laptop
hl.monitor({ output = "eDP-1",    mode = "1920x1080", position = "0x0",       scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "2560x1440", position = "1920x-340", scale = 1, bitdepth = 10 })

-- Desktop, 3090 removed 2026-08-30: the VA2719-2K came back up on the iGPU's
-- DP-1 rather than HDMI-A-1 (it currently enumerates as DP-5 and lights up
-- through the fallback rule). bitdepth 10 deliberately omitted -- re-add
-- `bitdepth = 10` once the link is confirmed stable at this refresh rate.
hl.monitor({ output = "DP-1", mode = "preferred", position = "0x0", scale = 1 })

-- Catch-all so an output with no rule still lights up instead of staying dark.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
