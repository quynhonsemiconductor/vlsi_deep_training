"""Boot-flow figures for QNSC_BOOT_SPEC: download path, frame, bootloader flow,
PC-ROM handshake. Monochrome.

    python3 doc/build/tools/build_boot.py
"""
import os
import sys
_DOC = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # doc/
sys.path.insert(0, os.path.join(_DOC, "build", "tools"))
from diagen import Node as N, Edge as E, emit

IMG = os.path.join(_DOC, "figures", "img")
DRAWIO = os.path.join(_DOC, "figures", "drawio", "QNSC_BOOT.drawio")

# ---------- Figure: blocks on the boot path ----------
path = [
    N("pc", 10, 250, 110, 50, "PC loader", "box", 10),
    N("uart", 170, 250, 110, 50, "UART0\nAPB_M8", "box", 11, True),
    N("pbus", 330, 250, 110, 50, "P_BUS", "box", 10),
    N("a2p", 490, 250, 110, 50, "AXI2APB", "box", 10),
    N("sbus", 330, 130, 430, 50, "S_BUS", "box", 11, True),
    N("cpu", 330, 20, 110, 50, "Ibex", "box", 11, True),
    N("rom", 490, 20, 110, 50, "ROM\nAXI_M0", "box", 10),
    N("isram", 650, 20, 110, 50, "ISRAM\nAXI_M1", "box", 10),
    N("dsram", 810, 130, 110, 50, "DSRAM\nAXI_M2", "box", 10),
    N("jtag", -150, 20, 110, 50, "JTAG probe", "box", 10),
    N("dbg", 10, 20, 110, 50, "SYSDBG\nAXI_S0", "box", 11, True),
    N("csr", 330, 350, 110, 50, "SYSCSR\nAPB_M1", "box", 11, True),
    N("pin", 170, 350, 110, 50, "DBG_EN pin", "box", 10),
]
path_e = [
    E("pc", "r", "uart", "l", bidir=True),
    E("uart", "r", "pbus", "l", bidir=True),
    E("pbus", "r", "a2p", "l", bidir=True),
    E("a2p", "t", "sbus", "b@0.6512", bidir=True),
    E("cpu", "b", "sbus", "t@0.1279", bidir=True),
    E("sbus", "t@0.5", "rom", "b"),
    E("sbus", "t@0.8721", "isram", "b"),
    E("sbus", "r", "dsram", "l"),
    E("jtag", "r", "dbg", "l", bidir=True),
    E("dbg", "r", "cpu", "l", "debug req", dashed=True),
    E("dbg", "b", "sbus", "l", bidir=True),
    E("pbus", "b", "csr", "t", bidir=True),
    E("pin", "r", "csr", "l"),
]

# ---------- Figure: boot frame ----------
# (name, width, size label, only with DEBUG_PROG = 0x55: dashed)
_F = [("MAGIC", 90, "4 B", False), ("LENGTH", 90, "4 B", False), ("DEBUG_PROG", 90, "4 B", False),
      ("HDR_CRC", 90, "4 B", False), ("DEBUG_PAYLOAD", 150, "4096 B", True),
      ("DBG_CRC", 90, "4 B", True), ("PAYLOAD", 150, "LENGTH bytes", False), ("PAY_CRC", 90, "4 B", False)]
frame, x = [], 10
for i, (name, w, size, opt) in enumerate(_F):
    frame.append(N("f%d" % i, x, 40, w, 50, name, "group" if opt else "box", 11, name.endswith("_CRC")))
    frame.append(N("s%d" % i, x, 95, w, 20, size, "port", 10))
    x += w
frame.append(N("hdr", 10, 5, 360, 30, "header, 16 B", "port", 10))
frame.append(N("dpt", 370, 5, 240, 30, "only when DEBUG_PROG = 0x55", "port", 10))

# ---------- Figure: bootloader flow (QNSC_BOOT_SPEC V3.4: one decision per check) ----------
_FX, _FW, _FH = 20, 270, 40            # boxes
_DX, _DW, _DH = 45, 220, 64            # decisions
_TX, _TW, _TH = 340, 120, 32           # failure tokens
_y = [10]
def _nx(h):
    t = _y[0]
    _y[0] += h + 26
    return t
def _fb(nid, label, bold=False):
    return N(nid, _FX, _nx(_FH), _FW, _FH, label, "box", 10, bold)
def _fd(nid, label):
    return N(nid, _DX, _nx(_DH), _DW, _DH, label, "diamond", 10)
flow = [
    _fb("init", "init UART0"),
    _fb("hunt", "waiting for each MAGIC byte from PC"),
    _fd("mag", "last 4 bytes\n= 'Q' 'S' 'O' 'C'?"),
    _fb("hdr", "waiting for the next header byte:\nLENGTH, DEBUG_PROG, HDR_CRC"),
    _fd("hto", "new byte within\nRX_TIMEOUT polls?"),
    _fd("h8", "12 header bytes\nreceived?"),
    _fd("hcr", "CRC32 = HDR_CRC?"),
    _fd("hrg", "LENGTH valid?\n(Table 6-1)"),
    _fb("ackh", "send ACKH", True),
    _fd("dsel", "DEBUG_PROG = 0x55?"),
    _fb("dpay", "waiting for the next debug program\nor DBG_CRC byte; write it to 0x2000_0000"),
    _fd("dto", "new byte within\nRX_TIMEOUT polls?"),
    _fd("dn", "4096 bytes and\nDBG_CRC received?"),
    _fd("dcr", "CRC32 = DBG_CRC?"),
    _fb("ackd", "send ACKD", True),
    _fb("pay", "waiting for the next payload or PAY_CRC byte;\nwrite the payload to 0x2000_1000 (ISRAM)"),
    _fd("pto", "new byte within\nRX_TIMEOUT polls?"),
    _fd("pn", "all payload and\nPAY_CRC bytes received?"),
    _fd("pcr", "CRC32 = PAY_CRC?"),
    _fb("ackp", "send ACKP", True),
    _fd("wt", "read SYSCSR.DBG_EN:\n= 1?"),
    _fb("jump", "jump to 0x2000_1080 (ISRAM)", True),
]
_fi = {n.id: n for n in flow}
flow += [
    N("rdy", 520, _fi["hunt"].y, 180, _FH, "send QRDY", "box", 10, True),
    N("drain", 520, _fi["hdr"].y - 10, 180, 60, "clear RX FIFO,\ndiscard bytes until quiet\nfor DRAIN_IDLE polls", "red", 10),
]
_seq = ["init", "hunt", "mag", "hdr", "hto", "h8", "hcr", "hrg", "ackh", "dsel", "dpay", "dto",
        "dn", "dcr", "ackd", "pay", "pto", "pn", "pcr", "ackp", "wt", "jump"]
_yes = {"mag": "yes", "hto": "yes", "h8": "yes", "hcr": "yes", "hrg": "yes", "dsel": "yes",
        "dto": "yes", "dn": "yes", "dcr": "yes", "pto": "yes", "pn": "yes", "pcr": "yes",
        "wt": "no"}
flow_e = [E(a, "b", b, "t", _yes.get(a, "")) for a, b in zip(_seq, _seq[1:])]
# the "no" loops at x = 8: the image starts 24 px left of the boxes, so the label fits;
# the no-debug-program bypass runs further left, at x = -8, past the debug-program loop
flow_e += [E("mag", "l", "hunt", "l", "no", mid=8), E("h8", "l", "hdr", "l", "no", mid=8),
           E("dn", "l", "dpay", "l", "no", mid=8), E("pn", "l", "pay", "l", "no", mid=8),
           E("dsel", "l", "pay", "l@0.25", "no", mid=-8)]
# widens the image so the bypass and its label are not cut
flow.append(N("lspace", -50, _fi["dsel"].y, 1, 1, "", "port", 9))
# the debug wait: the CPU runs this loop until the host writes DBG_BOOT.dbg_en_mask = 1
flow.append(N("poll", _TX, _fi["wt"].y + (_DH - _TH) / 2, 150, _TH,
              "CPU polling: read\nSYSCSR.DBG_EN again", "box", 10))
flow.append(N("pnote", _TX + 160, _fi["wt"].y - 6, 260, 76,
              "leaves the loop when the host writes\nDBG_BOOT.dbg_en_mask = 1 over JTAG;\n"
              "a halt enters the debug program at\n0x2000_0800; dret returns to this loop", "port", 9))
flow_e += [E("wt", "r", "poll", "l", "yes"),
           E("poll", "t", "wt", "t", mid=_fi["wt"].y - 12)]
for d, tok, lab in [("hto", "FTMO", "no"), ("hcr", "FHCR", "no"), ("hrg", "FHDR", "no"),
                    ("dto", "FTMO", "no"), ("dcr", "FDCR", "no"),
                    ("pto", "FTMO", "no"), ("pcr", "FPCR", "no")]:
    t = "t_" + d
    flow.append(N(t, _TX, _fi[d].y + (_DH - _TH) / 2, _TW, _TH, "send " + tok, "box", 10, True))
    flow_e += [E(d, "r", t, "l", lab), E(t, "r", "drain", "b")]
flow_e += [E("drain", "t", "rdy", "b"), E("rdy", "l", "hunt", "r", "retry")]

# ---------- Figure: PC - ROM handshake (no token after reset; QRDY only after a failure) ----------
_Y = [60, 110, 160, 210, 260, 310, 360]
seq = [
    N("pc", 20, 0, 160, 40, "PC loader", "box", 11, True),
    N("rom", 500, 0, 160, 40, "Boot ROM", "box", 11, True),
    N("lp", 100, 40, 0.1, 350, "", "group", 10),
    N("lr", 580, 40, 0.1, 350, "", "group", 10),
]
for i, y in enumerate(_Y):
    seq.append(N("a%d" % i, 90, y, 20, 10, "", "port", 10))
    seq.append(N("b%d" % i, 570, y, 20, 10, "", "port", 10))
seq_e = [
    E("a0", "r", "b0", "l", "header (16 B)"),
    E("b1", "l", "a1", "r", "ACKH or FAIL"),
    E("a2", "r", "b2", "l", "DEBUG_PAYLOAD + DBG_CRC (only when DEBUG_PROG = 0x55)", dashed=True),
    E("b3", "l", "a3", "r", "ACKD or FAIL (only when DEBUG_PROG = 0x55)", dashed=True),
    E("a4", "r", "b4", "l", "PAYLOAD + PAY_CRC"),
    E("b5", "l", "a5", "r", "ACKP or FAIL"),
    E("b6", "l", "a6", "r", "QRDY, only after FAIL, once the line is drained", dashed=True),
]

# ---------- Figure: reset to application (the one figure to present) ----------
_X, _W, _H = 40, 330, 44
def _s(nid, y, label, style="box", bold=False):
    return N(nid, _X, y, _W, _H, label, style, 10, bold)
top = [
    _s("rst", 0, "Power on", "term", True),
    _s("scrc", 70, "SCRC: hold the whole chip in reset, clock the IPs"),
    _s("rel", 140, "SCRC: release the reset of every IP except the CPU"),
    _s("srel", 210, "SCRC releases the CPU reset"),
    _s("rom", 280, "Ibex fetches 0x0000_0080 (ROM)"),
    N("note", 395, 282, 300, 40, "no boot address mux and no CPU hold:\n"
      "normal and debug boot both run the ROM", "port", 8),
    _s("uart", 350, "init UART0 (19200 - 8N1 - polling)"),
    N("dl", _X, 420, _W, 70, "receive the frame from the PC over UART0\n(Figure 7-1):\n"
      "DEBUG_PAYLOAD -> 0x2000_0000 (if DEBUG_PROG = 0x55)\n"
      "PAYLOAD -> 0x2000_1000", "box", 9, True),
    N("dbg", _X + 65, 520, 200, 70, "SYSCSR.DBG_EN = 1?", "diamond", 10),
    N("poll", 720, 533, 330, 44, "CPU polling: read SYSCSR.DBG_EN again\n"
      "(the CPU runs the ROM; it is not held in reset)", "box", 10),
    N("pnote", 720, 590, 330, 60, "leaves the loop when the host writes DBG_BOOT.dbg_en_mask = 1\n"
      "(SYSDBG bus master, AXI_S0)\n"
      "at any time: debug request -> debug program at 0x2000_0800,\n"
      "dret -> back to this loop", "port", 8),
    N("dnote", 395, 600, 300, 30, "DBG_EN = DBG_EN pin through 2 FF,\n"
      "forced to 0 while dbg_en_mask = 1", "port", 8),
    _s("jmp", 660, "jump to 0x2000_1080 (ISRAM)"),
    _s("app", 730, "application runs from ISRAM", "term", True),
]
top_e = [
    E("rst", "b", "scrc", "t"), E("scrc", "b", "rel", "t"), E("rel", "b", "srel", "t"),
    E("srel", "b", "rom", "t"), E("rom", "b", "uart", "t"), E("uart", "b", "dl", "t"),
    E("dl", "b", "dbg", "t"),
    E("dbg", "r", "poll", "l", "1: debug boot"),
    E("poll", "t", "dbg", "t", mid=505),
    E("dbg", "b", "jmp", "t", "0: normal boot"),
    E("jmp", "b", "app", "t"),
]

emit([
    ("fig_boot_top", "Reset to application", top, top_e),
    ("fig_boot_path", "Boot download path", path, path_e),
    ("fig_boot_frame", "Boot frame", frame, []),
    ("fig_boot_flow", "Bootloader flow", flow, flow_e),
    ("fig_boot_seq", "PC-ROM handshake", seq, seq_e),
], DRAWIO, IMG)
