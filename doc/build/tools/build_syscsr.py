"""SYSCSR figures for QNSC_SYSCSR_MAS: block, DBG_BOOT.dbg_en, register fields,
reset-cause timing.

    python3 doc/build/tools/build_syscsr.py
"""
import os
import sys
_DOC = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # doc/
sys.path.insert(0, os.path.join(_DOC, "build", "tools"))
from diagen import Node as N, Edge as E, emit
from regfig import regfig
from wavegen import wave

IMG = os.path.join(_DOC, "figures", "img")
DRAWIO = os.path.join(_DOC, "figures", "drawio", "QNSC_SYSCSR.drawio")

# ---------- Figure: SYSCSR block ----------
# Four registers inside the generated block, each fed from one side.
# The one figure to present: who writes each register, who reads it.
blk = [
    N("ibex", 10, 30, 110, 36, "Ibex", "box", 10),
    N("dbg", 10, 90, 110, 36, "SYSDBG", "box", 10),
    N("sbus", 160, 30, 60, 96, "S_BUS", "box", 10),
    N("a2p", 160, 160, 60, 40, "AXI2\nAPB", "box", 10),
    N("pbus", 160, 230, 60, 70, "P_BUS", "box", 10),
    N("wrap", 280, 30, 440, 410, "m_qnsc_wrap_syscsr   APB_M1   reset: o_rst_n_por only", "group", 11, True, va="top"),
    N("csr", 300, 65, 400, 295, "m_qnsc_syscsr_csr  (generated)", "group", 10, va="top"),
    N("dec", 320, 100, 90, 245, "APB\nslave", "box", 10),
    N("rc", 470, 100, 210, 50, "RESET_CAUSE  (W1C)", "box", 11, True),
    N("ds", 470, 165, 210, 50, "DOMAIN_RST_STATUS  (RO)", "box", 11, True),
    N("id", 470, 230, 210, 50, "CHIP_ID_REV  (RO)", "box", 11, True),
    N("db", 470, 295, 210, 50, "DBG_BOOT  (RO, RW)", "box", 11, True),
    N("sync", 470, 380, 210, 44, "m_qnsc_syscsr_dbg_en\n2 FF + mask", "box", 10),
    N("pin", 10, 380, 110, 44, "DBG_EN pin", "box", 10),
    N("cid", 740, 237, 120, 36, "C_CHIP_ID", "box", 10),
    N("scrc", 900, 30, 250, 330, "SCRC", "group", 11, True, va="top"),
    N("rrc", 920, 100, 210, 50, "RRC", "box", 11, True),
    N("ctrl", 920, 165, 210, 50, "CTRL x 18", "box", 11, True),
    N("por", 920, 290, 210, 40, "o_clk_pbus, o_rst_n_por", "port", 10),
]
blk_e = [
    E("ibex", "r", "sbus", "l@0.1875", bidir=True),
    E("dbg", "r", "sbus", "l@0.8125", bidir=True),
    E("sbus", "b", "a2p", "t", bidir=True),
    E("a2p", "b", "pbus", "t", bidir=True),
    E("pbus", "r", "dec", "l@0.6735", "APB_M1", bidir=True),
    E("dec", "r@0.1020", "rc", "l"),
    E("dec", "r@0.3673", "ds", "l"),
    E("dec", "r@0.6327", "id", "l"),
    E("dec", "r@0.8980", "db", "l", bidir=True),
    E("sync", "t@0.3", "db", "b@0.3"),
    E("db", "b@0.7", "sync", "t@0.7"),
    E("pin", "r", "sync", "l"),
    E("rrc", "l", "rc", "r", "o_cause_we_wdt, _sw"),
    E("ctrl", "l", "ds", "r", "~o_rst_n_<d>"),
    E("cid", "l", "id", "r"),
    E("por", "l", "wrap", "r@0.6829"),
]

# ---------- Figure: DBG_BOOT.dbg_en (QNSC_SYSCSR_MAS 7.5, the mentor's drawing of 12/10) ----------
dbg = [
    N("grp", 135, 10, 445, 225, "m_qnsc_syscsr_dbg_en and DBG_BOOT", "group", 10, va="top"),
    N("pin", 10, 60, 100, 40, "DBG_EN pin", "box", 10),
    N("ff1", 150, 60, 50, 40, "FF", "box", 10),
    N("ff2", 230, 60, 50, 40, "FF", "box", 10),
    N("k0", 230, 112, 50, 26, "1'b0", "port", 10),
    N("mux", 330, 40, 50, 110, "mux", "box", 10),
    N("mask", 300, 175, 110, 44, "dbg_en_mask\n(RW, reset 0)", "box", 10, True),
    N("st", 440, 75, 120, 40, "dbg_en (RO)", "box", 10, True),
    N("rom", 600, 75, 150, 40, "read by the boot ROM\n(polls while 1)", "port", 9),
    N("host", 600, 177, 170, 40, "written 1 by the host over JTAG\n(SYSDBG bus master)", "port", 9),
]
dbg_e = [
    E("pin", "r", "ff1", "l"),
    E("ff1", "r", "ff2", "l"),
    E("ff2", "r", "mux", "l@0.3636", "0"),
    E("k0", "r", "mux", "l@0.7", "1"),
    E("mask", "t", "mux", "b", "select"),
    E("mux", "r", "st", "l"),
    E("st", "r", "rom", "l"),
    E("host", "l", "mask", "r"),
]
emit([("fig_syscsr_block", "SYSCSR block", blk, blk_e),
      ("fig_syscsr_dbg_en", "DBG_BOOT.dbg_en", dbg, dbg_e)], DRAWIO, IMG)

# ---------- Figure: register fields ----------
_DOM = [(0, "sbus"), (1, "pbus"), (2, "wdt"), (3, "timer_0"), (4, "timer_1"),
        (5, "uart_0"), (6, "uart_1"), (7, "spi"), (8, "i2c"), (9, "gpio_0"),
        (10, "dma"), (11, "rom"), (12, "ram"), (14, "sysdbg"), (15, "pwm"),
        (16, "gpio_1"), (17, "gpio_2"), (31, "cpu")]
# Labels are the field names of the specification, exactly.
regfig("fig_syscsr_regs", [
    ("RESET_CAUSE", [(0, 0, "cause_por"), (1, 1, "cause_wdt"), (2, 2, "cause_soft")]),
    ("DOMAIN_RST_STATUS", [(b, b, "stat_" + n) for b, n in _DOM]),
    ("CHIP_ID_REV", [(0, 31, "chip_id_rev = 0x5153_4F43  ('Q' 'S' 'O' 'C')")]),
    ("DBG_BOOT", [(0, 0, "dbg_en"), (1, 1, "dbg_en_mask")]),
], img_dir=IMG, height=96)

# ---------- Timing: reset cause across POR, a firmware clear and a WDT bite ----------
# i_cause_we_wdt is a level for the whole chip reset (QNSC_SCRC_MAS 7.3), so a
# W1C write still in flight when the bite lands cannot win over it.
wave("wave_syscsr_cause", [
    ("i_clk_cpu", "clk"),
    ("i_rst_n_por", "bit", "01111111111111111"),
    ("APB write 0x1 (W1C)", "bit", "00011100000000000"),
    ("i_cause_we_wdt", "bit", "00000001111111000"),
    ("o_rst_n_pbus", "bit", "11111110000000011"),
    ("RESET_CAUSE", "bus", ["0x1", None, None, None, None, "0x0", None, None,
                            "0x2", None, None, None, None, None, None, None, None]),
    ("", "note", [(7, 14, "16 cycles")]),
], steps=17, gaps=(11,), img_dir=IMG,
    marks=[(1, "POR"), (3, "W1C"), (7, "WDT bite")])
