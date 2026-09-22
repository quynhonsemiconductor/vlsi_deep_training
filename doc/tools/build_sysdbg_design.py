import os
import sys
_DOC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # doc/
sys.path.insert(0, os.path.join(_DOC, "tools"))
from diagen import Node as N, Edge as E, emit

IMG = os.path.join(_DOC, "img")
DRAWIO = os.path.join(_DOC, "drawio", "QNSC_SYSDBG_Design.drawio")

# --------------------------------------------------------- 1. internal structure
# One closed loop: a command travels 1-4 left to right, the result travels 5-7
# right to left. Every arrow carries the signal name that makes it happen.
f1 = [
    N("pads", 20, 210, 150, 110, "JTAG pads\nTCK  TMS\nTDI  TDO", "blue", 10),

    N("ztck", 210, 60, 380, 480, "TCK clock domain", "group", 11, True, "top"),
    N("tap", 230, 110, 340, 72,
      "TAP controller\nCapture-DR · Shift-DR · Update-DR", "purple", 10),
    N("acc", 230, 232, 340, 78,
      "ACCESS shift register  68 bit\nop[1:0] · size[1:0] · addr[31:0] · data[31:0]", "green", 10),
    N("resp", 230, 350, 340, 70,
      "response latch\nrdata[31:0] · status[1:0]", "green", 10),
    N("also", 230, 452, 340, 60,
      "also in the chain:\nIR 4 bit · IDCODE 32 bit · BYPASS 1 bit", "grey", 9),

    N("cdc", 630, 232, 110, 188, "CDC\nreq / ack\n2-flop sync", "red", 10, True),

    N("zsys", 780, 60, 430, 420, "system clock domain", "group", 11, True, "top"),
    N("fsm", 800, 110, 390, 72,
      "Command FSM\nIDLE · DECODE · LOCAL / BUS · DONE", "yellow", 10),
    N("regs", 800, 232, 175, 78, "SYSDBG registers\nCTRL · STATUS · ID", "box", 9),
    N("dreq", 1015, 232, 175, 78, "debug_req logic\nCTRL[0] in, halt status out", "red", 9),
    N("axim", 800, 360, 390, 72, "Bus master\nreq · gnt · rsp_valid · be", "green", 10),

    N("cpu", 1260, 205, 165, 92, "Ibex CPU", "blue", 11, True),
    N("bus", 1260, 360, 165, 72, "S_BUS\nAXI_S0", "yellow", 11, True),

    N("steps", 20, 580, 1405, 160,
      "1  host shifts op, addr and data in on TDI\n"
      "2  at Update-DR the 68 bits are latched as one command\n"
      "3  the command crosses into the system clock domain\n"
      "4  the FSM executes it  |  addr[31:28] = 0xF goes to a SYSDBG register  |  "
      "anything else becomes a bus request\n"
      "5  rdata and status travel back across the CDC\n"
      "6  they are captured at the next Capture-DR\n"
      "7  the host shifts them out on TDO  |  so a READ takes two scans: "
      "one to ask, one to collect", "group", 11, False, "top"),
]
f1e = [
    E("pads", "r@0.12", "tap", "l", "TMS, TCK"),
    E("pads", "r@0.5", "acc", "l@0.35", "1  TDI"),
    E("acc", "r", "cdc", "l@0.2", "2  Update-DR"),
    E("cdc", "r@0.2", "fsm", "l", "3  cmd req"),
    E("fsm", "b@0.154", "regs", "t", "4a  local"),
    E("fsm", "b@0.5", "axim", "t@0.5", "4b  BUS"),
    E("regs", "r@0.8", "dreq", "l@0.8"),
    E("dreq", "r@0.25", "cpu", "l@0.25", "debug_req"),
    E("cpu", "l@0.85", "dreq", "r@0.85", "debug_mode"),
    E("axim", "r", "bus", "l", "axi_from_mem"),
    E("fsm", "l@0.8", "cdc", "r@0.8", "5  rdata, status"),
    E("cdc", "l@0.8", "resp", "r", "6  Capture-DR"),
    E("resp", "l", "pads", "r@0.85", "7  TDO"),
]

# --------------------------------------------------------- 2. command format
def fld(nid, x, w, top, bot, style):
    return N(nid, x, 90, w, 84, top + "\n" + bot, style, 11)

f2 = [
    N("t_in", 40, 40, 940, 34, "shifted IN on TDI  |  68 bits", "group", 12, True),
    fld("op",   40,  90, "op", "[1:0]", "red"),
    fld("size", 140, 90, "size", "[1:0]", "purple"),
    fld("addr", 240, 330, "addr", "[31:0]", "blue"),
    fld("data", 580, 400, "data", "[31:0]", "green"),

    N("t_out", 40, 230, 940, 34, "shifted OUT on TDO  |  same scan", "group", 12, True),
    N("rdata", 40, 280, 700, 84,
      "rdata [31:0]\nresult of the PREVIOUS command", "green", 11),
    N("status", 760, 280, 220, 84, "status\n[1:0]", "yellow", 11),

    N("leg", 40, 420, 940, 150,
      "op:  00 = NOP   |   01 = READ   |   10 = WRITE\n"
      "size:  00 = byte   |   01 = halfword   |   10 = word   ->  drives mem_be_o\n"
      "status:  00 = OK   |   01 = BUSY   |   10 = ERROR\n"
      "addr[31:28] = 0xF  ->  SYSDBG registers   |   otherwise  ->  system bus\n"
      "the payload always sits in the LOW bits of data: hardware shifts it into the addressed lane\n"
      "one scan = one command, and the answer arrives on the next scan", "box", 11),
]
f2e = []

# --------------------------------------------------------- 3. FSM
f3 = [
    N("idle", 60, 180, 170, 80, "IDLE\nwait for a command", "blue", 11, True),
    N("dec", 300, 180, 170, 80, "DECODE\nSYSDBG reg or bus?\nreject misaligned", "yellow", 11, True),
    N("loc", 300, 40, 170, 76, "LOCAL\nread/write CTRL,\nSTATUS", "purple", 10),
    N("axi", 540, 180, 170, 80, "BUS\nissue request,\nwait for rsp_valid", "green", 11, True),
    N("done", 780, 180, 170, 80, "DONE\nlatch rdata\nand status", "grey", 11, True),
    N("f3leg", 60, 370, 890, 96,
      "one scan = one command   |   status reads BUSY while the FSM is not in IDLE\n"
      "BusTimeout expiry inside BUS sets ERROR and STATUS.bus_timeout but does NOT leave the state:\n"
      "a granted request cannot be cancelled, so its response is waited for and discarded",
      "group", 10),
]
f3e = [
    E("idle", "r", "dec", "l", "op != NOP"),
    E("dec", "t", "loc", "b", "addr[31:28] = F"),
    E("dec", "r", "axi", "l", "otherwise"),
    E("loc", "r", "done", "t", "", False, False, 20),
    E("axi", "r", "done", "l", "rsp_valid"),
    E("done", "b", "idle", "b", "next Capture-DR", False, False, 330),
]

# --------------------------------------------------------- 4. host software stack
f4 = [
    N("app", 40, 40, 400, 80, "Our debug application\nhalt, load, dump, run", "blue", 12, True),
    N("api", 40, 160, 400, 90,
      "SYSDBG API\nread(addr) · write(addr, val)\nhalt() · resume()", "green", 11),
    N("jt", 40, 290, 400, 80, "JTAG layer\nir_scan() · dr_scan()", "purple", 11),
    N("ftdi", 40, 410, 400, 70, "libftdi (MPSSE mode)", "grey", 11),
    N("usb", 40, 520, 400, 70, "USB", "grey", 11),
    N("board", 540, 520, 360, 70, "FT2232H board", "yellow", 11),
    N("qsoc", 540, 410, 360, 70, "QSOC JTAG pins", "red", 12, True),
    N("note", 540, 40, 360, 330,
      "Each API call becomes\none 68-bit DR scan.\n\n"
      "read() needs two scans:\none to send the command,\none to collect rdata.\n\n"
      "Same reason JTAG\nreturns the PREVIOUS\nresult, not this one.", "group", 11),
]
f4e = [
    E("app", "b", "api", "t"),
    E("api", "b", "jt", "t"),
    E("jt", "b", "ftdi", "t"),
    E("ftdi", "b", "usb", "t"),
    E("usb", "r", "board", "l"),
    E("board", "t", "qsoc", "b"),
]

# --------------------------------------------------------- 5. halting the CPU
# The one flow worth walking through end to end in a presentation.
def step(nid, y, text, style):
    return N(nid, 60, y, 600, 74, text, style, 11)

f5 = [
    step("s1", 40,  "1.  PC:  halt()", "blue"),
    step("s2", 144, "2.  PC:  write(0xF000_0000, 0x1)\nbecomes one 68-bit DR scan", "blue"),
    step("s3", 248, "3.  JTAG:  op = WRITE, addr = 0xF000_0000, data = 1\nlatched at Update-DR", "purple"),
    step("s4", 352, "4.  CDC:  the command crosses to the system clock", "red"),
    step("s5", 456, "5.  FSM:  DECODE sees addr[31:28] = F, goes to LOCAL,\nwrites CTRL[0] = 1", "yellow"),
    step("s6", 560, "6.  SYSDBG:  debug_req driven high and HELD high", "yellow"),
    step("s7", 664, "7.  Ibex:  saves PC to dpc, sets dcsr.cause = 3,\njumps to DmHaltAddr, raises debug_mode", "green"),
    step("s8", 768, "8.  SYSDBG:  STATUS[2] = 1", "yellow"),
    step("s9", 872, "9.  PC:  read(0xF000_0004), two scans, sees bit 2 set\nthe CPU is halted", "blue"),

    N("k", 720, 40, 300, 340,
      "Colour = who is acting\n\n"
      "blue    the PC\n"
      "purple  the TCK domain\n"
      "red     the clock crossing\n"
      "yellow  SYSDBG, system clock\n"
      "green   the CPU\n\n"
      "Steps 1-6 are the command path.\nStep 7 is the CPU reacting.\n"
      "Steps 8-9 are how the host\nfinds out it worked.", "box", 11, False, "top"),
    N("k2", 720, 420, 300, 200,
      "Resume is the same path\nwith CTRL[1] instead,\nand the core returns\nthrough DRET.\n\n"
      "Reading memory is the same\npath with op = READ and an\naddress that is not 0xF...",
      "group", 11),
]
f5e = [E(f"s{i}", "b", f"s{i+1}", "t") for i in range(1, 9)]

emit([("fig_sysdbg_internal", "SYSDBG internal structure", f1, f1e),
      ("fig_jtag_cmd", "JTAG command format", f2, f2e),
      ("fig_sysdbg_fsm", "SYSDBG command FSM", f3, f3e),
      ("fig_host_stack", "Host software stack", f4, f4e),
      ("fig_halt_flow", "Halting the CPU, end to end", f5, f5e)],
     DRAWIO, IMG)
