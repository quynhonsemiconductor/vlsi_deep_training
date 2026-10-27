"""Schematic primitives for review drawings, written as draw.io XML.

Flip-flop (box + clock triangle, a bubble for the falling edge), multiplexer
(trapezoid, input labels), logic gates (draw.io electrical library), net labels,
junction dots and orthogonal wires given as explicit points. Black and white, as
the MAS figures (doc/build/tools/diagen.py). Each element is one line of RTL: a
flip-flop an always_ff, a multiplexer a ?: or case, a gate an assign.

    from sch import Sheet
    s = Sheet("name")
    q = s.flop("r_q", x, y, "r_q[3:0]")      # returns pin coordinates
    s.wire([q["q"], (x2, y2)], "w_x[3:0]")
    open("f.drawio", "w").write(Sheet.file([s]))
"""
import html

FONT = "fontFamily=Helvetica;fontSize=11;"


class Sheet:
    def __init__(self, name):
        self.name, self.cells, self.n = name, [], 0

    def _id(self):
        self.n += 1
        return f"{self.name}_{self.n}"

    def _vertex(self, x, y, w, h, style, value=""):
        self.cells.append(
            f'<mxCell id="{self._id()}" value="{html.escape(value, quote=True).replace(chr(10), '&#xa;')}" style="{style}" '
            f'vertex="1" parent="1"><mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" '
            f'as="geometry"/></mxCell>')

    # ------------------------------------------------------------ text
    def text(self, x, y, s, align="left", size=11, bold=False, w=None, h=16):
        w = w or max(20, 7 * max(len(l) for l in s.split("\n")))
        x0 = x if align == "left" else x - w if align == "right" else x - w / 2
        self._vertex(x0, y - h / 2, w, h * len(s.split("\n")),
                     f"text;html=0;align={align};verticalAlign=middle;fontFamily=Helvetica;"
                     f"fontSize={size};fontStyle={1 if bold else 0};whiteSpace=nowrap;", s)

    def group(self, x, y, w, h, title):
        self._vertex(x, y, w, h, "rounded=0;html=0;fillColor=none;dashed=1;dashPattern=6 4;"
                     f"verticalAlign=top;fontStyle=1;{FONT}", title)

    def box(self, x, y, w, h, label, bold=False, thick=False, align="center"):
        self._vertex(x, y, w, h, f"rounded=0;html=0;whiteSpace=wrap;fontStyle={1 if bold else 0};align={align};spacingLeft=8;"
                     f"strokeWidth={2.5 if thick else 1};{FONT}", label)
        return dict(l=(x, y + h / 2), r=(x + w, y + h / 2), t=(x + w / 2, y), b=(x + w / 2, y + h))

    # ------------------------------------------------------------ flip-flop
    def flop(self, x, y, label, w=90, h=60, falling=False, en=None):
        """D left, Q right, clock triangle bottom left. Returns pin points."""
        self._vertex(x, y, w, h, f"rounded=0;html=0;whiteSpace=wrap;{FONT}", label)
        self._vertex(x, y + h - 18, 10, 14, "triangle;html=0;direction=east;fillColor=none;")
        if falling:
            self._vertex(x - 8, y + h - 15, 8, 8, "ellipse;html=0;fillColor=#ffffff;")
        return dict(d=(x, y + 18), q=(x + w, y + 18), clk=(x - (8 if falling else 0), y + h - 11),
                    rst=(x + w / 2, y + h))

    # ------------------------------------------------------------ multiplexer
    def mux(self, x, y, labels, w=34, pitch=22):
        """Inputs on the left, top to bottom, labelled; select at the bottom."""
        h = pitch * (len(labels) + 1)
        self._vertex(x, y, w, h, "shape=trapezoid;perimeter=trapezoidPerimeter;html=0;"
                     "fixedSize=1;size=10;direction=south;fillColor=#ffffff;")
        ins = []
        for i, lab in enumerate(labels):
            py = y + pitch * (i + 1)
            self.text(x + 3, py, lab, size=9)
            ins.append((x, py))
        return dict(i=ins, o=(x + w, y + h / 2), s=(x + w / 2, y + h - 5))

    # ------------------------------------------------------------ gates
    def gate(self, x, y, op, w=60, h=40, neg=False):
        """op: and | or | xor. Inputs at 1/4 and 3/4 of the height."""
        self._vertex(x, y, w, h, "shape=mxgraph.electrical.logic_gates.logic_gate;html=0;"
                     f"operation={op};{'negating=1;negSize=0.15;' if neg else ''}")
        return dict(a=(x, y + h * 0.25), b=(x, y + h * 0.75), o=(x + w, y + h / 2))

    def inv(self, x, y, w=40, h=26):
        self._vertex(x, y, w, h, "shape=mxgraph.electrical.logic_gates.inverter_2;html=0;")
        return dict(a=(x, y + h / 2), o=(x + w, y + h / 2))

    def dot(self, p):
        self._vertex(p[0] - 3, p[1] - 3, 6, 6, "ellipse;html=0;fillColor=#000000;")

    # ------------------------------------------------------------ wires
    def wire(self, pts, label=None, arrow=True, at=0, dy=-8):
        """Orthogonal wire through pts; label above segment `at`."""
        (x0, y0), (x1, y1) = pts[0], pts[-1]
        mids = "".join(f'<mxPoint x="{px}" y="{py}"/>' for px, py in pts[1:-1])
        self.cells.append(
            f'<mxCell id="{self._id()}" value="" style="endArrow={"classic" if arrow else "none"};'
            f'endSize=6;html=0;rounded=0;" edge="1" parent="1"><mxGeometry relative="1" '
            f'as="geometry"><mxPoint x="{x0}" y="{y0}" as="sourcePoint"/><mxPoint x="{x1}" '
            f'y="{y1}" as="targetPoint"/><Array as="points">{mids}</Array></mxGeometry></mxCell>')
        if label:
            (ax, ay), (bx, by) = pts[at], pts[at + 1]
            self.text((ax + bx) / 2, (ay + by) / 2 + dy, label, align="center", size=9)

    # ------------------------------------------------------------ file
    def page(self, pid):
        return (f'<diagram name="{html.escape(self.name)}" id="{pid}"><mxGraphModel grid="0" '
                f'page="0"><root><mxCell id="0"/><mxCell id="1" parent="0"/>'
                + "".join(self.cells) + "</root></mxGraphModel></diagram>")

    @staticmethod
    def file(sheets):
        return ('<mxfile host="app.diagrams.net">' +
                "".join(s.page(f"p{i}") for i, s in enumerate(sheets)) + "</mxfile>")
