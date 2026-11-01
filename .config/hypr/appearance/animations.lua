-- credit: https://github.com/end-4/dots-hyprland
-- Bezier curves take the two control points; `style` is the same string the
-- old `animation = ...` line carried after the curve.

-- Curves
hl.curve("linear",        { type = "bezier", points = { { 0,    0    }, { 1,    1    } } })
hl.curve("md3_standard",  { type = "bezier", points = { { 0.2,  0    }, { 0,    1    } } })
hl.curve("md3_decel",     { type = "bezier", points = { { 0.05, 0.7  }, { 0.1,  1    } } })
hl.curve("md3_accel",     { type = "bezier", points = { { 0.3,  0    }, { 0.8,  0.15 } } })
hl.curve("overshot",      { type = "bezier", points = { { 0.05, 0.9  }, { 0.1,  1.1  } } })
hl.curve("crazyshot",     { type = "bezier", points = { { 0.1,  1.5  }, { 0.76, 0.92 } } })
hl.curve("hyprnostretch", { type = "bezier", points = { { 0.05, 0.9  }, { 0.1,  1.0  } } })
hl.curve("menu_decel",    { type = "bezier", points = { { 0.1,  1    }, { 0,    1    } } })
hl.curve("menu_accel",    { type = "bezier", points = { { 0.38, 0.04 }, { 1,    0.07 } } })
hl.curve("easeInOutCirc", { type = "bezier", points = { { 0.85, 0    }, { 0.15, 1    } } })
hl.curve("easeOutCirc",   { type = "bezier", points = { { 0,    0.55 }, { 0.45, 1    } } })
hl.curve("easeOutExpo",   { type = "bezier", points = { { 0.16, 1    }, { 0.3,  1    } } })
hl.curve("softAcDecel",   { type = "bezier", points = { { 0.26, 0.26 }, { 0.15, 1    } } })
hl.curve("md2",           { type = "bezier", points = { { 0.4,  0    }, { 0.2,  1    } } })

-- Animations
hl.animation({ leaf = "windows",          enabled = true, speed = 4, bezier = "overshot",    style = "popin 80%" })
hl.animation({ leaf = "windowsIn",        enabled = true, speed = 4, bezier = "overshot",    style = "popin 80%" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 5, bezier = "md3_accel",   style = "slidevert" })
hl.animation({ leaf = "windowsMove",      enabled = true, speed = 5, bezier = "easeOutCirc", style = "slide" })
hl.animation({ leaf = "border",           enabled = true, speed = 8, bezier = "easeOutCirc" })
hl.animation({ leaf = "fade",             enabled = true, speed = 4, bezier = "easeOutExpo" })
hl.animation({ leaf = "layers",           enabled = true, speed = 4, bezier = "overshot",    style = "popin 80%" })
hl.animation({ leaf = "layersIn",         enabled = true, speed = 4, bezier = "overshot",    style = "popin 80%" })
hl.animation({ leaf = "layersOut",        enabled = true, speed = 2, bezier = "md3_accel",   style = "popin 80%" })
hl.animation({ leaf = "fadeLayersIn",     enabled = true, speed = 3, bezier = "easeOutExpo" })
hl.animation({ leaf = "fadeLayersOut",    enabled = true, speed = 3, bezier = "easeOutCirc" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 5, bezier = "overshot",    style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "overshot",    style = "slidevert" })
