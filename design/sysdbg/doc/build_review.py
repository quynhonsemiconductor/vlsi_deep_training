"""Review drawings of SYSDBG, flip-flop level, from QNSC_SYSDBG_MAS V3.1.

    python3 design/sysdbg/doc/build_review.py

Writes sysdbg_review.drawio (one page per drawing, editable) and one .svg per
page, beside this file. Not part of the MAS: these are what the RTL is written
and reviewed against (design/README.md, "doc/"). Where a drawing and the MAS
differ, the MAS is right and the drawing is fixed.

Pages, in the order of the data path:
  2  JTAG side: TAP FSM outputs, IR, data registers, TDO
  3  request logic: Update-DR to read_req / write_req, busy, capture   (to come)
  4  clock domain crossing, flip-flop level                             (to come)
  5  AXI manager                                                        (to come)
Page 1 is the MAS block diagram, doc/figures/img/fig_sysdbg_block.svg.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, os.path.join(ROOT, "doc", "build", "tools"))
from diagen import Node as N, Edge as E, emit  # noqa: E402

# ------------------------------------------------- 2. JTAG side (MAS 5, 6)
# Every register here is clocked by i_jtag_tck and reset by
# w_rst_n_tck = i_jtag_trst_n AND i_rst_n_por (MAS 3).
jtag = [
    N("zt", 160, 20, 900, 640, "TCK domain  ·  i_jtag_tck  ·  w_rst_n_tck = i_jtag_trst_n & i_rst_n_por",
      "group", 11, True, "top"),

    N("p_tms", 20, 80, 110, 30, "i_jtag_tms", "port", 10),
    N("p_tdi", 20, 277, 110, 30, "i_jtag_tdi", "port", 10),
    N("p_tdo", 1100, 560, 120, 30, "o_jtag_tdo", "port", 10),
    N("p_oe", 1100, 610, 120, 30, "o_jtag_tdo_oe", "port", 10),

    N("tap", 180, 60, 200, 70, "TAP FSM\nIEEE 1149.1, 16 states", "box", 10, True),
    N("ctl", 420, 60, 300, 70,
      "w_capture_ir  w_shift_ir  w_update_ir\nw_capture_dr  w_shift_dr  w_update_dr\nw_test_logic_reset",
      "box", 9),

    N("irs", 180, 170, 200, 60, "IR shift  4 bit\nCapture-IR loads 0001", "box", 10),
    N("ir", 420, 170, 300, 60, "r_ir  4 bit\nUpdate-IR loads shift\nTest-Logic-Reset loads 1110 (IDCODE)",
      "box", 9),
    N("dec", 760, 170, 280, 60, "IR decode: one DR between TDI and TDO\nunlisted codes act as BYPASS",
      "box", 9),

    N("dr_addr", 180, 270, 200, 44, "ADDR 33   0100\ncapture r_addr", "box", 9),
    N("dr_data", 180, 322, 200, 44, "DATA 32   0101\ncapture r_rdata_hold", "box", 9),
    N("dr_stat", 180, 374, 200, 44, "STATUS 3   0110\ncapture {busy, r_resp}", "box", 9),
    N("dr_dbg", 180, 426, 200, 44, "CPUDBG 1   0111\ncapture r_dbgreq", "box", 9),
    N("dr_hold", 180, 478, 200, 44, "CPUHOLD 1   1000\ncapture r_cpu_hold", "box", 9),
    N("dr_id", 180, 530, 200, 44, "IDCODE 32   1110\ncapture 0x0515_3001", "box", 9),
    N("dr_byp", 180, 582, 200, 44, "BYPASS 1   1111\ncapture 0", "box", 9),

    N("upd", 420, 270, 300, 200,
      "Update-DR, only when the IR selects it\n\nADDR -> r_addr[32:0]    if !busy\nDATA -> r_wdata[31:0]   if !busy\n"
      "CPUDBG -> r_dbgreq\nCPUHOLD -> r_cpu_hold\n\nSTATUS, IDCODE, BYPASS: nothing\n\n"
      "reset: r_addr 0, r_wdata 0,\nr_dbgreq 0, r_cpu_hold 1", "box", 9),
    N("req", 420, 600, 300, 50, "to page 3: request logic\n(read_req, write_req, busy)", "red", 9),

    N("mux", 760, 380, 280, 70, "TDO select\nShift-IR: IR shift bit 0\nShift-DR: bit 0 of the selected DR",
      "box", 9),
    N("ff", 760, 540, 280, 70,
      "TDO flip-flop on the FALLING edge of i_jtag_tck\no_jtag_tdo_oe = 1 in Shift-IR, Shift-DR",
      "box", 9, True),
]
jtag_e = [
    E("p_tms", "r", "tap", "l", "TMS"),
    E("tap", "r", "ctl", "l"),
    E("p_tdi", "r", "dr_addr", "l@0.3", "TDI"),
    E("p_tdi", "r", "irs", "l", mid=150),
    E("irs", "r", "ir", "l", "Update-IR"),
    E("ir", "r", "dec", "l"),
    E("dec", "b", "mux", "t", "select"),
    E("dr_addr", "r", "upd", "l@0.2"),
    E("dr_hold", "r", "upd", "l@0.9"),
    E("upd", "b", "req", "t", "Update-DR ADDR / DATA"),
    E("mux", "b", "ff", "t"),
    E("dr_id", "r", "mux", "l", "bit 0 of every DR", mid=740),
    E("ff", "r", "p_tdo", "l"),
    E("ff", "r@0.8", "p_oe", "l"),
]

PAGES = [("sysdbg_review_2_jtag", "SYSDBG 2: JTAG side (MAS 5, 6)", jtag, jtag_e)]

if __name__ == "__main__":
    emit(PAGES, os.path.join(HERE, "sysdbg_review.drawio"), HERE)
    for key, *_ in PAGES:                      # keep the svg; the png is a by-product
        os.remove(os.path.join(HERE, key + ".png"))
