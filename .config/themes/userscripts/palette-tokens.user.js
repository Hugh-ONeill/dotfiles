// ==UserScript==
// @name         Palette tokens
// @namespace    github.com/wiz/themes
// @version      1.0.0
// @description  Remap rotating hashed CSS color tokens onto the theme palette by value
// @match        https://www.linkedin.com/*
// @run-at       document-idle
// @grant        none
// @updateURL    http://127.0.0.1:8790/palette-tokens.user.js
// @downloadURL  http://127.0.0.1:8790/palette-tokens.user.js
// ==/UserScript==

// Some sites (LinkedIn's 2026 design system) color the page from tokens whose
// names rotate per build, e.g. --gvyet: light-dark(#FFFFFF, #1B1F23). Stylus
// can't target names that change, so this maps each token by its VALUE onto
// --cp-* palette vars that the site's Stylus style publishes on :root.
// Values are emitted as var() references, so palette switches need no update.

(() => {
  "use strict";

  // ============================================================
  // SITE CONFIG
  // ============================================================

  const SITES = [
    { host: /(^|\.)linkedin\.com$/, name: /^--[a-z0-9]{4,7}$/ },
  ];
  const site = SITES.find((s) => s.host.test(location.hostname));
  if (!site) return;

  const NEUTRALS = ["crust", "mantle", "base", "surface0", "surface1", "surface2",
    "overlay0", "overlay1", "overlay2", "subtext0", "subtext1", "text"];
  const HUES = ["red", "orange", "yellow", "green", "teal", "cyan", "blue", "purple", "pink"];

  // ============================================================
  // COLOR MATH
  // ============================================================

  const probe = document.createElement("div");
  probe.style.display = "none";

  // Resolve any CSS color string to [r, g, b, a] (0-255, 0-1).
  function rgba(css) {
    probe.style.color = "";
    probe.style.color = css;
    if (!probe.style.color) return null;
    const m = getComputedStyle(probe).color.match(/[\d.]+/g);
    if (!m) return null;
    return [+m[0], +m[1], +m[2], m[3] === undefined ? 1 : +m[3]];
  }

  function hsl([r, g, b]) {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b), l = (max + min) / 2;
    if (max === min) return [0, 0, l];
    const d = max - min;
    const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    const h = max === r ? (g - b) / d + (g < b ? 6 : 0) : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
    return [h * 60, s, l];
  }

  // ============================================================
  // PALETTE
  // ============================================================

  function readPalette() {
    const cs = getComputedStyle(document.documentElement);
    const pal = {};
    for (const k of [...NEUTRALS, ...HUES]) {
      const v = cs.getPropertyValue(`--cp-${k}`).trim();
      if (!v) return null; // Stylus style off: leave the site alone
      pal[k] = rgba(v);
    }
    return pal;
  }

  const mix = (name, a) =>
    a >= 0.999 ? `var(--cp-${name})` : `color-mix(in srgb, var(--cp-${name}) ${Math.round(a * 100)}%, transparent)`;

  function mapColor(c, pal, dark) {
    const [h, , l] = hsl(c);
    const a = c[3];
    if (a < 0.01) return "transparent";
    // Neutrals: nearest palette surface by lightness. Translucent white/black
    // overlays keep their alpha so hover and divider layering still works.
    // Chroma, not HSL saturation: dark greys like #1B1F23 have inflated s.
    const chroma = (Math.max(c[0], c[1], c[2]) - Math.min(c[0], c[1], c[2])) / 255;
    if (chroma < 0.1) {
      if (a < 0.999 && l > 0.9) return mix(dark ? "text" : "crust", a);
      if (a < 0.999 && l < 0.1) return mix(dark ? "crust" : "text", a);
      let best = "base", bd = 9;
      for (const n of NEUTRALS) {
        const d = Math.abs(hsl(pal[n])[2] - (dark ? l : 1 - l) * 0.9 - (dark ? 0.06 : 0));
        if (d < bd) { bd = d; best = n; }
      }
      return mix(best, a);
    }
    // Chromatic: nearest palette hue. Dark tints (badge and pill backgrounds)
    // become the hue mixed into base instead of a full-strength accent.
    let best = "blue", bd = 999;
    for (const n of HUES) {
      const ph = hsl(pal[n])[0];
      const d = Math.min(Math.abs(ph - h), 360 - Math.abs(ph - h));
      if (d < bd) { bd = d; best = n; }
    }
    if (dark ? l < 0.35 : l > 0.85) {
      return `color-mix(in srgb, var(--cp-${best}) ${a < 0.999 ? Math.round(a * 100) : 25}%, var(--cp-base))`;
    }
    return mix(best, a);
  }

  // Pick the branch of light-dark(a, b) that matches the palette.
  function pickBranch(v, dark) {
    const m = v.match(/^light-dark\((.*)\)$/s);
    if (!m) return v;
    let depth = 0;
    for (let i = 0; i < m[1].length; i++) {
      const ch = m[1][i];
      if (ch === "(") depth++;
      else if (ch === ")") depth--;
      else if (ch === "," && depth === 0) return (dark ? m[1].slice(i + 1) : m[1].slice(0, i)).trim();
    }
    return v;
  }

  // ============================================================
  // APPLY
  // ============================================================

  const style = document.createElement("style");
  style.id = "palette-tokens";
  let lastSig = "";

  function apply() {
    const pal = readPalette();
    if (!pal) { style.textContent = ""; return; }
    const dark = hsl(pal.base)[2] < 0.5;
    const root = document.documentElement;
    const saved = style.textContent;
    style.textContent = ""; // read the site's own values, not ours
    const cs = getComputedStyle(root);
    const decls = [];
    for (const p of cs) {
      if (!site.name.test(p) || p.startsWith("--cp-")) continue;
      const raw = cs.getPropertyValue(p).trim();
      if (!/^(#|rgb|hsl|light-dark)/.test(raw)) continue;
      const c = rgba(pickBranch(raw, dark));
      if (c) decls.push(`${p}: ${mapColor(c, pal, dark)} !important;`);
    }
    const css = decls.length ? `*, :root { ${decls.join(" ")} }` : "";
    const sig = decls.length + ":" + css.length;
    style.textContent = sig === lastSig ? saved : css;
    lastSig = sig;
  }

  document.documentElement.appendChild(probe);
  document.head.appendChild(style);
  apply();

  // LinkedIn is a SPA that loads CSS chunks (with new token names) on route
  // changes, so rescan whenever stylesheets are added.
  let timer = 0;
  new MutationObserver((muts) => {
    if (!muts.some((m) => [...m.addedNodes].some((n) => n !== style && (n.nodeName === "STYLE" || n.nodeName === "LINK")))) return;
    clearTimeout(timer);
    timer = setTimeout(apply, 300);
  }).observe(document.documentElement, { childList: true, subtree: true });
})();
