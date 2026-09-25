import os
import sys
_DOC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # doc/
sys.path.insert(0, os.path.join(_DOC, "tools"))
from diagen import Node as N, Edge as E, emit

IMG = os.path.join(_DOC, "img")
DRAWIO = os.path.join(_DOC, "drawio", "QNSC_RAM_Block.drawio")

# m_qnsc_wrap_axi4_sram: the vendored controller, unmodified, plus the wstrb FIFO.
# Wiring follows vendor/nguyenquanicd/AXI4-SRAM-CONTROLLER/rtl at the pinned commit:
# FIFO data goes to u_sram_misc; the arbiter sees only requests and returns grants.

ROW = {"w": 170, "aw": 235, "ar": 300, "r": 365, "b": 430}   # box tops, h = 44
H = 44
MISC_Y, MISC_H = 170, 304
SRAM_Y, SRAM_H = 200, 220


def mf(y):   # anchor on u_sram_misc's side at absolute y
    return "%.4f" % ((y - MISC_Y) / MISC_H)


def sf(y):   # anchor on the macro's side at absolute y
    return "%.4f" % ((y - SRAM_Y) / SRAM_H)


def c(r):    # centre y of a row
    return ROW[r] + H / 2


f = [
    N("clk", 10, 24, 190, 50, "i_clk_mem\ni_rst_n_mem", "box", 11, True),

    N("busg", 10, 110, 190, 380, "S_BUS  AXI_M1 (ISRAM)\nor AXI_M2 (DSRAM)",
      "group", 11, True, "top"),
    N("ch_w", 25, ROW["w"], 150, H, "W", "blue", 11, True),
    N("ch_aw", 25, ROW["aw"], 150, H, "AW", "blue", 11, True),
    N("ch_ar", 25, ROW["ar"], 150, H, "AR", "blue", 11, True),
    N("ch_r", 25, ROW["r"], 150, H, "R", "blue", 11, True),
    N("ch_b", 25, ROW["b"], 150, H, "B", "blue", 11, True),

    N("wrap", 230, 20, 750, 580, "m_qnsc_wrap_axi4_sram", "group", 12, True, "top"),
    N("sf", 520, 60, 170, H, "u_strbfifo\nwstrb, 4 bit x 8", "red", 10),

    N("ctrl", 260, 130, 690, 450, "u_ctrl  |  m_vlsi_axi4_sram  (IP, unmodified)",
      "group", 11, True, "top"),
    N("aw", 290, ROW["aw"], 150, H, "u_axfsm_wr", "purple", 10),
    N("ar", 290, ROW["ar"], 150, H, "u_axfsm_rd", "purple", 10),
    N("wf", 490, ROW["w"], 140, H, "WFIFO", "green", 10),
    N("awf", 490, ROW["aw"], 140, H, "AWFIFO", "green", 10),
    N("arf", 490, ROW["ar"], 140, H, "ARFIFO", "green", 10),
    N("rf", 490, ROW["r"], 140, H, "RFIFO", "green", 10),
    N("bf", 490, ROW["b"], 140, H, "BFIFO", "green", 10),
    N("misc", 700, MISC_Y, 220, MISC_H,
      "u_sram_misc\nFIFO pop, SRAM mux\nR and B generation", "yellow", 10),
    N("arb", 700, 510, 220, H, "u_arbiter\nround-robin", "yellow", 10),

    N("sram", 1260, SRAM_Y, 180, SRAM_H,
      "SRAM macro\nsingle port\n1-cycle read\nno reset", "grey", 11, True),
]
e = [
    E("clk", "r", "wrap", "l@%.4f" % ((49 - 20) / 580)),
    # AXI channels
    E("ch_w", "r", "wf", "l", "wdata"),
    E("ch_w", "r@0.2", "sf", "l", mid=215),
    E("ch_aw", "r", "aw", "l"),
    E("ch_ar", "r", "ar", "l"),
    E("rf", "l", "ch_r", "r"),
    E("bf", "l", "ch_b", "r"),
    E("aw", "r", "awf", "l"),
    E("ar", "r", "arf", "l"),
    # FIFO data into and out of u_sram_misc
    E("wf", "r", "misc", "l@" + mf(c("w"))),
    E("awf", "r", "misc", "l@" + mf(c("aw"))),
    E("arf", "r", "misc", "l@" + mf(c("ar"))),
    E("misc", "l@" + mf(c("r")), "rf", "r"),
    E("misc", "l@" + mf(c("b")), "bf", "r"),
    # arbiter: requests in, grants out, no data
    E("misc", "b@0.15", "arb", "t@0.15", "req_write, req_read"),
    E("arb", "t@0.85", "misc", "b@0.85", "arb_sel, write_en"),
    # strobe FIFO: popped by the write strobe, drives the byte enables
    E("misc", "t@0.85", "sf", "b@0.8", "o_mem_we (pop)", mid=117),
    E("sf", "r", "sram", "t", "bwe[3:0]"),
    # macro
    E("misc", "r@" + mf(235), "sram", "l@" + sf(235), "addr[15:2] / [14:2]"),
    E("misc", "r@" + mf(285), "sram", "l@" + sf(285), "wdata, we, oe"),
    E("sram", "l@" + sf(380), "misc", "r@" + mf(380), "rdata"),
]
emit([("fig_ram_simple", "RAM block: wrapper, controller and macro", f, e)], DRAWIO, IMG)
