"""Boot-flow figures for QNSC_BOOT_SPEC V3.1: download path, frame, bootloader flow,
PC-ROM handshake, reset to application. Monochrome.

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
    N("syscsr", 330, 360, 110, 50, "SYSCSR\nAPB_M1", "box", 10),
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
    E("pbus", "b", "syscsr", "t", bidir=True),
    E("a2p", "t", "sbus", "b@0.6512", bidir=True),
    E("cpu", "b", "sbus", "t@0.1279", bidir=True),
    E("sbus", "t@0.5", "rom", "b"),
    E("sbus", "t@0.8721", "isram", "b"),
    E("sbus", "r", "dsram", "l"),
]

# ---------- Figure: boot frame ----------
_F = [("MAGIC", 4, 100), ("LENGTH", 4, 100), ("DEBUG_PROG", 4, 100), ("HDR_CRC", 4, 100),
      ("DEBUG_PAYLOAD", "4096 B, only if\nDEBUG_PROG = 0x55", 220), ("DBG_CRC", 4, 100),
      ("PAYLOAD", "LENGTH bytes", 200), ("PAY_CRC", 4, 100)]
frame, x = [], 10
for i, (name, size, w) in enumerate(_F):
    frame.append(N("f%d" % i, x, 40, w, 50, name, "box", 10, name.endswith("_CRC")))
    frame.append(N("s%d" % i, x, 95, w, 36 if isinstance(size, str) and "\n" in size else 20,
                   size if isinstance(size, str) else "4 B", "port", 10))
    x += w
frame.append(N("hdr", 10, 5, 400, 30, "header, 16 B", "port", 10))

# ---------- Figure: bootloader flow ----------
flow = [
    N("init", 20, 10, 200, 40, "init UART0, 19200 8N1", "box", 10),
    N("rdy", 20, 80, 200, 40, "QRDY", "box", 10, True),
    N("hunt", 20, 150, 200, 40, "find MAGIC (slide 1 byte)", "box", 10),
    N("hdr", 20, 220, 200, 40, "header: 12 B", "box", 10),
    N("chk", 20, 290, 200, 40, "HDR_CRC, LENGTH, DEBUG_PROG", "box", 10),
    N("ackh", 20, 360, 200, 40, "ACKH", "box", 10, True),
    N("dec", 40, 425, 160, 70, "DEBUG_PROG\n= 0x55?", "diamond", 10),
    N("dpay", 330, 440, 200, 40, "DEBUG_PAYLOAD\nto 0x2000_0000", "box", 10),
    N("dchk", 330, 510, 200, 40, "check DBG_CRC", "box", 10),
    N("dack", 330, 580, 200, 40, "ACKD", "box", 10, True),
    N("pay", 20, 530, 200, 40, "PAYLOAD to 0x2000_1000", "box", 10),
    N("pchk", 20, 620, 200, 40, "check PAY_CRC", "box", 10),
    N("ackp", 20, 690, 200, 40, "ACKP", "box", 10, True),
    N("gate", 20, 760, 200, 40, "wait while SYSCSR.DBG_EN = 1", "box", 10),
    N("jump", 20, 830, 200, 40, "jump to 0x2000_1080", "box", 11, True),
    N("fail", 700, 330, 220, 70, "send failure token\ndrain the line\nsend QRDY", "red", 10),
]
flow_e = [
    E("init", "b", "rdy", "t"),
    E("rdy", "b", "hunt", "t"),
    E("hunt", "b", "hdr", "t"),
    E("hdr", "b", "chk", "t"),
    E("chk", "b", "ackh", "t", "ok"),
    E("ackh", "b", "dec", "t"),
    E("dec", "b", "pay", "t", "0xAA"),
    E("dec", "r", "dpay", "l", "0x55"),
    E("dpay", "b", "dchk", "t"),
    E("dchk", "b", "dack", "t", "ok"),
    E("dack", "l", "pay", "r"),
    E("pay", "b", "pchk", "t"),
    E("pchk", "b", "ackp", "t", "ok"),
    E("ackp", "b", "gate", "t"),
    E("gate", "b", "jump", "t", "DBG_EN = 0"),
    E("hdr", "r", "fail", "t@0.2", "FTMO"),
    E("chk", "r", "fail", "t@0.6", "FHCR, FHDR"),
    E("dpay", "r", "fail", "b@0.2", "FTMO"),
    E("dchk", "r", "fail", "b@0.6", "FDCR"),
    E("pchk", "r", "fail", "b@0.9", "FPCR"),
    E("fail", "r", "rdy", "r", "retry", mid=925),
]

# ---------- Figure: PC - ROM handshake ----------
_Y = [60, 110, 160, 210, 260, 310, 360]
seq = [
    N("pc", 20, 0, 160, 40, "PC loader", "box", 11, True),
    N("rom", 500, 0, 160, 40, "Boot ROM", "box", 11, True),
    N("lp", 100, 40, 0.1, 360, "", "group", 10),
    N("lr", 580, 40, 0.1, 360, "", "group", 10),
]
for i, y in enumerate(_Y):
    seq.append(N("a%d" % i, 90, y, 20, 10, "", "port", 10))
    seq.append(N("b%d" % i, 570, y, 20, 10, "", "port", 10))
seq_e = [
    E("b0", "l", "a0", "r", "QRDY"),
    E("a1", "r", "b1", "l", "MAGIC + header"),
    E("b2", "l", "a2", "r", "ACKH or FAIL"),
    E("a3", "r", "b3", "l", "DEBUG_PAYLOAD + DBG_CRC (if 0x55)"),
    E("b4", "l", "a4", "r", "ACKD or FAIL"),
    E("a5", "r", "b5", "l", "PAYLOAD + PAY_CRC"),
    E("b6", "l", "a6", "r", "ACKP or FAIL"),
]

# ---------- Figure: reset to application (the one figure to present) ----------
_X, _W, _H = 40, 330, 44


def _s(nid, y, label, style="box", bold=False):
    return N(nid, _X, y, _W, _H, label, style, 10, bold)


top = [
    _s("rst", 0, "Power on", "term", True),
    _s("hold", 70, "SCRC holds the chip in reset\nand clocks every block (7.3)"),
    _s("rel", 140, "SCRC releases every IP except the CPU,\nwaits 16 clock cycles (7.5)"),
    _s("cpu", 210, "SCRC releases the CPU"),
    _s("rom", 280, "Ibex fetches 0x0000_0080 (ROM)\n_start: sp = 0x3000_8000, boot_main"),
    _s("uart", 350, "init UART0 (19200 8N1), send QRDY"),
    _s("dl", 420, "download frame to ISRAM\n(Figure 7-1)", bold=True),
    N("ok", _X + 65, 490, 200, 70, "ACKP\nsent?", "diamond", 10),
    N("dbg", _X + 65, 600, 200, 70, "SYSCSR.DBG_EN\n= 1?", "diamond", 10),
    _s("jmp", 710, "wait TEMT, fence.i, jump to 0x2000_1080"),
    _s("app", 780, "user program runs from ISRAM", "term", True),
    N("poll", 440, 585, 400, 100,
      "ROM polling loop, CPU not held in reset\nJTAG cpu_dbg_en: debug at 0x2000_0800,\ndret returns here\nJTAG writes DBG_EN_MASK = 1: DBG_EN reads 0", "box", 10),
    N("fail", 440, 505, 240, 40, "failure token, drain, QRDY", "red", 10),
]
top_e = [
    E("rst", "b", "hold", "t"), E("hold", "b", "rel", "t"), E("rel", "b", "cpu", "t"),
    E("cpu", "b", "rom", "t"),
    E("rom", "b", "uart", "t"), E("uart", "b", "dl", "t"), E("dl", "b", "ok", "t"),
    E("ok", "b", "dbg", "t", "yes"), E("ok", "r", "fail", "l", "no"),
    E("fail", "r", "dl", "r", mid=715),
    E("dbg", "r", "poll", "l", "1"),
    E("dbg", "b", "jmp", "t", "0"),
    E("jmp", "b", "app", "t"),
]

emit([
    ("fig_boot_top", "Reset to application", top, top_e),
    ("fig_boot_path", "Boot download path", path, path_e),
    ("fig_boot_frame", "Boot frame", frame, []),
    ("fig_boot_flow", "Bootloader flow", flow, flow_e),
    ("fig_boot_seq", "PC-ROM handshake", seq, seq_e),
], DRAWIO, IMG)
