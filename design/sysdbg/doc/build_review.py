"""Review drawings of SYSDBG, flip-flop level, from QNSC_SYSDBG_MAS V3.1.

    python3 design/sysdbg/doc/build_review.py

Writes sysdbg_review.drawio (one page per drawing) and exports each page to
.svg with draw.io Desktop (/Applications/draw.io.app, or DRAWIO=<path>). Not
part of the MAS: these are what the RTL is written and reviewed against
(design/README.md, "doc/"). Where a drawing and the MAS differ, the MAS is
right and the drawing is fixed.

Drawn as the teacher's reference (doc/reference/VLSI_SYSDBG.drawio): one symbol
per line of RTL -- flip-flop, multiplexer with its select written at the
inputs, gate -- and every wire named as in the RTL (Naming Rule V1.2).

Pages, in the order of the data path:
  2  JTAG side: TAP FSM, IR, one data register in full, TDO
  3  request logic: Update-DR to read_req / write_req, busy, capture   (to come)
  4  clock domain crossing                                              (to come)
  5  AXI manager                                                        (to come)
Page 1 is the MAS block diagram, doc/figures/img/fig_sysdbg_block.svg.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from sch import Sheet  # noqa: E402

DRAWIO = os.environ.get("DRAWIO", "/Applications/draw.io.app/Contents/MacOS/draw.io")


def into(s, src, pin, label=None):
    """Wire from a point to an input pin, with a jog half way."""
    (x0, y0), (x1, y1) = src, pin
    mx = (x0 + x1) / 2
    s.wire([src, (mx, y0), (mx, y1), pin] if y0 != y1 else [src, pin], label)


def feed(s, pin, label, length=150):
    """A named net entering an input pin from the left."""
    s.wire([(pin[0] - length, pin[1]), pin], label)


def sel(s, m, label, depth=34):
    """A select line from below."""
    x, y = m["s"]
    s.wire([(x, y + depth), (x, y)])
    s.text(x, y + depth + 8, label, align="center", size=9)


# ------------------------------------------------- 2. JTAG side (MAS 5, 6)
p2 = Sheet("2 JTAG side")
p2.group(140, 20, 1260, 900,
         "TCK domain: every flip-flop on i_jtag_tck (bubble = falling edge), "
         "reset w_rst_n_tck  (MAS 3, 5, 6)")

# reset
g = p2.gate(200, 70, "and")
feed(p2, g["a"], "i_jtag_trst_n", 120)
feed(p2, g["b"], "i_rst_n_por", 120)
p2.wire([g["o"], (g["o"][0] + 60, g["o"][1])], "w_rst_n_tck", arrow=False)

# TAP FSM
tap = p2.flop(340, 120, "TAP FSM\nIEEE 1149.1\nr_tap_state[3:0]", w=150, h=150)
feed(p2, tap["d"], "i_jtag_tms", 200)
outs = ["w_test_logic_reset", "w_capture_ir", "w_shift_ir", "w_update_ir",
        "w_capture_dr", "w_shift_dr", "w_update_dr"]
for k, n in enumerate(outs):
    y = 135 + 19 * k
    p2.wire([(490, y), (540, y)], arrow=False)
    p2.text(545, y, n, size=9)

# IR: shift register, then the instruction register
m1 = p2.mux(300, 320, ["cap", "sh", "#"])
feed(p2, m1["i"][0], "4'b0001")
feed(p2, m1["i"][1], "{i_jtag_tdi, r_ir_sh[3:1]}")
feed(p2, m1["i"][2], "r_ir_sh")
sel(p2, m1, "w_capture_ir / w_shift_ir")
f1 = p2.flop(380, m1["o"][1] - 18, "r_ir_sh[3:0]")
into(p2, m1["o"], f1["d"])
m2 = p2.mux(560, 320, ["tlr", "upd", "#"])
feed(p2, m2["i"][0], "4'b1110", 60)
into(p2, f1["q"], m2["i"][1])
feed(p2, m2["i"][2], "r_ir", 60)
sel(p2, m2, "w_test_logic_reset / w_update_ir")
f2 = p2.flop(640, m2["o"][1] - 18, "r_ir[3:0]")
into(p2, m2["o"], f2["d"])
p2.wire([f2["q"], (f2["q"][0] + 25, f2["q"][1])], arrow=False)

# one data register in full: ADDR; the others are the same structure
m3 = p2.mux(300, 500, ["cap", "sh", "#"])
feed(p2, m3["i"][0], "r_addr[32:0]")
feed(p2, m3["i"][1], "{i_jtag_tdi, r_dr_addr[32:1]}")
feed(p2, m3["i"][2], "r_dr_addr")
sel(p2, m3, "IR = ADDR (0100) and w_capture_dr / w_shift_dr")
f3 = p2.flop(380, m3["o"][1] - 18, "r_dr_addr[32:0]", w=100)
into(p2, m3["o"], f3["d"])
m4 = p2.mux(560, 500, ["#", "upd"])
feed(p2, m4["i"][0], "r_addr", 40)
into(p2, f3["q"], m4["i"][1])
sel(p2, m4, "IR = ADDR and w_update_dr and !w_busy")
f4 = p2.flop(640, m4["o"][1] - 18, "r_addr[32:0]")
into(p2, m4["o"], f4["d"])
p2.wire([f4["q"], (f4["q"][0] + 70, f4["q"][1])], "to page 3", arrow=True)

p2.box(160, 640, 600, 250,
       "The other data registers: the same capture / shift / hold multiplexer and shift "
       "register; an update register where the IR code updates one (MAS 6)\n\n"
       "DATA 0101, r_dr_data[31:0]: capture r_rdata_hold; update r_wdata[31:0] if !w_busy\n"
       "STATUS 0110, r_dr_status[2:0]: capture {w_busy, r_resp[1:0]}; no update\n"
       "CPUDBG 0111, r_dr_cpudbg: capture r_dbgreq; update r_dbgreq\n"
       "CPUHOLD 1000, r_dr_cpuhold: capture r_cpu_hold; update r_cpu_hold\n"
       "IDCODE 1110, r_dr_idcode[31:0]: capture 32'h0515_3001; no update\n"
       "BYPASS 1111 and every other code, r_dr_bypass: capture 1'b0; no update\n\n"
       "Reset: r_ir 1110, r_addr 0, r_wdata 0, r_dbgreq 0, r_cpu_hold 1", align="left")

# TDO
m5 = p2.mux(880, 330, ["0100", "0101", "0110", "0111", "1000", "1110", "#"], w=40)
for k, n in enumerate(["r_dr_addr[0]", "r_dr_data[0]", "r_dr_status[0]", "r_dr_cpudbg",
                       "r_dr_cpuhold", "r_dr_idcode[0]", "r_dr_bypass"]):
    feed(p2, m5["i"][k], n, 120)
sel(p2, m5, "r_ir[3:0]")
m6 = p2.mux(1000, m5["o"][1] - 33, ["1", "0"])
p2.wire([(m6["i"][0][0] - 50, m6["i"][0][1]), m6["i"][0]], "r_ir_sh[0]")
into(p2, m5["o"], m6["i"][1])
sel(p2, m6, "w_shift_ir")
f5 = p2.flop(1110, m6["o"][1] - 18, "r_tdo", w=80, falling=True)
into(p2, m6["o"], f5["d"])
p2.text(1290, f5["q"][1], "o_jtag_tdo", size=11, bold=True)
p2.wire([f5["q"], (1285, f5["q"][1])])

g2 = p2.gate(990, 640, "or")
feed(p2, g2["a"], "w_shift_ir", 100)
feed(p2, g2["b"], "w_shift_dr", 100)
f6 = p2.flop(1110, g2["o"][1] - 18, "r_tdo_oe", w=80, falling=True)
into(p2, g2["o"], f6["d"])
p2.text(1290, f6["q"][1], "o_jtag_tdo_oe", size=11, bold=True)
p2.wire([f6["q"], (1285, f6["q"][1])])

SHEETS = [("sysdbg_review_2_jtag", p2)]

if __name__ == "__main__":
    path = os.path.join(HERE, "sysdbg_review.drawio")
    open(path, "w").write(Sheet.file([s for _, s in SHEETS]))
    for i, (key, _) in enumerate(SHEETS):
        subprocess.run([DRAWIO, "-x", "-f", "svg", "-p", str(i + 1), "-o",
                        os.path.join(HERE, key + ".svg"), path],
                       check=True, capture_output=True)
        print("wrote", key + ".svg")
