#!/usr/bin/env python3
"""Report Catppuccin upstream changes since each template was last synced.

Templates are ports with deliberate local edits, so this never diffs our output
against upstream. It lists upstream commits to the tracked file since the
commit recorded in upstream.json, skipping noise (version bumps, formatting).

Usage:
  upstream-check.py                 report every entry with new upstream commits
  upstream-check.py --all           also list entries that are up to date
  upstream-check.py --notify        notify-send about changes not notified yet
  upstream-check.py --mark NAME...  record NAME(s) as synced to upstream HEAD
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import urllib.parse
from dataclasses import dataclass
from pathlib import Path

THEMES_DIR = Path.home() / ".config" / "themes"
MANIFEST = THEMES_DIR / "upstream.json"
STATE = Path.home() / ".cache" / "themes" / "upstream-notified.json"


# ============================================================
# GITHUB
# ============================================================


@dataclass(frozen=True)
class Commit:
    sha: str
    date: str
    subject: str


def gh_json(endpoint: str) -> object:
    out = subprocess.run(
        ["gh", "api", endpoint], capture_output=True, text=True, timeout=60
    )
    if out.returncode != 0:
        raise RuntimeError(out.stderr.strip() or f"gh api {endpoint} failed")
    return json.loads(out.stdout)


def commits_for(repo: str, path: str, limit: int = 50) -> list[Commit]:
    """Newest-first commits touching path on the default branch."""
    q = urllib.parse.quote(path)
    data = gh_json(f"repos/catppuccin/{repo}/commits?path={q}&per_page={limit}")
    assert isinstance(data, list)
    return [
        Commit(
            sha=c["sha"],
            date=c["commit"]["committer"]["date"][:10],
            subject=c["commit"]["message"].split("\n", 1)[0],
        )
        for c in data
    ]


# ============================================================
# MANIFEST
# ============================================================


def load_manifest() -> dict:
    return json.loads(MANIFEST.read_text())


def save_manifest(m: dict) -> None:
    MANIFEST.write_text(json.dumps(m, indent=2) + "\n")


def is_noise(subject: str, patterns: list[str]) -> bool:
    return any(re.search(p, subject, re.IGNORECASE) for p in patterns)


@dataclass
class Result:
    name: str
    entry: dict
    head: str
    new: list[Commit]
    noise: int
    error: str = ""


def check(name: str, entry: dict, noise: list[str]) -> Result:
    try:
        commits = commits_for(entry["repo"], entry["path"])
    except (RuntimeError, subprocess.TimeoutExpired) as e:
        return Result(name, entry, "", [], 0, error=str(e))
    if not commits:
        return Result(name, entry, "", [], 0, error="path not found upstream")
    pending: list[Commit] = []
    for c in commits:
        if c.sha.startswith(entry["synced"]):
            break
        pending.append(c)
    real = [c for c in pending if not is_noise(c.subject, noise)]
    return Result(name, entry, commits[0].sha, real, len(pending) - len(real))


def compare_url(r: Result) -> str:
    return (
        f"https://github.com/catppuccin/{r.entry['repo']}/compare/"
        f"{r.entry['synced'][:12]}...{r.head[:12]}"
    )


# ============================================================
# COMMANDS
# ============================================================


def run_report(show_all: bool) -> list[Result]:
    m = load_manifest()
    results = [check(n, e, m["noise"]) for n, e in m["entries"].items()]
    for r in results:
        if r.error:
            print(f"! {r.name:18} {r.error}")
        elif r.new:
            print(f"▲ {r.name:18} {len(r.new)} change(s)  -> {r.entry['template']}")
            if r.entry.get("note"):
                print(f"    note: {r.entry['note']}")
            for c in r.new:
                print(f"    {c.date}  {c.subject}")
            print(f"    {compare_url(r)}")
        elif show_all:
            extra = f" ({r.noise} noise)" if r.noise else ""
            print(f"  {r.name:18} up to date{extra}")
    if not any(r.new or r.error for r in results):
        print("All tracked themes are in sync with upstream.")
    return results


def run_notify() -> None:
    m = load_manifest()
    seen: dict[str, str] = {}
    if STATE.exists():
        seen = json.loads(STATE.read_text())
    fresh: list[Result] = []
    for n, e in m["entries"].items():
        r = check(n, e, m["noise"])
        if r.new and seen.get(n) != r.head:
            fresh.append(r)
            seen[n] = r.head
    if fresh:
        names = ", ".join(r.name for r in fresh)
        subprocess.run(
            ["notify-send", "-a", "theme", "Catppuccin upstream changes",
             f"{names}\nRun: theme upstream"],
            check=False,
        )
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(seen, indent=2) + "\n")


def run_mark(names: list[str]) -> None:
    m = load_manifest()
    for n in names:
        if n not in m["entries"]:
            sys.exit(f"unknown entry: {n} (see {MANIFEST})")
        e = m["entries"][n]
        head = commits_for(e["repo"], e["path"], limit=1)[0]
        e["synced"] = head.sha[:12]
        print(f"✓ {n} synced to {head.sha[:12]} ({head.date})")
    save_manifest(m)


def main() -> None:
    ap = argparse.ArgumentParser(description=(__doc__ or "").split("\n", 1)[0])
    ap.add_argument("--all", action="store_true", help="list up-to-date entries too")
    ap.add_argument("--notify", action="store_true", help="desktop notification mode")
    ap.add_argument("--mark", nargs="+", metavar="NAME", help="record as synced")
    a = ap.parse_args()
    if a.mark:
        run_mark(a.mark)
    elif a.notify:
        run_notify()
    else:
        run_report(a.all)


if __name__ == "__main__":
    main()
