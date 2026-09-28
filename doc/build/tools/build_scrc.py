"""SCRC figures and timing diagrams for QNSC_SCRC_MAS.

Block diagrams (diagen): top level, domains, reset filter, RRC, CTRL, APB guard,
MCPU program states. Timing diagrams (wavegen): RRC, power-up, clock gating,
APB guard. All monochrome.

Rules kept in every figure: a block carries its name only; a signal that leaves
the block being drawn carries its port name; numbers live in the specification's
tables, except where a timing diagram needs one to be read.

    python3 doc/build/tools/build_scrc.py
"""
import os
import sys
_DOC = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # doc/
sys.path.insert(0, os.path.join(_DOC, "build", "tools"))
from diagen import Node as N, Edge as E, emit
from wavegen import wave

IMG = os.path.join(_DOC, "figures", "img")
DRAWIO = os.path.join(_DOC, "figures", "drawio", "QNSC_SCRC.drawio")

# ---------- Figure: SCRC top level ----------
# Straight wires wherever two ports line up; the anchor fractions below are the
# ones that make them line up.
blk = [
    N("scrc", 170, 90, 730, 510, "m_qnsc_scrc", "group", 12, True, va="top"),
    N("ctl", 190, 230, 610, 190, "controller", "group", 10, va="top"),

    N("p_por", 10, 130, 140, 40, "i_rst_n_pad", "port", 10),
    N("p_apb", 10, 350, 140, 40, "i_bus_apb_*\n(APB_M0)", "port", 10),
    N("p_clk", 10, 485, 140, 30, "i_clk_pad", "port", 10),
    N("p_wdt", 600, 30, 140, 30, "i_wdt_rst_req", "port", 10),
    N("p_rpor", 930, 120, 170, 30, "o_rst_n_por", "port", 10),
    N("p_cause", 930, 150, 170, 30, "o_cause_we_wdt, _sw", "port", 10),
    N("p_blk", 930, 313, 170, 30, "o_guard_blk[17:0]", "port", 10),
    N("p_busy", 930, 337, 170, 30, "i_guard_busy[17:0]", "port", 10),
    N("p_oclk", 930, 476, 170, 30, "o_clk_<d>  x 18", "port", 10),
    N("p_orst", 930, 504, 170, 30, "o_rst_n_<d>  x 18", "port", 10),
    N("p_hold", 620, 620, 160, 30, "i_dbg_cpu_hold", "port", 10),

    N("filt", 190, 125, 90, 50, "Reset\nFilter", "box", 10),
    N("rsync", 305, 125, 110, 50, "Reset\nSync", "box", 10),
    N("rrc", 600, 125, 140, 50, "RRC", "box", 11, True),
    N("rom", 205, 290, 80, 40, "CRM ROM", "box", 10),
    N("mcpu", 305, 290, 90, 40, "MCPU", "box", 11, True),
    N("wf1", 425, 290, 40, 40, "WF", "box", 10),
    N("wf2", 425, 350, 40, 40, "WF", "box", 10),
    N("bus", 500, 280, 90, 120, "APB\nBUS", "box", 10),
    N("csr", 640, 310, 120, 60, "SCRC CSR", "box", 11, True),
    N("buf", 300, 485, 50, 30, "BUF", "box", 10),
    N("ctrl", 600, 470, 220, 70, "CTRL  x 18", "box", 11, True),
]
blk_e = [
    E("p_por", "r", "filt", "l"),
    E("filt", "r", "rsync", "l"),
    E("rsync", "r", "rrc", "l", "w_rst_n_por"),
    E("p_wdt", "b", "rrc", "t"),
    E("rrc", "r@0.2", "p_rpor", "l"),
    E("rrc", "r@0.8", "p_cause", "l"),
    E("rrc", "b@0.2", "ctl", "t@0.7180", "w_rst_n_sys"),
    E("csr", "t@0.25", "rrc", "b@0.5", "SW_RST"),
    E("rom", "r", "mcpu", "l"),
    E("mcpu", "r", "wf1", "l"),
    E("p_apb", "r", "wf2", "l"),
    E("wf1", "r", "bus", "l@0.25"),
    E("wf2", "r", "bus", "l@0.75"),
    E("bus", "r", "csr", "l"),
    E("csr", "r@0.3", "p_blk", "l"),
    E("p_busy", "l", "csr", "r@0.7"),
    E("csr", "b", "ctrl", "t@0.4545", "ICG_EN, RST_REL"),
    E("p_clk", "r", "buf", "l"),
    E("buf", "r", "ctrl", "l@0.4286", "w_clk_root"),
    E("ctrl", "r@0.3", "p_oclk", "l"),
    E("ctrl", "r@0.7", "p_orst", "l"),
    E("p_hold", "t", "ctrl", "b@0.4545"),
]

# ---------- Figure: the 18 domains ----------
def _dom(nid, x, y, name, bit, style="box"):
    return N(nid, x, y, 100, 40, "%s\nbit %s" % (name, bit), style, 10)


_AO = [("cpu", "31"), ("sbus", "0"), ("pbus", "1"), ("rom", "11"), ("ram", "12"),
       ("sysdbg", "14 (POR)"), ("wdt", "2")]
_GT = [("timer_0", "3"), ("timer_1", "4 (off)"), ("uart_0", "5"),
       ("uart_1", "6"), ("spi", "7"), ("i2c", "8"), ("gpio_0", "9"), ("dma", "10"),
       ("pwm", "15"), ("gpio_1", "16"), ("gpio_2", "17")]
dom = [N("ao", 20, 20, 250, 290, "always-on   ICG enable = 1", "group", 11, True, va="top"),
       N("gt", 300, 20, 490, 290, "gateable   ICG enable = ICG_EN[n]", "group", 11, True, va="top")]
for i, (n, b) in enumerate(_AO):
    dom.append(_dom("a%d" % i, 35 + (i % 2) * 115, 55 + (i // 2) * 60, n, b))
for i, (n, b) in enumerate(_GT):
    dom.append(_dom("g%d" % i, 315 + (i % 4) * 118, 55 + (i // 4) * 52, n, b,
                    "red" if n == "timer_1" else "box"))

# ---------- Figure: Reset Filter (after the mentor's VLSI_SCRC.drawio) ----------
filt = [
    N("grp", 150, 20, 700, 240, "m_qnsc_scrc_rst_filter", "group", 11, True, va="top"),
    N("pad", 10, 115, 120, 30, "i_rst_n_pad", "port", 10),
    N("line", 170, 95, 300, 70, "", "group", 10),
    N("d1", 185, 110, 70, 40, "DLY", "box", 10, True),
    N("d2", 285, 110, 70, 40, "DLY", "box", 10, True),
    N("d3", 385, 110, 70, 40, "DLY", "box", 10, True),
    N("set", 530, 50, 90, 40, "SET", "box", 10),
    N("clr", 530, 170, 90, 40, "CLR", "box", 10),
    N("ff", 680, 90, 130, 80, "FF\nD = 0, CK = 0", "box", 10, True),
    N("out", 880, 115, 150, 30, "to Reset Sync", "port", 10),
]
filt_e = [
    E("pad", "r", "d1", "l"),
    E("d1", "r", "d2", "l"),
    E("d2", "r", "d3", "l"),
    E("line", "t@0.5", "set", "l", "pad + 3 taps"),
    E("line", "b@0.5", "clr", "l", "pad + 3 taps"),
    E("set", "r", "ff", "l@0.25", "all 1"),
    E("clr", "r", "ff", "l@0.75", "all 0"),
    E("ff", "r", "out", "l"),
]

# ---------- Figure: Reset Request Controller ----------
rrc = [
    N("grp", 170, 15, 640, 250, "m_qnsc_scrc_rrc   reset: w_rst_n_por", "group", 11, True, va="top"),
    N("wdt", 10, 60, 140, 30, "i_wdt_rst_req", "port", 10),
    N("sw", 10, 150, 140, 30, "SW_RST", "port", 10),
    N("sync", 190, 50, 100, 50, "SYNC\n2-FF", "box", 10),
    N("or", 350, 95, 60, 40, "OR", "box", 10),
    N("cnt", 460, 85, 120, 60, "CNT\n4-bit", "box", 10, True),
    N("ff", 640, 90, 80, 50, "FF", "box", 10),
    N("cause", 460, 195, 120, 40, "CAUSE", "box", 10),
    N("out", 840, 100, 150, 30, "w_rst_n_sys", "port", 10),
    N("cout", 840, 200, 150, 30, "o_cause_we_wdt, _sw", "port", 10),
    N("porin", 10, 280, 140, 30, "w_rst_n_por", "port", 10),
    N("porout", 840, 280, 150, 30, "o_rst_n_por", "port", 10),
]
rrc_e = [
    E("wdt", "r", "sync", "l"),
    E("sync", "r", "or", "l@0.3"),
    E("sw", "r", "or", "l@0.75"),
    E("or", "r", "cnt", "l"),
    E("cnt", "r", "ff", "l"),
    E("ff", "r", "out", "l"),
    E("cnt", "b", "cause", "t", "load"),
    E("cause", "r", "cout", "l"),
    E("porin", "r", "porout", "l"),
]

# ---------- Figure: one domain controller ----------
ctrl = [
    N("grp", 190, 20, 380, 240, "m_qnsc_scrc_ctrl", "group", 11, True, va="top"),
    N("clk", 20, 50, 130, 30, "w_clk_root", "port", 10),
    N("en", 20, 110, 130, 30, "ICG_EN[n] or 1", "port", 10),
    N("rel", 20, 190, 130, 30, "RST_REL[n]", "port", 10),
    N("icg", 230, 55, 120, 70, "ICG", "box", 11, True),
    N("sync", 400, 175, 130, 60, "RST SYNC", "box", 11, True),
    N("oclk", 610, 75, 130, 30, "o_clk_<d>", "port", 10),
    N("orst", 610, 190, 130, 30, "o_rst_n_<d>", "port", 10),
]
ctrl_e = [
    E("clk", "r", "icg", "l@0.1429"),
    E("en", "r", "icg", "l@0.8571"),
    E("icg", "r", "oclk", "l"),
    E("icg", "b", "sync", "t@0.1923"),
    E("rel", "r", "sync", "l"),
    E("sync", "r", "orst", "l"),
]

# ---------- Figure: complete operation flow (the one figure to present) ----------
# From any reset source to the runtime loop. Step numbers are those of 7.5.
_X, _W, _H = 40, 300, 44
def _s(nid, y, label, style="box", bold=False, h=_H):
    return N(nid, _X, y, _W, h, label, style, 10, bold)
prog = [
    _s("src", 0, "Reset source: POR, WDT bite or SW_RST", "term", True),
    _s("rrc", 70, "RRC: w_rst_n_sys = 0 for 16 cycles\nWDT / SW cause set in SYSCSR"),
    _s("csr", 140, "SCRC CSR at reset values: RST_REL = 0,\nICG_EN = 0, APB_BLK = 0x3_87F8\nevery domain except sysdbg in reset", h=54),
    _s("s1", 220, "1. ICG_EN <- CLK_EN  (all clocks but timer_1)"),
    _s("s2", 290, "2. wait >= 3 cycles"),
    _s("s3", 360, "3. RST_REL <- every domain except the CPU"),
    _s("s4", 430, "4. wait >= 16 cycles"),
    _s("s5", 500, "5. APB_BLK <- NOT CLK_EN  (guards open)"),
    _s("s6", 570, "6. RST_REL[CPU] <- 1  (CPU released last)", bold=True),
    _s("idle", 650, "IDLE: read CLK_EN", bold=True),
    N("d1", _X + 50, 730, 200, 70, "CLK_EN\nchanged?", "diamond", 10),
    N("gate", 440, 735, 330, 60,
      "stop: APB_BLK = 1, wait APB_BUSY = 0, ICG_EN = 0\nstart: ICG_EN = 1, wait 3, APB_BLK = 0", "box", 10),
    N("ibex", 440, 570, 330, 44, "Ibex starts when i_dbg_cpu_hold = 0\n(QNSC_BOOT_SPEC)", "term", 10),
    N("any", 440, 0, 330, 44, "WDT bite or Ibex writes SW_RST, at any time", "box", 10),
    N("padl", 0, 760, 1, 1, "", "port", 10),
    N("padr", 840, 760, 1, 1, "", "port", 10),
]
prog_e = [
    E("src", "b", "rrc", "t"), E("rrc", "b", "csr", "t"), E("csr", "b", "s1", "t"),
    E("s1", "b", "s2", "t"), E("s2", "b", "s3", "t"), E("s3", "b", "s4", "t"),
    E("s4", "b", "s5", "t"), E("s5", "b", "s6", "t"), E("s6", "b", "idle", "t"),
    E("s6", "r", "ibex", "l", dashed=True),
    E("idle", "b", "d1", "t"),
    E("d1", "r", "gate", "l", "yes"),
    E("d1", "l", "idle", "l", "no", mid=15),
    E("gate", "r", "idle", "r", mid=800),
    E("any", "l", "src", "r", dashed=True),
]

# ---------- Figure: reset tree ----------
# Three levels: power-on (everything), chip reset (all but the POR-only logic),
# CPU hold (the CPU alone). No per-peripheral reset.
rt = [
    N("pad", 0, 40, 110, 40, "i_rst_n_pad", "port", 10),
    N("flt", 130, 40, 110, 40, "Reset Filter", "box", 10),
    N("rsy", 260, 40, 110, 40, "Reset Sync", "box", 10),
    N("porl", 520, 10, 560, 90, "reset by POR only", "group", 10, True, va="top"),
    N("p1", 540, 45, 150, 40, "RRC flip-flops", "box", 10),
    N("p2", 710, 45, 150, 40, "SYSCSR", "box", 10),
    N("p3", 880, 45, 180, 40, "CTRL sysdbg", "box", 10),
    N("wdt", 150, 195, 150, 30, "i_wdt_rst_req", "port", 10),
    N("sw", 150, 225, 150, 30, "SW_RST", "port", 10),
    N("rrc", 420, 160, 120, 100, "RRC\nstretch 16\n(WDT, SW)", "box", 11, True),
    N("mcpu", 660, 185, 150, 50, "MCPU, SCRC CSR", "box", 10),
    N("c17", 960, 150, 170, 50, "CTRL x 17", "box", 10, True),
    N("and", 960, 260, 60, 40, "AND", "box", 10),
    N("ccpu", 1050, 260, 80, 40, "CTRL cpu", "box", 10, True),
    N("chip", 1180, 120, 280, 230, "reset by POR, WDT, SW", "group", 10, True, va="top"),
    N("d_bus", 1200, 150, 240, 40, "sbus, pbus, rom, ram, wdt", "box", 10),
    N("d_per", 1200, 200, 240, 40, "11 peripheral domains", "box", 10),
    N("d_cpu", 1200, 260, 240, 40, "cpu  (also CPU hold)", "box", 11, True),
    N("hold", 870, 330, 220, 30, "NOT i_dbg_cpu_hold", "port", 10),
]
rt_e = [
    E("pad", "r", "flt", "l"), E("flt", "r", "rsy", "l"),
    E("rsy", "r", "porl", "l@0.5556", "w_rst_n_por"),
    E("rsy", "b", "rrc", "l@0.2"),
    E("wdt", "r", "rrc", "l@0.5"), E("sw", "r", "rrc", "l@0.8"),
    E("rrc", "r@0.5", "mcpu", "l", "w_rst_n_sys"),
    E("mcpu", "r@0.3", "c17", "l", "RST_REL[17:0]", mid=900),
    E("mcpu", "r@0.8", "and", "l", "RST_REL[31]", mid=900),
    E("hold", "t", "and", "b@0.5"),
    E("and", "r", "ccpu", "l"),
    E("c17", "r@0.3", "d_bus", "l", mid=1160),
    E("c17", "r@0.7", "d_per", "l", mid=1165),
    E("ccpu", "r", "d_cpu", "l"),
]

# ---------- Figure: APB guard ----------
guard = [
    N("pbus", 0, 80, 120, 60, "P_BUS\nslave port n", "port", 10),
    N("guard", 230, 70, 220, 80, "m_qnsc_scrc_apb_guard", "box", 11, True),
    N("ip", 560, 80, 150, 60, "peripheral\nwrapper n", "box", 10),
    N("scrc", 265, 220, 150, 40, "m_qnsc_scrc", "box", 10),
    N("clk", 0, 230, 170, 30, "o_clk_pbus, o_rst_n_pbus", "port", 10),
]
guard_e = [
    E("pbus", "r", "guard", "l", "APB", bidir=True),
    E("guard", "r", "ip", "l", "APB", bidir=True),
    E("scrc", "t@0.3", "guard", "b@0.3636", "APB_BLK[n]"),
    E("guard", "b@0.6364", "scrc", "t@0.7", "busy"),
    E("clk", "r", "guard", "b@0.1"),
]

emit([
    ("fig_scrc_block", "SCRC top level", blk, blk_e),
    ("fig_scrc_domains", "SCRC domains", dom, []),
    ("fig_scrc_filter", "Reset Filter", filt, filt_e),
    ("fig_scrc_rrc", "Reset Request Controller", rrc, rrc_e),
    ("fig_scrc_rsttree", "SCRC reset tree", rt, rt_e),
    ("fig_scrc_ctrl", "Domain controller", ctrl, ctrl_e),
    ("fig_scrc_flow", "SCRC operation flow", prog, prog_e),
    ("fig_scrc_guard", "APB guard", guard, guard_e),
], DRAWIO, IMG)

# ---------- Timing: watchdog bite through RRC ----------
# The request is cleared by o_rst_n_wdt (aon_timer rst_aon_ni), asynchronously.
wave("wave_scrc_rrc", [
    ("i_clk_pad", "clk"),
    ("i_wdt_rst_req", "bit", "001110000000000"),
    ("wdt_s (synchronised)", "bit", "000011100000000"),
    ("o_cause_we_wdt", "bit", "000001111111110"),
    ("CNT", "bus", ["0", None, None, None, None, "15", "14", "13", "12", "11", "..",
                    "2", "1", "0", None]),
    ("w_rst_n_sys", "bit", "111110000000001"),
    ("o_rst_n_wdt", "bit", "111110000000000"),
    ("", "note", [(5, 14, "16 cycles")]),
], steps=15, gaps=(10,), img_dir=IMG)

# ---------- Timing: power-up sequence, steps of 7.5 ----------
_n = 20
wave("wave_scrc_powerup", [
    ("i_clk_pad", "clk"),
    ("w_rst_n_sys", "bit", "0" + "1" * 19),
    ("ICG_EN", "bus", ["0", None, None, "0x387E8"] + [None] * 16),
    ("o_clk_uart_0", "gclk", "000" + "1" * 17),
    ("o_clk_timer_1", "gclk", "0" * _n),
    ("RST_REL", "bus", ["0"] + [None] * 6 + ["0x39FFF"] + [None] * 7 + ["0x80039FFF"]
     + [None] * 4),
    ("o_rst_n_uart_0", "bit", "0" * 9 + "1" * 11),
    ("o_rst_n_timer_1", "bit", "0" * _n),
    ("APB_BLK", "bus", ["0x387F8"] + [None] * 12 + ["0x10"] + [None] * 6),
    ("o_rst_n_cpu", "bit", "0" * 17 + "111"),
    ("", "note", [(3, 7, ">= 3"), (7, 13, ">= 16"), (15, 17, "2"), (17, 19, "2")]),
], steps=_n, gaps=(10,), img_dir=IMG,
    marks=[(1, "1"), (3, "2"), (7, "3"), (13, "5"), (15, "6"), (19, "first fetch")])

# ---------- Timing: stop, then start, the clock of domain n ----------
wave("wave_scrc_gate", [
    ("i_clk_pad", "clk"),
    ("CLK_EN[n]", "bit", "1" + "0" * 10 + "1" * 9),
    ("APB_BLK[n]", "bit", "000" + "1" * 14 + "000"),
    ("i_guard_busy[n]", "bit", "11111" + "0" * 15),
    ("ICG_EN[n]", "bit", "1" * 7 + "0" * 6 + "1" * 7),
    ("o_clk_<d>", "gclk", "1" * 8 + "0" * 6 + "1" * 6),
    ("", "note", [(3, 7, "until busy = 0"), (13, 17, ">= 3")]),
], steps=20, img_dir=IMG,
    marks=[(1, "Ibex: CLK_EN[n] = 0"), (11, "Ibex: CLK_EN[n] = 1")])

# ---------- Timing: APB guard, one blocked and one forwarded transfer ----------
wave("wave_scrc_guard", [
    ("o_clk_pbus", "clk"),
    ("PSEL (P_BUS)", "bit", "011001110"),
    ("PENABLE", "bit", "001000110"),
    ("APB_BLK[n]", "bit", "111100000"),
    ("PREADY (to P_BUS)", "bit", "001000010"),
    ("PSLVERR", "bit", "001000000"),
    ("PSEL (to IP)", "bit", "000001110"),
    ("busy", "bit", "000001110"),
], steps=9, img_dir=IMG, marks=[(1, "blocked"), (5, "forwarded")])
