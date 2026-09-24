"""Figures for QNSC_SYSDBG_MAS V3.0.

    python3 tools/build_sysdbg_mas.py

New file names, so the V1.x figures that QNSC_SYSDBG_DECISIONS.md and the
presentation still show are left as they were drawn.

The structure follows the teacher's reference drawing, drawio/VLSI_SYSDBG.drawio:
a JTAG TAP in the TCK domain, an AXI manager in the AXI domain, and a 4-phase
handshake between them.

Labels are signal and state names only. What they mean is in the specification.
"""
import os
import sys
_DOC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # doc/
sys.path.insert(0, os.path.join(_DOC, "tools"))
from diagen import Node as N, Edge as E, emit

IMG = os.path.join(_DOC, "img")
DRAWIO = os.path.join(_DOC, "drawio", "QNSC_SYSDBG_MAS.drawio")

# --------------------------------------------------------------- 1. block
blk = [
    N("jpad", 20, 180, 130, 150, "JTAG pads\nTCK  TMS  TDI\nTDO  TRST_N", "blue", 10),
    N("dpad", 20, 600, 130, 50, "DBG_EN pad", "blue", 10, True),

    N("ztck", 190, 60, 400, 420, "TCK domain  ·  i_jtag_tck  ·  TRST_N & POR",
      "group", 11, True, "top"),
    N("tap", 210, 100, 170, 60, "TAP FSM\n16 states", "yellow", 10, True),
    N("ctl", 400, 100, 170, 60, "control signals\ncapture  shift  update", "box", 10),
    N("ir", 210, 190, 170, 50, "IR  4 bit", "purple", 10),
    N("drs", 210, 270, 360, 80,
      "ADDR 33  ·  DATA 32  ·  STATUS 3\nCPUDBG 1  ·  CPUHOLD 1\nIDCODE 32  ·  BYPASS 1",
      "green", 10),
    N("tdo", 210, 390, 170, 60, "TDO mux\nfalling-edge flop", "box", 10),
    N("hs", 400, 390, 170, 60, "read_req  ·  write_req\nbusy", "red", 10),

    N("cdc", 620, 160, 130, 320,
      "CDC\n\nread_req  ->\n<-  read_ack\nwrite_req  ->\n<-  write_ack\n"
      "dbgreq  ->\ncpu_hold  ->\n2FF each\n\naddr  wdata  ->\n<-  rdata  resp\nset_max_delay",
      "red", 10, True),

    N("zaxi", 780, 60, 420, 250, "AXI domain  ·  i_clk_cpu  ·  i_rst_n_sysbus",
      "group", 11, True, "top"),
    N("edge", 800, 100, 180, 70, "2FF + edge\nset_ar  ·  set_aw", "box", 10),
    N("axim", 1000, 100, 180, 70, "AXI manager\nAR  R  ·  AW  W  B", "green", 10, True),
    N("rsp", 800, 220, 180, 60, "rdata_reg  ·  resp_reg\nread_ack  ·  write_ack", "box", 10),

    N("zpor", 780, 350, 420, 200, "system domain  ·  i_clk_cpu  ·  i_rst_n_por",
      "group", 11, True, "top"),
    N("sync", 800, 390, 180, 60, "dbgreq  ·  cpu_hold\n2FF", "box", 10),
    N("dben", 800, 470, 180, 60, "DBG_EN\n2FF + capture", "box", 10),
    N("outs", 1000, 430, 180, 60, "o_cpu_debug_req\no_dbg_en  ·  o_cpu_hold", "box", 10),

    N("sbus", 1250, 100, 150, 70, "S_BUS  AXI_S0", "yellow", 10),
    N("cpu", 1250, 230, 150, 90, "Ibex CPU", "blue", 11, True),
    N("top", 1250, 430, 150, 60, "SCRC  ·  boot mux\nIO MUX", "box", 10),
]
blk_e = [
    E("jpad", "r@0.2", "tap", "l", "TMS"),
    E("jpad", "r@0.45", "ir", "l", "TDI"),
    E("tdo", "l", "jpad", "r@0.85", "TDO"),
    E("tap", "r", "ctl", "l"),
    E("ctl", "b", "drs", "t@0.764"),
    E("ir", "b", "drs", "t@0.236", "select"),
    E("drs", "b@0.236", "tdo", "t"),
    E("drs", "b@0.764", "hs", "t", "Update-DR"),
    E("hs", "r", "cdc", "l@0.781"),
    E("drs", "r@0.2", "cdc", "l@0.4"),
    E("cdc", "l@0.55", "drs", "r@0.8"),
    E("cdc", "r@0.2", "edge", "l"),
    E("edge", "r", "axim", "l"),
    E("axim", "r", "sbus", "l", "AXI4"),
    E("axim", "b", "rsp", "r", "R  B"),
    E("rsp", "l", "cdc", "r@0.28"),
    E("cdc", "r@0.8", "sync", "l"),
    E("sync", "r", "outs", "l@0.3"),
    E("dben", "r", "outs", "l@0.8"),
    E("outs", "r@0.2", "cpu", "l@0.8", "debug_req"),
    E("outs", "r@0.7", "top", "l@0.7"),
    E("dpad", "r", "dben", "b", "i_dbg_en"),
]

# --------------------------------------------------------------- 2. read handshake
def b(nid, x, y, text, style="box", bold=False):
    return N(nid, x, y, 170, 60, text, style, 10, bold)

hsk = [
    N("zt", 20, 20, 400, 420, "TCK domain", "group", 11, True, "top"),
    N("za", 460, 20, 590, 420, "AXI domain", "group", 11, True, "top"),
    b("t1", 40, 70, "Update-DR  ADDR\naddr[32] = 0,  not busy", "blue"),
    b("t2", 230, 70, "read_req_reg", "red", True),
    b("a1", 480, 70, "2FF  ·  dly"),
    b("a2", 670, 70, "set_ar\nsync & !dly"),
    b("a3", 860, 70, "AR  ·  R", "green", True),
    b("a4", 860, 220, "rdata_reg\nresp_reg"),
    b("a5", 670, 220, "read_ack_reg\ndly & !rready", "red", True),
    b("t3", 230, 220, "2FF  ·  dly"),
    b("t4", 40, 220, "Data register\nResponse register", "blue"),
    b("t5", 40, 360, "addr_reg[31:0]", "blue"),
    b("a6", 860, 360, "araddr", "green"),
    N("note", 20, 470, 1030, 50,
      "write:  Update-DR  DATA,  addr[32] = 1   ·   AW  W  B   ·   write_req  /  write_ack",
      "group", 10),
]
hsk_e = [
    E("t1", "r", "t2", "l", "set"),
    E("t2", "r", "a1", "l", "read_req"),
    E("a1", "r", "a2", "l"),
    E("a2", "r", "a3", "l"),
    E("a3", "b", "a4", "t", "rvalid"),
    E("a4", "l", "a5", "r"),
    E("a5", "l", "t3", "r", "read_ack"),
    E("t3", "l", "t4", "r", "rising edge"),
    E("t3", "t", "t2", "b", "clear"),
    E("a4", "b", "t4", "b", "rdata · resp   set_max_delay 1 TCK", False, False, 315),
    E("t5", "r", "a6", "l", "set_max_delay 1 AXI clock"),
]

# --------------------------------------------------------------- 3. debug boot wiring
wire = [
    N("dpad", 20, 40, 150, 50, "DBG_EN pad", "blue", 11, True),
    N("jpad", 20, 160, 150, 60, "JTAG pads", "blue", 11),
    N("dbg", 260, 80, 220, 200, "SYSDBG", "red", 13, True),
    N("scrc", 600, 440, 170, 60, "SCRC", "box", 12, True),
    N("iomux", 600, 50, 170, 70, "IO MUX\nJTAG pads = JTAG", "box", 10),
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
    E("dbg", "b@0.8", "sbus", "l", "AXI4"),
    E("cpu", "b", "sbus", "t"),
    E("sbus", "b", "isram", "t"),
]

emit([("fig_sysdbg_block", "SYSDBG block diagram", blk, blk_e),
      ("fig_sysdbg_handshake", "Read handshake", hsk, hsk_e),
      ("fig_sysdbg_boot_wiring", "Debug boot wiring", wire, wire_e)],
     DRAWIO, IMG)
