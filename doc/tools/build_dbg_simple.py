import os
import sys
_DOC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # doc/
sys.path.insert(0, os.path.join(_DOC, "tools"))
from diagen import Node as N, Edge as E, emit

IMG = os.path.join(_DOC, "img")
DRAWIO = os.path.join(_DOC, "drawio", "QNSC_Debugger_Block.drawio")

# Top-level view of the in-house SYSDBG block: JTAG in, bus master and debug_req out.
f = [
    N("pc", 20, 210, 150, 90, "PC\ndebug application", "blue", 11, True),
    N("ftdi", 200, 210, 130, 90, "FT2232H\nUSB to JTAG", "grey", 10),

    N("box", 366, 40, 470, 470, "SYSDBG  |  in-house block", "group", 12, True, "top"),
    N("jtag", 390, 88, 200, 72, "JTAG front-end\nTAP · IR · DR", "purple", 10),
    N("cdc", 620, 88, 190, 72, "CDC\nTCK to system clock", "red", 10),
    N("fsm", 390, 190, 420, 72, "Command FSM   decode · execute", "yellow", 10),
    N("regs", 390, 292, 200, 72, "SYSDBG registers\nCTRL · STATUS · ID", "box", 9),
    N("dreq", 620, 292, 190, 72, "debug_req logic", "red", 10),
    N("axim", 390, 394, 420, 72, "Bus master  req / gnt / rsp_valid", "green", 10),

    N("cpu", 900, 248, 160, 84, "Ibex CPU\nRV32IMC", "blue", 11, True),
    N("bus", 900, 394, 160, 72, "S_BUS\nAXI_S0", "yellow", 11, True),
    N("ram", 900, 500, 160, 72, "RAM, ROM\nperipherals", "grey", 10),

    N("leg", 20, 560, 560, 120,
      "1  a command is shifted in over JTAG\n"
      "2  the 68 bits are op, size, addr and data\n"
      "3  it crosses into the system clock domain\n"
      "4  the FSM runs it: a SYSDBG register, or a bus request\n"
      "5  rdata and status go back out on the next scan", "group", 10, False, "top"),
]
e = [
    E("pc", "r", "ftdi", "l", "USB"),
    E("ftdi", "r", "jtag", "l", "1  TCK TMS TDI TDO"),
    E("jtag", "r", "cdc", "l", "2  68 bit"),
    E("cdc", "b", "fsm", "t@0.774", "3  command"),
    E("fsm", "b@0.238", "regs", "t", "4a  local"),
    E("fsm", "b@0.5", "axim", "t@0.5", "4b  AXI"),
    E("fsm", "b@0.774", "dreq", "t"),
    E("fsm", "t@0.238", "jtag", "b", "5  rdata, status"),
    E("regs", "r@0.8", "dreq", "l@0.8"),
    E("axim", "r", "bus", "l", "axi_from_mem"),
    E("dreq", "r@0.25", "cpu", "l@0.25", "debug_req"),
    E("cpu", "l@0.85", "dreq", "r@0.85", "debug_mode"),
    E("bus", "b", "ram", "t"),
]
emit([("fig_dbg_simple", "SYSDBG top level", f, e)], DRAWIO, IMG)
