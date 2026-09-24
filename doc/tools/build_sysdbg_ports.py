import os
import sys
_DOC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # doc/
sys.path.insert(0, os.path.join(_DOC, "tools"))
from diagen import Node as N, Edge as E, emit

IMG = os.path.join(_DOC, "img")
DRAWIO = os.path.join(_DOC, "drawio", "QNSC_SYSDBG_Ports.drawio")

# What one bus port reaches, and how a CPU register is read without a slave port.
#
# The figure this replaces showed a dashed "slave port, Stage 2 only" arrow into
# SYSDBG and a legend reading "STAGE 2, needs a slave port". Both contradicted
# section 9 of the specification, which states that every capability is delivered
# through one master port. It also listed "reset" as a capability, and QSOC has no
# debug reset.
#
# Box labels are kept to a few words each: the explanation belongs in the
# specification, and a diagram that repeats it is a second copy to keep in step.
nodes = [
    N("dbg", 40, 210, 210, 150, "SYSDBG\nmaster only", "red", 13, True),
    N("cpu", 660, 40, 210, 100, "Ibex CPU\nmaster only", "blue", 12),
    N("bus", 660, 210, 210, 150, "S_BUS\ncrossbar", "yellow", 13, True),
    # Side by side, not stacked: stacked, the arrow to the lower box had to pass
    # through the upper one.
    N("isram", 540, 450, 230, 90, "ISRAM\ndispatch loop + sequences", "green", 11),
    N("rest", 800, 450, 230, 90, "ROM, DSRAM\nperipherals", "green", 11),

    N("key", 40, 610, 990, 86,
      "No slave port anywhere in this block.\n"
      "Two masters cannot address each other, so a CPU register is read by making\n"
      "the core store it to ISRAM, then reading ISRAM through the same master port.",
      "box", 11),
]
edges = [
    # Both dedicated wires go up and over on separate columns, so neither crosses
    # the crossbar box.
    E("dbg", "t@0.3", "cpu", "l@0.35", "debug_req"),
    E("cpu", "l@0.75", "dbg", "t@0.75", "debug_mode", True),
    E("dbg", "r@0.6", "bus", "l@0.6", "AXI_S0 master"),
    E("cpu", "b", "bus", "t"),
    E("bus", "b@0.25", "isram", "t"),
    E("bus", "b@0.75", "rest", "t"),
]

emit([("fig_sysdbg_ports", "What one bus port reaches", nodes, edges)], DRAWIO, IMG)
