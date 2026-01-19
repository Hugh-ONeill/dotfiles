# vim:ft=zsh

autoload -U colors && colors

# ══════════════════════════════════════════════════════════════════════════════
# Catppuccin Mocha Palette (RGB values for ANSI 38;2;R;G;B sequences)
# ══════════════════════════════════════════════════════════════════════════════

typeset -gA CATPPUCCIN
CATPPUCCIN=(
  rosewater "245;224;220"
  flamingo  "242;205;205"
  pink      "245;194;231"
  mauve     "203;166;247"
  red       "243;139;168"
  maroon    "235;160;172"
  peach     "250;179;135"
  yellow    "249;226;175"
  green     "166;227;161"
  teal      "148;226;213"
  sky       "137;220;235"
  sapphire  "116;199;236"
  blue      "137;180;250"
  lavender  "180;190;254"
  text      "205;214;244"
  subtext1  "186;194;222"
  subtext0  "166;173;200"
  overlay2  "147;153;178"
  overlay1  "127;132;156"
  overlay0  "108;112;134"
  surface2  "88;91;112"
  surface1  "69;71;90"
  surface0  "49;50;68"
  base      "30;30;46"
  mantle    "24;24;37"
  crust     "17;17;27"
)

# Helper to get ANSI escape for a color
ctp() { echo "38;2;${CATPPUCCIN[$1]}" }
ctp_bg() { echo "48;2;${CATPPUCCIN[$1]}" }

# Command Color Options
# LS_COLORS (for completions and ls command)
source "${ZDOTDIR}"/catppuccin-mocha-ls-colors.zsh
# EZA_COLORS (Catppuccin Mocha)
export EZA_COLORS="\
di=38;2;137;180;250:\
ln=38;2;245;194;231:\
ex=1;38;2;166;227;161:\
fi=38;2;205;214;244:\
ur=38;2;249;226;175:\
uw=38;2;243;139;168:\
ux=38;2;166;227;161:\
gr=38;2;249;226;175:\
gw=38;2;243;139;168:\
gx=38;2;166;227;161:\
tr=38;2;249;226;175:\
tw=38;2;243;139;168:\
tx=38;2;166;227;161:\
sn=38;2;250;179;135:\
sb=38;2;250;179;135:\
da=38;2;137;180;250:\
uu=38;2;245;194;231:\
un=38;2;243;139;168:\
gu=38;2;245;194;231:\
gn=38;2;243;139;168:\
ga=38;2;166;227;161:\
gm=38;2;249;226;175:\
gd=38;2;243;139;168:\
gv=38;2;203;166;247:\
gt=38;2;148;226;213"
# GREP_COLORS (Catppuccin Mocha)
export GREP_COLORS="\
ms=1;38;2;243;139;168:\
mc=1;38;2;243;139;168:\
sl=:\
cx=:\
fn=38;2;137;180;250:\
ln=38;2;166;227;161:\
bn=38;2;250;179;135:\
se=38;2;148;226;213"
export SYSTEMD_COLORS=1
