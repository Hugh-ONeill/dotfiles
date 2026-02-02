#!/usr/bin/env python3
"""Bundle generated Stylus userstyles into a single importable JSON."""

import json
import re
import sys
from pathlib import Path


def parse_var_select(line: str) -> dict | None:
    """Parse a @var select line into a vars entry."""
    # @var select varName "Label" ["opt1:Label1", "opt2:Label2*", ...]
    match = re.match(
        r'@var\s+select\s+(\w+)\s+"([^"]+)"\s+\[([^\]]+)\]',
        line.strip()
    )
    if not match:
        return None

    var_name, label, options_str = match.groups()

    # Parse options
    options = []
    default = None
    for opt in re.findall(r'"([^"]+)"', options_str):
        # Format: "value:Label" or "value:Label*" (default)
        is_default = opt.endswith('*')
        opt = opt.rstrip('*')
        if ':' in opt:
            value, opt_label = opt.split(':', 1)
        else:
            value = opt_label = opt

        options.append({
            "name": value,
            "label": opt_label,
            "value": value
        })
        if is_default:
            default = value

    return {
        "name": var_name,
        "data": {
            "type": "select",
            "label": label,
            "name": var_name,
            "value": None,
            "default": default or (options[0]["value"] if options else None),
            "options": options
        }
    }


def parse_var_checkbox(line: str) -> dict | None:
    """Parse a @var checkbox line into a vars entry."""
    # @var checkbox varName "Label" 1
    match = re.match(
        r'@var\s+checkbox\s+(\w+)\s+"([^"]+)"\s+([01])',
        line.strip()
    )
    if not match:
        return None

    var_name, label, default = match.groups()

    return {
        "name": var_name,
        "data": {
            "type": "checkbox",
            "label": label,
            "name": var_name,
            "value": None,
            "default": default,
            "options": None
        }
    }


def extract_metadata(content: str) -> tuple[dict, dict]:
    """Extract UserStyle metadata and vars from content."""
    metadata = {}
    vars_dict = {}

    match = re.search(r'/\* ==UserStyle==(.+?)==/UserStyle== \*/', content, re.DOTALL)
    if match:
        header = match.group(1)
        for line in header.strip().split('\n'):
            line = line.strip()
            # Parse @var select
            if line.startswith('@var select'):
                var_info = parse_var_select(line)
                if var_info:
                    vars_dict[var_info["name"]] = var_info["data"]
            # Parse @var checkbox
            elif line.startswith('@var checkbox'):
                var_info = parse_var_checkbox(line)
                if var_info:
                    vars_dict[var_info["name"]] = var_info["data"]
            # Parse other metadata
            elif m := re.match(r'@(\w+)\s+(.+)', line):
                key, value = m.groups()
                if key != 'var':
                    metadata[key] = value

    return metadata, vars_dict


def bundle_styles(theme_dir: Path) -> list[dict]:
    """Bundle all userstyles from a theme directory."""
    stylus_dir = theme_dir / "stylus"
    if not stylus_dir.exists():
        print(f"Error: No stylus directory in {theme_dir}", file=sys.stderr)
        return []

    styles = []
    for less_file in sorted(stylus_dir.glob("*.user.less")):
        content = less_file.read_text()
        metadata, vars_dict = extract_metadata(content)
        name = less_file.stem.replace(".user", "")

        style = {
            "enabled": True,
            "name": metadata.get("name", name),
            "description": metadata.get("description", ""),
            "author": metadata.get("author", ""),
            "sourceCode": content,
            "sections": [{"code": ""}],
            "usercssData": {
                "name": metadata.get("name", name),
                "namespace": metadata.get("namespace", f"custom/{name}"),
                "version": metadata.get("version", "1.0.0"),
                "homepageURL": metadata.get("homepageURL", ""),
                "supportURL": metadata.get("supportURL", ""),
                "description": metadata.get("description", ""),
                "author": metadata.get("author", ""),
                "license": metadata.get("license", ""),
                "preprocessor": metadata.get("preprocessor", "less"),
                "vars": vars_dict,
            },
        }
        styles.append(style)
        print(f"  + {name}")

    return styles


def main():
    if len(sys.argv) < 2:
        print("Usage: bundle-styles.py <theme-name>")
        print("       bundle-styles.py --current")
        sys.exit(1)

    themes_dir = Path(__file__).parent.parent

    if sys.argv[1] == "--current":
        current_file = themes_dir / ".current"
        if not current_file.exists():
            print("Error: No current theme set", file=sys.stderr)
            sys.exit(1)
        theme_name = current_file.read_text().strip()
    else:
        theme_name = sys.argv[1]

    theme_dir = themes_dir / theme_name
    if not theme_dir.exists():
        print(f"Error: Theme '{theme_name}' not found", file=sys.stderr)
        sys.exit(1)

    print(f"Bundling styles for: {theme_name}")
    styles = bundle_styles(theme_dir)

    if not styles:
        sys.exit(1)

    output_file = theme_dir / "stylus-bundle.json"
    output_file.write_text(json.dumps(styles, indent=2))

    print(f"\nCreated: {output_file}")
    print(f"Import into Stylus: Settings > Backup > Import")


if __name__ == "__main__":
    main()
