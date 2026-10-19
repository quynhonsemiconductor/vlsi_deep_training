"""Vẽ giải thích AXI4 bằng draw.io, 6 trang, chữ tiếng Việt:
  1 năm kênh, 2 bắt tay VALID/READY, 3 giao dịch ghi, 4 giao dịch đọc, 5 burst và mã phản hồi, 6 ID và thứ tự.
Ký hiệu theo QNSC_DRAWIO_LIB_V1.0. Mã burst và resp đọc từ vendor/pulp-platform/axi/src/axi_pkg.sv.
Quy tắc chung của AXI4 (bắt tay, thứ tự, ranh giới 4 KiB) lấy từ đặc tả ARM AXI4, không có trong repo.

    python -X utf8 gen_axi4_drawio.py [out.drawio]
"""
import re
import sys
from pathlib import Path
from xml.sax.saxutils import quoteattr

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent.parent
axi_pkg_txt = (REPO / "vendor/pulp-platform/axi/src/axi_pkg.sv").read_text(encoding="utf-8")


def pkg_const(name):
    m = re.search(rf"{name}\s*=\s*2'b([01]{{2}})", axi_pkg_txt)
    if not m:
        raise SystemExit(f"{name} không có trong axi_pkg")
    return int(m.group(1), 2)


BURST = {k: pkg_const(f"BURST_{k}") for k in ("FIXED", "INCR", "WRAP")}
RESP = {k: pkg_const(f"RESP_{k}") for k in ("OKAY", "EXOKAY", "SLVERR", "DECERR")}


def h(v):
    return f"0x{v:04X}"


S_RECT = "rounded=0;whiteSpace=wrap;html=1;fontSize=18;strokeWidth=2;"
S_CLOUD = "ellipse;shape=cloud;whiteSpace=wrap;html=1;fontSize=18;strokeWidth=2;"
S_TRAP = "shape=trapezoid;perimeter=trapezoidPerimeter;whiteSpace=wrap;html=1;fixedSize=1;strokeWidth=2;"
S_TEXT = "text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;rounded=0;fontSize=18;"
S_TRI = "triangle;whiteSpace=wrap;html=1;strokeWidth=2;fillColor=#ffffff;"
S_HEX = "shape=hexagon;perimeter=hexagonPerimeter2;size=0.18;whiteSpace=wrap;html=1;strokeWidth=2;fillColor=#ffffff;"
ARW = "edgeStyle=none;html=1;rounded=0;endArrow=block;endFill=1;endSize=8;startSize=8;"


def sm(t, px=13):
    return f'<span style="font-size:{px}px">{t}</span>'


class Page:
    def __init__(self, name, w, h_):
        self.name, self.w, self.h = name, w, h_
        self.cells = []
        self.n = 1

    def nid(self):
        self.n += 1
        return f"{self.name[:1]}{self.n}"

    def vertex(self, x, y, w, h_, html, style, rotation=0):
        rot = f"rotation={rotation};" if rotation else ""
        self.cells.append(f'<mxCell id="{self.nid()}" value={quoteattr(html)} style="{style}{rot}" vertex="1" parent="1">'
                          f'<mxGeometry x="{x}" y="{y}" width="{w}" height="{h_}" as="geometry"/></mxCell>')

    def box(self, x, y, w, h_, html, size=16, align="center", valign="middle", extra=""):
        self.vertex(x, y, w, h_, html, S_RECT + f"fontSize={size};align={align};verticalAlign={valign};spacingLeft=8;spacingRight=8;" + extra)

    def text(self, x, y, w, h_, html, size=14, align="center", bold=False, valign="middle"):
        self.vertex(x, y, w, h_, html, S_TEXT + f"fontSize={size};align={align};verticalAlign={valign};{'fontStyle=1;' if bold else ''}")

    def label(self, x, y, w, h_, html, size=12):
        self.vertex(x, y, w, h_, html, S_TEXT + f"fontSize={size};align=center;verticalAlign=middle;fillColor=#ffffff;spacing=1;")

    def region(self, x, y, w, h_, title, dash="10 6", width=2):
        self.vertex(x, y, w, h_, f"<b>{title}</b>",
                    f"rounded=0;whiteSpace=wrap;html=1;fillColor=none;strokeWidth={width};dashed=1;dashPattern={dash};"
                    "fontSize=14;align=left;verticalAlign=top;spacingLeft=10;spacingTop=4;")

    def edge(self, pts, width=2, arrow=True, dashed=False):
        mid = "".join(f'<mxPoint x="{px}" y="{py}"/>' for px, py in pts[1:-1])
        way = f'<Array as="points">{mid}</Array>' if mid else ""
        end = "endArrow=block;endFill=1;" if arrow else "endArrow=none;"
        self.cells.append(f'<mxCell id="{self.nid()}" style="{ARW}{end}strokeWidth={width};{"dashed=1;" if dashed else ""}" edge="1" parent="1">'
                          f'<mxGeometry relative="1" as="geometry"><mxPoint x="{pts[0][0]}" y="{pts[0][1]}" as="sourcePoint"/>'
                          f'<mxPoint x="{pts[-1][0]}" y="{pts[-1][1]}" as="targetPoint"/>{way}</mxGeometry></mxCell>')

    def bus(self, pts, width_text=None, name=None, name_pos="above"):
        """Mũi tên bus: nét đậm, gạch chéo kèm số bit, tên net."""
        self.edge(pts, 4)
        (x0, y0), (x1, y1) = pts[0], pts[1]
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        horiz = abs(y1 - y0) < abs(x1 - x0)
        if width_text:
            if horiz:
                self.edge([(mx - 6, my + 9), (mx + 6, my - 9)], 2, arrow=False)
                self.text(mx + 4, my - 30, 44, 18, sm(width_text, 12), 12, "left")
            else:
                self.edge([(mx - 9, my + 6), (mx + 9, my - 6)], 2, arrow=False)
                self.text(mx + 10, my - 9, 44, 18, sm(width_text, 12), 12, "left")
        if name:
            if horiz:
                dy = -34 if name_pos == "above" else 12
                self.label(mx - 70, my + dy + (0 if width_text and name_pos == "above" else 0), 140, 20, f"<i>{name}</i>", 12)
            else:
                self.label(mx + 30, my - 10, 150, 20, f"<i>{name}</i>", 12)

    def reg(self, x, y, w, h_, name, active=True):
        """Thanh ghi: hình chữ nhật có tam giác clock. Bypass thì nét đứt."""
        self.vertex(x, y, w, h_, f"{name}", S_RECT + f"fontSize=12;{'dashed=1;' if not active else ''}align=center;verticalAlign=middle;")
        self.vertex(x + 2, y + h_ - 16, 12, 12, "", S_TRI + "fillColor=none;strokeWidth=1.5;", rotation=0)

    def mux(self, cx, cy, vis_w, vis_h, rot=180):
        self.vertex(cx - vis_w / 2, cy - vis_h / 2, vis_w, vis_h, "", S_TRAP, rotation=rot)

    def demux_v(self, cx, cy, vis_w, vis_h):
        """Đầu vào bên trái hẹp, các đầu ra bên phải rộng."""
        self.vertex(cx - vis_h / 2, cy - vis_w / 2, vis_h, vis_w, "", S_TRAP, rotation=-90)

    def mux_v(self, cx, cy, vis_w, vis_h):
        """Các đầu vào bên trái rộng, đầu ra bên phải hẹp."""
        self.vertex(cx - vis_h / 2, cy - vis_w / 2, vis_h, vis_w, "", S_TRAP, rotation=90)

    def dot(self, x, y, r=6):
        self.vertex(x - r, y - r, 2 * r, 2 * r, "", "ellipse;fillColor=#000000;strokeColor=#000000;")

    def clk_tri(self, x, y):
        self.vertex(x, y, 12, 14, "", S_TRI + "strokeWidth=1.5;", rotation=90)

    def xml(self):
        return (f'<diagram id="{self.name}" name={quoteattr(self.name)}><mxGraphModel dx="1400" dy="900" grid="0" gridSize="10" '
                f'guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="{self.w}" '
                f'pageHeight="{self.h}" math="0" shadow="0"><root><mxCell id="0"/><mxCell id="1" parent="0"/>'
                + "".join(self.cells) + "</root></mxGraphModel></diagram>")


def heading(page, t, sub):
    page.text(20, 8, 2000, 40, f"<b>{t}</b>", 26, "left")
    page.text(20, 50, 2200, 26, sub, 14, "left")



def two_way(page, pts, width=3):
    mid = "".join(f'<mxPoint x="{px}" y="{py}"/>' for px, py in pts[1:-1])
    way = f'<Array as="points">{mid}</Array>' if mid else ""
    page.cells.append(f'<mxCell id="{page.nid()}" style="{ARW}endArrow=block;endFill=1;startArrow=block;startFill=1;strokeWidth={width};" edge="1" parent="1">'
                      f'<mxGeometry relative="1" as="geometry"><mxPoint x="{pts[0][0]}" y="{pts[0][1]}" as="sourcePoint"/>'
                      f'<mxPoint x="{pts[-1][0]}" y="{pts[-1][1]}" as="targetPoint"/>{way}</mxGeometry></mxCell>')


SIGW = 26


class Wave:
    """Dạng sóng số trên một trang: X0 là mép trái, CW bề rộng một chu kỳ, NC số chu kỳ."""

    def __init__(self, page, x0, cw, nc, label_w=330):
        self.p, self.x0, self.cw, self.nc, self.lw = page, x0, cw, nc, label_w

    def grid(self, y0, y1, first=0):
        for c in range(self.nc + 1):
            self.p.edge([(self.x0 + c * self.cw, y0), (self.x0 + c * self.cw, y1)], 1, arrow=False, dashed=True)
        for c in range(self.nc):
            self.p.text(self.x0 + c * self.cw, y0 - 24, self.cw, 22, sm(f"chu kỳ {c + first}", 12), 12)

    def name(self, y_, name):
        self.p.text(self.x0 - self.lw - 10, y_ - 6, self.lw, SIGW + 12, sm(name, 12), 12, "right")

    def clk(self, y_, name="clk"):
        self.name(y_, name)
        pts = []
        for c in range(self.nc):
            x1 = self.x0 + c * self.cw
            pts += [(x1, y_ + SIGW), (x1, y_), (x1 + self.cw // 2, y_), (x1 + self.cw // 2, y_ + SIGW)]
        pts.append((self.x0 + self.nc * self.cw, y_ + SIGW))
        self.p.edge(pts, 2, arrow=False)

    def bit(self, y_, name, hi):
        self.name(y_, name)
        seq = [1 if c in hi else 0 for c in range(self.nc)]
        pts, prev, prev_y = [], None, None
        for c, v in enumerate(seq):
            yy = y_ if v else y_ + SIGW
            x1 = self.x0 + c * self.cw
            if prev is None:
                pts.append((x1, yy))
            elif prev != v:
                pts += [(x1, prev_y), (x1, yy)]
            prev, prev_y = v, yy
        pts.append((self.x0 + len(seq) * self.cw, prev_y))
        self.p.edge(pts, 2, arrow=False)

    def bus(self, y_, name, segs):
        self.name(y_, name)
        self.p.edge([(self.x0, y_ + SIGW // 2), (self.x0 + self.nc * self.cw, y_ + SIGW // 2)], 1, arrow=False)
        for c0, c1_, lab in segs:
            self.p.vertex(self.x0 + c0 * self.cw + 4, y_, (c1_ - c0) * self.cw - 8, SIGW, sm(lab, 12), S_HEX + "fontSize=12;")

    def xfer(self, c, y_top, y_bot, label="chuyển"):
        self.p.vertex(self.x0 + c * self.cw + 2, y_top, self.cw - 4, y_bot - y_top, "", "rounded=0;fillColor=none;strokeWidth=2;dashed=1;dashPattern=4 3;")
        self.p.text(self.x0 + c * self.cw - 10, y_bot + 2, self.cw + 20, 20, f"<b>{sm(label, 11)}</b>", 11)


# ====================================================================== TRANG 1: năm kênh
a1 = Page("1. Năm kênh AXI4", 1900, 1000)
heading(a1, "AXI4: 5 kênh độc lập giữa master và slave",
        "Mỗi kênh có cặp VALID và READY riêng. Ba kênh đi từ master sang slave (AW, W, AR), hai kênh đi ngược lại (B, R).")
a1.box(40, 130, 200, 760, "<b>Master</b><br>" + sm("bên bắt đầu giao dịch<br>(CPU, DMA, SYSDBG)", 12), 18, valign="top")
a1.box(1660, 130, 200, 760, "<b>Slave</b><br>" + sm("bên trả lời<br>(ROM, RAM, ngoại vi)", 12), 18, valign="top")
a1.region(280, 120, 1340, 400, "Giao dịch GHI")
a1.region(280, 540, 1340, 350, "Giao dịch ĐỌC")
lanes = [
    ("AW", "địa chỉ ghi và điều khiển", 210, True,
     "awid · awaddr[31:0] · awlen[7:0] · awsize[2:0] · awburst[1:0]<br>awlock · awcache[3:0] · awprot[2:0] · awqos[3:0] · awregion[3:0]", "awvalid · awready"),
    ("W", "dữ liệu ghi", 330, True, "wdata[31:0] · wstrb[3:0] · wlast", "wvalid · wready"),
    ("B", "phản hồi ghi", 440, False, "bid · bresp[1:0]", "bvalid · bready"),
    ("AR", "địa chỉ đọc và điều khiển", 620, True,
     "arid · araddr[31:0] · arlen[7:0] · arsize[2:0] · arburst[1:0]<br>arlock · arcache[3:0] · arprot[2:0] · arqos[3:0] · arregion[3:0]", "arvalid · arready"),
    ("R", "dữ liệu đọc và phản hồi", 760, False, "rid · rdata[31:0] · rresp[1:0] · rlast", "rvalid · rready"),
]
for nm, what, yy, fwd, sigs, hs in lanes:
    pts = [(240, yy), (1660, yy)] if fwd else [(1660, yy), (240, yy)]
    a1.edge(pts, 4)
    a1.box(880, yy - 24, 120, 48, f"<b>{nm}</b>", 20)
    a1.text(300, yy - 62, 580, 56, sm(sigs, 12), 12, "left")
    a1.text(1010, yy - 36, 300, 24, sm(f"<b>{what}</b>", 13), 13, "left")
    a1.text(1010, yy + 8, 300, 22, sm(hs + (" (master → slave, slave → master)" if fwd else " (slave → master, master → slave)"), 10), 10, "left")
a1.text(280, 905, 1340, 70, sm(
    "VALID do bên gửi dữ liệu của kênh đó bật, READY do bên nhận bật. Dữ liệu chỉ được chuyển khi cả hai cùng bằng 1.<br>"
    "Các kênh không có thứ tự cố định với nhau, trừ hai quy tắc: slave chỉ trả B sau khi nhận xong beat W cuối, và chỉ trả R sau khi nhận AR.", 13), 13, "left", valign="top")

# ====================================================================== TRANG 2: bắt tay
a2 = Page("2. Bắt tay VALID và READY", 2000, 1160)
heading(a2, "Bắt tay VALID và READY",
        "Dữ liệu chỉ được chuyển ở chu kỳ có cả VALID và READY bằng 1. Ba cách xảy ra, đều hợp lệ.")
W2 = Wave(a2, 400, 110, 7, 300)
cases = [
    ("A. VALID lên trước, READY lên sau", 150, dict(valid={1, 2, 3}, ready={3}, data=[(1, 4, "D")], x=3)),
    ("B. READY lên trước, VALID lên sau", 460, dict(valid={3}, ready={0, 1, 2, 3, 4}, data=[(3, 4, "D")], x=3)),
    ("C. VALID và READY lên cùng lúc", 770, dict(valid={2}, ready={2}, data=[(2, 3, "D")], x=2)),
]
for title_, y0, d in cases:
    a2.text(20, y0 - 38, 800, 26, f"<b>{title_}</b>", 15, "left")
    W2.grid(y0 - 4, y0 + 230)
    W2.clk(y0 + 10)
    W2.bit(y0 + 70, "VALID (bên gửi)", d["valid"])
    W2.bit(y0 + 130, "READY (bên nhận)", d["ready"])
    W2.bus(y0 + 190, "dữ liệu (bên gửi)", d["data"])
    W2.xfer(d["x"], y0 + 60, y0 + 222, "chuyển dữ liệu")
a2.text(1250, 150, 700, 700, sm(
    "<b>Quy tắc</b><br><br>"
    "1. Chuyển dữ liệu xảy ra ở chu kỳ có VALID = 1 và READY = 1 (bên nhận lấy dữ liệu ở cạnh lên clock cuối chu kỳ đó).<br><br>"
    "2. Bên gửi bật VALID khi có dữ liệu, không được chờ READY lên rồi mới bật VALID.<br><br>"
    "3. Đã bật VALID thì phải giữ VALID và giữ nguyên dữ liệu cho tới khi bắt tay xong (ví dụ A).<br><br>"
    "4. Bên nhận được phép bật READY trước khi có VALID (ví dụ B), hoặc chờ thấy VALID rồi mới bật.<br><br>"
    "5. READY = 1 mà VALID = 0 thì không có gì được chuyển; VALID = 1 mà READY = 0 thì bên gửi chờ.<br><br>"
    "Quy tắc này áp dụng cho cả 5 kênh. Bên nhận làm chậm luồng dữ liệu bằng cách hạ READY (gọi là back-pressure).", 14), 14, "left", valign="top")

# ====================================================================== TRANG 3: ghi
a3 = Page("3. Giao dịch ghi", 2300, 1160)
heading(a3, "Giao dịch ghi: burst 4 beat",
        "AW gửi địa chỉ một lần, W gửi 4 beat dữ liệu, B phản hồi một lần cho cả burst. Beat thứ 3 bị chờ vì wready = 0.")
W3 = Wave(a3, 440, 110, 11, 360)
W3.grid(140, 1040)
y = 150
W3.clk(y, "clk")
y += 60
a3.text(20, y - 4, 600, 24, "<b>Kênh AW: địa chỉ</b>", 15, "left")
y += 30
W3.bit(y, "awvalid", {1}); y += 52
W3.bit(y, "awready", {1}); y += 52
W3.bus(y, "awaddr[31:0]", [(1, 2, "A")]); y += 52
W3.bus(y, "awlen[7:0]", [(1, 2, "3")]); y += 52
aw_end = y
y += 14
a3.text(20, y - 4, 600, 24, "<b>Kênh W: dữ liệu</b>", 15, "left")
y += 30
w_top = y
W3.bit(y, "wvalid", {2, 3, 4, 5, 6}); y += 52
W3.bit(y, "wready", {2, 3, 5, 6}); y += 52
W3.bus(y, "wdata[31:0]", [(2, 3, "D0"), (3, 4, "D1"), (4, 6, "D2"), (6, 7, "D3")]); y += 52
W3.bus(y, "wstrb[3:0]", [(2, 7, "4'b1111")]); y += 52
W3.bit(y, "wlast", {6}); y += 52
w_end = y
y += 14
a3.text(20, y - 4, 600, 24, "<b>Kênh B: phản hồi</b>", 15, "left")
y += 30
b_top = y
W3.bit(y, "bvalid", {8}); y += 52
W3.bit(y, "bready", {7, 8, 9}); y += 52
W3.bus(y, "bresp[1:0]", [(8, 9, "OKAY")]); y += 52
b_end = y
W3.xfer(1, 190, aw_end - 6, "AW")
for c_, lab in ((2, "D0"), (3, "D1"), (5, "D2"), (6, "D3 (wlast)")):
    pass
W3.xfer(2, w_top - 6, w_end - 6, "D0")
W3.xfer(3, w_top - 6, w_end - 6, "D1")
W3.xfer(5, w_top - 6, w_end - 6, "D2")
W3.xfer(6, w_top - 6, w_end - 6, "D3, wlast")
W3.xfer(8, b_top - 6, b_end - 6, "B")
a3.text(1740, 200, 520, 640, sm(
    "<b>Các bước</b><br><br>"
    "Chu kỳ 1, kênh AW: master gửi địa chỉ A và awlen = 3, nghĩa là 4 beat. Slave nhận ngay (awready = 1).<br><br>"
    "Chu kỳ 2 đến 6, kênh W: master gửi 4 beat D0 đến D3. Ở chu kỳ 4, wvalid = 1 nhưng wready = 0, nên master giữ D2 và chờ. Beat cuối có wlast = 1.<br><br>"
    "Chu kỳ 8, kênh B: sau khi nhận beat cuối, slave gửi một phản hồi bresp = OKAY cho cả burst.<br><br>"
    "<b>Lưu ý</b><br>"
    "AW và W độc lập nhau: W có thể đi trước, cùng lúc hoặc sau AW.<br>"
    "wstrb có một bit cho mỗi byte, bit nào bằng 1 thì byte đó được ghi.<br>"
    "Slave chỉ được trả B sau khi đã nhận cả AW và beat W cuối.", 13), 13, "left", valign="top")

# ====================================================================== TRANG 4: đọc
a4 = Page("4. Giao dịch đọc", 2300, 900)
heading(a4, "Giao dịch đọc: burst 4 beat",
        "AR gửi địa chỉ một lần, slave trả 4 beat dữ liệu qua kênh R. Mỗi beat có rresp riêng, beat cuối có rlast = 1.")
W4 = Wave(a4, 440, 110, 11, 360)
W4.grid(140, 840)
y = 150
W4.clk(y, "clk")
y += 60
a4.text(20, y - 4, 600, 24, "<b>Kênh AR: địa chỉ</b>", 15, "left")
y += 30
ar_top = y
W4.bit(y, "arvalid", {1, 2}); y += 52
W4.bit(y, "arready", {2}); y += 52
W4.bus(y, "araddr[31:0]", [(1, 3, "A")]); y += 52
W4.bus(y, "arlen[7:0]", [(1, 3, "3")]); y += 52
ar_end = y
y += 14
a4.text(20, y - 4, 600, 24, "<b>Kênh R: dữ liệu đọc</b>", 15, "left")
y += 30
r_top = y
W4.bit(y, "rvalid", {5, 6, 7, 8, 9}); y += 52
W4.bit(y, "rready", {5, 6, 8, 9}); y += 52
W4.bus(y, "rdata[31:0]", [(5, 6, "R0"), (6, 7, "R1"), (7, 9, "R2"), (9, 10, "R3")]); y += 52
W4.bus(y, "rresp[1:0]", [(5, 10, "OKAY")]); y += 52
W4.bit(y, "rlast", {9}); y += 52
r_end = y
W4.xfer(2, ar_top - 6, ar_end - 6, "AR")
for c_, lab in ((5, "R0"), (6, "R1"), (8, "R2"), (9, "R3, rlast")):
    W4.xfer(c_, r_top - 6, r_end - 6, lab)
a4.text(1740, 170, 520, 600, sm(
    "<b>Các bước</b><br><br>"
    "Chu kỳ 1 và 2, kênh AR: master gửi địa chỉ A, arlen = 3. Slave chưa sẵn sàng ở chu kỳ 1 (arready = 0), nên master giữ arvalid và địa chỉ. Bắt tay xong ở chu kỳ 2.<br><br>"
    "Chu kỳ 5 đến 9, kênh R: slave trả 4 beat R0 đến R3. Ở chu kỳ 7, master hạ rready, nên slave giữ R2 và chờ. Beat cuối có rlast = 1.<br><br>"
    "<b>Lưu ý</b><br>"
    "Từ lúc nhận AR đến beat R đầu có thể mất nhiều chu kỳ, tuỳ slave.<br>"
    "Khác với ghi, đọc không có kênh phản hồi riêng: kết quả (rresp) đi cùng từng beat dữ liệu.", 13), 13, "left", valign="top")

# ====================================================================== TRANG 5: burst
a5 = Page("5. Burst: len, size, loại", 2000, 1250)
heading(a5, "Burst: số beat, kích thước beat và ba loại burst",
        "Địa chỉ và điều khiển chỉ gửi một lần cho cả burst, các beat sau slave tự tính địa chỉ.")
a5.box(40, 100, 560, 150, "<b>Số beat</b> = AxLEN + 1<br><b>Byte mỗi beat</b> = 2 mũ AxSIZE<br>"
       + sm("AxSIZE = 2 nghĩa là 4 byte mỗi beat (bus 32 bit rộng 4 byte).<br>AxLEN rộng 8 bit: INCR tối đa 256 beat, FIXED và WRAP tối đa 16 beat.", 12), 15, align="left")
base, sz = 0x1000, 4
a5.text(40, 270, 900, 28, f"<b>INCR</b> {sm('(AxBURST = 2' + chr(39) + 'b01): địa chỉ tăng dần. Ví dụ araddr = ' + h(base) + ', arlen = 3, arsize = 2', 13)}", 15, "left")
for k in range(4):
    a5.box(40 + k * 215, 310, 195, 70, f"<b>beat {k}</b><br>{sm(h(base + k * sz), 13)}", 14)
    if k:
        a5.edge([(40 + k * 215 - 20, 345), (40 + k * 215, 345)], 2)
a5.text(40, 392, 880, 26, sm("4 beat × 4 byte = 16 byte, địa chỉ cộng thêm 4 sau mỗi beat.", 12), 12, "left")
a5.text(40, 440, 900, 28, f"<b>FIXED</b> {sm('(AxBURST = 2' + chr(39) + 'b00): mọi beat cùng một địa chỉ. Dùng khi đọc ghi liên tục vào một thanh ghi hay FIFO', 13)}", 15, "left")
for k in range(4):
    a5.box(40 + k * 215, 480, 195, 70, f"<b>beat {k}</b><br>{sm(h(base), 13)}", 14)
a5.text(40, 580, 900, 28, f"<b>WRAP</b> {sm('(AxBURST = 2' + chr(39) + 'b10): địa chỉ tăng rồi quay vòng trong một vùng. Ví dụ bắt đầu ' + h(base + 8) + ', 4 beat', 13)}", 15, "left")
wrap_seq = [base + 8, base + 12, base, base + 4]
for k, ad in enumerate(wrap_seq):
    a5.box(40 + k * 215, 620, 195, 70, f"<b>beat {k}</b><br>{sm(h(ad), 13)}", 14)
a5.text(40, 702, 900, 44, sm(f"Vùng quay vòng = số beat × byte mỗi beat = 16 byte, căn theo 16 byte ({h(base)} đến {h(base + 15)}). WRAP chỉ có 2, 4, 8 hoặc 16 beat. Hay dùng để nạp cache line.", 12), 12, "left", valign="top")
a5.region(40, 790, 900, 200, "Ranh giới 4 KiB")
a5.text(50, 822, 880, 160, sm(
    "Một burst không được vượt qua ranh giới 4 KiB (địa chỉ có phần 12 bit cao đổi giữa chừng).<br>"
    "Lý do: mỗi slave thường nằm gọn trong một vùng 4 KiB, nên burst vượt ranh giới có thể rơi vào hai slave khác nhau.<br><br>"
    "Trong QSOC: CPU chỉ gửi burst 1 beat (len = 0).", 13), 13, "left", valign="top")

# bảng mã
a5.text(1000, 100, 940, 28, "<b>Mã AxBURST và xRESP</b>", 16, "left")
tbl = [("AxBURST", "ý nghĩa"), (f"2'b{BURST['FIXED']:02b}", "FIXED"), (f"2'b{BURST['INCR']:02b}", "INCR"), (f"2'b{BURST['WRAP']:02b}", "WRAP")]
for r_, (c1_, c2_) in enumerate(tbl):
    a5.box(1000, 140 + r_ * 44, 140, 44, f"<b>{c1_}</b>" if r_ == 0 else c1_, 14)
    a5.box(1140, 140 + r_ * 44, 200, 44, f"<b>{c2_}</b>" if r_ == 0 else c2_, 14)
rt = [("xRESP", "ý nghĩa", "ai trả"),
      (f"2'b{RESP['OKAY']:02b}", "OKAY: thành công", "slave"),
      (f"2'b{RESP['EXOKAY']:02b}", "EXOKAY: exclusive access thành công", "slave"),
      (f"2'b{RESP['SLVERR']:02b}", "SLVERR: slave báo lỗi (ví dụ ghi vào vùng chỉ đọc, tuỳ slave)", "slave"),
      (f"2'b{RESP['DECERR']:02b}", "DECERR: không có slave nào ở địa chỉ này", "interconnect")]
for r_, (c1_, c2_, c3_) in enumerate(rt):
    hh = 44 if r_ < 3 else 60
    yy = 360 + (r_ * 44 if r_ < 4 else 3 * 44 + 60)
    if r_ == 3:
        yy = 360 + 3 * 44
    if r_ == 4:
        yy = 360 + 3 * 44 + 60
    a5.box(1000, yy, 120, hh, f"<b>{c1_}</b>" if r_ == 0 else c1_, 14)
    a5.box(1120, yy, 620, hh, f"<b>{c2_}</b>" if r_ == 0 else c2_, 13)
    a5.box(1740, yy, 200, hh, f"<b>{c3_}</b>" if r_ == 0 else c3_, 13)
a5.text(1000, 660, 940, 40, sm("Kênh ghi có một bresp cho cả burst. Kênh đọc có rresp ở từng beat.", 13), 13, "left")
a5.text(1000, 720, 460, 28, "<b>wstrb: byte nào được ghi</b>", 16, "left")
a5.text(1000, 752, 940, 40, sm("wstrb có 1 bit cho mỗi byte của wdata. Ví dụ bus 32 bit, wstrb = 4'b0011: chỉ byte 1 và byte 0 được ghi.", 13), 13, "left", valign="top")
for k, nm in enumerate(["byte 3", "byte 2", "byte 1", "byte 0"]):
    on = k >= 2
    a5.box(1000 + k * 160, 810, 150, 70, f"<b>{nm}</b><br>{sm('wstrb = ' + ('1: ghi' if on else '0: bỏ qua'), 12)}", 14, extra="" if on else "dashed=1;")
a5.text(1000, 900, 940, 60, sm("Dùng khi ghi 1 byte (sb) hay 2 byte (sh): master đưa dữ liệu vào đúng làn byte rồi đặt wstrb tương ứng.", 13), 13, "left", valign="top")

# ====================================================================== TRANG 6: ID và thứ tự
a6 = Page("6. ID và thứ tự", 1900, 1000)
heading(a6, "ID và thứ tự trả lời",
        "ID cho biết response thuộc request nào. Khác ID thì slave được trả lẫn thứ tự, cùng ID thì phải giữ thứ tự.")


def seq(page, x0, title_, steps, note):
    page.text(x0, 90, 800, 28, f"<b>{title_}</b>", 16, "left")
    page.box(x0, 140, 160, 50, "<b>Master</b>", 16)
    page.box(x0 + 480, 140, 160, 50, "<b>Slave</b>", 16)
    page.edge([(x0 + 80, 190), (x0 + 80, 700)], 2, arrow=False, dashed=True)
    page.edge([(x0 + 560, 190), (x0 + 560, 700)], 2, arrow=False, dashed=True)
    for k, (fwd, lab) in enumerate(steps):
        yy = 250 + k * 100
        pts = [(x0 + 80, yy), (x0 + 560, yy)] if fwd else [(x0 + 560, yy), (x0 + 80, yy)]
        page.edge(pts, 3)
        page.label(x0 + 150, yy - 30, 340, 24, lab, 13)
    page.text(x0, 720, 640, 130, sm(note, 13), 13, "left", valign="top")
    page.text(x0 + 650, 190, 40, 24, sm("thời gian", 11), 11, "left")


seq(a6, 40, "Khác ID: được trả lẫn thứ tự", [
    (True, "AR  id = 1  (đọc vùng chậm)"), (True, "AR  id = 2  (đọc vùng nhanh)"),
    (False, "R  id = 2  (xong trước, trả trước)"), (False, "R  id = 1"),
], "Hợp lệ. Master nhìn vào ID của R để biết response nào ứng với request nào. Nhờ vậy slave nhanh không phải chờ slave chậm.")
seq(a6, 960, "Cùng ID: phải giữ thứ tự", [
    (True, "AR  id = 1  (A)"), (True, "AR  id = 1  (B)"),
    (False, "R  id = 1  (A, phải trả trước)"), (False, "R  id = 1  (B)"),
], "Bắt buộc. Các giao dịch cùng ID và cùng chiều (đọc với đọc, ghi với ghi) phải được trả đúng thứ tự phát.")
a6.text(40, 860, 1800, 120, sm(
    "<b>Thêm</b><br>"
    "Đọc và ghi độc lập: AXI4 không quy định thứ tự giữa một giao dịch đọc và một giao dịch ghi.<br>"
    "AXI4 không có WID: dữ liệu ghi của các burst không được xen kẽ nhau, nên beat W đi theo đúng thứ tự AW.<br>"
    "Trong QSOC: cầu của CPU luôn dùng ID 0 nên response về đúng thứ tự phát. S_BUS thêm 2 bit vào đầu ID (5 thành 7 bit) để biết response của master nào.", 13), 13, "left", valign="top")

xml = ('<mxfile host="app.diagrams.net">' + a1.xml() + a2.xml() + a3.xml() + a4.xml() + a5.xml() + a6.xml() + "</mxfile>")
out = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "axi4_co_ban.drawio"
out.write_text(xml, encoding="utf-8")
print(f"đã ghi {out}")
