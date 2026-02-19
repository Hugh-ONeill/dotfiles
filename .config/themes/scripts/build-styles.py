#!/usr/bin/env python3
"""Build custom Stylus themes from Catppuccin userstyles."""

import os
import re
import urllib.request
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
TEMPLATES_DIR = SCRIPT_DIR.parent / "templates" / "stylus"

STYLES = {
    "google": "https://raw.githubusercontent.com/catppuccin/userstyles/main/styles/google/catppuccin.user.less",
    # "gmail": excluded - import issues with custom lib replacement
    "github": "https://raw.githubusercontent.com/catppuccin/userstyles/main/styles/github/catppuccin.user.less",
    # "youtube": excluded - import issues with custom lib replacement
    "reddit": "https://raw.githubusercontent.com/catppuccin/userstyles/main/styles/reddit/catppuccin.user.less",
    "stackoverflow": "https://raw.githubusercontent.com/catppuccin/userstyles/main/styles/stack-overflow/catppuccin.user.less",
    "linkedin": "https://raw.githubusercontent.com/catppuccin/userstyles/main/styles/linkedin/catppuccin.user.less",
    "archwiki": "https://raw.githubusercontent.com/catppuccin/userstyles/main/styles/arch-wiki/catppuccin.user.less",
    "stylus": "https://raw.githubusercontent.com/catppuccin/userstyles/main/styles/stylus/catppuccin.user.less",
}

LIB_CONTENT = '''
// Custom palette colors
@rosewater: ${ACCENT};
@flamingo: ${ACCENT_SECONDARY};
@pink: ${ACCENT};
@mauve: ${ACCENT};
@red: ${SEM_ERR};
@maroon: ${SEM_ERR};
@peach: ${SEM_WARN};
@yellow: ${SEM_WARN};
@green: ${SEM_OK};
@teal: ${ACCENT_TERTIARY};
@sky: ${SEM_INFO};
@sapphire: ${SEM_INFO};
@blue: ${SEM_LINK};
@lavender: ${ACCENT_BRIGHT};
@text: ${TEXT};
@subtext1: ${SUBTEXT1};
@subtext0: ${SUBTEXT0};
@overlay2: ${OVERLAY2};
@overlay1: ${OVERLAY1};
@overlay0: ${OVERLAY0};
@surface2: ${SURFACE2};
@surface1: ${SURFACE1};
@surface0: ${SURFACE0};
@base: ${BASE};
@mantle: ${MANTLE};
@crust: ${CRUST};
@accent: @mauve;

// For styles that use flavor conditionals (YouTube)
@white: @text;
@black: @base;

#lib {
  .palette() {}
  .defaults() {
    color-scheme: dark;
    ::selection {
      background-color: fade(@accent, 30%);
      color: @text;
    }
  }
  .css-variables() {}
}
'''

def process_style(name: str, url: str) -> None:
    """Download and process a single style."""
    print(f"  Downloading {name}...")

    with urllib.request.urlopen(url) as response:
        content = response.read().decode('utf-8')

    # Remove the remote lib import and replace with our colors
    content = re.sub(
        r'@import "https://userstyles\.catppuccin\.com/lib/lib\.less";\n?',
        LIB_CONTENT + '\n',
        content
    )

    # Update style name
    content = re.sub(r'@name (.+) Catppuccin', r'@name \1 Custom', content)

    # Remove updateURL to prevent overwriting
    content = re.sub(r'@updateURL .+\n', '', content)

    # Write template
    output = TEMPLATES_DIR / f"{name}.user.less.tmpl"
    output.write_text(content)
    print(f"  Created: {name}.user.less.tmpl")

def main():
    TEMPLATES_DIR.mkdir(parents=True, exist_ok=True)

    print("Building Stylus style templates...")
    print()

    for name, url in STYLES.items():
        process_style(name, url)

    print()
    print(f"Done! Templates in: {TEMPLATES_DIR}")
    print()
    print("Next: ./generate-stylus.sh <theme-name>")

if __name__ == "__main__":
    main()
