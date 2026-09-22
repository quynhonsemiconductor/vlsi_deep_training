import os
import sys
_DOC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # doc/
sys.path.insert(0, os.path.join(_DOC, "tools"))
from diagen import Node as N, Edge as E, emit

IMG = os.path.join(_DOC, "img")
DRAWIO = os.path.join(_DOC, "drawio", "QNSC_RAM_Block.drawio")

# nguyenquanicd/AXI4-SRAM-CONTROLLER, as the RTL actually is.
f = [
    N("busg", 10, 40, 130, 350, "S_BUS | AXI_M1", "group", 11, True, "top"),
    N("ch_aw", 20, 80, 110, 44, "AW", "blue", 11, True),
    N("ch_w", 20, 145, 110, 44, "W", "blue", 11, True),
    N("ch_ar", 20, 210, 110, 44, "AR", "blue", 11, True),
    N("ch_r", 20, 275, 110, 44, "R", "blue", 11, True),
    N("ch_b", 20, 340, 110, 44, "B", "blue", 11, True),

    N("ctrl", 180, 40, 760, 400,
      "SRAM controller  |  m_vlsi_axi4_sram", "group", 12, True, "top"),
    N("aw", 210, 80, 170, 44, "u_axfsm_wr", "purple", 10),
    N("ar", 210, 210, 170, 44, "u_axfsm_rd", "purple", 10),

    N("awf", 410, 80, 150, 44, "AWFIFO", "green", 10),
    N("wf", 410, 145, 150, 44, "WFIFO", "green", 10),
    N("arf", 410, 210, 150, 44, "ARFIFO", "green", 10),
    N("rf", 410, 275, 150, 44, "RFIFO", "green", 10),
    N("bf", 410, 340, 150, 44, "BFIFO", "green", 10),

    N("arb", 610, 90, 150, 150, "u_arbiter\nround-robin\nW / R grant", "yellow", 10),
    N("misc", 610, 270, 300, 100,
      "u_sram_misc\nFIFO pop · SRAM mux\nR and B generation", "yellow", 10),

    N("sram", 990, 270, 170, 100, "SRAM macro\nsingle port\n1-cycle read", "grey", 11, True),

    N("todo", 180, 470, 760, 66,
      "ADDED FOR QSOC | WSTRB byte-enable path: AW and W channels, "
      "an extra FIFO field,\nand byte write enables on the macro.  "
      "Without it a byte store overwrites the whole word.", "red", 10),

    N("note", 990, 400, 300, 136,
      "Burst address generation\nlives in the two AXFSMs.\n\n"
      "Constrain masters to INCR\nand FIXED: the WRAP path\n"
      "aligns but never wraps.", "box", 10, False, "top"),
]
e = [
    E("ch_aw", "r", "aw", "l"),
    E("ch_ar", "r", "ar", "l"),
    E("ch_w", "r", "wf", "l"),
    E("rf", "l", "ch_r", "r"),
    E("bf", "l", "ch_b", "r"),
    E("aw", "r", "awf", "l"),
    E("ar", "r", "arf", "l"),
    E("awf", "r", "arb", "l@0.1"),
    E("wf", "r", "arb", "l@0.62"),
    E("arf", "r", "arb", "l@0.92"),
    E("arb", "b@0.15", "misc", "t@0.15"),
    E("misc", "l@0.25", "rf", "r"),
    E("misc", "l@0.75", "bf", "r"),
    E("misc", "r@0.3", "sram", "l@0.3", "addr, wdata, we, oe"),
    E("sram", "l@0.75", "misc", "r@0.75", "rdata"),
]
emit([("fig_ram_simple", "AXI4 SRAM controller", f, e)], DRAWIO, IMG)
