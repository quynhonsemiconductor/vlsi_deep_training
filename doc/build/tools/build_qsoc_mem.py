import os
import sys
_DOC = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # doc/
sys.path.insert(0, os.path.join(_DOC, "build", "tools"))
from diagen import Node as N, Edge as E, emit

IMG = os.path.join(_DOC, "figures", "img")
DRAWIO = os.path.join(_DOC, "figures", "drawio", "QNSC_QSOC_MemMap.drawio")

# Figure 1 of both QNSC_RAM_MAS and QNSC_SYSDBG_MAS.
# Masters above the bus, slaves below it; the author's two blocks are coloured.
f = [
    N("jtag", 20, 160, 120, 70, "JTAG pads\nTCK TMS TDI TDO", "grey", 10),
    N("cpu", 390, 40, 180, 70, "Ibex CPU", "blue", 12, True),

    N("sysdbg", 170, 160, 180, 70, "SYSDBG", "red", 12, True),
    N("cpu2axi", 390, 160, 180, 70, "CPU2AXI", "grey", 11),
    N("dma", 610, 160, 180, 70, "DMA", "grey", 11),

    N("sbus", 100, 300, 900, 64, "S_BUS   (AXI)", "yellow", 13, True),

    N("rom", 120, 425, 150, 92, "ROM  8 KiB\n0x0000_0000", "grey", 11),
    N("isram", 300, 425, 185, 92,
      "ISRAM  64 KiB\n0x2000_0000\ndebug = first 4 KiB", "green", 11, True),
    N("dsram", 515, 425, 150, 92, "DSRAM  32 KiB\n0x3000_0000\ndata", "green", 11, True),
    N("apb", 695, 425, 215, 92,
      "AXI2APB  ->  P_BUS\n0x8000_0000\nUART SPI I2C TIMER GPIO", "grey", 10),

    N("key", 20, 560, 880, 66,
      "Coloured = the blocks specified by this author  |  SYSDBG is a bus MASTER, "
      "the two RAMs are SLAVES\nThe debug program is the first 4 KiB of ISRAM, 0x2000_0000 -- 0x2000_0FFF, "
      "an address convention, not a block of its own", "box", 10),
]
e = [
    E("jtag", "r", "sysdbg", "l"),
    E("cpu", "b", "cpu2axi", "t"),
    E("sysdbg", "t", "cpu", "l", "debug_req", True),
    E("sysdbg", "b", "sbus", "t@0.178", "AXI_S0"),
    E("cpu2axi", "b", "sbus", "t@0.422", "AXI_S1"),
    E("dma", "b", "sbus", "t@0.667", "AXI_S2"),
    E("sbus", "b@0.106", "rom", "t", "AXI_M0"),
    E("sbus", "b@0.319", "isram", "t", "AXI_M1"),
    E("sbus", "b@0.544", "dsram", "t", "AXI_M2"),
    E("sbus", "b@0.780", "apb", "t", "AXI_M3"),
]
emit([("fig_qsoc_mem", "Where the two blocks sit in QSOC", f, e)], DRAWIO, IMG)
