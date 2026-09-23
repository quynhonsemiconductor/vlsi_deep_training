#!/usr/bin/env python3
"""Fail if a generated diagram carries colour.

The diagrams are printed, photocopied and read on screens that render colour
every possible way, so they are monochrome. Colour got into every one of them
without anyone noticing, because the shared palette in tools/diagen.py defined
named colours and the scripts asked for "blue" and "green" by name. The palette
is monochrome now, and this is what keeps it that way.

Only #000000 and #ffffff are allowed, plus "none". Nothing in between: a grey
that looks fine on a screen is indistinguishable from black once photocopied.

    python3 doc/tools/check_mono.py

One exception, listed rather than hidden: img/fig_qsoc_full.svg is the coloured
original that img/fig_qsoc_full_mono.svg is derived from by tools/svg_mono.py, and
the script that produced it is not in the repository, so it cannot be regenerated
monochrome. Nothing references it -- the documents use the _mono pair.
"""

import pathlib
import re
import sys

IMG = pathlib.Path(__file__).resolve().parent.parent / "img"
ALLOWED = {"#000000", "#ffffff", "#fff", "#000"}
EXEMPT = {"fig_qsoc_full.svg"}

COLOUR = re.compile(r"#[0-9a-fA-F]{3,8}\b")


def main():
    bad, checked = {}, 0
    for svg in sorted(IMG.glob("*.svg")):
        if svg.name in EXEMPT:
            continue
        checked += 1
        found = {c.lower() for c in COLOUR.findall(svg.read_text())} - ALLOWED
        if found:
            bad[svg.name] = sorted(found)

    if not checked:
        print("no diagram found -- nothing to check", file=sys.stderr)
        return 0
    if bad:
        print("diagram(s) with colour -- the palette in tools/diagen.py is "
              "monochrome, so this came from somewhere else:", file=sys.stderr)
        for name, cols in bad.items():
            print("  %s: %s" % (name, " ".join(cols)), file=sys.stderr)
        return 1
    print("%d diagram(s) monochrome" % checked)
    return 0


if __name__ == "__main__":
    sys.exit(main())
