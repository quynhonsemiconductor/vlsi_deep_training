"""I2C figures for QNSC_I2C_MAS: block in the SoC, register fields, one byte on the bus.

    python3 doc/build/tools/build_i2c.py
"""
import os
import sys
_DOC = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # doc/
sys.path.insert(0, os.path.join(_DOC, "build", "tools"))
from diagen import Node as N, Edge as E, emit
from regfig import regfig
from wavegen import wave

IMG = os.path.join(_DOC, "figures", "img")
DRAWIO = os.path.join(_DOC, "figures", "drawio", "QNSC_I2C.drawio")

# ---------- Figure: the block in the SoC (the one figure to present) ----------
blk = [
    N("pbus", 10, 150, 90, 60, "P_BUS\nAPB_M11", "box", 10, True),
    N("scrc", 10, 30, 90, 50, "SCRC", "box", 10),
    N("wrap", 170, 20, 640, 310, "m_qnsc_wrap_i2c", "group", 12, True, va="top"),
    N("core", 190, 55, 500, 255, "apb_i2c  (upstream, unmodified)", "group", 10, va="top"),
    N("reg", 210, 100, 120, 180, "APB registers\nPRER CTRL\nTX RX CMD\nSTATUS", "box", 10, True),
    N("byte", 370, 100, 140, 70, "byte controller\nshift, ACK", "box", 10),
    N("bit", 370, 200, 140, 80, "bit controller\nSCL gen, filter\nSTART/STOP, AL", "box", 10),
    N("irq", 550, 60, 120, 40, "irq_flag\n(sticky)", "box", 10),
    N("inv", 710, 200, 80, 80, "oe =\nNOT\npadoen", "box", 10),
    N("iom", 850, 200, 110, 80, "IO MUX\nopen-drain\npads", "box", 10),
    N("intm", 850, 100, 110, 40, "INTMAP\nline 3", "box", 10),
    N("bus", 1000, 200, 100, 80, "SCL, SDA\npull-ups\n(board)", "box", 10),
]
blk_e = [
    E("pbus", "r", "reg", "l@0.3333", "APB", bidir=True),
    E("scrc", "r", "wrap", "l@0.1", "o_clk_i2c"),
    E("reg", "r@0.2", "byte", "l"),
    E("byte", "b", "bit", "t"),
    E("reg", "r@0.1", "irq", "l", mid=350),
    E("irq", "r", "intm", "l", "o_int_i2c"),
    E("bit", "r", "inv", "l", "scl/sda_padoen"),
    E("inv", "r@0.3", "iom", "l@0.3", "o_pad_*_oe"),
    E("iom", "l@0.7", "inv", "r@0.7", "i_pad_*"),
    E("iom", "r", "bus", "l", bidir=True),
]

emit([("fig_i2c_block", "I2C in QSOC", blk, blk_e)], DRAWIO, IMG)

# ---------- Figure: register fields ----------
regfig("fig_i2c_regs", [
    ("PRER 0x00", [(0, 15, "prescale")]),
    ("CTRL 0x04", [(6, 6, "ien"), (7, 7, "en")]),
    ("STATUS 0x0C", [(0, 0, "if"), (1, 1, "tip"), (5, 5, "al"), (6, 6, "busy"), (7, 7, "rxack")]),
    ("CMD 0x14", [(0, 0, "iack"), (3, 3, "ack"), (4, 4, "wr"), (5, 5, "rd"), (6, 6, "sto"), (7, 7, "sta")]),
], img_dir=IMG, height=80)

# ---------- Timing: a write of one data byte, bus view ----------
wave("wave_i2c_write", [
    ("SDA (bus)", "bus", ["idle", "S", "addr[6:0]", None, None, "W", "ACK", "data[7:0]", None, None, "ACK", "P", "idle"]),
    ("master drives", "bus", ["--", "STA|WR", "addr, W", None, None, None, "slave", "WR|STO", None, None, "slave", "--", None]),
    ("irq_flag", "bit", "0000001000010"),
], steps=13, gaps=(), img_dir=IMG,
    marks=[(1, "CMD = STA|WR"), (7, "CMD = WR|STO")])
