#!/usr/bin/env python3
"""
svg_mono.py -- turn a diagen-produced diagram into pure black and white.

The coloured diagrams are fine on a screen and poor everywhere else: printed, in
a black-and-white copy of a specification, or for a reader who cannot distinguish
the pale green from the pale yellow. This produces a version that carries the
same information with no hue at all.

What replaces colour is STROKE WEIGHT, not grey fill:

    in-house blocks     white fill, BOLD border   (what we designed)
    everything else     white fill, thin border   (vendored IP, buses, memories)
    group outlines      dashed, thin              (unchanged, already neutral)

Grey fills were rejected deliberately -- a wash of five greys is harder to read
than one line weight, and photocopies flatten them into each other.

The mapping from colour to meaning comes from diagen's STYLES: the red family was
used for the blocks written here, which is the one distinction worth keeping.

Usage:
    python3 tools/svg_mono.py img/fig_qsoc_full.svg
    python3 tools/svg_mono.py img/fig_qsoc_full.svg -o img/fig_qsoc_full_mono.svg

Writes the .svg and, if rsvg-convert is available, the .png beside it.
"""
from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

# diagen's palette, by the meaning each colour carried.
IN_HOUSE_FILL = "#f8cecc"          # the red family: blocks designed here
COLOURED_FILLS = [
    "#f8cecc",                     # red    -- in house
    "#dae8fc",                     # blue   -- CPU and its adapter
    "#d5e8d4",                     # green  -- memories
    "#fff2cc",                     # yellow -- buses
    "#e1d5e7",                     # purple
    "#f5f5f5",                     # grey   -- other peripherals
]
THIN = "1.4"
BOLD = "2.6"


def to_mono(svg: str) -> tuple[str, int, int]:
    """Return (mono svg, blocks emphasised, colours removed)."""
    bold_count = 0

    def rect(m: re.Match) -> str:
        nonlocal bold_count
        tag = m.group(0)
        fill = re.search(r'fill="(#[0-9a-fA-F]{6})"', tag)
        if not fill or fill.group(1).lower() not in [c.lower() for c in COLOURED_FILLS]:
            return tag
        is_ours = fill.group(1).lower() == IN_HOUSE_FILL.lower()
        tag = re.sub(r'fill="#[0-9a-fA-F]{6}"', 'fill="#ffffff"', tag)
        tag = re.sub(r'stroke="#[0-9a-fA-F]{6}"', 'stroke="#000000"', tag)
        if is_ours:
            tag = re.sub(r'stroke-width="[0-9.]+"', f'stroke-width="{BOLD}"', tag)
            bold_count += 1
        return tag

    out = re.sub(r"<rect\b[^>]*>", rect, svg)

    # Everything else that carries a hue: connector strokes, arrow heads, text.
    before = len(set(re.findall(r'(?:fill|stroke)="(#[0-9a-fA-F]{3,6})"', out)))
    out = re.sub(r'stroke="#(?!000000\b)[0-9a-fA-F]{3,6}"', 'stroke="#000000"', out)
    out = re.sub(r'fill="#333\b"', 'fill="#000000"', out)          # arrow markers
    out = re.sub(r'fill="#(?:333333|666666|999999)"', 'fill="#000000"', out)
    # Text was set in near-blacks (#111 for a label, #444 for a secondary one).
    # Flatten both to black: on paper the difference is invisible anyway, and
    # leaving them makes "is this really monochrome?" a question a reader has to
    # check rather than see.
    out = re.sub(r'fill="#(?:111|222|444|555)"', 'fill="#000000"', out)
    out = re.sub(r'fill="#fff"', 'fill="#ffffff"', out)
    after = len(set(re.findall(r'(?:fill|stroke)="(#[0-9a-fA-F]{3,6})"', out)))
    return out, bold_count, before - after


def main() -> int:
    ap = argparse.ArgumentParser(description="Convert a diagram SVG to black and white.")
    ap.add_argument("svg", type=Path)
    ap.add_argument("-o", "--out", type=Path,
                    help="output svg; defaults to <name>_mono.svg beside the input")
    args = ap.parse_args()

    if not args.svg.is_file():
        print(f"not a file: {args.svg}")
        return 1

    out_svg = args.out or args.svg.with_name(args.svg.stem + "_mono.svg")
    mono, bold, removed = to_mono(args.svg.read_text())
    out_svg.write_text(mono)
    print(f"wrote {out_svg}  ({bold} block(s) emphasised, {removed} colour(s) removed)")

    if shutil.which("rsvg-convert"):
        out_png = out_svg.with_suffix(".png")
        subprocess.run(["rsvg-convert", "-z", "2", "-o", str(out_png), str(out_svg)],
                       check=True)
        print(f"wrote {out_png}")
    else:
        print("rsvg-convert not found -- svg written, png skipped")
    return 0


if __name__ == "__main__":
    sys.exit(main())
