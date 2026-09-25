import os
import sys
_DOC = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # doc/
sys.path.insert(0, os.path.join(_DOC, "build", "tools"))
from diagen import Node as N, Edge as E, emit

IMG = os.path.join(_DOC, "figures", "img")
DRAWIO = os.path.join(_DOC, "figures", "drawio", "QNSC_Timer_PWM.drawio")

# ---------- Figure 1: TIMER0 and TIMER1 in QSOC ----------
t = [
    N("pbus", 200, 40, 840, 50, "P_BUS  (APB4, 20 MHz)", "yellow", 13, True),

    N("t0", 200, 170, 300, 140,
      "TIMER0\napb_timer_unit\n0x8001_8000\nMODE_64 = 1", "red", 11, True),
    N("t1", 740, 170, 300, 140,
      "TIMER1\napb_timer_unit\n0x8001_C000\nMODE_64 = 0", "red", 11, True),

    N("g0", 20, 177, 115, 56, "SCRC clock gate\nCLK_EN[TBD]\nopen at reset", "box", 9),
    N("r0", 20, 250, 115, 40, "SCRC\no_rst_n_timer_0", "box", 9),
    N("g1", 560, 177, 115, 56, "SCRC clock gate\nCLK_EN[TBD]\nclosed at reset", "box", 9),
    N("r1", 560, 250, 115, 40, "SCRC\no_rst_n_timer_1", "box", 9),

    N("tie0", 176, 380, 120, 56, "event_lo_i = 0\nevent_hi_i = 0\nref_clk_i = 0", "box", 9),
    N("nc0h", 385, 380, 50, 30, "n.c.", "box", 9),
    N("nc0b", 445, 380, 50, 30, "n.c.", "box", 9),
    N("tie1", 716, 380, 120, 56, "event_lo_i = 0\nevent_hi_i = 0\nref_clk_i = 0", "box", 9),
    N("nc1b", 985, 380, 50, 30, "n.c.", "box", 9),

    N("intmap", 200, 480, 840, 160, "INTMAP", "group", 11, True, va="top"),
    N("or1", 860, 505, 105, 36, "OR", "box", 10),
    N("f10", 275, 570, 120, 50, "irq_fast_i[10]\nmcause 26", "grey", 10, True),
    N("f6", 852.5, 570, 120, 50, "irq_fast_i[6]\nmcause 22", "grey", 10, True),
]
e = [
    E("pbus", "b@0.1786", "t0", "t", "APB_M6"),
    E("pbus", "b@0.8214", "t1", "t", "APB_M7"),
    E("g0", "r", "t0", "l@0.25", "HCLK"),
    E("r0", "r", "t0", "l@0.7143", "HRESETn"),
    E("g1", "r", "t1", "l@0.25", "HCLK"),
    E("r1", "r", "t1", "l@0.7143", "HRESETn"),
    E("tie0", "t", "t0", "b@0.12"),
    E("tie1", "t", "t1", "b@0.12"),
    E("t0", "b@0.45", "f10", "t", "irq_lo_o"),
    E("t0", "b@0.70", "nc0h", "t", "irq_hi_o"),
    E("t0", "b@0.90", "nc0b", "t", "busy_o"),
    E("t1", "b@0.45", "or1", "t@0.1429", "irq_lo_o"),
    E("t1", "b@0.70", "or1", "t@0.8571", "irq_hi_o"),
    E("t1", "b@0.90", "nc1b", "t", "busy_o"),
    E("or1", "b", "f6", "t"),
]

# ---------- Figure 2: inside one TIMER instance ----------
_RW, _RX = 360, 380          # register file width and left edge


def _rf(x):
    return "%.4f" % ((x - _RX) / _RW)


ti = [
    N("ev", 480, 40, 110, 40, "event_lo_i\nevent_hi_i", "box", 10),
    N("busy", 560, 110, 70, 30, "busy_o", "box", 10),

    N("plo", 400, 180, 110, 60, "prescaler lo\n/ (PRESC+1)\nbypass when\nPRESC_EN = 0", "box", 10),
    N("clo", 615, 180, 140, 60, "counter_lo  32-bit\n== TIMER_CMP_LO", "box", 10, True),
    N("ref", 200, 265, 120, 70, "ref_clk_i\nsync + edge\n4 flops", "box", 10),
    N("regs", _RX, 265, _RW, 70,
      "APB register file\nCFG_REG  TIMER_VAL  TIMER_CMP\nTIMER_START  TIMER_RESET", "box", 10, True),
    N("phi", 400, 360, 110, 60, "prescaler hi\n/ (PRESC+1)\nbypass when\nPRESC_EN = 0", "box", 10),
    N("chi", 615, 360, 140, 60, "counter_hi  32-bit\n== TIMER_CMP_HI", "box", 10, True),

    N("irq", 870, 180, 100, 240, "IRQ logic\n\nIRQ_EN\nMODE_64", "box", 10, True),
    N("olo", 1020, 183, 90, 30, "irq_lo_o", "box", 10),
    N("ohi", 1020, 387, 90, 30, "irq_hi_o", "box", 10),

    N("rin", 40, 285, 110, 30, "ref_clk_i", "box", 10),
    N("apb", 500, 470, 120, 40, "APB\nPADDR[5:0]", "box", 10),
]
ei = [
    E("ev", "b", "regs", "t@" + _rf(535)),
    E("regs", "t@" + _rf(595), "busy", "b"),
    E("apb", "t", "regs", "b@" + _rf(560), "", False, True),
    E("rin", "r", "ref", "l"),
    E("ref", "t", "plo", "l", "ref edge"),
    E("ref", "b", "phi", "l", "ref edge"),
    E("regs", "t@" + _rf(455), "plo", "b", "CFG"),
    E("regs", "b@" + _rf(455), "phi", "t", "CFG"),
    E("regs", "t@" + _rf(685), "clo", "b", "CMP"),
    E("regs", "b@" + _rf(685), "chi", "t", "CMP"),
    E("plo", "r", "clo", "l", "tick"),
    E("phi", "r", "chi", "l", "tick"),
    E("clo", "r@0.75", "chi", "r@0.25", "MODE_64 carry", mid=800),
    E("clo", "r@0.3", "irq", "l@0.075", "match_lo"),
    E("chi", "r@0.7", "irq", "l@0.925", "match_hi"),
    E("irq", "r@0.075", "olo", "l"),
    E("irq", "r@0.925", "ohi", "l"),
]

# ---------- Figure 2: the PWM block ----------
# Rows are the four timer modules; signals flow left to right. The anchor
# fractions are chosen so every wire between two boxes is a straight line.
_MY = [240 + i * 103 for i in range(4)]          # timer_module row tops, h = 70
_CG_Y, _CG_H = 240, 380                          # the clock-gate column
_CH_Y, _CH_H = 240, 380                          # the channel collection bar


def _cg(y):
    return "%.4f" % ((y - _CG_Y) / _CG_H)


def _ch(y):
    return "%.4f" % ((y - _CH_Y) / _CH_H)


p = [
    N("pbus2", 270, -30, 390, 40, "P_BUS  (APB)", "yellow", 13, True),
    N("pwm", 170, 90, 800, 640, "PWM   apb_adv_timer   0x8003_0000",
      "group", 12, True, va="top"),

    N("regs", 300, 130, 330, 56,
      "APB register file   adv_timer_apb_if\n"
      "CMD  CFG  TH  CHn_TH  CHn_LUT  COUNTER  EVENT_CFG  CH_EN", "box", 10, True),

    N("cg", 200, _CG_Y, 120, _CG_H,
      "4 clock gates\none per module\n\nen = CH_EN[i]\n\ntest_en =\ndft_cg_enable_i",
      "box", 10),

    N("m0", 400, _MY[0], 220, 70,
      "timer_module 0\ninput_stage (IN_SEL)\nprescaler, 16-bit counter\n4 comparators", "blue", 10),
    N("m1", 400, _MY[1], 220, 70,
      "timer_module 1\ninput_stage (IN_SEL)\nprescaler, 16-bit counter\n4 comparators", "blue", 10),
    N("m2", 400, _MY[2], 220, 70,
      "timer_module 2  (internal)\ninput_stage (IN_SEL)\nprescaler, 16-bit counter\n4 comparators", "blue", 10),
    N("m3", 400, _MY[3], 220, 70,
      "timer_module 3  (internal)\ninput_stage (IN_SEL)\nprescaler, 16-bit counter\n4 comparators", "blue", 10),

    N("chbus", 700, _CH_Y, 60, _CH_H, "16\nch", "box", 10, True),
    N("pool", 350, 650, 270, 50,
      "input pool, 48 signals\next_sig_i[31:0] + ch[15:0]", "box", 10),
    N("evmux", 780, 150, 140, 60, "event mux\n4 x (16 : 1)\n+ rising edge", "box", 10),

    N("clk", 10, 280, 120, 36, "i_clk_peri", "box", 10, True),
    N("rst", 10, 340, 120, 36, "i_rst_n_peri", "box", 10, True),
    N("tdft", 10, 400, 120, 36, "dft_cg_enable_i = 0", "box", 10),
    N("tls", 10, 460, 120, 36, "low_speed_clk_i = 0", "box", 10),
    N("text", 10, 657, 120, 36, "ext_sig_i[31:4] = 0", "box", 10),

    N("tpads", 10, 760, 120, 44, "TIM_EXT0 .. 3\npads", "grey", 10),
    N("iomux_in", 170, 760, 130, 44, "IO MUX", "grey", 11, True),
    N("sync2ff", 330, 760, 120, 44, "2FF sync\ni_clk_peri", "box", 10),

    N("intmap2", 1020, 150, 170, 60, "INTMAP\nfast line 7  (mcause 23)", "grey", 10, True),
    N("iomux_out", 1020, 240, 170, 160,
      "IO MUX\n\nPWM_0 .. 3 = o_pad_pwm[3:0]\n\nPWM_4 .. 7 = o_pad_pwm[7:4]",
      "grey", 10),
]
q = [
    E("pbus2", "b", "regs", "t", "APB_M12"),
    E("regs", "l", "cg", "t", "CH_EN"),
    E("regs", "b@0.6364", "m0", "t", "config, per module"),
    E("regs", "r@0.6786", "evmux", "l@0.3", "EVENT_CFG"),

    E("clk", "r", "cg", "l@" + _cg(298)),
    E("tdft", "r", "cg", "l@" + _cg(418)),
    E("rst", "r", "pwm", "l@%.4f" % ((358 - 90) / 640)),
    E("tls", "r", "pwm", "l@%.4f" % ((478 - 90) / 640)),

    E("cg", "r@" + _cg(_MY[0] + 21), "m0", "l@0.3"),
    E("cg", "r@" + _cg(_MY[1] + 21), "m1", "l@0.3"),
    E("cg", "r@" + _cg(_MY[2] + 21), "m2", "l@0.3"),
    E("cg", "r@" + _cg(_MY[3] + 21), "m3", "l@0.3"),

    E("pool", "t@0.0741", "m0", "l@0.75"),
    E("pool", "t@0.0741", "m1", "l@0.75"),
    E("pool", "t@0.0741", "m2", "l@0.75"),
    E("pool", "t@0.0741", "m3", "l@0.75"),

    E("m0", "r", "chbus", "l@" + _ch(_MY[0] + 35), "ch_0_o[3:0]"),
    E("m1", "r", "chbus", "l@" + _ch(_MY[1] + 35), "ch_1_o[3:0]"),
    E("m2", "r", "chbus", "l@" + _ch(_MY[2] + 35), "ch_2_o[3:0]"),
    E("m3", "r", "chbus", "l@" + _ch(_MY[3] + 35), "ch_3_o[3:0]"),

    E("chbus", "r@" + _ch(_MY[0] + 35), "iomux_out", "l@%.4f" % ((_MY[0] + 35 - 240) / 160),
      "o_pad_pwm[3:0]"),
    E("chbus", "r@" + _ch(_MY[1] + 35), "iomux_out", "l@%.4f" % ((_MY[1] + 35 - 240) / 160),
      "o_pad_pwm[7:4]"),
    E("chbus", "t", "evmux", "l@0.7", "16"),
    E("chbus", "b", "pool", "r", "ch[15:0]"),
    E("evmux", "r", "intmap2", "l", "events_o[3:0]"),

    E("text", "r", "pool", "l"),
    E("tpads", "r", "iomux_in", "l"),
    E("iomux_in", "r", "sync2ff", "l", "i_pad_tim_ext"),
    E("sync2ff", "r", "pool", "b@0.4815", "ext_sig_i[3:0]"),
]

emit([("fig_timer_block", "TIMER0 and TIMER1 in QSOC", t, e),
      ("fig_timer_inside", "Inside one TIMER instance", ti, ei),
      ("fig_pwm_block", "The PWM block and where its outputs go", p, q)],
     DRAWIO, IMG)
