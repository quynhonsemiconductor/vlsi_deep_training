"""UART figures for QNSC_UART_MAS: block in the SoC, register fields, one frame.

    python3 doc/build/tools/build_uart.py
"""
import os
import sys
_DOC = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # doc/
sys.path.insert(0, os.path.join(_DOC, "build", "tools"))
from diagen import Node as N, Edge as E, emit
from regfig import regfig
from wavegen import wave

IMG = os.path.join(_DOC, "figures", "img")
DRAWIO = os.path.join(_DOC, "figures", "drawio", "QNSC_UART.drawio")

# ---------- Figure: the block in the SoC (the one figure to present) ----------
blk = [
    N("pbus", 10, 150, 110, 60, "P_BUS\nAPB_M8 / M9", "box", 10, True),
    N("scrc", 10, 30, 60, 50, "SCRC", "box", 10),
    N("wrap", 170, 20, 690, 330, "m_qnsc_wrap_uart", "group", 12, True, va="top"),
    N("apb", 190, 55, 650, 280, "apb_uart  (upstream, unmodified)", "group", 10, va="top"),
    N("a2o", 210, 150, 110, 60, "apb_to_obi", "box", 10),
    N("core", 350, 90, 470, 225, "obi_uart", "group", 10, True, va="top"),
    N("reg", 370, 125, 120, 170, "registers\n16550\nDLAB", "box", 10, True),
    N("bg", 520, 125, 120, 40, "baud gen /16", "box", 10),
    N("tx", 520, 185, 120, 40, "TX FIFO 16\nTSR", "box", 10),
    N("rx", 520, 235, 120, 50, "RX sync\nFIFO 16, RSR", "box", 10),
    N("irq", 670, 125, 130, 40, "interrupt\npriority", "box", 10),
    N("mdm", 670, 250, 130, 50, "modem\ninputs tied 1", "box", 10),
    N("iom", 900, 185, 110, 60, "IO MUX\nRX idle = 1", "box", 10),
    N("intm", 900, 105, 110, 40, "INTMAP\nline 4 / 5", "box", 10),
    N("pad", 1050, 185, 90, 60, "pads\nTX, RX", "box", 10),
]
blk_e = [
    E("pbus", "r", "a2o", "l", "APB", bidir=True),
    E("scrc", "r", "wrap", "l@0.1", "o_clk_uart_<n>"),
    E("a2o", "r", "reg", "l@0.4706", "OBI", bidir=True),
    E("bg", "b", "tx", "t"),
    E("irq", "r", "intm", "l", "o_int_uart"),
    E("tx", "r", "iom", "l@0.2", "o_pad_uart_tx"),
    E("iom", "l@0.9167", "rx", "r@0.1", "i_pad_uart_rx"),
    E("iom", "r", "pad", "l", bidir=True),
]

emit([("fig_uart_block", "UART in QSOC", blk, blk_e)], DRAWIO, IMG)

# ---------- Figure: register fields ----------
regfig("fig_uart_regs", [
    ("IER 0x04", [(0, 0, "rx_data"), (1, 1, "thr_empty"), (2, 2, "line_st"), (3, 3, "modem")]),
    ("ISR 0x08 (rd)", [(0, 0, "pend_n"), (1, 3, "id"), (6, 7, "fifos_en")]),
    ("FCR 0x08 (wr)", [(0, 0, "fifo_en"), (1, 1, "rx_rst"), (2, 2, "tx_rst"), (6, 7, "rx_trig")]),
    ("LCR 0x0C", [(0, 1, "wls"), (2, 2, "stb"), (3, 3, "pen"), (4, 4, "eps"), (5, 5, "stick"), (6, 6, "break"), (7, 7, "dlab")]),
    ("LSR 0x14", [(0, 0, "dr"), (1, 1, "oe"), (2, 2, "pe"), (3, 3, "fe"), (4, 4, "bi"), (5, 5, "thre"), (6, 6, "temt"), (7, 7, "fifo_err")]),
], img_dir=IMG, height=80)

# ---------- Timing: one 8N1 frame, 0x4D ----------
wave("wave_uart_frame", [
    ("o_pad_uart_tx", "bit", "101011001011"),
    ("bit", "bus", ["idle", "start", "D0", "D1", "D2", "D3", "D4", "D5", "D6", "D7", "stop", "idle"]),
    ("", "note", [(1, 11, "10 bits, 88.0 us")]),
], steps=12, gaps=(), img_dir=IMG)
