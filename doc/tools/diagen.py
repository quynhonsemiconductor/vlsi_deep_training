"""Tiny block-diagram generator: one description -> .drawio (editable) + .svg + .png.

Usage:
    from diagen import Node as N, Edge as E, emit
    nodes = [N("cpu", x, y, w, h, "CPU", "blue", 12, bold=True)]
    edges = [E("cpu", "b", "bus", "t@0.25", "AXI_S1")]
    emit([("basename", "Diagram title", nodes, edges)], "out.drawio", "img_dir")

Sides are "l" | "r" | "t" | "b", optionally "t@0.25" to anchor a wire at a
fraction along that edge instead of its centre. Edge `mid` overrides the
elbow coordinate when two wires would otherwise share a track.
"""
import html
import os
import subprocess

STYLES = {
    "box":    dict(fill="#ffffff", stroke="#333333", dash=None),
    "blue":   dict(fill="#dae8fc", stroke="#6c8ebf", dash=None),
    "green":  dict(fill="#d5e8d4", stroke="#82b366", dash=None),
    "yellow": dict(fill="#fff2cc", stroke="#d6b656", dash=None),
    "red":    dict(fill="#f8cecc", stroke="#b85450", dash=None),
    "purple": dict(fill="#e1d5e7", stroke="#9673a6", dash=None),
    "grey":   dict(fill="#f5f5f5", stroke="#666666", dash=None),
    "group":  dict(fill="none",    stroke="#999999", dash="6 4"),
}
SIDES = {"l": (0, .5), "r": (1, .5), "t": (.5, 0), "b": (.5, 1)}


class Node:
    def __init__(s, nid, x, y, w, h, label, style="box", fs=11, bold=False, va="middle"):
        s.id, s.x, s.y, s.w, s.h = nid, x, y, w, h
        s.label, s.style, s.fs, s.bold, s.va = label, style, fs, bold, va

    def pt(s, side):
        if "@" in side:
            base, frac = side.split("@")
            f = float(frac)
            fx, fy = (f, 0) if base == "t" else (f, 1) if base == "b" \
                else (0, f) if base == "l" else (1, f)
        else:
            fx, fy = SIDES[side]
        return (s.x + fx * s.w, s.y + fy * s.h)


class Edge:
    def __init__(s, src, ss, dst, ds, label="", dashed=False, bidir=False, mid=None):
        s.src, s.ss, s.dst, s.ds = src, ss, dst, ds
        s.label, s.dashed, s.bidir, s.mid = label, dashed, bidir, mid


def route(a, b, ss, ds, mid=None):
    p1, p2 = a.pt(ss), b.pt(ds)
    ss, ds = ss[0], ds[0]
    if ss in "lr" and ds in "lr":
        if abs(p1[1] - p2[1]) < 1:
            return [p1, p2]
        mx = mid if mid is not None else (p1[0] + p2[0]) / 2
        return [p1, (mx, p1[1]), (mx, p2[1]), p2]
    if ss in "tb" and ds in "tb":
        if abs(p1[0] - p2[0]) < 1:
            return [p1, p2]
        my = mid if mid is not None else (p1[1] + p2[1]) / 2
        return [p1, (p1[0], my), (p2[0], my), p2]
    if ss in "lr":
        return [p1, (p2[0], p1[1]), p2]
    return [p1, (p1[0], p2[1]), p2]


def to_svg(nodes, edges, title, pad=24, draw_title=False):
    xs = [n.x for n in nodes] + [n.x + n.w for n in nodes]
    ys = [n.y for n in nodes] + [n.y + n.h for n in nodes]
    minx, miny = min(xs) - pad, min(ys) - pad - (26 if draw_title else 0)
    W, H = max(xs) - minx + pad, max(ys) - miny + pad
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W:.0f}" height="{H:.0f}" '
         f'viewBox="{minx:.0f} {miny:.0f} {W:.0f} {H:.0f}" '
         f'font-family="Helvetica,Arial,sans-serif">',
         '<defs><marker id="ah" markerWidth="9" markerHeight="7" refX="8.5" refY="3.5" '
         'orient="auto"><polygon points="0 0, 9 3.5, 0 7" fill="#333"/></marker>'
         '<marker id="ahs" markerWidth="9" markerHeight="7" refX="0.5" refY="3.5" '
         'orient="auto"><polygon points="9 0, 0 3.5, 9 7" fill="#333"/></marker></defs>',
         f'<rect x="{minx}" y="{miny}" width="{W}" height="{H}" fill="#ffffff"/>']
    if draw_title:
        o.append(f'<text x="{minx+pad}" y="{miny+20}" font-size="13" font-weight="bold" '
                 f'fill="#111">{html.escape(title)}</text>')
    idx = {n.id: n for n in nodes}
    for n in nodes:
        st = STYLES[n.style]
        d = f' stroke-dasharray="{st["dash"]}"' if st["dash"] else ""
        o.append(f'<rect x="{n.x}" y="{n.y}" width="{n.w}" height="{n.h}" rx="3" '
                 f'fill="{st["fill"]}" stroke="{st["stroke"]}" stroke-width="1.4"{d}/>')
    for e in edges:
        pts = route(idx[e.src], idx[e.dst], e.ss, e.ds, e.mid)
        p = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
        d = ' stroke-dasharray="5 3"' if e.dashed else ""
        st = ' marker-start="url(#ahs)"' if e.bidir else ""
        o.append(f'<polyline points="{p}" fill="none" stroke="#333" stroke-width="1.4"'
                 f'{d} marker-end="url(#ah)"{st}/>')
        if e.label:
            mi = len(pts) // 2
            mx = (pts[mi - 1][0] + pts[mi][0]) / 2
            my = (pts[mi - 1][1] + pts[mi][1]) / 2
            tw = 6.0 * len(e.label) + 6
            o.append(f'<rect x="{mx-tw/2:.1f}" y="{my-8:.1f}" width="{tw:.1f}" '
                     f'height="14" fill="#fff"/>')
            o.append(f'<text x="{mx:.1f}" y="{my+3:.1f}" font-size="10" fill="#444" '
                     f'text-anchor="middle">{html.escape(e.label)}</text>')
    for n in nodes:
        lines = n.label.split("\n")
        lh = n.fs + 3
        y0 = n.y + n.fs + 6 if n.va == "top" else \
            n.y + n.h / 2 - (len(lines) - 1) * lh / 2 + n.fs / 3
        fw = ' font-weight="bold"' if n.bold else ""
        for i, ln in enumerate(lines):
            o.append(f'<text x="{n.x+n.w/2:.1f}" y="{y0+i*lh:.1f}" font-size="{n.fs}" '
                     f'text-anchor="middle" fill="#111"{fw}>{html.escape(ln)}</text>')
    o.append("</svg>")
    return "\n".join(o)


def to_drawio_page(nodes, edges, name, pid):
    idx = {n.id: n for n in nodes}
    c = [f'  <diagram name="{html.escape(name)}" id="{pid}">',
         '    <mxGraphModel dx="1200" dy="800" grid="1" gridSize="10" guides="1" '
         'tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" '
         'pageWidth="1169" pageHeight="826" math="0" shadow="0">',
         "      <root>", '        <mxCell id="0"/>', '        <mxCell id="1" parent="0"/>']
    for n in nodes:
        st = STYLES[n.style]
        s = (f'rounded=0;whiteSpace=wrap;html=1;fillColor={st["fill"]};'
             f'strokeColor={st["stroke"]};fontSize={n.fs};'
             f'{"dashed=1;" if st["dash"] else "dashed=0;"}'
             f'{"fontStyle=1;" if n.bold else ""}'
             f'verticalAlign={"top" if n.va == "top" else "middle"};')
        lbl = html.escape(n.label).replace("\n", "&#10;")
        c.append(f'        <mxCell id="{n.id}" value="{lbl}" style="{s}" vertex="1" parent="1">')
        c.append(f'          <mxGeometry x="{n.x}" y="{n.y}" width="{n.w}" '
                 f'height="{n.h}" as="geometry"/>')
        c.append("        </mxCell>")
    for i, e in enumerate(edges):
        a, b = idx[e.src], idx[e.dst]
        p1, p2 = a.pt(e.ss), b.pt(e.ds)
        sx, sy = (p1[0] - a.x) / a.w, (p1[1] - a.y) / a.h
        dx, dy = (p2[0] - b.x) / b.w, (p2[1] - b.y) / b.h
        s = (f'edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;exitX={sx};exitY={sy};'
             f'entryX={dx};entryY={dy};exitDx=0;exitDy=0;entryDx=0;entryDy=0;'
             f'{"dashed=1;" if e.dashed else ""}'
             f'{"startArrow=classic;startFill=1;" if e.bidir else ""}')
        c.append(f'        <mxCell id="{e.src}_{e.dst}_{i}" value="{html.escape(e.label)}" '
                 f'style="{s}" edge="1" parent="1" source="{e.src}" target="{e.dst}">')
        c.append('          <mxGeometry relative="1" as="geometry"/>')
        c.append("        </mxCell>")
    c += ["      </root>", "    </mxGraphModel>", "  </diagram>"]
    return "\n".join(c)


def emit(pages, drawio_path, img_dir):
    """pages: list of (basename, title, nodes, edges)"""
    out = ['<mxfile host="app.diagrams.net" type="device">']
    for i, (key, title, nodes, edges) in enumerate(pages):
        out.append(to_drawio_page(nodes, edges, title, "pg%d" % i))
        sp = os.path.join(img_dir, key + ".svg")
        pp = os.path.join(img_dir, key + ".png")
        open(sp, "w").write(to_svg(nodes, edges, title))
        subprocess.run(["rsvg-convert", "-z", "2", "-o", pp, sp], check=True)
        print("wrote", pp)
    out.append("</mxfile>")
    open(drawio_path, "w").write("\n".join(out))
    print("wrote", drawio_path)
