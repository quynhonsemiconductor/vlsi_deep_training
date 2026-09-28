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

# ---------- Figure: bootloader flow ----------
flow = [
    N("init", 20, 10, 200, 40, "init UART0", "box", 10),
    N("rdy", 20, 80, 200, 40, "QRDY", "box", 10, True),
    N("hunt", 20, 150, 200, 40, "find MAGIC", "box", 10),
    N("hdr", 20, 220, 200, 40, "header", "box", 10),
    N("chk", 20, 290, 200, 40, "check header", "box", 10),
    N("ackh", 20, 360, 200, 40, "ACKH", "box", 10, True),
    N("pay", 20, 430, 200, 40, "payload", "box", 10),
    N("pchk", 20, 500, 200, 40, "check payload", "box", 10),
    N("ackp", 20, 570, 200, 40, "ACKP", "box", 10, True),
    N("jump", 20, 640, 200, 40, "jump to ENTRY", "box", 11, True),
    N("fail", 330, 360, 200, 60, "send failure token\ndrain the line", "red", 10),
    N("edge", 600, 90, 1, 20, "", "port", 10),
]
flow_e = [
    E("init", "b", "rdy", "t"),
    E("rdy", "b", "hunt", "t"),
    E("hunt", "b", "hdr", "t"),
    E("hdr", "b", "chk", "t"),
    E("chk", "b", "ackh", "t", "ok"),
    E("ackh", "b", "pay", "t"),
    E("pay", "b", "pchk", "t"),
    E("pchk", "b", "ackp", "t", "ok"),
    E("ackp", "b", "jump", "t"),
    E("hdr", "r", "fail", "t@0.2", "FTMO, FUAR"),
    E("chk", "r", "fail", "t@0.6", "FHCR, FHDR"),
    E("pay", "r", "fail", "b@0.3", "FTMO, FUAR"),
    E("pchk", "r", "fail", "b@0.8", "FPCR"),
    E("fail", "r", "rdy", "r", "retry", mid=570),
]

# ---------- Figure: PC - ROM handshake ----------
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
    E("b0", "l", "a0", "r", "QRDY"),
    E("a1", "r", "b1", "l", "header"),
    E("b2", "l", "a2", "r", "ACKH or FAIL"),
    E("a3", "r", "b3", "l", "PAYLOAD + PAY_CRC"),
    E("b4", "l", "a4", "r", "ACKP or FAIL"),
]

# ---------- Figure: reset to application (the one figure to present) ----------
_X, _W, _H = 40, 330, 44
def _s(nid, y, label, style="box", bold=False):
    return N(nid, _X, y, _W, _H, label, style, 10, bold)
top = [
    _s("rst", 0, "Reset: POR, WDT bite or SW_RST", "term", True),
    _s("scrc", 70, "SCRC: chip reset, then power-up\n(QNSC_SCRC_MAS 7.3, 7.5)"),
    N("dbg", _X + 65, 140, 200, 70, "DBG_EN\ncaptured = 1?", "diamond", 10),
    _s("rom", 250, "Ibex fetches 0x0000_0080 (ROM)\n_start: sp = 0x3000_8000, boot_main"),
    _s("uart", 320, "init UART0, send QRDY"),
    _s("dl", 390, "download frame to ISRAM\n(Figure 7-1)", bold=True),
    N("ok", _X + 65, 460, 200, 70, "ACKP\nsent?", "diamond", 10),
    _s("jmp", 570, "wait TEMT, fence.i, jump to ENTRY"),
    _s("app", 640, "application runs from ISRAM", "term", True),
    N("host", 720, 140, 330, 70, "SYSDBG holds the CPU\nhost writes the image over JTAG\nthen CPUHOLD = 0 (QNSC_SYSDBG_MAS 7.1)", "box", 10),
    N("dapp", 720, 570, 330, 44, "Ibex fetches 0x2000_1080", "box", 10),
    N("fail", 430, 475, 240, 40, "failure token, drain, QRDY", "red", 10),
    N("padr", 1060, 300, 1, 1, "", "port", 10),
]
top_e = [
    E("rst", "b", "scrc", "t"), E("scrc", "b", "dbg", "t"),
    E("dbg", "b", "rom", "t", "0: normal boot"),
    E("dbg", "r", "host", "l", "1: debug boot"),
    E("rom", "b", "uart", "t"), E("uart", "b", "dl", "t"), E("dl", "b", "ok", "t"),
    E("ok", "b", "jmp", "t", "yes"), E("ok", "r", "fail", "l", "no"),
    E("fail", "r", "dl", "r", mid=695),
    E("jmp", "b", "app", "t"),
    E("host", "b", "dapp", "t"),
    E("dapp", "b", "app", "r"),
]

emit([
    ("fig_boot_top", "Reset to application", top, top_e),
    ("fig_boot_path", "Boot download path", path, path_e),
    ("fig_boot_frame", "Boot frame", frame, []),
    ("fig_boot_flow", "Bootloader flow", flow, flow_e),
    ("fig_boot_seq", "PC-ROM handshake", seq, seq_e),
], DRAWIO, IMG)
