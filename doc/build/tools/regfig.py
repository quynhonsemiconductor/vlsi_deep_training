"""Register bit-field diagram: one 32-bit register per row, monochrome, .svg + .png.

Usage:
    from regfig import regfig
    regfig("fig_x", [
        ("RESET_CAUSE", [(0, 0, "por"), (1, 1, "wdt"), (2, 2, "soft")]),
    ], img_dir=IMG)

Fields are (lsb, msb, name). Bits not covered by a field are drawn as one
reserved block per gap, shaded. A field one bit wide gets its name written
vertically, so a register with 1-bit fields stays readable at 32 cells.
"""
import html
import os
import subprocess

CELL, NAME_W, TOP = 24, 150, 18


def _row(o, y, name, fields, height):
    o.append(f'<text x="{NAME_W - 10}" y="{y + height / 2 + 4}" font-size="12" font-weight="bold" '
             f'text-anchor="end" font-family="Courier New,monospace">{html.escape(name)}</text>')
    x_of = lambda bit: NAME_W + (31 - bit) * CELL          # bit 31 on the left
    for b in range(32):                                     # bit numbers
        o.append(f'<text x="{x_of(b) + CELL / 2}" y="{y - 4}" font-size="9" '
                 f'text-anchor="middle">{b}</text>')
    covered = set()
    for lsb, msb, _ in fields:
        covered.update(range(lsb, msb + 1))
    gaps, b = [], 0
    while b < 32:                                           # reserved runs
        if b in covered:
            b += 1
            continue
        s = b
        while b < 32 and b not in covered:
            b += 1
        gaps.append((s, b - 1, ""))
    for lsb, msb, label in list(fields) + gaps:
        x0, x1 = x_of(msb), x_of(lsb) + CELL
        rsvd = (lsb, msb, label) in gaps
        fill = "#e6e6e6" if rsvd else "#ffffff"
        o.append(f'<rect x="{x0}" y="{y}" width="{x1 - x0}" height="{height}" fill="{fill}" '
                 f'stroke="#000" stroke-width="1.2"/>')
        cx, cy = (x0 + x1) / 2, y + height / 2
        if rsvd:
            continue
        if msb == lsb and len(label) > 2:
            o.append(f'<text x="{cx + 4}" y="{cy}" font-size="10" text-anchor="middle" '
                     f'transform="rotate(-90 {cx + 4} {cy})">{html.escape(label)}</text>')
        else:
            o.append(f'<text x="{cx}" y="{cy + 4}" font-size="10.5" '
                     f'text-anchor="middle">{html.escape(label)}</text>')


def regfig(key, regs, img_dir=".", height=74):
    o, y = [], TOP
    for name, fields in regs:
        _row(o, y, name, fields, height)
        y += height + 34
    W, H = NAME_W + 32 * CELL + 16, y - 20
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
           f'viewBox="0 0 {W} {H}" font-family="Helvetica,Arial,sans-serif">'
           f'<rect width="{W}" height="{H}" fill="#fff"/>' + "".join(o) + "</svg>")
    sp, pp = os.path.join(img_dir, key + ".svg"), os.path.join(img_dir, key + ".png")
    open(sp, "w").write(svg)
    subprocess.run(["rsvg-convert", "-z", "2", "-o", pp, sp], check=True)
    print("wrote", pp)
