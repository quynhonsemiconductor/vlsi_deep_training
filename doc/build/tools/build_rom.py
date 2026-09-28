"""ROM figures for QNSC_ROM_MAS: wrapper, memory layout, read and write timing.

    python3 doc/build/tools/build_rom.py
"""
import os
import sys
_DOC = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # doc/
sys.path.insert(0, os.path.join(_DOC, "build", "tools"))
from diagen import Node as N, Edge as E, emit
from wavegen import wave

IMG = os.path.join(_DOC, "figures", "img")
DRAWIO = os.path.join(_DOC, "figures", "drawio", "QNSC_ROM.drawio")

# ---------- Figure: ROM wrapper, full read and write paths (the one figure to present) ----------
blk = [
    N("m_ibex", 10, 20, 100, 36, "Ibex", "box", 10),
    N("m_dbg", 120, 20, 100, 36, "SYSDBG", "box", 10),
    N("m_dma", 230, 20, 100, 36, "DMA", "box", 10),
    N("sbus", 10, 90, 320, 40, "S_BUS  (decode error above 0x7FF)", "box", 11, True),
    N("axi", 200, 210, 130, 220, "AXI_M0", "box", 11, True),
    N("wrap", 400, 150, 760, 330, "m_qnsc_wrap_rom", "group", 12, True, va="top"),
    N("ctl", 420, 185, 420, 150, "m_vlsi_axi4_sram  (vendored, write inputs tied idle)", "group", 10, va="top"),
    N("arfsm", 440, 220, 100, 40, "AR FSM", "box", 10),
    N("arfifo", 570, 220, 100, 40, "AR FIFO", "box", 10),
    N("misc", 700, 220, 120, 40, "read issue", "box", 10),
    N("rfifo", 570, 285, 100, 40, "R FIFO", "box", 10),
    N("img", 980, 210, 160, 70, "m_qnsc_rom_image\n512 x 32 constants", "box", 10, True),
    N("rsp_l", 420, 350, 300, 20, "write-error responder", "port", 10),
    N("idle", 440, 380, 110, 40, "IDLE", "box", 10, True),
    N("data", 620, 380, 110, 40, "DATA", "box", 10),
    N("resp", 800, 380, 170, 40, "RESP: B = SLVERR", "box", 10),
    N("clk", 200, 455, 170, 20, "i_clk_mem, i_rst_n_mem", "port", 10),
]
blk_e = [
    E("m_ibex", "b", "sbus", "t@0.1563"), E("m_dbg", "b", "sbus", "t@0.5"), E("m_dma", "b", "sbus", "t@0.8438"),
    E("sbus", "b@0.7969", "axi", "t@0.5", bidir=True),
    E("axi", "r@0.1364", "arfsm", "l", "AR"),
    E("arfsm", "r", "arfifo", "l"), E("arfifo", "r", "misc", "l"),
    E("misc", "r", "img", "l@0.4286", "i_mem_oe, i_mem_addr"),
    E("img", "b", "rfifo", "r", "o_mem_rdata"),
    E("rfifo", "l", "axi", "r@0.4318", "R"),
    E("axi", "r@0.8636", "idle", "l", "AW, W, B", bidir=True),
    E("idle", "r", "data", "l", "AW"),
    E("data", "r", "resp", "l", "WLAST"),
    E("resp", "b", "idle", "b", "BREADY", mid=455),
    E("clk", "r", "wrap", "l@0.9545"),
]

# ---------- Figure: memory layout ----------
lay = [
    N("vec", 200, 20, 260, 50, "trap vector table\n32 x j rom_trap", "box", 10, True),
    N("code", 200, 70, 260, 170, "_start, then the bootloader", "box", 10, True),
    N("a0", 20, 10, 170, 20, "0x0000_0000", "port", 10),
    N("a1", 20, 60, 170, 20, "0x0000_0080  first fetch", "port", 10),
    N("a2", 20, 230, 170, 20, "0x0000_07FF", "port", 10),
    N("s0", 470, 35, 100, 20, "128 B", "port", 10),
    N("s1", 470, 145, 100, 20, "1920 B", "port", 10),
]
emit([
    ("fig_rom_block", "ROM wrapper, read and write paths", blk, blk_e),
    ("fig_rom_layout", "ROM layout", lay, []),
], DRAWIO, IMG)

# ---------- Timing: single-beat read at the AXI port (QNSC_RAM_MAS 7.1) ----------
wave("wave_rom_read", [
    ("i_clk_mem", "clk"),
    ("ARVALID, ARREADY", "bit", "01000000"),
    ("ARADDR", "bus", ["--", "4n", "--", None, None, None, None, None]),
    ("RVALID", "bit", "00000110"),
    ("RREADY", "bit", "00000010"),
    ("RDATA", "bus", ["--", None, None, None, None, "word n", None, "--"]),
    ("RRESP", "bus", ["--", None, None, None, None, "OKAY", None, "--"]),
    ("", "note", [(1, 5, "4 cycles")]),
], steps=8, img_dir=IMG)

# ---------- Timing: the image port, the only interface this block designs ----------
wave("wave_rom_image", [
    ("i_clk_mem", "clk"),
    ("i_mem_oe", "bit", "01000"),
    ("i_mem_addr", "bus", ["--", "n", "--", None, None]),
    ("o_mem_rdata", "bus", ["--", None, "word n (held)", None, None]),
    ("", "note", [(1, 2, "1")]),
], steps=5, img_dir=IMG)

# ---------- Timing: a single-beat write, answered by the responder ----------
wave("wave_rom_write", [
    ("i_clk_mem", "clk"),
    ("AWVALID", "bit", "0100000"),
    ("AWREADY", "bit", "1100011"),
    ("WVALID, WLAST", "bit", "0010000"),
    ("WREADY", "bit", "0010000"),
    ("BVALID", "bit", "0001100"),
    ("BREADY", "bit", "0000100"),
    ("BRESP", "bus", ["--", None, None, "SLVERR", None, "--", None]),
], steps=7, img_dir=IMG, marks=[(1, "AW"), (2, "W"), (4, "B")])
