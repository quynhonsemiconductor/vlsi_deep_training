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
]

# ---------- Figure: boot frame ----------
_F = [("MAGIC", 4), ("LENGTH", 4), ("LOAD_ADDR", 4), ("ENTRY", 4), ("HDR_CRC", 4),
      ("PAYLOAD", 0), ("PAY_CRC", 4)]
frame, x = [], 10
for i, (name, size) in enumerate(_F):
    w = 200 if size == 0 else 100
    frame.append(N("f%d" % i, x, 40, w, 50, name, "box", 11, name in ("HDR_CRC", "PAY_CRC")))
    frame.append(N("s%d" % i, x, 95, w, 20, "LENGTH bytes" if size == 0 else "4 B", "port", 10))
    x += w
frame.append(N("hdr", 10, 5, 500, 30, "header, 20 B", "port", 10))

# ---------- Figure: bootloader flow (QNSC_BOOT_SPEC V3.1: one decision per check) ----------
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
    _fb("hdr", "waiting for the next header byte\nLENGTH, LOAD_ADDR, ENTRY, HDR_CRC"),
    _fd("hue", "UART error?"),
    _fd("hto", "byte within\nRX_TIMEOUT polls?"),
    _fd("h16", "16 header bytes\nincludes HDR_CRC\nreceived?"),
    _fd("hcr", "CRC32 = HDR_CRC?"),
    _fd("hrg", "fields in range?\n(Table 6-1)"),
    _fb("ackh", "send ACKH", True),
    _fb("pay", "wait for the next payload byte;\nevery 4 payload bytes: word to ISRAM, CRC32"),
    _fd("pue", "UART error?"),
    _fd("pto", "byte within\nRX_TIMEOUT polls?"),
    _fd("pn", "LENGTH payload bytes and\nPAY_CRC received?"),
    _fd("pcr", "CRC32 = PAY_CRC?"),
    _fb("ackp", "send ACKP", True),
    _fb("jump", "jump to ENTRY", True),
]
_fi = {n.id: n for n in flow}
flow += [
    N("rdy", 520, _fi["hunt"].y, 180, _FH, "send QRDY", "box", 10, True),
    N("drain", 520, _fi["hdr"].y - 10, 180, 60, "clear RX FIFO,\ndiscard bytes until quiet\nfor DRAIN_IDLE", "red", 10),
]
_seq = ["init", "hunt", "mag", "hdr", "hue", "hto", "h16", "hcr", "hrg", "ackh", "pay", "pue", "pto",
        "pn", "pcr", "ackp", "jump"]
_yes = {"mag": "yes", "hue": "no", "hto": "yes", "h16": "yes", "hcr": "yes", "hrg": "yes",
        "pue": "no", "pto": "yes", "pn": "yes", "pcr": "yes"}
flow_e = [E(a, "b", b, "t", _yes.get(a, "")) for a, b in zip(_seq, _seq[1:])]
flow_e += [E("mag", "l", "hunt", "l", "no", mid=0), E("h16", "l", "hdr", "l", "no", mid=0),
           E("pn", "l", "pay", "l", "no", mid=0)]
for d, tok, lab in [("hue", "FUAR", "yes"), ("hto", "FTMO", "no"), ("hcr", "FHCR", "no"), ("hrg", "FHDR", "no"),
                    ("pue", "FUAR", "yes"), ("pto", "FTMO", "no"), ("pcr", "FPCR", "no")]:
    t = "t_" + d
    flow.append(N(t, _TX, _fi[d].y + (_DH - _TH) / 2, _TW, _TH, "send " + tok, "box", 10, True))
    flow_e += [E(d, "r", t, "l", lab), E(t, "r", "drain", "b")]
flow_e += [E("drain", "t", "rdy", "b"), E("rdy", "l", "hunt", "r", "retry")]

# ---------- Figure: PC - ROM handshake (no token after reset; QRDY only after a failure) ----------
_Y = [60, 110, 160, 210, 260]
seq = [
    N("pc", 20, 0, 160, 40, "PC loader", "box", 11, True),
    N("rom", 500, 0, 160, 40, "Boot ROM", "box", 11, True),
    N("lp", 100, 40, 0.1, 250, "", "group", 10),
    N("lr", 580, 40, 0.1, 250, "", "group", 10),
]
for i, y in enumerate(_Y):
    seq.append(N("a%d" % i, 90, y, 20, 10, "", "port", 10))
    seq.append(N("b%d" % i, 570, y, 20, 10, "", "port", 10))
seq_e = [
    E("a0", "r", "b0", "l", "header"),
    E("b1", "l", "a1", "r", "ACKH or FAIL"),
    E("a2", "r", "b2", "l", "PAYLOAD + PAY_CRC"),
    E("b3", "l", "a3", "r", "ACKP or FAIL"),
    E("b4", "l", "a4", "r", "QRDY, only after FAIL, once the line is drained", dashed=True),
]

# ---------- Figure: reset to application (the one figure to present) ----------
_X, _W, _H = 40, 330, 44
def _s(nid, y, label, style="box", bold=False):
    return N(nid, _X, y, _W, _H, label, style, 10, bold)
top = [
    _s("rst", 0, "Reset: POR, WDT bite or SW_RST", "term", True),
    _s("scrc", 70, "SCRC: chip reset, then power-up\n(QNSC_SCRC_MAS 7.3, 7.5)"),
    N("dbg", _X + 65, 140, 200, 70, "DBG_EN\ncaptured = 1?", "diamond", 10),
    N("note", 395, 186, 300, 30, "boot address picked by a hardware mux (o_dbg_en -> boot_addr_i),\n"
      "not by ROM code: in debug boot the ROM never runs", "port", 8),
    _s("srel", 250, "SCRC release CPU"),
    _s("rom", 320, "Ibex fetches 0x0000_0080 (ROM)"),
    _s("uart", 390, "init UART0 (19200 - 8N1 - polling)"),
    _s("dl", 460, "download frame to ISRAM\n(Figure 7-1)", bold=True),
    N("ok", _X + 65, 530, 200, 70, "CRC\npass?", "diamond", 10),
    _s("jmp", 640, "jump to ENTRY"),
    _s("app", 710, "application runs from ISRAM", "term", True),
    N("host", 720, 140, 330, 70, "SYSDBG holds the CPU\nhost writes the image over JTAG\nthen CPUHOLD = 0 (QNSC_SYSDBG_MAS 7.1)", "box", 10),
    N("hrel", 720, 390, 330, 44, "SYSDBG release CPU", "box", 10),
    N("dapp", 720, 640, 330, 44, "Ibex fetches 0x2000_1080 (ISRAM)", "box", 10),
    N("fail", 430, 545, 240, 40, "failure token, drain, QRDY", "red", 10),
]
top_e = [
    E("rst", "b", "scrc", "t"), E("scrc", "b", "dbg", "t"),
    E("dbg", "b", "srel", "t", "0: normal boot"),
    E("dbg", "r", "host", "l", "1: debug boot"),
    E("srel", "b", "rom", "t"),
    E("rom", "b", "uart", "t"), E("uart", "b", "dl", "t"), E("dl", "b", "ok", "t"),
    E("ok", "b", "jmp", "t", "yes"), E("ok", "r", "fail", "l", "no"),
    E("fail", "r", "dl", "r", mid=695),
    E("jmp", "b", "app", "t"),
    E("host", "b", "hrel", "t"),
    E("hrel", "b", "dapp", "t"),
    E("dapp", "b", "app", "r"),
]

emit([
    ("fig_boot_top", "Reset to application", top, top_e),
    ("fig_boot_path", "Boot download path", path, path_e),
    ("fig_boot_frame", "Boot frame", frame, []),
    ("fig_boot_flow", "Bootloader flow", flow, flow_e),
    ("fig_boot_seq", "PC-ROM handshake", seq, seq_e),
], DRAWIO, IMG)
