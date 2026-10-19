"""Vẽ m_qnsc_wrap_bus (S_BUS + cầu AXI2APB, không có router P_BUS) bằng draw.io, 5 trang, chữ tiếng Việt:
  1 block diagram mức module, 2 bản đồ địa chỉ, 3 timing, 4 bên trong crossbar, 5 chi tiết tên net và độ rộng bus.
Ký hiệu theo QNSC_DRAWIO_LIB_V1.0 (nét 2 pt, mũi tên block, mux hình thang, mây COM).

Số liệu và tên đọc từ nguồn, không gõ tay:
  rtl/emacs/m_qnsc_wrap_bus.src.sv   tên instance, clock, ATOPs, danh sách chỉ số APB, tham số bridge
  rtl/qnsc_s_bus_pkg.sv              độ rộng ID, Cfg của axi_xbar
  util/qsoc_contract.yml             bản đồ bộ nhớ, ngoại vi APB, độ rộng địa chỉ

    python -X utf8 gen_s_bus_drawio.py [out.drawio]
"""
import math
import re
import sys
from pathlib import Path
from xml.sax.saxutils import quoteattr

import yaml

HERE = Path(__file__).resolve().parent
BLOCK = HERE.parent
REPO = BLOCK.parent.parent
src = (BLOCK / "rtl/emacs/m_qnsc_wrap_bus.src.sv").read_text(encoding="utf-8")
pkg = (BLOCK / "rtl/qnsc_s_bus_pkg.sv").read_text(encoding="utf-8")
contract = yaml.safe_load((REPO / "util/qsoc_contract.yml").read_text(encoding="utf-8"))


def need(pattern, text, what):
    m = re.search(pattern, text)
    if not m:
        raise SystemExit(f"không tìm thấy {what}")
    return m


for inst in ("u_axi_xbar", "u_axi_to_axi_lite", "u_axi_lite_to_apb"):
    need(rf"\b{inst}\b", src, inst)
SLV_ID = int(need(r"P_SLV_ID_W\s*=\s*(\d+);", pkg, "P_SLV_ID_W").group(1))
NO_SLV = int(need(r"P_NO_SLV_PORTS\s*=\s*(\d+);", pkg, "P_NO_SLV_PORTS").group(1))
NO_MST = int(need(r"P_NO_MST_PORTS\s*=\s*(\d+);", pkg, "P_NO_MST_PORTS").group(1))
ADD_BITS = math.ceil(math.log2(NO_SLV))
MST_ID = SLV_ID + ADD_BITS
cfg = dict(re.findall(r"c\.(\w+)\s*=\s*([^;]+?)\s*;", pkg))
for k in ("MaxMstTrans", "MaxSlvTrans", "FallThrough", "LatencyMode", "UniqueIds", "AxiIdUsedSlvPorts"):
    if k not in cfg:
        raise SystemExit(f"không tìm thấy Cfg.{k}")
LATENCY = cfg["LatencyMode"].split("::")[-1]
ATOPS = need(r"\.ATOPs\s*\(([^)]*)\)", src, "ATOPs").group(1).strip()
CLK_S = need(r"\.clk_i\s*\((i_clk_sbus)\)", src, "clock xbar").group(1)
RST_S = need(r"\.rst_ni\s*\((i_rst_n_sbus)\)", src, "reset xbar").group(1)
CLK_P = need(r"\.clk_i\s*\((i_clk_pbus)\)", src, "clock bridge").group(1)
RST_P = need(r"\.rst_ni\s*\((i_rst_n_pbus)\)", src, "reset bridge").group(1)
BR_WR = need(r"\.AxiMaxWriteTxns\s*\((\d+)\)", src, "AxiMaxWriteTxns").group(1)
BR_RD = need(r"\.AxiMaxReadTxns\s*\((\d+)\)", src, "AxiMaxReadTxns").group(1)
meta = contract["meta"]
PBUS_W, APB_W = meta["pbus_paddr_width"], meta["apb_paddr_width"]
APB_BASE, APB_SIZE = meta["apb_window_base"], meta["apb_window_size"]

apb = [(e["name"], int(str(e["port"]).split("APB_M")[1]), e["base"], e["size"])
       for e in contract["memory_map"] if str(e["port"]).startswith("APB_M")]
for port in ("o_bus_apb_m_0_paddr", "o_bus_apb_m_0_pwdata", "i_bus_apb_m_0_prdata"):
    need(rf"\b{port}\b", src, port)
APB_SLOT = apb[0][3]

axi_rows = sorted((e for e in contract["memory_map"] if str(e["port"]).startswith("AXI_M")), key=lambda e: e["base"])
rules = []
for e in axi_rows:
    if rules and rules[-1]["port"] == e["port"] and rules[-1]["end"] == e["base"]:
        rules[-1]["end"] = e["base"] + e["size"]
        rules[-1]["names"].append(e["name"])
    else:
        rules.append({"port": e["port"], "base": e["base"], "end": e["base"] + e["size"], "names": [e["name"]]})
rules.append({"port": "AXI_M3", "base": APB_BASE, "end": APB_BASE + APB_SIZE, "names": ["apb"]})
rules.sort(key=lambda r: r["base"])
PORT_NAME = {"rom": "ROM", "isram": "ISRAM", "isram_dbg": "ISRAM", "dsram": "DSRAM", "apb": "Ngoại vi APB"}


def rname(r):
    return " + ".join(dict.fromkeys(PORT_NAME.get(x, x) for x in r["names"]))


def cv(v):
    v = v.split('::')[-1]
    if v.startswith("1'b"):
        v = v[3:]
    return str(SLV_ID) if v == 'P_SLV_ID_W' else v


def h(v):
    if v >= 1 << 32:
        return "0x1_0000_0000"
    return f"0x{v >> 16:04X}_{v & 0xFFFF:04X}"


def h18(v):
    return f"0x{v >> 16:X}_{v & 0xFFFF:04X}"


def kib(v):
    return f"{v // 1024} KiB" if v % 1024 == 0 else f"{v} B"


# ---------------------------------------------------------------- ví dụ cho trang 2, tính từ contract
syscsr = next(a for a in apb if a[0] == "syscsr")
SYS_ADDR, SYS_OFF, SYS_IDX = syscsr[2], syscsr[2] - APB_BASE, syscsr[1]
SYS_END_OFF = SYS_OFF + syscsr[3] - 1
dsram_end = next(r["end"] for r in rules if r["port"] == "AXI_M2")
BAD_ADDR = 0x40000000
assert dsram_end <= BAD_ADDR < APB_BASE, "địa chỉ ví dụ phải nằm ngoài mọi rule"
last_apb_end = max(a[2] + a[3] for a in apb)
HEAD_ADDR = last_apb_end
assert HEAD_ADDR < APB_BASE + APB_SIZE, "cửa sổ APB không còn chỗ trống"
HEAD_OFF = HEAD_ADDR - APB_BASE

# ---------------------------------------------------------------- độ rộng các bundle, tính từ axi_pkg / typedef.svh
axi_pkg_txt = (REPO / "vendor/pulp-platform/axi/src/axi_pkg.sv").read_text(encoding="utf-8")
typedef_txt = (REPO / "vendor/pulp-platform/axi/include/axi/typedef.svh").read_text(encoding="utf-8")


def pkg_w(name):
    m = re.search(rf"typedef logic \[(\d+):0\]\s+{name};", axi_pkg_txt)
    if not m:
        raise SystemExit(f"{name} không có trong axi_pkg")
    return int(m.group(1)) + 1


LEN, SIZE, BURST, CACHE, PROT, QOS, REGION, ATOP, RESP = (
    pkg_w(n) for n in ("len_t", "size_t", "burst_t", "cache_t", "prot_t", "qos_t", "region_t", "atop_t", "resp_t"))
ADDR, DATA = contract["meta"]["addr_width"], contract["meta"]["data_width"]
STRB = DATA // 8
USER = int(need(r"P_AXI_USER_W\s*=\s*(\d+);", pkg, "P_AXI_USER_W").group(1))
for tok in ("AXI_LITE_TYPEDEF_AW_CHAN_T", "AXI_LITE_TYPEDEF_W_CHAN_T", "AXI_LITE_TYPEDEF_R_CHAN_T"):
    need(tok, typedef_txt, tok)


def axi_w(idw):
    aw = idw + ADDR + LEN + SIZE + BURST + 1 + CACHE + PROT + QOS + REGION + ATOP + USER
    w = DATA + STRB + 1 + USER
    ar = idw + ADDR + LEN + SIZE + BURST + 1 + CACHE + PROT + QOS + REGION + USER
    b = idw + RESP + USER
    r = idw + DATA + RESP + 1 + USER
    return dict(aw=aw, w=w, ar=ar, b=b, r=r, req=aw + 1 + w + 1 + 1 + ar + 1 + 1, rsp=1 + 1 + 1 + 1 + b + 1 + r)


SW, MW = axi_w(SLV_ID), axi_w(MST_ID)
LITE_REQ = (ADDR + PROT) + 1 + (DATA + STRB) + 1 + 1 + (ADDR + PROT) + 1 + 1   # aw, w, b_ready, ar, r_ready
LITE_RSP = 1 + 1 + 1 + 1 + RESP + 1 + (DATA + RESP)                              # ready x3, b, r
for fld in ("paddr", "pprot", "psel", "penable", "pwrite", "pwdata", "pstrb", "pready", "prdata", "pslverr"):
    need(rf"\b{fld}\b", pkg, f"apb.{fld}")
APB_REQ = ADDR + PROT + 1 + 1 + 1 + DATA + STRB
APB_RSP = 1 + DATA + 1
RULE_BITS = 32 + ADDR + ADDR

# ---------------------------------------------------------------- ký hiệu (QNSC_DRAWIO_LIB_V1.0: nét 2 pt, chữ 18, block arrow)
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


MASTERS = [("SYSDBG", "AXI_S0"), ("CPU", "AXI_S1"), ("DMA", "AXI_S2")]
SLAVES = [("ROM", "AXI_M0"), ("ISRAM", "AXI_M1"), ("DSRAM", "AXI_M2")]
assert len(MASTERS) == NO_SLV and len(SLAVES) == NO_MST - 1
APB_N = len(apb)

# ====================================================================== TRANG 1: block diagram
p1 = Page("5. Chi tiết: tên net, độ rộng bus", 2620, 1290)
heading(p1, "m_qnsc_wrap_bus: block diagram chi tiết (tên net, độ rộng bus)",
        "Xem bảng chú giải ký hiệu ở góc dưới bên trái. Số bit tính từ typedef của axi_pkg.")
BX0, BX1 = 330, 2200
EXT_X = 2400
p1.vertex(BX0, 100, BX1 - BX0, 1130, "", "rounded=0;fillColor=none;strokeWidth=3;")
p1.text(BX0 + 10, 104, 500, 26, "<b>m_qnsc_wrap_bus</b>", 17, "left")
CY = [270, 450, 630]

for i, (name, port) in enumerate(MASTERS):
    p1.box(20, CY[i] - 45, 150, 90, f"<b>{name}</b><br>{sm(port, 13)}", 16)
    p1.bus([(170, CY[i] - 22), (380, CY[i] - 22)], None)
    p1.bus([(380, CY[i] + 22), (170, CY[i] + 22)], None)
    p1.text(176, CY[i] - 66, 150, 36, sm(f"i_bus_axi_s_{i}_*<br>AW {SW['aw']} · W {SW['w']} · AR {SW['ar']}", 11), 11)
    p1.text(176, CY[i] + 28, 150, 36, sm(f"o_bus_axi_s_{i}_*<br>B {SW['b']} · R {SW['r']}", 11), 11)
    p1.vertex(BX0 - 7, CY[i] - 29, 14, 14, "", S_TRI + "strokeWidth=1.5;", rotation=90)
    p1.vertex(BX0 - 7, CY[i] + 15, 14, 14, "", S_TRI + "strokeWidth=1.5;", rotation=-90)
    p1.box(380, CY[i] - 40, 140, 80, f"assign<br>{sm('flat đến struct', 12)}", 14)
    p1.bus([(520, CY[i] - 22), (640, CY[i] - 22)], f"{SW['req']}", f"w_slv_reqs[{i}]")
    p1.bus([(640, CY[i] + 22), (520, CY[i] + 22)], f"{SW['rsp']}", f"w_slv_resps[{i}]", "below")

# u_axi_xbar
XB = (640, 190, 480, 600)
p1.box(*XB, "", 16)
p1.text(XB[0] + 10, XB[1] + 6, 300, 26, f"<b>u_axi_xbar</b> : axi_xbar", 18, "left")
params = [f"Cfg {NO_SLV} slv × {NO_MST} mst · ID {SLV_ID} → {MST_ID}",
          f"LatencyMode {LATENCY} · MaxTrans {cv(cfg['MaxMstTrans'])}/{cv(cfg['MaxSlvTrans'])}",
          f"Connectivity full · ATOPs {cv(ATOPS)} · UniqueIds {cv(cfg['UniqueIds'])}"]
p1.text(XB[0] + 60, XB[1] + 110, XB[2] - 120, 66, sm("<br>".join(params), 12), 12, "center", valign="top")
for i in range(NO_SLV):
    p1.text(XB[0] + 8, CY[i] - 38, 230, 18, sm(f"▶ slv_ports_req_i[{i}]", 11), 11, "left")
    p1.text(XB[0] + 8, CY[i] + 6, 230, 18, sm(f"◀ slv_ports_resp_o[{i}]", 11), 11, "left")
for j in range(NO_MST - 1):
    p1.text(XB[0] + XB[2] - 238, CY[j] - 38, 230, 18, sm(f"mst_ports_req_o[{j}] ▶", 11), 11, "right")
    p1.text(XB[0] + XB[2] - 238, CY[j] + 6, 230, 18, sm(f"mst_ports_resp_i[{j}] ◀", 11), 11, "right")
# M3: pin ở mép phải, phía dưới các hàng khác
M3Y = 730
p1.text(XB[0] + XB[2] - 238, M3Y - 20, 230, 18, sm(f"mst_ports_req_o[{NO_MST - 1}] ▶", 11), 11, "right")
p1.text(XB[0] + XB[2] - 238, M3Y + 24, 230, 18, sm(f"mst_ports_resp_i[{NO_MST - 1}] ◀", 11), 11, "right")
# clock/reset pin ở mép trên bên phải
CKX, RSX = XB[0] + 330, XB[0] + 410
p1.text(CKX - 24, XB[1] + 20, 70, 18, sm("clk_i", 11), 11, "center")
p1.clk_tri(CKX - 6, XB[1] + 1)
p1.text(RSX - 30, XB[1] + 20, 70, 18, sm("rst_ni", 11), 11, "center")
p1.edge([(CKX, 100), (CKX, XB[1])], 2)
p1.edge([(RSX, 100), (RSX, XB[1])], 2)
p1.text(CKX + 8, 112, 110, 20, sm(CLK_S, 12), 12, "left")
p1.text(RSX + 8, 112, 110, 20, sm(RST_S, 12), 12, "left")
# pin cấu hình ở đáy và các hằng nối vào
tie_y = XB[1] + XB[3]
ties = [("addr_map_i", f"P_ADDR_MAP<br>{len(rules)} rule × {RULE_BITS}b"),
        ("en_default_mst_port_i", f"'0 [{NO_SLV - 1}:0]"),
        ("default_mst_port_i", f"'0 [{NO_SLV * max(1, math.ceil(math.log2(NO_MST))) - 1}:0]")]
for k, (pn, tie) in enumerate(ties):
    px = XB[0] + 50 + k * 140
    p1.text(px - 50, tie_y - 22, 130, 18, sm(pn, 10), 10, "center")
    p1.edge([(px + 15, tie_y + 44), (px + 15, tie_y)], 2)
    p1.text(px - 40, tie_y + 46, 110, 40, sm(tie, 11), 11)

# glue ra + slave ngoài
GX = 1180
for j, (name, port) in enumerate(SLAVES):
    p1.bus([(XB[0] + XB[2], CY[j] - 22), (GX, CY[j] - 22)], f"{MW['req']}", f"w_mst_reqs[{j}]")
    p1.bus([(GX, CY[j] + 22), (XB[0] + XB[2], CY[j] + 22)], f"{MW['rsp']}", f"w_mst_resps[{j}]", "below")
    p1.box(GX, CY[j] - 40, 140, 80, f"assign<br>{sm('struct đến flat', 12)}", 14)
    p1.bus([(GX + 140, CY[j] - 22), (EXT_X, CY[j] - 22)], None)
    p1.bus([(EXT_X, CY[j] + 22), (GX + 140, CY[j] + 22)], None)
    p1.text(1560, CY[j] - 66, 330, 40, sm(f"o_bus_axi_m_{j}_*<br>AW {MW['aw']} · W {MW['w']} · AR {MW['ar']}", 11), 11)
    p1.text(1560, CY[j] + 28, 330, 40, sm(f"i_bus_axi_m_{j}_*<br>B {MW['b']} · R {MW['r']}", 11), 11)
    p1.vertex(BX1 - 7, CY[j] - 29, 14, 14, "", S_TRI + "strokeWidth=1.5;", rotation=-90)
    p1.vertex(BX1 - 7, CY[j] + 15, 14, 14, "", S_TRI + "strokeWidth=1.5;", rotation=90)
    p1.box(EXT_X, CY[j] - 45, 160, 90, f"<b>{name}</b><br>{sm(port + ' · ID ' + str(MST_ID), 13)}", 16)

# miền sbus
p1.region(360, 150, 1000, 735, f"miền sbus: {CLK_S}, {RST_S}")

# chuỗi AXI2APB
CH_Y = 940
B1 = (1000, CH_Y, 260, 160)
B2 = (1400, CH_Y, 260, 160)
AS = (1760, CH_Y + 20, 90, 120)
RT = (1930, CH_Y - 20, 250, 200)
p1.box(*B1, "", 16)
p1.text(B1[0] + 8, B1[1] + 4, B1[2] - 16, 24, "<b>u_axi_to_axi_lite</b>", 15, "left")
p1.text(B1[0] + 8, B1[1] + 28, B1[2] - 16, 20, sm("axi_to_axi_lite", 12), 12, "left")
p1.text(B1[0] + 8, B1[1] + 52, B1[2] - 16, 70, sm("AXI4 đến AXI4-Lite<br>axi_atop_filter + axi_burst_splitter<br>" + f"AxiMaxWriteTxns {BR_WR} · AxiMaxReadTxns {BR_RD}", 11), 11, "left", valign="top")
p1.box(*B2, "", 16)
p1.text(B2[0] + 8, B2[1] + 4, B2[2] - 16, 24, "<b>u_axi_lite_to_apb</b>", 15, "left")
p1.text(B2[0] + 8, B2[1] + 28, B2[2] - 16, 20, sm("axi_lite_to_apb", 12), 12, "left")
p1.text(B2[0] + 8, B2[1] + 52, B2[2] - 16, 70, sm("AXI4-Lite đến APB4<br>NoApbSlaves 1 · NoRules 1<br>PipelineRequest/Response 0", 11), 11, "left", valign="top")
# M3: từ pin mép phải của xbar đi xuống bridge 1
x_req, x_rsp = 1160, 1230
p1.edge([(XB[0] + XB[2], M3Y), (x_req, M3Y), (x_req, CH_Y)], 4)
p1.edge([(x_rsp, CH_Y), (x_rsp, M3Y + 44), (XB[0] + XB[2], M3Y + 44)], 4)
p1.edge([(x_req - 9, 820 + 6), (x_req + 9, 820 - 6)], 2, arrow=False)
p1.text(x_req - 150, 800, 140, 18, sm(f"{MW['req']}", 12), 12, "right")
p1.label(x_req - 190, 826, 180, 20, "<i>w_mst_reqs[3]</i>", 12)
p1.edge([(x_rsp - 9, 820 + 6), (x_rsp + 9, 820 - 6)], 2, arrow=False)
p1.text(x_rsp + 12, 800, 60, 18, sm(f"{MW['rsp']}", 12), 12, "left")
p1.label(x_rsp + 12, 826, 180, 20, "<i>w_mst_resps[3]</i>", 12)
p1.bus([(B1[0] + B1[2], CH_Y + 60), (B2[0], CH_Y + 60)], f"{LITE_REQ}", "w_axi2apb_lite_req")
p1.bus([(B2[0], CH_Y + 110), (B1[0] + B1[2], CH_Y + 110)], f"{LITE_RSP}", "w_axi2apb_lite_resp", "below")
p1.box(*AS, f"assign<br>{sm(f'paddr[{PBUS_W - 1}:0]<br>struct → port', 11)}", 13)
p1.bus([(B2[0] + B2[2], CH_Y + 60), (AS[0], CH_Y + 60)], f"{APB_REQ}", "w_apb_req[0]")
p1.bus([(AS[0], CH_Y + 110), (B2[0] + B2[2], CH_Y + 110)], f"{APB_RSP}", "w_apb_resp[0]", "below")
p1.bus([(AS[0] + AS[2], CH_Y + 60), (EXT_X, CH_Y + 60)], None)
p1.bus([(EXT_X, CH_Y + 110), (AS[0] + AS[2], CH_Y + 110)], None)
p1.text(BX1 + 6, CH_Y - 46, 190, 90, sm(f"o_bus_apb_m_0_*<br>paddr[{PBUS_W - 1}:0] pwdata[{DATA - 1}:0]<br>pstrb[{STRB - 1}:0] psel penable pwrite", 10), 10)
p1.text(BX1 + 6, CH_Y + 122, 190, 50, sm(f"i_bus_apb_m_0_*<br>pready pslverr prdata[{DATA - 1}:0]", 10), 10)
p1.vertex(BX1 - 7, CH_Y + 53, 14, 14, "", S_TRI + "strokeWidth=1.5;", rotation=-90)
p1.vertex(BX1 - 7, CH_Y + 103, 14, 14, "", S_TRI + "strokeWidth=1.5;", rotation=90)
p1.box(EXT_X, CH_Y - 40, 160, 250, f"<b>P_BUS</b><br>{sm('phía sau cổng APB<br>ngoài wrapper', 11)}", 14)

# miền pbus
p1.region(980, 900, 710, 250, f"miền pbus: {CLK_P}, {RST_P}")
for bx in (B1, B2):
    p1.text(bx[0] + 40, bx[1] + bx[3] + 4, 90, 16, sm("clk_i", 11), 11)
    p1.text(bx[0] + 140, bx[1] + bx[3] + 4, 70, 16, sm("rst_ni", 11), 11)
    p1.clk_tri(bx[0] + 75, bx[1] + bx[3] - 14)
yb = CH_Y + 200
p1.edge([(B1[0] + 85, B1[1] + B1[3]), (B1[0] + 85, yb), (B2[0] + 85, yb), (B2[0] + 85, B2[1] + B2[3])], 2, arrow=False)
p1.edge([(B1[0] + 175, B1[1] + B1[3]), (B1[0] + 175, yb + 22), (B2[0] + 175, yb + 22), (B2[0] + 175, B2[1] + B2[3])], 2, arrow=False)
p1.edge([(B1[0] + 85, yb), (B1[0] + 85, 1240)], 2)
p1.edge([(B1[0] + 175, yb + 22), (B1[0] + 175, 1240)], 2)
p1.text(B1[0] + 20, 1244, 130, 20, sm(CLK_P, 12), 12, "center")
p1.text(B1[0] + 110, 1244, 130, 20, sm(RST_P, 12), 12, "center")
for (px, py) in ((B1[0] + 85, yb), (B2[0] + 85, yb), (B1[0] + 175, yb + 22), (B2[0] + 175, yb + 22)):
    p1.dot(px, py, 5)

p1.text(380, 900, 560, 300,
        sm("<b>Ghi chú</b><br>sbus và pbus cùng 20 MHz, luôn bật (SCRC), nên giữa hai miền không có mạch CDC.<br><br>"
           "Cổng AXI ở biên là cổng phẳng (không struct). Hai khối assign ghép và tách tín hiệu với struct bên trong.<br><br>"
           "emacs sinh: cổng clock/reset và chân của 3 instance. Cổng APB viết tay trong .src.sv.", 12), 12, "left", valign="top")


# ---- chú giải ký hiệu
LX, LY = 20, 700
p1.box(LX, LY, 290, 440, "", 12)
p1.text(LX + 10, LY + 6, 270, 26, "<b>Chú giải ký hiệu</b>", 16, "left")
STEP = 66
y0 = LY + 44
# 1. bus
p1.edge([(LX + 14, y0 + 26), (LX + 84, y0 + 26)], 4)
p1.edge([(LX + 43, y0 + 35), (LX + 55, y0 + 17)], 2, arrow=False)
p1.text(LX + 52, y0 - 2, 40, 18, sm("54", 12), 12, "left")
p1.text(LX + 100, y0 + 2, 185, 52, sm("Bus nhiều bit. Số cạnh gạch chéo là số bit của bus (ví dụ 54 bit).", 12), 12, "left")
y0 += STEP
# 2. cổng
p1.vertex(LX + 42, y0 + 16, 16, 16, "", S_TRI + "strokeWidth=1.5;", rotation=90)
p1.text(LX + 100, y0 + 2, 185, 52, sm("Tam giác trắng ở viền khung: cổng của module. Mũi tam giác chỉ chiều vào hoặc ra.", 12), 12, "left")
y0 += STEP
# 3. clock
p1.box(LX + 24, y0 + 6, 56, 40, "", 10)
p1.clk_tri(LX + 46, y0 + 34)
p1.text(LX + 100, y0 + 2, 185, 52, sm("Tam giác nhỏ ở cạnh khối: chân clock (clk_i). Đường nối vào đó là dây clock.", 12), 12, "left")
y0 += STEP
# 4. các kênh
p1.text(LX + 14, y0 + 8, 80, 36, sm("AW 73<br>W 38", 12), 12, "center")
p1.text(LX + 100, y0 + 2, 185, 52, sm("AW, W, AR, B, R là 5 kênh của AXI4. Số bên cạnh là số bit của kênh đó.", 12), 12, "left")
y0 += STEP
# 5. miền
p1.vertex(LX + 22, y0 + 8, 60, 38, "", "rounded=0;fillColor=none;strokeWidth=2;dashed=1;dashPattern=10 6;")
p1.text(LX + 100, y0 + 2, 185, 52, sm("Khung nét đứt: một miền clock và reset.", 12), 12, "left")
y0 += STEP
# 6. net
p1.text(LX + 14, y0 + 12, 80, 28, sm("<i>w_slv_reqs</i>", 12), 12, "center")
p1.text(LX + 100, y0 + 2, 185, 52, sm("Chữ nghiêng: tên dây bên trong module.", 12), 12, "left")

# ====================================================================== TRANG 2: micro-architecture của crossbar
p2 = Page("4. Bên trong crossbar", 2300, 1400)
heading(p2, "axi_xbar: micro-architecture của một cổng vào (demux) và một cổng ra (mux)",
        f"Thanh ghi nét liền: có thật với LatencyMode = {LATENCY}. Nét đứt: bypass, đi thẳng. Mỗi cổng vào có một demux, mỗi cổng ra có một mux.")

# --- DEMUX
p2.region(20, 90, 1100, 640, "axi_demux  (một cái cho mỗi cổng vào, gen_slv_port_demux[i])")
LANES = {"AW": 190, "W": 290, "B": 400, "AR": 520, "R": 640}
for nm, yy in LANES.items():
    p2.text(34, yy - 14, 40, 28, f"<b>{nm}</b>", 16, "left")
# AW
p2.edge([(80, LANES["AW"]), (150, LANES["AW"])], 2)
p2.reg(150, LANES["AW"] - 22, 90, 44, "i_aw_<br>spill_reg")
p2.edge([(240, LANES["AW"]), (290, LANES["AW"])], 2)
p2.vertex(290, LANES["AW"] - 36, 130, 72, "cc_addr_decode<br>" + sm("addr_map_i", 10), S_CLOUD + "fontSize=12;")
p2.edge([(420, LANES["AW"]), (460, LANES["AW"])], 2)
p2.text(470, LANES["AW"] - 46, 80, 18, sm("select", 11), 11)
p2.reg(460, LANES["AW"] - 22, 100, 44, "i_aw_select_<br>spill_reg")
p2.edge([(560, LANES["AW"]), (610, LANES["AW"])], 2)
p2.box(610, LANES["AW"] - 48, 210, 96, f"<b>Kiểm thứ tự</b><br>{sm('i_aw_id_counter: tra ID, đếm giao dịch mở<br>i_counter_open_w + w_select: chặn AW sang cổng ra khác khi còn W đang mở', 10)}", 12)
p2.edge([(820, LANES["AW"]), (880, LANES["AW"])], 2)
p2.demux_v(895, LANES["AW"], 40, 90)
for k in range(NO_MST + 1):
    yk = LANES["AW"] - 36 + k * 18
    p2.edge([(912, yk), (1000, yk)], 2)
p2.text(1004, LANES["AW"] - 46, 110, 100, sm(f"mst_reqs_o[0..{NO_MST - 1}].aw<br>và cổng lỗi<br>({NO_MST + 1} đầu ra)", 11), 11, "left")
# W
p2.edge([(80, LANES["W"]), (150, LANES["W"])], 2)
p2.reg(150, LANES["W"] - 22, 90, 44, "i_w_<br>spill_reg", active=False)
p2.edge([(240, LANES["W"]), (880, LANES["W"])], 2)
p2.demux_v(895, LANES["W"], 40, 70)
p2.text(300, LANES["W"] - 40, 520, 22, sm("W đi theo w_select (đã chốt lúc AW được nhận): dữ liệu W cùng cổng ra với AW", 11), 11, "left")
p2.edge([(912, LANES["W"]), (1000, LANES["W"])], 2)
p2.text(1004, LANES["W"] - 14, 110, 28, sm("mst_reqs_o[k].w", 11), 11, "left")
# B (về)
p2.edge([(1000, LANES["B"]), (930, LANES["B"])], 2)
p2.text(1004, LANES["B"] - 14, 110, 28, sm("mst_resps_i[k].b", 11), 11, "left")
p2.mux_v(915, LANES["B"], 40, 70)
p2.edge([(895, LANES["B"]), (820, LANES["B"])], 2)
p2.box(610, LANES["B"] - 30, 210, 60, f"<b>i_b_mux</b><br>{sm('cc_rr_arb_tree: chọn B từ các cổng ra', 10)}", 12)
p2.edge([(610, LANES["B"]), (240, LANES["B"])], 2)
p2.reg(150, LANES["B"] - 22, 90, 44, "i_b_<br>spill_reg", active=False)
p2.edge([(150, LANES["B"]), (80, LANES["B"])], 2)
# AR
p2.edge([(80, LANES["AR"]), (150, LANES["AR"])], 2)
p2.reg(150, LANES["AR"] - 22, 90, 44, "i_ar_<br>spill_reg")
p2.edge([(240, LANES["AR"]), (290, LANES["AR"])], 2)
p2.vertex(290, LANES["AR"] - 36, 130, 72, "cc_addr_decode<br>" + sm("addr_map_i", 10), S_CLOUD + "fontSize=12;")
p2.edge([(420, LANES["AR"]), (460, LANES["AR"])], 2)
p2.reg(460, LANES["AR"] - 22, 100, 44, "i_ar_sel_<br>spill_reg")
p2.edge([(560, LANES["AR"]), (610, LANES["AR"])], 2)
p2.box(610, LANES["AR"] - 36, 210, 72, f"<b>Kiểm thứ tự</b><br>{sm('i_ar_id_counter: tra ID, đếm giao dịch mở', 10)}", 12)
p2.edge([(820, LANES["AR"]), (880, LANES["AR"])], 2)
p2.demux_v(895, LANES["AR"], 40, 90)
for k in range(NO_MST + 1):
    yk = LANES["AR"] - 36 + k * 18
    p2.edge([(912, yk), (1000, yk)], 2)
p2.text(1004, LANES["AR"] - 40, 110, 80, sm(f"mst_reqs_o[0..{NO_MST - 1}].ar<br>và cổng lỗi", 11), 11, "left")
# R (về)
p2.edge([(1000, LANES["R"]), (930, LANES["R"])], 2)
p2.text(1004, LANES["R"] - 14, 110, 28, sm("mst_resps_i[k].r", 11), 11, "left")
p2.mux_v(915, LANES["R"], 40, 70)
p2.edge([(895, LANES["R"]), (820, LANES["R"])], 2)
p2.box(610, LANES["R"] - 30, 210, 60, f"<b>i_r_mux</b><br>{sm('cc_rr_arb_tree: chọn R từ các cổng ra', 10)}", 12)
p2.edge([(610, LANES["R"]), (240, LANES["R"])], 2)
p2.reg(150, LANES["R"] - 22, 90, 44, "i_r_<br>spill_reg", active=False)
p2.edge([(150, LANES["R"]), (80, LANES["R"])], 2)

# --- MUX
p2.region(1160, 90, 1120, 640, "axi_mux  (một cái cho mỗi cổng ra, gen_mst_port_mux[j])")
ML = {"AW": 190, "W": 290, "B": 400, "AR": 520, "R": 640}
for nm, yy in ML.items():
    p2.text(1174, yy - 14, 40, 28, f"<b>{nm}</b>", 16, "left")
# AW: vào từ các cổng vào
p2.text(1210, ML["AW"] - 62, 190, 18, sm(f"slv_reqs_i[0..{NO_SLV - 1}].aw", 11), 11, "left")
for k in range(NO_SLV):
    yk = ML["AW"] - 24 + k * 24
    p2.edge([(1220, yk), (1270, yk)], 2)
p2.box(1270, ML["AW"] - 40, 130, 80, f"<b>i_id_prepend</b><br>{sm(f'×{NO_SLV}: thêm chỉ số cổng vào ({ADD_BITS} bit) vào đầu ID', 10)}", 12)
p2.edge([(1400, ML["AW"]), (1450, ML["AW"])], 2)
p2.box(1450, ML["AW"] - 40, 150, 80, f"<b>i_aw_arbiter</b><br>{sm(f'cc_rr_arb_tree {NO_SLV} đến 1, round-robin', 10)}", 12)
p2.edge([(1600, ML["AW"]), (1660, ML["AW"])], 2)
p2.reg(1660, ML["AW"] - 22, 90, 44, "i_aw_<br>spill_reg")
p2.edge([(1750, ML["AW"]), (1830, ML["AW"])], 2)
p2.text(1834, ML["AW"] - 22, 220, 44, sm("mst_req_o.aw<br>ID mở rộng thành " + str(MST_ID) + " bit", 11), 11, "left")
# W: FIFO nhớ chỉ số
p2.box(1450, ML["W"] - 50, 150, 44, f"<b>i_w_fifo</b><br>{sm('cc_fifo: chỉ số theo thứ tự AW', 10)}", 12)
p2.edge([(1525, ML["AW"] + 40), (1525, ML["W"] - 50)], 2)
for k in range(NO_SLV):
    yk = ML["W"] - 24 + k * 24
    p2.edge([(1220, yk), (1384, yk)], 2)
p2.text(1210, ML["W"] - 52, 160, 20, sm(f"slv_reqs_i[0..{NO_SLV - 1}].w", 11), 11, "left")
p2.mux_v(1400, ML["W"], 60, 80)
p2.edge([(1420, ML["W"]), (1660, ML["W"])], 2)
p2.edge([(1450, ML["W"] - 28), (1400, ML["W"] - 28), (1400, ML["W"] - 22)], 2)
p2.reg(1660, ML["W"] - 22, 90, 44, "i_w_<br>spill_reg", active=False)
p2.edge([(1750, ML["W"]), (1830, ML["W"])], 2)
p2.text(1834, ML["W"] - 14, 220, 28, sm("mst_req_o.w", 11), 11, "left")
# B (về)
p2.edge([(1830, ML["B"]), (1750, ML["B"])], 2)
p2.text(1834, ML["B"] - 14, 220, 28, sm("mst_resp_i.b", 11), 11, "left")
p2.reg(1660, ML["B"] - 22, 90, 44, "i_b_<br>spill_reg", active=False)
p2.edge([(1660, ML["B"]), (1600, ML["B"])], 2)
p2.box(1400, ML["B"] - 36, 200, 72, f"<b>Chọn cổng vào</b><br>{sm(f'theo {ADD_BITS} bit đầu của b.id, rồi bỏ {ADD_BITS} bit', 10)}", 12)
for k in range(NO_SLV):
    yk = ML["B"] - 24 + k * 24
    p2.edge([(1400, yk), (1220, yk)], 2)
p2.text(1210, ML["B"] - 54, 170, 20, sm(f"slv_resps_o[0..{NO_SLV - 1}].b", 11), 11, "left")
# AR
p2.text(1210, ML["AR"] - 62, 190, 18, sm(f"slv_reqs_i[0..{NO_SLV - 1}].ar", 11), 11, "left")
for k in range(NO_SLV):
    yk = ML["AR"] - 24 + k * 24
    p2.edge([(1220, yk), (1270, yk)], 2)
p2.box(1270, ML["AR"] - 40, 130, 80, f"<b>i_id_prepend</b><br>{sm(f'×{NO_SLV}: thêm chỉ số cổng vào', 10)}", 12)
p2.edge([(1400, ML["AR"]), (1450, ML["AR"])], 2)
p2.box(1450, ML["AR"] - 40, 150, 80, f"<b>i_ar_arbiter</b><br>{sm(f'cc_rr_arb_tree {NO_SLV} đến 1, round-robin', 10)}", 12)
p2.edge([(1600, ML["AR"]), (1660, ML["AR"])], 2)
p2.reg(1660, ML["AR"] - 22, 90, 44, "i_ar_<br>spill_reg")
p2.edge([(1750, ML["AR"]), (1830, ML["AR"])], 2)
p2.text(1834, ML["AR"] - 22, 220, 44, sm("mst_req_o.ar", 11), 11, "left")
# R (về)
p2.edge([(1830, ML["R"]), (1750, ML["R"])], 2)
p2.text(1834, ML["R"] - 14, 220, 28, sm("mst_resp_i.r", 11), 11, "left")
p2.reg(1660, ML["R"] - 22, 90, 44, "i_r_<br>spill_reg", active=False)
p2.edge([(1660, ML["R"]), (1600, ML["R"])], 2)
p2.box(1400, ML["R"] - 36, 200, 72, f"<b>Chọn cổng vào</b><br>{sm(f'theo {ADD_BITS} bit đầu của r.id, rồi bỏ {ADD_BITS} bit', 10)}", 12)
for k in range(NO_SLV):
    yk = ML["R"] - 24 + k * 24
    p2.edge([(1400, yk), (1220, yk)], 2)
p2.text(1210, ML["R"] - 54, 170, 20, sm(f"slv_resps_o[0..{NO_SLV - 1}].r", 11), 11, "left")

# --- tổng hợp: nối chéo
p2.region(20, 760, 2260, 610, "Nối giữa các demux và mux (lưới 3 x 4) và độ trễ")
GR = [880, 1010, 1140]
GC = [900 + 210 * j for j in range(NO_MST)]
for i in range(NO_SLV):
    p2.box(40, GR[i] - 34, 190, 68, f"<b>demux {i}</b><br>{sm(MASTERS[i][0] + ' · ' + MASTERS[i][1], 12)}", 14)
    p2.edge([(230, GR[i]), (GC[-1] + 30, GR[i])], 2, arrow=False)
    for c in GC:
        p2.dot(c, GR[i])
for j, c in enumerate(GC):
    p2.edge([(c, GR[0]), (c, 1260)], 2)
    p2.box(c - 80, 1260, 160, 60, f"<b>mux {j}</b><br>{sm((SLAVES[j][0] if j < NO_MST - 1 else 'AXI2APB') + ' · ' + ('AXI_M' + str(j)), 12)}", 14)
p2.text(1760, 820, 500, 300,
        sm(f"<b>Độ trễ của yêu cầu</b><br>AW và AR qua hai thanh ghi nối tiếp: spill ở demux, rồi spill ở mux. Địa chỉ ra khỏi S_BUS trễ 2 chu kỳ so với lúc vào (CUT_ALL_AX).<br>"
           f"W, B, R không có thanh ghi cắt nên đi tổ hợp.<br><br>"
           f"Mỗi demux còn một đầu ra tới responder lỗi (DECERR, đọc ra 0xBADCAB1E) cho địa chỉ không khớp rule.<br><br><b>Giới hạn</b><br>mỗi cổng vào tối đa {cv(cfg['MaxMstTrans'])} giao dịch mở (MaxMstTrans),<br>mỗi cổng ra {cv(cfg['MaxSlvTrans'])} giao dịch ghi mở (MaxSlvTrans, độ sâu i_w_fifo).<br>"
           f"Tra ID bằng {cv(cfg['AxiIdUsedSlvPorts'])} bit (AxiLookBits), UniqueIds = {cv(cfg['UniqueIds'])}.", 12), 12, "left", valign="top")

# ====================================================================== TRANG 3: bản đồ địa chỉ
p3 = Page("2. Bản đồ địa chỉ", 1700, 1420)
heading(p3, "Bản đồ địa chỉ của S_BUS",
        "Rule của axi_xbar: start_addr nhỏ hơn hoặc bằng địa chỉ, địa chỉ nhỏ hơn end_addr. Chỗ không có rule: DECERR.")
MAPX, MAPW = 330, 420
rows = []   # (top addr, end addr exclusive, text, kind)
cur = 0
for r in rules:
    if r["base"] > cur:
        rows.append((cur, r["base"], "không rule: DECERR", "gap"))
    rows.append((r["base"], r["end"], f"{r['port']}  {rname(r)}", "rule"))
    cur = r["end"]
if cur < (1 << 32):
    rows.append((cur, 1 << 32, "không rule: DECERR", "gap"))
heights = {"rule": 90, "gap": 56}
y = 110
p3.text(MAPX, y - 4, MAPW, 24, "<b>Không gian địa chỉ 32 bit</b>", 15)
y += 28
apb_top = None
for a, b, txt, kind in rows:
    hh = heights[kind]
    sty = "dashed=1;" if kind == "gap" else ""
    p3.box(MAPX, y, MAPW, hh, f"<b>{txt}</b><br>{sm(h(a) + ' đến ' + h(b) + ('' if kind == 'gap' else ', ' + kib(b - a)), 12)}", 14, extra=sty)
    p3.text(40, y - 4, 270, 22, f"<b>{h(a)}</b>", 14, "right")
    if txt.startswith("AXI_M3"):
        apb_top = (y, y + hh)
    y += hh
p3.text(40, y - 6, 270, 22, f"<b>{h(rows[-1][1])}</b>", 14, "right")
# phóng to cửa sổ APB
ZX, ZW = 900, 420
zy = 110
p3.text(ZX, zy - 4, ZW + 150, 24, f"<b>Cửa sổ AXI2APB, {kib(APB_SIZE)}</b>  {sm('(' + str(APB_SIZE // APB_SLOT) + ' khe, mỗi khe ' + kib(APB_SLOT) + ')', 13)}", 15, "left")
zy += 28
SLOT_H = 52
n_slots = APB_SIZE // APB_SLOT
by_off = {(a[2] - APB_BASE) // APB_SLOT: a for a in apb}
for k in range(n_slots):
    yy = zy + k * SLOT_H
    off = k * APB_SLOT
    if k in by_off:
        nm = by_off[k][0]
        p3.box(ZX, yy, ZW, SLOT_H, f"APB_M{by_off[k][1]}  <b>{nm}</b>", 14)
        p3.text(ZX + ZW + 8, yy + 14, 150, 22, sm(f"offset {h18(off)}", 11), 11, "left")
    else:
        p3.box(ZX, yy, ZW, SLOT_H, f"dự phòng {sm('(chưa có ngoại vi)', 11)}", 13, extra="dashed=1;")
        p3.text(ZX + ZW + 8, yy + 14, 150, 22, sm(f"offset {h18(off)}", 11), 11, "left")
if apb_top:
    p3.edge([(MAPX + MAPW, apb_top[0]), (ZX, zy)], 2, arrow=False, dashed=True)
    p3.edge([(MAPX + MAPW, apb_top[1]), (ZX, zy + n_slots * SLOT_H)], 2, arrow=False, dashed=True)
p3.text(ZX, zy + n_slots * SLOT_H + 14, 760, 80,
        sm(f"Cổng APB của wrapper cho ra offset {PBUS_W} bit (địa chỉ AXI bỏ phần trên). Việc chia thành {APB_N} ngoại vi do khối phía sau cổng APB làm, không nằm trong wrapper.<br>"
           f"Địa chỉ ngoài cửa sổ không tới cổng APB: crossbar trả DECERR.", 13), 13, "left", valign="top")

# ====================================================================== TRANG 4: timing diagram
p4 = Page("3. Timing một lần đọc", 2260, 1320)
heading(p4, "Timing: CPU lấy lệnh từ ROM qua S_BUS (đọc 1 beat)",
        "Giả thiết: không có master nào khác tranh chấp, ROM nhận AR ngay (ar_ready = 1), ROM trả R sau 2 chu kỳ. Độ trễ của ROM chỉ là ví dụ.")
NC = 11
X0, CW = 400, 120
SIGW = 26
ROWS = []
ya = 130


def wave_bit(y_, seq, name):
    """seq: chuỗi 0/1 theo chu kỳ."""
    p4.text(20, y_ - 6, 370, SIGW + 12, sm(name, 12), 12, "right")
    hi, lo = y_, y_ + SIGW
    pts = []
    prev = None
    for c, v in enumerate(seq):
        yy = hi if v else lo
        x1 = X0 + c * CW
        if prev is None:
            pts.append((x1, yy))
        elif prev != v:
            pts.append((x1, prev_y))
            pts.append((x1, yy))
        prev, prev_y = v, yy
    pts.append((X0 + len(seq) * CW, prev_y))
    p4.edge(pts, 2, arrow=False)


def wave_clk(y_):
    p4.text(20, y_ - 6, 370, SIGW + 12, sm("clk_i", 12), 12, "right")
    pts = []
    for c in range(NC):
        x1 = X0 + c * CW
        pts += [(x1, y_ + SIGW), (x1, y_), (x1 + CW // 2, y_), (x1 + CW // 2, y_ + SIGW)]
    pts.append((X0 + NC * CW, y_ + SIGW))
    p4.edge(pts, 2, arrow=False)


def wave_bus(y_, segs, name):
    """segs: [(c0, c1, nhãn)]; chỗ khác là rảnh (đường giữa)."""
    p4.text(20, y_ - 6, 370, SIGW + 12, sm(name, 12), 12, "right")
    p4.edge([(X0, y_ + SIGW // 2), (X0 + NC * CW, y_ + SIGW // 2)], 1, arrow=False)
    for c0, c1, lab in segs:
        p4.vertex(X0 + c0 * CW + 4, y_, (c1 - c0) * CW - 8, SIGW, sm(lab, 12), S_HEX + "fontSize=12;")


def seq1(*hi):
    return [1 if c in hi else 0 for c in range(NC)]


def always1():
    return [1] * NC


# lưới chu kỳ
for c in range(NC + 1):
    p4.edge([(X0 + c * CW, ya - 12), (X0 + c * CW, 1190)], 1, arrow=False, dashed=True)
for c in range(NC):
    p4.text(X0 + c * CW, ya - 38, CW, 22, sm(f"chu kỳ {c}", 12), 12)
wave_clk(ya)
ya += 66
groups = [
    ("Phía master: cổng vào AXI_S1 (CPU, cổng lệnh)", [
        ("bit", "i_bus_axi_s_1_ar_valid", seq1(1)),
        ("bit", "o_bus_axi_s_1_ar_ready", always1()),
        ("bus", "i_bus_axi_s_1_ar_id[4:0]", [(1, 2, "5'b00000")]),
        ("bus", "i_bus_axi_s_1_ar_addr[31:0]", [(1, 2, h(rules[0]["base"] + 0x80))]),
    ]),
    ("Phía slave: cổng ra AXI_M0 (ROM), sau 2 chu kỳ", [
        ("bit", "o_bus_axi_m_0_ar_valid", seq1(3)),
        ("bit", "i_bus_axi_m_0_ar_ready", always1()),
        ("bus", "o_bus_axi_m_0_ar_id[6:0]", [(3, 4, "7'b01_00000")]),
        ("bus", "o_bus_axi_m_0_ar_addr[31:0]", [(3, 4, h(rules[0]["base"] + 0x80))]),
    ]),
    ("Phản hồi R: hai phía cùng chu kỳ (R không có thanh ghi cắt)", [
        ("bit", "i_bus_axi_m_0_r_valid", seq1(5)),
        ("bit", "o_bus_axi_s_1_r_valid", seq1(5)),
        ("bit", "i_bus_axi_s_1_r_ready", always1()),
        ("bus", "i_bus_axi_m_0_r_id[6:0]", [(5, 6, "7'b01_00000")]),
        ("bus", "o_bus_axi_s_1_r_id[4:0]", [(5, 6, "5'b00000")]),
        ("bus", "o_bus_axi_s_1_r_data[31:0]", [(5, 6, "lệnh")]),
    ]),
]
for title_, sigs in groups:
    p4.text(20, ya - 4, 900, 24, f"<b>{title_}</b>", 15, "left")
    ya += 30
    for kind, nm, data in sigs:
        (wave_bit if kind == "bit" else wave_bus)(ya, data, nm)
        ya += 60
    ya += 18
# chú thích
def mark(c, text_, y_):
    p4.edge([(X0 + c * CW + CW // 2, y_), (X0 + c * CW + CW // 2, y_ + 26)], 2)
    p4.text(X0 + c * CW - 40, y_ - 26, CW + 80, 26, f"<b>{text_}</b>", 12)


for c_, tx_ in ((1, "AR vào S_BUS"), (3, "AR ra tới ROM, +2 chu kỳ"), (5, "R về, không thêm trễ")):
    xx = X0 + c_ * CW + CW // 2
    p4.edge([(xx, ya + 44), (xx, ya + 8)], 2)
    p4.text(xx - 110, ya + 46, 220, 36, f"<b>{tx_}</b>", 12)
p4.text(1770, 330, 440, 330,
        sm(f"<b>Đọc hình này</b><br>"
           f"Chu kỳ 1: CPU đưa AR, ar_ready = 1 nên bắt tay xong.<br>"
           f"Chu kỳ 3: AR ra tới ROM. ID thêm {ADD_BITS} bit đầu (01 = cổng vào số 1), từ {SLV_ID} thành {MST_ID} bit.<br>"
           f"Chu kỳ 5: ROM trả R. S_BUS nhìn {ADD_BITS} bit đầu của ID để đưa về CPU, bỏ {ADD_BITS} bit đó, ID trở lại {SLV_ID} bit.<br>"
           f"R đi tổ hợp, không thêm trễ.<br><br>"
           f"Địa chỉ {h(rules[0]['base'] + 0x80)} là điểm bắt đầu chạy sau reset (ROM + 0x80).", 12), 12, "left", valign="top")


# ====================================================================== TRANG 1: block diagram mức module
def two_way(page, pts, width=3):
    mid = "".join(f'<mxPoint x="{px}" y="{py}"/>' for px, py in pts[1:-1])
    way = f'<Array as="points">{mid}</Array>' if mid else ""
    page.cells.append(f'<mxCell id="{page.nid()}" style="{ARW}endArrow=block;endFill=1;startArrow=block;startFill=1;strokeWidth={width};" edge="1" parent="1">'
                      f'<mxGeometry relative="1" as="geometry"><mxPoint x="{pts[0][0]}" y="{pts[0][1]}" as="sourcePoint"/>'
                      f'<mxPoint x="{pts[-1][0]}" y="{pts[-1][1]}" as="targetPoint"/>{way}</mxGeometry></mxCell>')


p0 = Page("1. Block diagram", 2420, 1280)
heading(p0, "m_qnsc_wrap_bus: block diagram",
        "Mỗi mũi tên hai chiều là một giao diện (yêu cầu đi, phản hồi về). Khung nét đứt là miền clock và reset. Độ rộng từng kênh và tên net nội bộ ở trang 5.")
BXL, BXR, BYT, BYB = 340, 2010, 100, 1070
p0.vertex(BXL, BYT, BXR - BXL, BYB - BYT, "", "rounded=0;fillColor=none;strokeWidth=3;")
p0.text(BXL + 10, BYT + 4, 700, 26, "<b>m_qnsc_wrap_bus</b>  (wrapper, emacs sinh từ .src.sv)", 16, "left")
RY = [270, 420, 570]
COLS = [920, 1050, 1180, 1310]
XB = (580, 180, 790, 640)       # x, y, w, h
p0.region(360, 140, 1000, 700, f"miền sbus: {CLK_S}, {RST_S}")

# --- master ngoài, glue vào
for i, (name, port) in enumerate(MASTERS):
    p0.box(20, RY[i] - 40, 170, 80, f"<b>{name}</b><br>{sm(port, 13)}", 16)
    two_way(p0, [(190, RY[i]), (390, RY[i])])
    p0.text(192, RY[i] - 40, 148, 34, sm(f"<i>i/o_bus_axi_s_{i}_*</i><br>ID {SLV_ID} bit", 11), 11)
    p0.box(390, RY[i] - 32, 120, 64, f"assign<br>{sm('flat ↔ struct', 11)}", 13)
    two_way(p0, [(510, RY[i]), (XB[0], RY[i])])

# --- u_axi_xbar
p0.box(*XB, "", 16)
p0.text(XB[0] + 10, XB[1] + 6, 460, 26, "<b>u_axi_xbar</b> : axi_xbar", 18, "left")
p0.text(XB[0] + 10, XB[1] + 32, 560, 20, sm(f"{NO_SLV} cổng slave × {NO_MST} cổng master · ID {SLV_ID} → {MST_ID} bit · {LATENCY} · Connectivity đầy đủ", 12), 12, "left")
for i in range(NO_SLV):
    yy = RY[i]
    p0.text(XB[0] + 6, yy - 30, 140, 18, sm(f"slv_ports_*[{i}]", 11), 11, "left")
    p0.vertex(XB[0] + 60, yy - 36, 130, 72, f"<b>cc_addr_decode</b><br>{sm('so với addr_map_i', 10)}", S_CLOUD + "fontSize=10;")
    p0.edge([(XB[0] + 180, yy), (XB[0] + 215, yy)], 2)
    p0.demux_v(XB[0] + 230, yy, 30, 84)
    p0.edge([(XB[0] + 245, yy), (COLS[-1] + 20, yy)], 2, arrow=False)
    for c in COLS:
        p0.dot(c, yy)
    p0.box(XB[0] + 150, yy + 42, 140, 40, f"responder lỗi<br>{sm('DECERR', 10)}", 11)
MUXY = 710
for j, c in enumerate(COLS):
    p0.edge([(c, RY[0]), (c, MUXY - 22)], 2, arrow=False)
    p0.edge([(c, MUXY - 24), (c, MUXY - 12)], 2)
    p0.mux(c, MUXY, 110, 36)
    p0.text(c - 50, MUXY - 12, 100, 24, "<b>mux</b>", 12)
    r = rules[j]
    p0.text(c + 6, MUXY + 24, 122, 62, sm(f"<b>{r['port']}</b> {rname(r)}<br>{h(r['base'])}<br>đến {h(r['end'])}", 9), 9, "left")
p0.text(XB[0] + 8, XB[1] + XB[3] - 54, 320, 50,
        sm(f"Mỗi mux: trọng tài round-robin, thêm {ADD_BITS} bit vào ID<br>addr_map_i ← P_ADDR_MAP, {len(rules)} rule<br>en_default_mst_port_i ← '0, default_mst_port_i ← '0", 10), 10, "left")
p0.text(XB[0] + XB[2] - 215, XB[1] + 8, 205, 40, sm(f"clk_i ← {CLK_S}<br>rst_ni ← {RST_S}", 11), 11, "right")
p0.edge([(XB[0] + XB[2] - 60, BYT), (XB[0] + XB[2] - 60, XB[1])], 2)
p0.text(XB[0] + XB[2] - 50, BYT + 28, 130, 18, sm(CLK_S, 11), 11, "left")

# --- glue ra + slave ngoài (đi xuống qua đáy wrapper)
SLY = 1150
for j, (name, port) in enumerate(SLAVES):
    c = COLS[j]
    p0.edge([(c, MUXY + 18), (c, 800)], 2, arrow=False)
    two_way(p0, [(c, 790), (c, SLY)])
    p0.box(c - 62, 880, 124, 56, f"assign<br>{sm('struct ↔ flat', 11)}", 12)
    p0.text(c + 8, 960, 118, 40, sm(f"<i>i/o_bus_axi_m_{j}_*</i><br>ID {MST_ID} bit", 10), 10, "left")
    p0.box(c - 62, SLY, 124, 70, f"<b>{name}</b><br>{sm(port, 12)}", 14)

# --- AXI_M3: cầu AXI2APB (miền pbus)
c3 = COLS[3]
p0.edge([(c3, MUXY + 18), (c3, 800)], 2, arrow=False)
two_way(p0, [(c3, 790), (c3, 940), (1350, 940)])
p0.label(c3 + 6, 824, 110, 16, f'AXI4, ID {MST_ID} bit', 10)
p0.region(1330, 830, 440, 230, f"miền pbus: {CLK_P}, {RST_P}")
BR = (1350, 870, 400, 170)
p0.box(*BR, "", 14)
p0.text(BR[0] + 8, BR[1] + 2, 430, 20, f"<b>Cầu AXI2APB</b> {sm('u_axi_to_axi_lite + u_axi_lite_to_apb', 11)}", 13, "left")
SBW = 130
sub = [("axi_atop_<br>filter", 1360), ("axi_burst_<br>splitter", 1490), ("axi_lite_<br>to_apb", 1620)]
for lab, xs in sub:
    p0.box(xs, 915, 110, 80, f"{sm(lab, 11)}", 12)
p0.edge([(1470, 955), (1490, 955)], 2)
p0.edge([(1600, 955), (1620, 955)], 2)
p0.text(1360, 998, 250, 30, sm("u_axi_to_axi_lite: AXI4 → AXI4-Lite", 10), 10, "left")
p0.text(1620, 998, 130, 30, sm("AXI4-Lite → APB4", 10), 10, "left")
# clock pbus
p0.edge([(1420, BYB), (1420, 1040)], 2)
p0.edge([(1540, BYB), (1540, 1040)], 2)
p0.text(1370, BYB + 2, 110, 18, sm(CLK_P, 11), 11)
p0.text(1490, BYB + 2, 120, 18, sm(RST_P, 11), 11)
# cổng APB ra
two_way(p0, [(BR[0] + BR[2], 955), (2170, 955)])
p0.text(1790, 908, 360, 40, sm(f"APB4 · <i>i/o_bus_apb_m_0_*</i>", 11), 11)
p0.text(1790, 964, 360, 70, sm(f"paddr {PBUS_W} bit, pwdata, pstrb,<br>psel, penable, pwrite<br>↩ pready, pslverr, prdata", 10), 10)
p0.box(2170, 880, 220, 150, f"<b>P_BUS</b><br>{sm('phía sau cổng APB<br>ngoài wrapper', 11)}", 14)

# chú giải gọn
p0.box(20, 760, 280, 230, "", 12)
p0.text(30, 766, 260, 24, "<b>Chú giải</b>", 15, "left")
two_way(p0, [(40, 820), (100, 820)])
p0.text(110, 800, 185, 40, sm("Giao diện hai chiều.", 11), 11, "left")
p0.vertex(40, 856, 60, 34, "", "rounded=0;fillColor=none;strokeWidth=2;dashed=1;dashPattern=10 6;")
p0.text(110, 856, 185, 34, sm("Miền clock và reset.", 11), 11, "left")
p0.vertex(40, 906, 60, 34, "", "rounded=0;fillColor=none;strokeWidth=3;")
p0.text(110, 906, 185, 34, sm("Ranh giới module.", 11), 11, "left")
p0.vertex(46, 950, 40, 28, "", S_CLOUD + "fontSize=9;")
p0.text(110, 950, 185, 28, sm("Logic tổ hợp (giải mã).", 11), 11, "left")


xml = ('<mxfile host="app.diagrams.net">' + p0.xml() + p3.xml() + p4.xml() + p2.xml() + p1.xml() + "</mxfile>")
out = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "s_bus.drawio"
out.write_text(xml, encoding="utf-8")
print(f"đã ghi {out}")
