#!/usr/bin/env python3
"""Serve ~/.config/themes/current/stylus on 127.0.0.1 for Stylus @updateURL.

Stylus installs a .user.less URL only when it's served as text/*, and it
re-downloads a localhost style whenever its code changes (no @version bump),
so a theme switch reaches the browser on the next update check.
The directory listing at / doubles as the one-time install page.
"""

from __future__ import annotations

import functools
import http.server
import sys
from pathlib import Path

STYLUS_DIR = Path.home() / ".config" / "themes" / "current" / "stylus"


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".less": "text/plain; charset=utf-8",
    }

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def log_message(self, format: str, *args: object) -> None:
        # Stylus polls every style each update interval; log only failures
        if len(args) > 1 and str(args[1]) not in ("200", "304"):
            sys.stderr.write("%s\n" % (format % args))


def main() -> None:
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8790
    handler = functools.partial(Handler, directory=str(STYLUS_DIR))
    with http.server.ThreadingHTTPServer(("127.0.0.1", port), handler) as srv:
        srv.serve_forever()


if __name__ == "__main__":
    main()
