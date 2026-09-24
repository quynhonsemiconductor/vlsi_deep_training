import os
import sys
_DOC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # doc/
sys.path.insert(0, os.path.join(_DOC, "tools"))
from diagen import Node as N, Edge as E, emit

IMG = os.path.join(_DOC, "img")
DRAWIO = os.path.join(_DOC, "drawio", "QNSC_Interrupt_Map.drawio")

# ------------------------------------------------- 1. sources -> INTMAP -> Ibex
# Everything per row is read from util/qsoc_contract.yml, so the figure cannot
# disagree with the generated tables. Monochrome, labels only.
import yaml
_C = yaml.safe_load(open(os.path.join(os.path.dirname(_DOC), "util",
                                      "qsoc_contract.yml")))["interrupts"]
NAME = {"dma": "DMA", "spi_device": "SPI device", "spi_host": "SPI host",
        "i2c": "I2C", "uart_0": "UART0", "uart_1": "UART1", "timer_0": "TIMER0",
        "timer_1": "TIMER1", "pwm": "PWM", "wdt_wakeup": "WDT", "wdt_bark": "WDT",
        "gpio": "GPIO0-2"}


def ports(l):
    """Same compaction as gen_doc_tables.source_ports, without markdown."""
    p, n = l["ports"], l["sources"]
    if len(p) > 4:
        pre, suf = p[0], p[0]
        while not all(x.startswith(pre) for x in p):
            pre = pre[:-1]
        while not all(x.endswith(suf) for x in p):
            suf = suf[1:]
        return "%s*%s ×%d" % (pre, suf, len(p))
    if len(p) == 1 and n > 1 and "[" not in p[0]:
        return "%s ×%d" % (p[0], n)
    return ", ".join(p)


def shape(l):
    s = l["shape"]
    return "pulse/level" if ("pulse" in s and "level" in s) else s


def inport(l):
    n = l["sources"]
    return "i_int_%s%s" % (l["peripheral"], "[%d:0]" % (n - 1) if n > 1 else "")


Y0, DY, H = 96, 44, 32
XS, WS = 40, 200          # source boxes
XG, WG = 272, 150         # gate boxes inside INTMAP
XC, WC = 560, 190         # Ibex outline
XP, WP = 570, 170         # core input pins inside Ibex
XT, WT = 490, 44          # tie-off constants, in design/top

f1, f1e = [], []
rows = list(_C["lines"]) + [dict(_C["nmi"], line=len(_C["lines"]))]
ncore = len(rows) + 1 + len(_C["tied_low"])     # + the spare-line pin
f1.append(N("cpu", XC, Y0 - 34, WC, ncore * DY + 34, "Ibex", "box", 12, True, "top"))
f1.append(N("intmap", XG - 14, Y0 - 30, WG + 28, len(rows) * DY + 22,
            "INTMAP", "group", 11, True, "top"))
for k, l in enumerate(rows):
    y = Y0 + k * DY
    nmi = l is rows[-1]
    st = "red" if nmi else "box"
    f1.append(N("s%d" % k, XS, y, WS, H,
                "%s\n%s · %s" % (NAME[l["peripheral"]], ports(l), shape(l)), st, 9))
    f1.append(N("g%d" % k, XG, y, WG, H,
                "%s\n%s" % (inport(l), "OR" if l["sources"] > 1 else "wire"), st, 9))
    if nmi:
        pin, out = "irq_nm_i   mcause %d" % l["mcause"], "o_int_nm"
    else:
        pin, out = ("irq_fast_i[%d]   mcause %d" % (k, 16 + k),
                    "o_int_fast[%d]" % k)
    f1.append(N("p%d" % k, XP, y, WP, H, pin, st, 9, nmi))
    f1e += [E("s%d" % k, "r", "g%d" % k, "l"), E("g%d" % k, "r", "p%d" % k, "l", out)]

used, avail = len(_C["lines"]), _C["fast_lines_available"]
ties = [("irq_fast_i[%d:%d]" % (avail - 1, used), "%d'b0" % (avail - used))]
ties += [(p, "0") for p in _C["tied_low"]]
for j, (pin, val) in enumerate(ties):
    k = len(rows) + j
    y = Y0 + k * DY
    f1.append(N("tp%d" % j, XP, y, WP, H, pin, "box", 9))
    f1.append(N("tv%d" % j, XT, y + 8, WT, H - 16, val, "box", 9))
    f1e.append(E("tv%d" % j, "r", "tp%d" % j, "l"))
ty = Y0 + len(rows) * DY
f1.append(N("top", XT - 12, ty - 12, WT + 24, len(ties) * DY,
            "design/top", "group", 9, False, "top"))

# ------------------------------------------------- 2. what replaced what
f2 = [
    N("t", 40, 70, 760, 30, "The same 26 sources, three ways", "group", 12, True),
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

emit([("fig_intr_map", "INTMAP: 5 OR gates and 6 wires onto irq_fast_i[10:0], one wire onto irq_nm_i", f1, f1e),
      ("fig_intr_levels", "The three designs, and what this one trades", f2, f2e)],
     DRAWIO, IMG)
