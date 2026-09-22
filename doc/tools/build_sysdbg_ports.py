import os
import sys
_DOC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # doc/
sys.path.insert(0, os.path.join(_DOC, "tools"))
from diagen import Node as N, Edge as E, emit

IMG = os.path.join(_DOC, "img")
DRAWIO = os.path.join(_DOC, "drawio", "QNSC_SYSDBG_Ports.drawio")

# ---------------------------------------------------------------- figure 1
# the nine steps, split across the two domains that actually carry the traffic
L, R, W = 60, 540, 330
f1 = [
    N("hL", L, 26, W, 46, "SYSDBG   (debug module)", "purple", 12, True),
    N("hR", R, 26, W, 46, "Ibex CPU", "blue", 12, True),

    N("s1", L,  96, W, 70, "1   Debugger writes\ndmcontrol.haltreq = 1   (over DMI)", "purple", 10),
    N("s2", R, 186, W, 70, "2   debug_req rises\nthe only debug input pin", "red", 10),
    N("s3", R, 276, W, 70, "3   PC saved to dpc\nPC <- DmHaltAddr", "blue", 10),
    N("s4", R, 366, W, 70, "4   CPU fetches the debug ROM\nfrom SYSDBG's slave port", "green", 10),
    N("s5", R, 456, W, 70, "5   CPU stores to\nHalted   (offset 0x100)", "green", 10),
    N("s6", L, 546, W, 70, "6   SYSDBG sees that write\ndmstatus.allhalted = 1", "purple", 10),
    N("s7", L, 636, W, 70, "7   SYSDBG writes an instruction\ninto AbstractCmd   (0x338)", "purple", 10),
    N("s8", R, 726, W, 70, "8   CPU executes it\nsw x5 -> DataAddr   (0x380)", "green", 10),
    N("s9", L, 816, W, 70, "9   SYSDBG reads the value,\nsends it out over DMI", "purple", 10),

    N("key", 60, 920, 810, 56,
      "red = the one dedicated wire        green = bus traffic through the slave port", "grey", 10),
]
f1e = [
    E("s1", "r", "s2", "l", "one wire"),
    E("s2", "b", "s3", "t"),
    E("s3", "b", "s4", "t"),
    E("s4", "b", "s5", "t"),
    E("s5", "l", "s6", "r", "bus write"),
    E("s6", "b", "s7", "t"),
    E("s7", "r", "s8", "l", "bus read"),
    E("s8", "l", "s9", "r", "bus write"),
]

# ---------------------------------------------------------------- figure 2
# what one bus port buys, and what it does not
f2 = [
    N("dbg", 40, 200, 200, 170, "SYSDBG", "red", 14, True),
    N("cpu", 640, 60, 200, 90, "Ibex CPU", "blue", 12),
    N("bus", 640, 240, 200, 130, "S_BUS", "yellow", 13, True),
    N("mem", 640, 450, 200, 80, "ROM, RAMs\nperipherals", "green", 11),

    N("can", 40, 570, 800, 62,
      "STAGE 1, master port alone | halt, resume, reset, read and write memory, load firmware",
      "green", 11),
    N("cant", 40, 652, 800, 62,
      "STAGE 2, needs a slave port | read a CPU register, single-step, attach GDB",
      "red", 11),
]
f2e = [
    E("dbg", "t", "cpu", "l", "debug_req  (dedicated wire)"),
    E("dbg", "r@0.25", "bus", "l@0.25", "AXI_S0 master | in Stage 1"),
    E("bus", "l@0.75", "dbg", "r@0.75", "slave port | Stage 2 only", True),
    E("cpu", "b", "bus", "t"),
    E("bus", "b", "mem", "t"),
]

emit([("fig_sysdbg_ports", "What one bus port can and cannot reach", f2, f2e)],
     DRAWIO, IMG)
