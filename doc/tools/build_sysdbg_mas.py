"""Figures for QNSC_SYSDBG_MAS V3.0.

    python3 tools/build_sysdbg_mas.py

New file names, so the V1.x figures that QNSC_SYSDBG_DECISIONS.md and the
presentation still show are left as they were drawn.

Labels are signal and state names only. What they mean is in the specification;
a sentence in a diagram is a second copy that drifts.
"""
import os
import sys
_DOC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # doc/
sys.path.insert(0, os.path.join(_DOC, "tools"))
from diagen import Node as N, Edge as E, emit

IMG = os.path.join(_DOC, "img")
DRAWIO = os.path.join(_DOC, "drawio", "QNSC_SYSDBG_MAS.drawio")

# --------------------------------------------------------------- 1. block
# Two dashed boxes are the two clock domains. Only the CDC column crosses
# between them, and only two single-bit toggles cross it.
blk = [
    N("jpad", 20, 190, 130, 150, "JTAG pads\nTCK  TMS  TDI\nTDO  TRST_N", "blue", 10),
    N("dpad", 20, 540, 130, 50, "DBG_EN pad", "blue", 10, True),

    N("ztck", 190, 60, 370, 400, "TCK domain  ·  i_jtag_tck", "group", 11, True, "top"),
    N("tap", 210, 100, 330, 60, "TAP controller  ·  IR 4 bit\nIDCODE  ·  BYPASS", "purple", 10),
    N("acc", 210, 190, 330, 60, "ACCESS shift register  68 bit", "green", 10),
    N("cmdh", 360, 280, 180, 60, "cmd_hold  68 bit\ncmd_req", "green", 10),
    N("cap", 210, 370, 330, 60, "Capture-DR mux\nrsp_hold  or  BUSY / TIMEOUT", "green", 10),

    N("cdc", 600, 180, 120, 270, "CDC\n\ncmd_req  ->\n<-  cmd_ack\n<-  timeout\n\n2FF each", "red", 10, True),

    N("zsys", 750, 60, 470, 460, "system domain  ·  i_clk_cpu  ·  i_rst_n_por",
      "group", 11, True, "top"),
    N("fsm", 770, 100, 190, 80, "Command FSM\nIDLE  DECODE\nLOCAL  BUS  DONE", "yellow", 10, True),
    N("rsph", 770, 300, 190, 60, "rsp_hold\nrdata  ·  status", "green", 10),
    N("regs", 1010, 100, 190, 60, "CTRL  ·  STATUS  ·  ID", "box", 10),
    N("halt", 1010, 190, 190, 60, "halt logic", "red", 10),
    N("bm", 1010, 300, 190, 60, "bus master\nreq  gnt  rsp", "green", 10),
    N("latch", 770, 420, 190, 60, "DBG_EN\n2FF + capture", "box", 10),
    N("outs", 1010, 420, 190, 60, "o_dbg_en\no_cpu_hold", "box", 10),

    N("cpu", 1340, 170, 150, 100, "Ibex CPU", "blue", 11, True),
    N("sbus", 1340, 300, 150, 60, "S_BUS  AXI_S0\naxi_from_mem", "yellow", 10),
    N("top", 1340, 420, 150, 60, "SCRC  ·  boot mux\nIO MUX", "box", 10),
]
blk_e = [
    E("jpad", "r@0.2", "tap", "l", "TMS"),
    E("jpad", "r@0.5", "acc", "l", "TDI"),
    E("acc", "b@0.75", "cmdh", "t", "Update-DR"),
    E("cmdh", "r", "cdc", "l@0.2", "", False, False, 570),
    E("cdc", "l@0.8", "cap", "r"),
    E("cap", "l", "jpad", "r@0.85", "TDO"),
    E("cdc", "r@0.2", "fsm", "l"),
    E("rsph", "l", "cdc", "r@0.8"),
    E("fsm", "b", "rsph", "t", "DONE"),
    E("fsm", "r@0.3", "regs", "l", "LOCAL"),
    E("fsm", "r@0.8", "bm", "l", "BUS", False, False, 985),
    E("regs", "b", "halt", "t", "haltreq"),
    E("halt", "r@0.3", "cpu", "l@0.38", "o_cpu_debug_req"),
    E("cpu", "l@0.7", "halt", "r@0.83", "i_cpu_debug_mode"),
    E("bm", "r", "sbus", "l", "o_mem_*"),
    E("dpad", "r", "latch", "b", "i_dbg_en"),
    E("latch", "r", "outs", "l"),
    E("outs", "r", "top", "l"),
]

# --------------------------------------------------------------- 2. FSM
fsm = [
    N("idle", 60, 180, 170, 80, "IDLE", "blue", 12, True),
    N("dec", 330, 180, 170, 80, "DECODE", "yellow", 12, True),
    N("loc", 330, 40, 170, 76, "LOCAL\nCTRL  STATUS  ID", "purple", 10),
    N("bus", 600, 180, 170, 80, "BUS\ntimer counts", "green", 12, True),
    N("done", 930, 180, 170, 80, "DONE\nload rsp_hold", "grey", 12, True),
    N("note", 60, 380, 1040, 70,
      "timer = BusTimeout  ->  timeout = 1, stay in BUS\n"
      "leave BUS  ->  timer = 0, timeout = 0",
      "group", 10),
]
fsm_e = [
    E("idle", "r", "dec", "l", "cmd_req edge"),
    E("dec", "t", "loc", "b", "addr[31:28] = F"),
    E("dec", "r", "bus", "l", "else"),
    E("loc", "r", "done", "t@0.3", "OK / ERROR"),
    E("bus", "r@0.3", "done", "l@0.3", "rsp_valid"),
    E("bus", "r@0.7", "done", "l@0.7", "sysbus reset"),
    E("dec", "b", "done", "b@0.3", "misaligned  ·  size 11  ·  sysbus in reset  ->  ERROR",
      False, False, 330),
    E("done", "t@0.7", "idle", "t", "toggle cmd_ack", False, False, 22),
]

# --------------------------------------------------------------- 3. debug boot wiring
wire = [
    N("dpad", 20, 40, 150, 50, "DBG_EN pad", "blue", 11, True),
    N("jpad", 20, 160, 150, 60, "JTAG pads", "blue", 11),
    N("dbg", 260, 80, 220, 200, "SYSDBG", "red", 13, True),
    N("scrc", 600, 440, 170, 60, "SCRC", "box", 12, True),
    N("iomux", 600, 50, 170, 70, "IO MUX\nPIN_8..12 = JTAG", "box", 10),
    N("mux", 600, 165, 170, 90, "boot_addr mux\n0: 0x0000_0000\n1: 0x2000_1000", "box", 10),
    N("gate", 600, 285, 170, 90, "CPU reset\nsynchroniser\nhold OR cpu reset", "box", 10),
    N("cpu", 900, 150, 170, 240, "Ibex CPU", "blue", 13, True),
    N("sbus", 900, 560, 170, 60, "S_BUS\nAXI_S0", "yellow", 12),
    N("isram", 900, 670, 170, 60, "ISRAM", "green", 12),
]
wire_e = [
    E("dpad", "r", "dbg", "l@0.1", "i_dbg_en"),
    E("jpad", "r", "dbg", "l@0.5", "JTAG"),
    E("dbg", "r@0.1", "iomux", "l", "o_dbg_en"),
    E("dbg", "r@0.45", "mux", "l", "o_dbg_en"),
    E("dbg", "r@0.85", "gate", "l@0.3", "o_cpu_hold"),
    E("scrc", "t", "gate", "b"),
    E("mux", "r", "cpu", "l@0.25", "boot_addr_i"),
    E("gate", "r", "cpu", "l@0.75", "rst_ni"),
    E("dbg", "t", "cpu", "t", "debug_req", False, False, 22),
    E("dbg", "b@0.8", "sbus", "l"),
    E("cpu", "b", "sbus", "t"),
    E("sbus", "b", "isram", "t"),
]

# --------------------------------------------------------------- 4. debug boot sequence
def s(nid, x, y, text, style="box", w=250, h=56):
    return N(nid, x, y, w, h, text, style, 10)

seq = [
    N("l_scrc", 20, 20, 250, 540, "SCRC", "group", 12, True, "top"),
    N("l_host", 300, 20, 290, 540, "host  ->  SYSDBG", "group", 12, True, "top"),
    N("l_cpu", 620, 20, 250, 540, "Ibex CPU", "group", 12, True, "top"),

    s("a1", 20, 70, "POR released\nbus  ROM  RAM  peripherals", "yellow"),
    s("c1", 620, 70, "held in reset\no_cpu_hold = 1", "red"),
    s("h1", 320, 150, "write window\n0x2000_0000  4 KiB", "blue"),
    s("h2", 320, 230, "write image\n0x2000_1000", "blue"),
    s("h3", 320, 310, "optional:  CTRL.haltreq = 1", "blue"),
    s("h4", 320, 390, "CTRL.cpu_hold = 0", "blue"),
    s("c2", 620, 390, "first fetch 0x2000_1080\nor halt before it", "green"),
    s("h5", 320, 480, "halt  ·  resume  ·  breakpoint\nread / write", "blue"),
    s("c3", 620, 480, "debug mode  <->  running", "green"),
]
seq_e = [
    E("a1", "r", "c1", "l"),
    E("h1", "b", "h2", "t"),
    E("h2", "b", "h3", "t"),
    E("h3", "b", "h4", "t"),
    E("h4", "r", "c2", "l", "release"),
    E("c1", "b", "c2", "t", "", True),
    E("h4", "b", "h5", "t"),
    E("h5", "r", "c3", "l", "", False, True),
]

emit([("fig_sysdbg_block", "SYSDBG block diagram", blk, blk_e),
      ("fig_sysdbg_cmd_fsm", "SYSDBG command FSM", fsm, fsm_e),
      ("fig_sysdbg_boot_wiring", "Debug boot wiring", wire, wire_e),
      ("fig_sysdbg_debug_boot", "Debug boot sequence", seq, seq_e)],
     DRAWIO, IMG)
