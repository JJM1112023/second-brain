#!/usr/bin/env python3
"""Serve the Z.E.R.O. dashboard locally without exposing it to the network."""

from __future__ import annotations

import argparse
import contextlib
import http.server
import socketserver
import sys
import webbrowser
from pathlib import Path

HOST = "127.0.0.1"
DEFAULT_PORT = 8765


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Serve the repository locally and open the Z.E.R.O. dashboard."
    )
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--no-browser", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo_root = Path(__file__).resolve().parents[1]
    dashboard = repo_root / "zero-brain" / "index.html"
    if not dashboard.is_file():
        print(f"ERROR: dashboard not found: {dashboard}", file=sys.stderr)
        return 2

    handler = http.server.SimpleHTTPRequestHandler
    url = f"http://{HOST}:{args.port}/zero-brain/"

    try:
        with contextlib.chdir(repo_root):
            with socketserver.TCPServer((HOST, args.port), handler) as server:
                print("Z.E.R.O. private local preview")
                print(f"Serving: {repo_root}")
                print(f"Open:    {url}")
                print("Network exposure: localhost only")
                print("Stop: Ctrl+C")
                if not args.no_browser:
                    webbrowser.open(url)
                server.serve_forever()
    except KeyboardInterrupt:
        print("\nPreview stopped.")
        return 0
    except OSError as exc:
        print(f"ERROR: could not start preview: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
