import os
import sys
_DOC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # doc/
sys.path.insert(0, os.path.join(_DOC, "tools"))
from diagen import Node as N, Edge as E, emit

IMG = os.path.join(_DOC, "img")
DRAWIO = os.path.join(_DOC, "drawio", "QNSC_Interrupt_Map.drawio")

# ------------------------------------------------- 1. sources -> OR -> fast lines
# One OR per peripheral. 26 sources become 11 lines. No state anywhere.
PER = [("DMA", 1, "pulse", 0), ("SPI device", 8, "level", 1), ("SPI host", 2, "level", 2),
       ("I2C", 1, "level", 3), ("UART0", 1, "level", 4), ("UART1", 1, "level", 5),
       ("TIMER1", 2, "pulse", 6), ("PWM", 4, "pulse", 7), ("WDT wakeup", 1, "level", 8),
       ("GPIO0-3", 4, "pulse", 9), ("TIMER0", 1, "pulse", 10)]

f1 = []
Y0, DY = 96, 46
for name, n, shape, line in PER:
    y = Y0 + line * DY
    f1.append(N("p%d" % line, 40, y, 168, 34,
                "%s   %d src" % (name, n), "blue" if shape == "level" else "green", 10))
    f1.append(N("or%d" % line, 262, y, 54, 34, "OR" if n > 1 else "\u2014", "grey", 10))
    f1.append(N("l%d" % line, 372, y, 210, 34,
                "irq_fast_i[%d]    mcause %d" % (line, 16 + line), "yellow", 10))

f1 += [
    N("nmisrc", 40, Y0 + 11 * DY + 14, 168, 34, "WDT bark   1 src", "red", 10),
    N("nmi", 372, Y0 + 11 * DY + 14, 210, 34, "irq_nm_i    mcause 31", "red", 10, True),
    N("cpu", 646, 180, 150, 210, "Ibex\n\nRV32IMC\n\nvectored\nmtvec", "blue", 13, True),
    N("intmap", 250, 74, 80, 11 * DY + 4, "INTMAP", "group", 11, True, "top"),
    # The legend used to restate sections 1, 7.2 and 10 in four sentences. A
    # diagram that repeats the text is a second copy to keep in step, so only the
    # one fact the drawing itself cannot show is kept.
    N("note", 40, Y0 + 12 * DY + 26, 756, 34,
      "11 OR gates, combinational: no clock, no reset, no flip-flop, no bus port.",
      "box", 11, False, "top"),
]
f1e = [E("p%d" % l, "r", "or%d" % l, "l") for _, _, _, l in PER]
f1e += [E("or%d" % l, "r", "l%d" % l, "l") for _, _, _, l in PER]
f1e += [E("l0", "r", "cpu", "l@0.12", "11 lines"),
        E("nmisrc", "r", "nmi", "l", "feed-through"),
        E("nmi", "r", "cpu", "l@0.9")]

# ------------------------------------------------- 2. what replaced what
f2 = [
    N("t", 40, 70, 760, 30, "The same 27 sources, three ways", "group", 12, True),
    N("h1", 40, 116, 246, 30, "OR tree  --  this revision", "green", 11, True),
    N("h2", 300, 116, 246, 30, "Latched in-house  V2.0-V7.0", "grey", 11, True),
    N("h3", 560, 116, 240, 30, "rv_plic  V8.0-V10.1", "grey", 11, True),

    N("a1", 40, 156, 246, 210,
      "11 fast lines + NMI\n\nmcause names the peripheral\n\n0 bus access per interrupt\n\n"
      "COMBINATIONAL\n\n0 flip-flops\n\nno register, no address",
      "green", 10, False, "top"),
    N("a2", 300, 156, 246, 210,
      "10 fast lines + NMI\n\nmcause names the peripheral\n\n1 bus access (W1C)\n\n"
      "1 cycle\n\n52 flip-flops\n\n6 registers on APB_M15",
      "box", 10, False, "top"),
    N("a3", 560, 156, 240, 210,
      "1 line (irq_external) + NMI\n\nread the CLAIM register\n\n2 bus access, 1 blocking\n\n"
      "2 cycles\n\n258 flip-flops\n\n10 registers, 4 MiB on AXI_M4",
      "box", 10, False, "top"),

    N("w", 40, 386, 760, 92,
      "What the OR tree gives up, stated rather than hidden:\n"
      "1  a one-cycle pulse arriving while mstatus.MIE is clear is LOST -- recoverable for 10 of 11 pulse\n"
      "    sources, but NOT for DMA, which has no status register.  That is the one open dependency.\n"
      "2  priority is FIXED at elaboration: it is the fast-line index, resolved lowest-index-first by Ibex.\n"
      "3  mcause 16-30 is an Ibex extension, so firmware is tied to this core.", "yellow", 11, False, "top"),
]
f2e = []

emit([("fig_intr_map", "INTMAP: 27 sources, one OR per peripheral, 12 wires to the CPU", f1, f1e),
      ("fig_intr_levels", "The three designs, and what this one trades", f2, f2e)],
     DRAWIO, IMG)
