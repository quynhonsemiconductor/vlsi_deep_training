"""Tiny timing-diagram generator: one description -> .svg + .png, monochrome.

Usage:
    from wavegen import wave
    wave("fig_x", [
        ("i_clk",   "clk"),                          # free-running clock
        ("o_clk",   "gclk", "1111000011"),           # clock, 1 = running in that step
        ("rst_n",   "bit",  "0011111111"),           # 0 / 1 / x per step
        ("REG",     "bus",  ["0", None, "0x3", None]),  # value per step, None = unchanged
        ("",        "note", [(2, 5, "16 cycles")]),  # double arrow between two steps
    ], steps=10, gaps=(4,), img_dir=IMG)

A step is one column. It is a clock cycle unless it is listed in `gaps`, where
time is compressed: the column is drawn with a break mark and clocks are flat.
"""
import html
import os
import subprocess

STEP, ROW, LABEL_W, HI, LO = 30, 34, 170, 8, 26   # geometry, px


def _x(i):
    return LABEL_W + i * STEP


def _mid(a, b, gaps):
    """Centre of the run a..b for its label, avoiding a gap column inside it."""
    inner = [g for g in gaps if a <= g < b]
    if not inner:
        return (_x(a) + _x(b)) / 2
    g = inner[0]
    left, right = (a, g), (g + 1, b)
    lo, hi = max((left, right), key=lambda s: s[1] - s[0])
    return (_x(lo) + _x(hi)) / 2


def wave(key, signals, steps, gaps=(), img_dir=".", marks=()):
    """marks: (step, text) -- dashed vertical line at the start of a step."""
    o = []
    H = ROW * len(signals) + 30
    W = _x(steps) + 20
    for r, sig in enumerate(signals):
        name, kind = sig[0], sig[1]
        y = 20 + r * ROW
        o.append(f'<text x="{LABEL_W - 12}" y="{y + 21}" font-size="12" text-anchor="end" '
                 f'font-family="Courier New,monospace">{html.escape(name)}</text>')
        if kind in ("clk", "gclk"):
            en = sig[2] if kind == "gclk" else "1" * steps
            d = []
            for i in range(steps):
                x0 = _x(i)
                if i in gaps or en[i] != "1":
                    d.append(f"M{x0},{y + LO} H{x0 + STEP}")
                else:
                    d.append(f"M{x0},{y + LO} V{y + HI} H{x0 + STEP / 2} V{y + LO} H{x0 + STEP}")
            o.append(f'<path d="{" ".join(d)}" fill="none" stroke="#000" stroke-width="1.3"/>')
        elif kind == "bit":
            v = sig[2]
            pts, prev = [], None
            for i in range(steps):
                c = v[i]
                lv = {"1": y + HI, "0": y + LO}.get(c)
                x0 = _x(i)
                if c == "x":
                    o.append(f'<rect x="{x0}" y="{y + HI}" width="{STEP}" height="{LO - HI}" '
                             f'fill="#ddd" stroke="none"/>')
                    lv = None
                if lv is not None:
                    if prev is not None and prev != lv:
                        pts.append((x0, prev))
                    pts.append((x0, lv))
                    pts.append((x0 + STEP, lv))
                    prev = lv
                else:
                    if pts:
                        o.append(_poly(pts))
                    pts, prev = [], None
            if pts:
                o.append(_poly(pts))
        elif kind == "bus":
            vals = sig[2]
            runs, cur, start = [], vals[0], 0
            for i in range(1, steps + 1):
                nv = vals[i] if i < steps and i < len(vals) else "END"
                if nv is not None:
                    runs.append((start, i, cur))
                    cur, start = nv, i
            for a, b, t in runs:
                x0, x1, s = _x(a), _x(b), 4
                ym = (y + HI + y + LO) / 2
                o.append(f'<polygon points="{x0},{ym} {x0 + s},{y + HI} {x1 - s},{y + HI} {x1},{ym} '
                         f'{x1 - s},{y + LO} {x0 + s},{y + LO}" fill="#fff" stroke="#000" '
                         f'stroke-width="1.3"/>')
                o.append(f'<text x="{_mid(a, b, gaps)}" y="{ym + 4}" font-size="10.5" '
                         f'text-anchor="middle" font-family="Courier New,monospace">'
                         f'{html.escape(t)}</text>')
        elif kind == "note":
            for a, b, t in sig[2]:
                x0, x1, ym = _x(a), _x(b), y + 16
                o.append(f'<line x1="{x0}" y1="{ym}" x2="{x1}" y2="{ym}" stroke="#000" '
                         f'stroke-width="1" marker-start="url(#as)" marker-end="url(#ae)"/>')
                o.append(f'<line x1="{x0}" y1="{y + 4}" x2="{x0}" y2="{y + 28}" stroke="#000" '
                         f'stroke-width="0.8"/>')
                o.append(f'<line x1="{x1}" y1="{y + 4}" x2="{x1}" y2="{y + 28}" stroke="#000" '
                         f'stroke-width="0.8"/>')
                tw, xt = 6.2 * len(t) + 6, _mid(a, b, gaps)
                o.append(f'<rect x="{xt - tw / 2}" y="{ym - 8}" width="{tw}" height="14" '
                         f'fill="#fff"/>')
                o.append(f'<text x="{xt}" y="{ym + 4}" font-size="11" '
                         f'text-anchor="middle">{html.escape(t)}</text>')
    for g in gaps:
        xm = _x(g) + STEP / 2
        o.append(f'<polygon points="{xm - 7},{H - 8} {xm - 1},12 {xm + 7},12 {xm + 1},{H - 8}" '
                 f'fill="#fff" stroke="none"/>')
        o.append(f'<path d="M{xm - 7},{H - 8} L{xm - 1},12 M{xm + 1},{H - 8} L{xm + 7},12" '
                 f'stroke="#000" stroke-width="1"/>')
    for step, t in marks:
        x = _x(step)
        o.append(f'<line x1="{x}" y1="14" x2="{x}" y2="{H - 6}" stroke="#000" '
                 f'stroke-width="0.8" stroke-dasharray="3 3"/>')
        o.append(f'<text x="{x}" y="11" font-size="11" text-anchor="middle">{html.escape(t)}</text>')
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
           f'viewBox="0 -4 {W} {H + 4}" font-family="Helvetica,Arial,sans-serif">'
           '<defs><marker id="ae" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto">'
           '<polygon points="0 0,8 3,0 6"/></marker>'
           '<marker id="as" markerWidth="8" markerHeight="6" refX="0" refY="3" orient="auto">'
           '<polygon points="8 0,0 3,8 6"/></marker></defs>'
           f'<rect x="0" y="-4" width="{W}" height="{H + 4}" fill="#fff"/>' + "".join(o) + "</svg>")
    sp, pp = os.path.join(img_dir, key + ".svg"), os.path.join(img_dir, key + ".png")
    open(sp, "w").write(svg)
    subprocess.run(["rsvg-convert", "-z", "2", "-o", pp, sp], check=True)
    print("wrote", pp)


def _poly(pts):
    p = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
    return f'<polyline points="{p}" fill="none" stroke="#000" stroke-width="1.3"/>'
