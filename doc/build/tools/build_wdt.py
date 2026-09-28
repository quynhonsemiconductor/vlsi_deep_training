"""WDT figures for QNSC_WDT_MAS: block in the SoC, register fields, bark and bite.

    python3 doc/build/tools/build_wdt.py
"""
import os
import sys
_DOC = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # doc/
sys.path.insert(0, os.path.join(_DOC, "build", "tools"))
from diagen import Node as N, Edge as E, emit
from regfig import regfig
from wavegen import wave

IMG = os.path.join(_DOC, "figures", "img")
DRAWIO = os.path.join(_DOC, "figures", "drawio", "QNSC_WDT.drawio")

# ---------- Figure: the block in the SoC (the one figure to present) ----------
blk = [
    N("pbus", 10, 70, 120, 60, "P_BUS\nAPB_M2", "box", 10),
    N("scrcc", 10, 260, 120, 60, "SCRC", "box", 10),
    N("wrap", 300, 20, 690, 360, "m_qnsc_wrap_wdt", "group", 12, True, va="top"),
    N("bridge", 320, 70, 170, 80, "qnsc_apb_to_tlul\nAPB FSM +\ntlul_adapter_host", "box", 10, True),
    N("tie", 320, 250, 170, 100, "tie-offs\nlc_escalate_en = Off\nsleep_mode = 0\nalert, racl idle", "box", 10),
    N("core", 520, 50, 450, 310, "aon_timer  (upstream, unmodified)", "group", 10, va="top"),
    N("reg", 540, 90, 120, 110, "registers\nTL-UL reg top\nCDC", "box", 10),
    N("wdog", 700, 80, 130, 60, "watchdog\n32-bit count", "box", 10),
    N("wkup", 700, 200, 130, 60, "wake-up\nprescaler\n64-bit count", "box", 10),
    N("rst", 860, 80, 90, 50, "rst_req\nsticky", "box", 10),
    N("intr", 860, 190, 90, 60, "INTR_STATE", "box", 10),
    N("scrcr", 1110, 70, 110, 60, "SCRC\nRRC", "box", 10),
    N("intm", 1110, 190, 110, 70, "INTMAP\nNMI, line 8", "box", 10),
]
blk_e = [
    E("pbus", "r", "bridge", "l@0.375", "APB", bidir=True),
    E("scrcc", "r", "wrap", "l@0.75", "o_clk_wdt, o_rst_n_wdt"),
    E("bridge", "r", "reg", "l@0.18", "TL-UL", bidir=True),
    E("tie", "r", "core", "l@0.806", dashed=True),
    E("reg", "r@0.2", "wdog", "l@0.53"),
    E("reg", "r@0.8", "wkup", "l@0.2"),
    E("wdog", "r@0.3", "rst", "l@0.36", "bite"),
    E("wdog", "r@0.8", "intr", "l@0.25", "bark"),
    E("wkup", "r@0.5", "intr", "l@0.75"),
    E("rst", "r", "scrcr", "l@0.583", "o_wdt_rst_req"),
    E("intr", "r@0.3", "intm", "l@0.3", "o_int_wdt_bark"),
    E("intr", "r@0.8", "intm", "l@0.8", "o_int_wdt_wakeup"),
]
emit([("fig_wdt_block", "WDT in QSOC", blk, blk_e)], DRAWIO, IMG)

# ---------- Figure: register fields ----------
regfig("fig_wdt_regs", [
    ("WKUP_CTRL 0x04", [(0, 0, "enable"), (1, 12, "prescaler")]),
    ("WDOG_REGWEN 0x18", [(0, 0, "regwen")]),
    ("WDOG_CTRL 0x1C", [(0, 0, "enable"), (1, 1, "pause_in_sleep")]),
    ("INTR_STATE 0x2C", [(0, 0, "wkup_timer_expired"), (1, 1, "wdog_timer_bark")]),
], img_dir=IMG, height=80)

# ---------- Timing: petted once, then hung: bark, bite, chip reset ----------
wave("wave_wdt_flow", [
    ("i_clk_wdt", "clk"),
    ("WDOG_COUNT", "bus", ["0", "1", "..", "BARK", "+1", "..", "0", "1", "..", "BARK",
                           "..", "BITE", "+1", None, "0", None]),
    ("o_int_wdt_bark (NMI)", "bit", "0000111000111100"),
    ("o_wdt_rst_req", "bit", "0000000000001100"),
    ("o_rst_n_wdt", "bit", "1111111111111001"),
], steps=16, gaps=(2, 5, 8, 10), img_dir=IMG,
    marks=[(0, "enable"), (6, "pet"), (12, "bite"), (14, "reset")])
