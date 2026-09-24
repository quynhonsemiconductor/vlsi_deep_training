"""Overall SYSDBG figure for the presentation notes (PRESENT_SYSDBG_VI.md).

    python3 tools/build_sysdbg_present.py

Not a MAS figure. The circled numbers follow section 1.2 of the notes (the ten
questions), so the figure can be presented step by step.
"""
import os
import sys
_DOC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # doc/
sys.path.insert(0, os.path.join(_DOC, "tools"))
from diagen import Node as N, Edge as E, emit

IMG = os.path.join(_DOC, "img")
DRAWIO = os.path.join(_DOC, "drawio", "QNSC_SYSDBG_Present.drawio")

nodes = [
    # outside the chip
    N("host", 20, 90, 160, 80, "Host PC\nJTAG adapter", "blue", 12, True),
    N("board", 20, 330, 160, 60, "Board\nDBG_EN jumper", "blue", 11),

    N("chip", 210, 20, 1330, 680, "QSoC", "group", 12, True, "top"),

    N("jpad", 240, 90, 140, 80, "5 JTAG pads\nTCK TMS TDI\nTDO TRST_N", "box", 10),
    N("dpad", 240, 330, 140, 60, "DBG_EN pad", "box", 10),
    N("iomux", 240, 470, 140, 70, "IO MUX\nforce JTAG pads", "box", 10),

    # SYSDBG
    N("sysdbg", 420, 50, 520, 390, "SYSDBG", "group", 12, True, "top"),
    N("tap", 440, 90, 210, 110,
      "JTAG TAP  (clock TCK)\nTAP FSM · IR 4 bit\nDR: ADDR DATA STATUS\nCPUDBG CPUHOLD\nIDCODE BYPASS",
      "purple", 10),
    N("cdc", 670, 90, 90, 110, "CDC\n4-phase\nreq / ack\n2FF", "red", 10, True),
    N("axim", 780, 90, 140, 110, "AXI4 manager\n(clock chip)\nAR R · AW W B", "green", 10),
    N("dben", 440, 330, 210, 70, "DBG_EN\n2FF + capture once", "box", 10),
    N("outs", 670, 300, 250, 110,
      "outputs (clock chip)\no_cpu_debug_req\no_cpu_hold\no_dbg_en", "box", 10),

    # rest of the chip
    N("sbus", 990, 90, 140, 110, "S_BUS\nAXI_S0", "yellow", 11, True),
    N("isram", 1240, 60, 280, 170,
      "ISRAM\n\n0x2000_0000  debug window 4 KiB\n  0x0800 ENTRY (halt)\n  0x0700 DATA · CMD\n  RESUME · HALTED\n0x2000_1000  program",
      "green", 10),
    N("cpu", 1240, 300, 280, 140, "Ibex CPU\n\nhalt: PC -> dpc, jump 0x2000_0800\nresume: dret -> dpc", "blue", 10, True),
    N("scrc", 700, 580, 220, 80, "SCRC\nCPU reset = SCRC OR hold\n(before synchroniser)", "box", 10),
    N("boot", 990, 470, 160, 80, "boot_addr mux\n0: 0x0000_0000 ROM\n1: 0x2000_1000", "box", 10),

    N("key", 20, 730, 1520, 50,
      "1 connect   2 choose mode   3 hold CPU   4 load code   5 run   6 read data   7 halt   8 resume",
      "group", 11),
]

edges = [
    E("host", "r", "jpad", "l", "1 JTAG"),
    E("board", "r", "dpad", "l"),
    E("jpad", "r", "tap", "l"),
    E("dpad", "r", "dben", "l", "2"),
    E("tap", "r", "cdc", "l"),
    E("cdc", "r", "axim", "l"),
    E("axim", "r", "sbus", "l", "AXI4"),
    E("sbus", "r@0.3", "isram", "l@0.25", "4 load / 6 read"),
    E("tap", "b@0.85", "outs", "l@0.25", "dbgreq · cpu_hold"),
    E("dben", "r", "outs", "l@0.8"),
    E("outs", "r@0.25", "cpu", "l@0.25", "7 debug_req"),
    E("outs", "b@0.3", "scrc", "t@0.35", "3 o_cpu_hold"),
    E("scrc", "r", "cpu", "b@0.25", "rst_ni", False, False, None),
    E("outs", "b@0.85", "boot", "t", "o_dbg_en"),
    E("boot", "r", "cpu", "b@0.75", "5 boot_addr"),
    E("outs", "b@0.1", "iomux", "r", "o_dbg_en"),
    E("cpu", "t", "isram", "b", "fetch · halt loop · 8 RESUME"),
]

emit([("fig_sysdbg_overall", "SYSDBG overall", nodes, edges)], DRAWIO, IMG)
