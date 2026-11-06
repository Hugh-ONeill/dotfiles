#!/usr/bin/env python3
"""Turn a Catppuccin Mocha theme file into a theme-system template.

Every Mocha color (with or without '#', any case) becomes the template
variable build-catppuccin-retheme.sh maps it to, so new ports match the
GTK/Kvantum recolor. Hex values that aren't Mocha colors (blends, one-offs)
are listed on stderr for hand-mapping, e.g. to ${SEM_ERR_BG20}.

Usage: catppuccin-to-tmpl.py <mocha-file> <out.tmpl>
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Mocha -> template variable; mirrors OUR_COLORS in build-catppuccin-retheme.sh
MOCHA: dict[str, str] = {
    "11111b": "CRUST", "181825": "MANTLE", "1e1e2e": "BASE",
    "313244": "SURFACE0", "45475a": "SURFACE1", "585b70": "SURFACE2",
    "6c7086": "OVERLAY0", "7f849c": "OVERLAY1", "9399b2": "OVERLAY2",
    "a6adc8": "SUBTEXT0", "bac2de": "SUBTEXT1", "cdd6f4": "TEXT",
    "f5e0dc": "TEXT",          # rosewater
    "f2cdcd": "GRADIENT_1",    # flamingo
    "f5c2e7": "GRADIENT_9",    # pink
    "cba6f7": "GRADIENT_8",    # mauve
    "f38ba8": "SEM_ERR",       # red
    "eba0ac": "GRADIENT_0",    # maroon
    "fab387": "GRADIENT_1",    # peach
    "f9e2af": "SEM_WARN",      # yellow
    "a6e3a1": "SEM_OK",        # green
    "94e2d5": "GRADIENT_4",    # teal
    "89dceb": "GRADIENT_5",    # sky
    "74c7ec": "GRADIENT_6",    # sapphire
    "89b4fa": "SEM_INFO",      # blue
    "b4befe": "ACCENT",        # lavender
}

HEX = re.compile(r"(#?)\b([0-9a-fA-F]{6})\b")


def convert(text: str) -> tuple[str, list[str]]:
    leftover: list[str] = []

    def sub(m: re.Match[str]) -> str:
        hashed, hexv = m.group(1), m.group(2).lower()
        var = MOCHA.get(hexv)
        if var is None:
            # unhashed hits can be false positives (ids, hashes); still list them
            leftover.append(("#" if hashed else "") + hexv)
            return m.group(0)
        return f"${{{var}}}" if hashed else f"${{{var}_NOHASH}}"

    return HEX.sub(sub, text), sorted(set(leftover))


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    text, leftover = convert(src.read_text())
    out.write_text(text)
    print(f"wrote {out}", file=sys.stderr)
    if leftover:
        print("non-Mocha colors left as-is: " + " ".join(leftover), file=sys.stderr)


if __name__ == "__main__":
    main()
