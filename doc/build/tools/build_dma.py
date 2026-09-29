"""DMA figures for QNSC_DMA_MAS: block in the SoC, job flow, register fields, one job.

    python3 doc/build/tools/build_dma.py
"""
import os
import sys
_DOC = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # doc/
sys.path.insert(0, os.path.join(_DOC, "build", "tools"))
from diagen import Node as N, Edge as E, emit
from regfig import regfig
from wavegen import wave

IMG = os.path.join(_DOC, "figures", "img")
DRAWIO = os.path.join(_DOC, "figures", "drawio", "QNSC_DMA.drawio")

# ---------- Figure: the block in the SoC (the one figure to present) ----------
blk = [
    N("cpu", 10, 20, 110, 40, "Ibex", "box", 10),
    N("sbus", 10, 110, 110, 250, "S_BUS", "box", 11, True),
    N("a2p", 10, 400, 110, 40, "AXI2APB", "box", 10),
    N("pbus", 10, 470, 110, 40, "P_BUS", "box", 10),
    N("mem", 150, 20, 150, 40, "ISRAM, DSRAM, ROM", "box", 10),
    N("per", 150, 540, 250, 40, "UART, SPI, I2C ... (APB slaves)", "box", 10),
    N("wrap", 190, 110, 750, 400, "m_qnsc_wrap_dma", "group", 12, True, va="top"),
    N("fe", 220, 420, 170, 60, "idma_reg32_2d\nfrontend reg", "box", 10, True),
    N("id", 220, 330, 170, 50, "idma_transfer_id_gen", "box", 10),
    N("mid", 450, 420, 170, 60, "idma_nd_midend\n2D", "box", 10, True),
    N("be", 680, 280, 170, 80, "idma_backend_rw_axi\n(generated)", "box", 10, True),
    N("join", 450, 150, 170, 60, "AR/R + AW/W/B\njoin (wires)", "box", 10),
    N("idle", 680, 420, 170, 50, "idle = NOT busy", "box", 10),
    N("p_int", 980, 430, 150, 30, "o_int_dma  (line 0)", "port", 10),
    N("p_clk", 980, 150, 150, 40, "i_clk_peri\ni_rst_n_peri", "port", 10),
]
blk_e = [
    E("cpu", "b", "sbus", "t", "AXI_S1", bidir=True),
    E("sbus", "r@0.1", "mem", "b", "AXI_M0..2", bidir=True),
    E("sbus", "b", "a2p", "t", "AXI_M3", bidir=True),
    E("a2p", "b", "pbus", "t", bidir=True),
    E("pbus", "b", "per", "l", bidir=True),
    E("pbus", "r", "fe", "l@0.8333", "APB_M13", bidir=True),
    E("fe", "r", "mid", "l", "nd job"),
    E("fe", "t", "id", "b", "launch"),
    E("mid", "r@0.3", "be", "l@0.9", "1D bursts"),
    E("be", "t", "join", "r", "read, write ports"),
    E("join", "l", "sbus", "r@0.24", "AXI_S2", bidir=True),
    E("be", "b", "idle", "t", "busy"),
    E("be", "l@0.6", "mid", "t@0.8", "1D responses"),
    E("mid", "t@0.2", "id", "r", "done (per job)"),
    E("mid", "r@0.6", "idle", "l@0.72", "busy"),
    E("idle", "r", "p_int", "l"),
    E("p_clk", "l", "wrap", "r@0.1"),
]

flow = [
    N("start", 40, 0, 330, 44, "Job to run", "term", 10, True),
    N("cfg", 40, 70, 330, 44, "write SRC, DST, LENGTH\nand for 2D: SRC_STRIDE, DST_STRIDE, REPS", "box", 10),
    N("conf", 40, 140, 330, 44, "write CONF: enable_nd, protocols AXI", "box", 10),
    N("go", 40, 210, 330, 44, "read NEXT_ID  (launches the job)", "box", 10, True),
    N("mie", 40, 290, 330, 44, "set mie[16], then wfi or other work", "box", 10),
    N("isr", 40, 360, 330, 44, "line 0 taken: DMA idle", "box", 10, True),
    N("done", 105, 430, 200, 70, "DONE_ID >= id?", "diamond", 10),
    N("fin", 40, 540, 330, 44, "clear mie[16]; job complete", "term", 10, True),
    N("ret", 430, 442, 260, 46, "return; the line rises again\nwhen the job ends", "box", 10),
]
flow_e = [
    E("start", "b", "cfg", "t"),
    E("cfg", "b", "conf", "t"),
    E("conf", "b", "go", "t"),
    E("go", "b", "mie", "t", "id"),
    E("mie", "b", "isr", "t"),
    E("isr", "b", "done", "t"),
    E("done", "b", "fin", "t", "yes"),
    E("done", "r", "ret", "l", "no"),
]

emit([("fig_dma_block", "DMA in QSOC", blk, blk_e), ("fig_dma_flow", "One DMA job", flow, flow_e)], DRAWIO, IMG)

# ---------- Figure: register fields ----------
regfig("fig_dma_regs", [
    ("CONF", [(0, 0, "decouple_aw"), (1, 1, "decouple_rw"), (2, 2, "src_reduce_len"), (3, 3, "dst_reduce_len"), (4, 6, "src_max_llen"), (7, 9, "dst_max_llen"), (10, 11, "enable_nd"), (12, 14, "src_prot"), (15, 17, "dst_prot")]),
    ("STATUS", [(0, 7, "backend busy"), (8, 8, "midend")]),
], img_dir=IMG, height=96)

# ---------- Timing: one job ----------
wave("wave_dma_job", [
    ("i_clk_peri", "clk"),
    ("APB read NEXT_ID", "bit", "011000000000000000000"),
    ("ARVALID (AXI_S2)", "bit", "000011000000000000000"),
    ("RVALID", "bit", "000000000101010100000"),
    ("AWVALID", "bit", "000000000110000000000"),
    ("WVALID", "bit", "000000000010101010000"),
    ("BVALID", "bit", "000000000000000000110"),
    ("busy", "bit", "000111111111111110000"),
    ("o_int_dma", "bit", "111000000000000001111"),
    ("DONE_ID", "bus", ["n-1"] + [None] * 19 + ["n"]),
], steps=21, gaps=(), img_dir=IMG,
    marks=[(1, "launch"), (4, "read burst"), (9, "write burst"), (17, "idle, not done"), (20, "done")])
