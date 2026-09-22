import os
import sys
_DOC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # doc/
sys.path.insert(0, os.path.join(_DOC, "tools"))
from diagen import Node as N, Edge as E, emit

IMG = os.path.join(_DOC, "img")
DRAWIO = os.path.join(_DOC, "drawio", "QNSC_Timer_PWM.drawio")

# ---------- Figure 1: the two timers ----------
t = [
    N("pbus", 40, 40, 900, 60, "P_BUS  (APB, 20 MHz)", "yellow", 13, True),

    N("t0", 90, 190, 330, 150,
      "TIMER0\napb_timer_unit\nAPB_M7   0x8001_C000\nD04, bit 3\nMODE_64 = 1", "red", 11, True),
    N("t1", 560, 190, 330, 150,
      "TIMER1\napb_timer_unit\nAPB_M8   0x8002_0000\nD05, bit 4\nMODE_64 = 0", "red", 11, True),

    N("c0", 120, 400, 120, 54, "counter_lo\n32-bit", "green", 10),
    N("c1", 265, 400, 120, 54, "counter_hi\n32-bit", "green", 10),
    N("c2", 590, 400, 120, 54, "counter_lo\n32-bit", "green", 10),
    N("c3", 735, 400, 120, 54, "counter_hi\n32-bit", "green", 10),

    N("intmap", 330, 530, 320, 62,
      "INTMAP  (OR tree)\n3 sources -> 2 fast lines", "grey", 11, True),
]
e = [
    E("pbus", "b@0.17", "t0", "t", "APB_M7"),
    E("pbus", "b@0.69", "t1", "t", "APB_M8"),
    E("t0", "b@0.10", "c0", "t", "", True),
    E("t0", "b@0.55", "c1", "t", "carry when lo = FFFF_FFFF", True),
    E("t1", "b@0.10", "c2", "t", "", True),
    E("t1", "b@0.55", "c3", "t", "", True),
    E("t0", "b@0.92", "intmap", "l", "irq_lo_o   1 source"),
    E("t1", "b@0.92", "intmap", "r", "irq_lo_o + irq_hi_o   2 sources"),
]

# ---------- Figure 2: the PWM block ----------
p = [
    N("pbus2", 40, 40, 900, 60, "P_BUS  (APB, 20 MHz)", "yellow", 13, True),

    N("pwm", 60, 170, 860, 210,
      "PWM   apb_adv_timer   APB_M13   0x8003_4000   D18, bit 15\n"
      "TIMER_NBITS = 16      EXTSIG_NUM = 32", "red", 12, True),

    N("m0", 100, 250, 180, 100, "timer_module 0\n16-bit counter\n4 comparators", "blue", 10),
    N("m1", 300, 250, 180, 100, "timer_module 1\n16-bit counter\n4 comparators", "blue", 10),
    N("m2", 500, 250, 180, 100, "timer_module 2\n16-bit counter\n4 comparators", "blue", 10),
    N("m3", 700, 250, 180, 100, "timer_module 3\n16-bit counter\n4 comparators", "blue", 10),

    N("ch", 60, 440, 420, 70,
      "16 channel outputs\nch_0_o[3:0] .. ch_3_o[3:0]", "green", 11, True),
    N("evt", 540, 440, 380, 70,
      "events_o[3:0]\nmux 4-of-16 + edge detect", "grey", 11, True),

    N("pads", 60, 580, 420, 62, "IO MUX -> 8 pads\nPWM_0 .. PWM_7", "grey", 11),
    N("intmap2", 540, 580, 380, 62, "INTMAP -> fast line 7\n4 sources, 1-cycle pulses", "grey", 11),
]
q = [
    E("pbus2", "b@0.5", "pwm", "t", "APB_M13"),
    E("ch", "r", "evt", "l", "the 16 channels are the event source", True),
    E("ch", "b", "pads", "t", "8 of 16"),
    E("evt", "b", "intmap2", "t", ""),
]

emit([("fig_timer_block", "TIMER0 and TIMER1 in QSOC", t, e),
      ("fig_pwm_block", "The PWM block and where its outputs go", p, q)],
     DRAWIO, IMG)
