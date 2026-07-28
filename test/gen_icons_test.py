#!/usr/bin/env python3
"""Smoke test for scripts/gen_icons.py.

Runs the generator and verifies the output set: all four PNGs exist with the
expected pixel dimensions, and the maskable icon genuinely differs from the
plain 512 icon (its art must shrink into the safe zone).

Requires Pillow (same dependency as the generator itself). Run from anywhere:

    python3 test/gen_icons_test.py

Note: the generator writes into the repo's icons/ directory by design; this
test runs it against a scratch copy of the repo layout so a test run never
touches the committed icons.
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parent.parent

EXPECTED = {
    "icon-192.png": (192, 192),
    "icon-512.png": (512, 512),
    "maskable-512.png": (512, 512),
    "favicon-64.png": (64, 64),
}


def main() -> int:
    failures = []
    with tempfile.TemporaryDirectory() as tmp:
        # gen_icons.py resolves its output dir relative to its own location
        # (script_dir/../icons), so mirror that layout in a scratch dir.
        scratch = Path(tmp)
        (scratch / "scripts").mkdir()
        shutil.copy(REPO_ROOT / "scripts" / "gen_icons.py", scratch / "scripts")

        proc = subprocess.run(
            [sys.executable, str(scratch / "scripts" / "gen_icons.py")],
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            print(f"FAIL: gen_icons.py exited {proc.returncode}")
            print(proc.stdout)
            print(proc.stderr)
            return 1

        icons = scratch / "icons"
        for name, size in EXPECTED.items():
            path = icons / name
            if not path.exists():
                failures.append(f"{name}: not generated")
                continue
            with Image.open(path) as img:
                if img.size != size:
                    failures.append(f"{name}: size {img.size}, expected {size}")
                if img.format != "PNG":
                    failures.append(f"{name}: format {img.format}, expected PNG")

        # The maskable variant must not be a byte-for-byte copy of icon-512.
        plain = icons / "icon-512.png"
        maskable = icons / "maskable-512.png"
        if plain.exists() and maskable.exists():
            if plain.read_bytes() == maskable.read_bytes():
                failures.append(
                    "maskable-512.png is identical to icon-512.png "
                    "(safe-zone shrink not applied)"
                )

    if failures:
        print("gen_icons smoke test FAILED:")
        for f in failures:
            print(f"  - {f}")
        return 1

    print(f"gen_icons smoke test OK: {len(EXPECTED)} icons verified")
    return 0


if __name__ == "__main__":
    sys.exit(main())
