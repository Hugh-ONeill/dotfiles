#!/usr/bin/env python3
"""Build a palette-recolored Aseprite theme from catppuccin/aseprite Mocha.

Aseprite themes bake their UI colors into sheet.png, so a template can't
cover it: this recolors every Mocha pixel (and theme.xml color) to the
palette color catppuccin-to-tmpl.py maps it to. Anti-aliased pixels near a
Mocha color keep their offset from it. Output: generated/<theme>/aseprite/.

Usage: build-aseprite-theme.py <theme>
"""

from __future__ import annotations

import json
import re
import sys
import urllib.request
from pathlib import Path

from PIL import Image

THEMES_DIR = Path.home() / ".config" / "themes"
CACHE = Path.home() / ".cache" / "theme-sources" / "aseprite-mocha"
UPSTREAM = ("https://raw.githubusercontent.com/catppuccin/aseprite/main/"
            "themes/mocha/catppuccin-theme-mocha/")
FILES = ("theme.xml", "sheet.png")

sys.path.insert(0, str(THEMES_DIR / "scripts"))
from importlib import import_module  # noqa: E402

MOCHA: dict[str, str] = import_module("catppuccin-to-tmpl").MOCHA

RGB = tuple[int, int, int]


def fetch() -> None:
    CACHE.mkdir(parents=True, exist_ok=True)
    for f in FILES:
        if not (CACHE / f).exists():
            urllib.request.urlretrieve(UPSTREAM + f, CACHE / f)


def hex_rgb(h: str) -> RGB:
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def palette_colors(theme: str) -> dict[str, str]:
    """Template var name (CRUST, SEM_ERR, GRADIENT_3...) -> #rrggbb."""
    pal = json.loads((THEMES_DIR / "palettes" / f"{theme}.json").read_text())
    colors: dict[str, str] = pal["colors"]

    def res(v: str) -> str:
        seen = 0
        while not v.startswith("#") and seen < 10:
            v = colors.get(v, v)
            seen += 1
        return v

    out = {k.upper(): res(v) for k, v in colors.items() if isinstance(v, str)}
    for i, g in enumerate(pal.get("gradient", [])):
        out[f"GRADIENT_{i}"] = res(g)
    return out


def build(theme: str) -> Path:
    fetch()
    pc = palette_colors(theme)
    cmap: dict[RGB, RGB] = {hex_rgb(m): hex_rgb(pc[v]) for m, v in MOCHA.items() if v in pc}
    out = THEMES_DIR / "generated" / theme / "aseprite"
    out.mkdir(parents=True, exist_ok=True)

    # ---- theme.xml: exact color swaps ----
    xml = (CACHE / "theme.xml").read_text()

    def sub(m: re.Match[str]) -> str:
        src = hex_rgb(m.group(1))
        dst = cmap.get(src)
        return m.group(0) if dst is None else "#%02x%02x%02x" % dst

    (out / "theme.xml").write_text(re.sub(r"#([0-9a-fA-F]{6})\b", sub, xml))

    # ---- sheet.png: per-pixel, nearest Mocha color within tolerance ----
    img = Image.open(CACHE / "sheet.png").convert("RGBA")
    px = img.load()
    assert px is not None
    srcs = list(cmap)
    memo: dict[RGB, RGB] = {}
    for y in range(img.height):
        for x in range(img.width):
            pix = px[x, y]
            assert isinstance(pix, tuple)
            r, g, b, a = pix
            if a == 0:
                continue
            key = (r, g, b)
            if key not in memo:
                near = min(srcs, key=lambda s: abs(s[0] - r) + abs(s[1] - g) + abs(s[2] - b))
                d = abs(near[0] - r) + abs(near[1] - g) + abs(near[2] - b)
                if d > 24:
                    memo[key] = key  # not a palette color (icons' own art)
                else:
                    t = cmap[near]
                    memo[key] = tuple(max(0, min(255, t[i] + key[i] - near[i])) for i in range(3))  # type: ignore[assignment]
            nr, ng, nb = memo[key]
            px[x, y] = (nr, ng, nb, a)
    img.save(out / "sheet.png")

    (out / "package.json").write_text(json.dumps({
        "name": "palette-theme",
        "displayName": f"Palette ({theme})",
        "description": "catppuccin/aseprite Mocha recolored by the theme system",
        "version": "1.0",
        "publisher": "theme-system",
        "categories": ["Themes"],
        "contributes": {"themes": [{"id": "palette", "path": "."}]},
    }, indent=2) + "\n")
    return out


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    print(build(sys.argv[1]))
