#!/usr/bin/env python3
"""Build a per-palette Papirus overlay icon theme with accent-colored folders.

papirus-folders recolors folders system-wide (root, one color at a time).
Instead, ~/.local/share/icons/Papirus-<theme>/ inherits Papirus-Dark/-Light
and holds only folder/user-dir icons, recolored from Papirus's default blue
to the palette accent. A per-palette name makes GTK reload icons on switch.

Usage: build-papirus-overlay.py <theme> <Papirus-Dark|Papirus-Light>
"""

from __future__ import annotations

import colorsys
import configparser
import json
import os
import re
import shutil
import sys
from pathlib import Path

PAPIRUS = Path("/usr/share/icons/Papirus")
THEMES_DIR = Path.home() / ".config" / "themes"
ICONS = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share")) / "icons"
BLUE_LINK = re.compile(r"^(folder|user)-blue(-.*)?\.svg$")


def resolve(colors: dict[str, str], v: str) -> str:
    for _ in range(10):
        if v.startswith("#"):
            return v
        v = colors.get(v, v)
    return v


def shade(hexv: str, factor: float) -> str:
    r, g, b = (int(hexv[i:i + 2], 16) / 255 for i in (1, 3, 5))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    r, g, b = colorsys.hls_to_rgb(h, max(0.0, min(1.0, l * factor)), s)
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


def build(theme: str, inherits: str) -> Path:
    pal = json.loads((THEMES_DIR / "palettes" / f"{theme}.json").read_text())
    accent = resolve(pal["colors"], pal["colors"]["accent"])
    # Papirus blue: face #5294e2, back #4877b1 (~0.82 lightness), emblem #1d344f
    swap = {"#5294e2": accent, "#4877b1": shade(accent, 0.82), "#1d344f": shade(accent, 0.35)}
    rx = re.compile("|".join(swap), re.IGNORECASE)

    out = ICONS / f"Papirus-{theme}"
    if out.exists():
        shutil.rmtree(out)
    src_index = configparser.ConfigParser(interpolation=None)
    src_index.optionxform = str  # type: ignore[assignment,method-assign]
    src_index.read(PAPIRUS / "index.theme")

    dirs: list[str] = []
    for places in sorted(PAPIRUS.glob("*/places")):
        rel = f"{places.parent.name}/places"
        dst = out / rel
        if places.parent.is_symlink():
            # 16x16@2x -> 16x16 upstream: mirror the link instead of copying
            alias = out / places.parent.name
            alias.parent.mkdir(parents=True, exist_ok=True)
            alias.symlink_to(os.readlink(places.parent))
            dirs.append(rel)
            continue
        n = 0
        for link in places.iterdir():
            target = os.readlink(link) if link.is_symlink() else link.name
            if not BLUE_LINK.match(Path(target).name) and not BLUE_LINK.match(link.name):
                continue
            svg = (places / target).resolve()
            if not svg.is_file():
                continue
            dst.mkdir(parents=True, exist_ok=True)
            (dst / link.name).write_text(rx.sub(lambda m: swap[m.group(0).lower()], svg.read_text()))
            n += 1
        if n:
            dirs.append(rel)

    index = [
        "[Icon Theme]",
        f"Name=Papirus-{theme}",
        f"Comment=Papirus folders in the {theme} accent (theme system overlay)",
        f"Inherits={inherits},hicolor",
        f"Directories={','.join(dirs)}",
        "",
    ]
    for d in dirs:
        index.append(f"[{d}]")
        sec = src_index[d] if src_index.has_section(d) else {"Size": d.split("x")[0], "Context": "Places", "Type": "Fixed"}
        index += [f"{k}={v}" for k, v in sec.items()]
        index.append("")
    (out / "index.theme").write_text("\n".join(index))
    return out


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    print(build(sys.argv[1], sys.argv[2]))
