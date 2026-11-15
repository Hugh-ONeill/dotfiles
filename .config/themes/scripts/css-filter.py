#!/usr/bin/env python3
"""Solve the CSS filter chain that recolors a black icon to a target color.

Catppuccin userstyles tint monochrome icons with `filter: @text-filter` and
friends, which upstream precomputes per flavor. This computes the same chain
for any palette color (SPSA search, after Barrett Sonntag's solver).

Results are seeded by the hex value and cached, so a palette always renders
to the same text: Stylus reinstalls a style whenever its code changes.

Usage:
  css-filter.py '#89b4fa'                 print the filter chain
  css-filter.py TEXT='#cdd6f4' BASE=...   print `export TEXT_FILTER='...'` lines
"""

from __future__ import annotations

import json
import math
import random
import sys
from pathlib import Path

CACHE = Path.home() / ".cache" / "themes" / "css-filters.json"

Rgb = tuple[float, float, float]
Matrix = tuple[float, float, float, float, float, float, float, float, float]

# ============================================================
# FILTER PRIMITIVES
# ============================================================


def clamp(v: float) -> float:
    return max(0.0, min(255.0, v))


def multiply(c: Rgb, m: Matrix) -> Rgb:
    r, g, b = c
    return (
        clamp(r * m[0] + g * m[1] + b * m[2]),
        clamp(r * m[3] + g * m[4] + b * m[5]),
        clamp(r * m[6] + g * m[7] + b * m[8]),
    )


def invert(c: Rgb, v: float) -> Rgb:
    r, g, b = c
    return (
        clamp((v + r / 255 * (1 - 2 * v)) * 255),
        clamp((v + g / 255 * (1 - 2 * v)) * 255),
        clamp((v + b / 255 * (1 - 2 * v)) * 255),
    )


def sepia(c: Rgb, v: float) -> Rgb:
    return multiply(c, (
        0.393 + 0.607 * (1 - v), 0.769 - 0.769 * (1 - v), 0.189 - 0.189 * (1 - v),
        0.349 - 0.349 * (1 - v), 0.686 + 0.314 * (1 - v), 0.168 - 0.168 * (1 - v),
        0.272 - 0.272 * (1 - v), 0.534 - 0.534 * (1 - v), 0.131 + 0.869 * (1 - v),
    ))


def saturate(c: Rgb, v: float) -> Rgb:
    return multiply(c, (
        0.213 + 0.787 * v, 0.715 - 0.715 * v, 0.072 - 0.072 * v,
        0.213 - 0.213 * v, 0.715 + 0.285 * v, 0.072 - 0.072 * v,
        0.213 - 0.213 * v, 0.715 - 0.715 * v, 0.072 + 0.928 * v,
    ))


def hue_rotate(c: Rgb, degrees: float) -> Rgb:
    a = math.radians(degrees)
    s, k = math.sin(a), math.cos(a)
    return multiply(c, (
        0.213 + k * 0.787 - s * 0.213, 0.715 - k * 0.715 - s * 0.715, 0.072 - k * 0.072 + s * 0.928,
        0.213 - k * 0.213 + s * 0.143, 0.715 + k * 0.285 + s * 0.140, 0.072 - k * 0.072 - s * 0.283,
        0.213 - k * 0.213 - s * 0.787, 0.715 - k * 0.715 + s * 0.715, 0.072 + k * 0.928 + s * 0.072,
    ))


def linear(c: Rgb, slope: float, intercept: float) -> Rgb:
    r, g, b = c
    return (
        clamp(r * slope + intercept * 255),
        clamp(g * slope + intercept * 255),
        clamp(b * slope + intercept * 255),
    )


def hsl(c: Rgb) -> Rgb:
    r, g, b = (x / 255 for x in c)
    hi, lo = max(r, g, b), min(r, g, b)
    light = (hi + lo) / 2
    if hi == lo:
        return (0.0, 0.0, light * 100)
    d = hi - lo
    sat = d / (2 - hi - lo) if light > 0.5 else d / (hi + lo)
    if hi == r:
        hue = (g - b) / d + (6 if g < b else 0)
    elif hi == g:
        hue = (b - r) / d + 2
    else:
        hue = (r - g) / d + 4
    return (hue / 6 * 100, sat * 100, light * 100)


# ============================================================
# SOLVER
# ============================================================


def apply(f: list[float]) -> Rgb:
    c: Rgb = (0.0, 0.0, 0.0)
    c = invert(c, f[0] / 100)
    c = sepia(c, f[1] / 100)
    c = saturate(c, f[2] / 100)
    c = hue_rotate(c, f[3] * 3.6)
    c = linear(c, f[4] / 100, 0)                      # brightness
    c = linear(c, f[5] / 100, -(0.5 * f[5] / 100) + 0.5)  # contrast
    return c


def loss(f: list[float], target: Rgb, target_hsl: Rgb) -> float:
    c = apply(f)
    h = hsl(c)
    return sum(abs(a - b) for a, b in zip(c, target)) + sum(
        abs(a - b) for a, b in zip(h, target_hsl)
    )


def fix(value: float, idx: int) -> float:
    hi = 7500.0 if idx == 2 else 200.0 if idx in (4, 5) else 100.0
    if idx == 3:  # hue-rotate wraps
        return value % hi
    return max(0.0, min(hi, value))


def spsa(
    rng: random.Random, target: Rgb, target_hsl: Rgb,
    big_a: float, a: list[float], c: float, values: list[float], iters: int,
) -> tuple[list[float], float]:
    alpha, gamma = 1.0, 1 / 6
    best, best_loss = values[:], math.inf
    for k in range(iters):
        ck = c / (k + 1) ** gamma
        deltas = [1 if rng.random() > 0.5 else -1 for _ in range(6)]
        hi = [values[i] + ck * deltas[i] for i in range(6)]
        lo = [values[i] - ck * deltas[i] for i in range(6)]
        diff = loss(hi, target, target_hsl) - loss(lo, target, target_hsl)
        for i in range(6):
            g = diff / (2 * ck) * deltas[i]
            ak = a[i] / (big_a + k + 1) ** alpha
            values[i] = fix(values[i] - ak * g, i)
        cur = loss(values, target, target_hsl)
        if cur < best_loss:
            best, best_loss = values[:], cur
    return best, best_loss


def solve(hexv: str) -> str:
    h = hexv.lstrip("#").lower()
    target: Rgb = (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))
    target_hsl = hsl(target)
    rng = random.Random(h)
    best: list[float] = []
    best_loss = math.inf
    for _ in range(12):
        wide, wide_loss = [50.0, 20.0, 3750.0, 50.0, 100.0, 100.0], math.inf
        for _ in range(3):
            if wide_loss <= 25:
                break
            cand, cand_loss = spsa(
                rng, target, target_hsl, 5, [60, 180, 18000, 600, 1.2, 1.2], 15,
                [50.0, 20.0, 3750.0, 50.0, 100.0, 100.0], 1000,
            )
            if cand_loss < wide_loss:
                wide, wide_loss = cand, cand_loss
        a1 = wide_loss + 1
        narrow, narrow_loss = spsa(
            rng, target, target_hsl, wide_loss,
            [0.25 * a1, 0.25 * a1, a1, 0.25 * a1, 0.2 * a1, 0.2 * a1], 2, wide[:], 500,
        )
        if narrow_loss < best_loss:
            best, best_loss = narrow, narrow_loss
        if best_loss < 3:
            break
    f = [round(v) for v in best]
    return (
        f"brightness(0) saturate(100%) invert({f[0]}%) sepia({f[1]}%) "
        f"saturate({f[2]}%) hue-rotate({round(best[3] * 3.6)}deg) "
        f"brightness({f[4]}%) contrast({f[5]}%)"
    )


# ============================================================
# CACHE + CLI
# ============================================================


def filters_for(hexes: list[str]) -> dict[str, str]:
    cache: dict[str, str] = {}
    if CACHE.exists():
        try:
            cache = json.loads(CACHE.read_text())
        except json.JSONDecodeError:
            cache = {}
    dirty = False
    out: dict[str, str] = {}
    for hexv in hexes:
        key = hexv.lstrip("#").lower()[:6]
        if key not in cache:
            cache[key] = solve(key)
            dirty = True
        out[hexv] = cache[key]
    if dirty:
        CACHE.parent.mkdir(parents=True, exist_ok=True)
        tmp = CACHE.with_suffix(f".{random.getrandbits(32):08x}.tmp")
        tmp.write_text(json.dumps(cache, indent=1, sort_keys=True) + "\n")
        tmp.replace(CACHE)
    return out


def main() -> None:
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    if "=" not in args[0]:
        for hexv, filt in filters_for(args).items():
            print(filt)
        return
    pairs = [a.split("=", 1) for a in args]
    solved = filters_for([hexv for _, hexv in pairs])
    for name, hexv in pairs:
        print(f"export {name}_FILTER='{solved[hexv]}'")


if __name__ == "__main__":
    main()
