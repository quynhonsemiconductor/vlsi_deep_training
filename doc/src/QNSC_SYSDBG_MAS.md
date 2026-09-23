---
title: "SYSDBG"
subtitle: "MICRO-ARCHITECTURE SPECIFICATION -- V2.0"
author: "QUY NHON SEMICONDUCTORS -- QNSC"
---

# Revision history

`V2.0` is a rewrite. The fourteen versions before it, and the reasoning and
evidence behind every decision recorded here, are in
[`QNSC_SYSDBG_DECISIONS.md`](QNSC_SYSDBG_DECISIONS.md).

| Version | Date | Author | Reviewer | Description of change |
|---|---|---|---|---|
| V2.0 | 2026-09-23 | Nghia VT | -- | Rewritten as specification only. Two block diagrams disagreed about where the CDC sits; the wrong one is deleted. Tables and figures are numbered by the build instead of by hand. Host software, the sourcing argument and the closed questions move to `_DECISIONS` |

# 1. Overview

`SYSDBG` is the QSOC debugger: it terminates a JTAG connection from the host, turns
each command arriving on it into one bus transaction on `AXI_S0`, drives the Ibex
`debug_req` input, and reports status back over the same JTAG scan.

**Designed in house.** `pulp-platform/riscv-dbg` is read as a reference and for the
address constants Ibex needs; no part of it is instantiated.

Two facts about its position shape the whole design:

- **It is a bus master, and only a master.** Nothing gives this block a slave port.
  It reads and writes memory and peripherals with no CPU involvement, which is how
  firmware is loaded.
- **The CPU cannot be reached over the bus.** Ibex exposes only master interfaces,
  so no master can address it, and two masters cannot talk to each other. Reading a
  CPU register therefore means making the core store the value to memory and
  reading that -- section 7.6, and the reason section 11 asks for a reserved
  memory window.

Outside any bus, `SYSDBG` carries one wire into the core, `debug_req_o`, and one
back, `debug_mode_i`.

Block directory `design/sysdbg`, module `m_qnsc_sysdbg`, owner Nghia Van Trong.

# 2. Features

- **JTAG Test Access Port** to IEEE 1149.1, with `IDCODE`, `BYPASS` and one command
  register.
- **One 68-bit command register**, so one JTAG scan is one read or one write.
- **Run control**: halt and resume the Ibex hart through `debug_req_o` and
  `debug_mode_i`.
- **Bus master on `AXI_S0`**: any address in the system memory map, byte, halfword
  or word, **including while the CPU runs**.
- **CPU register access with no extra port**, by having the halted core execute a
  short sequence from a reserved memory window.
- **A slave that never answers is reported, not abandoned** -- section 7.4.

# 3. Block diagram

![Internal structure, the two clock domains, and the crossing between them](../img/fig_sysdbg_internal.png){width=6.5in}

A command travels left to right across the top, the answer returns right to left
along the bottom, and **both directions pass through the one CDC**. The numbered
steps are the path of section 7.3.

: SYSDBG sub-blocks

| Domain | Sub-block | Role |
|---|---|---|
| `tck` | TAP controller | The IEEE 1149.1 state machine, driven by `tms_i` |
| `tck` | IR, 4 bit | Selects which data register is in the scan chain |
| `tck` | `IDCODE`, 32 bit | Identifies QSOC to the host |
| `tck` | `BYPASS`, 1 bit | Required by the standard |
| `tck` | `ACCESS`, 68 bit | The command register, section 7.2 |
| boundary | `m_sysdbg_cdc` | Request/acknowledge handshake, section 7.5 |
| system | Command FSM | Decodes and executes one command, section 7.3 |
| system | Register file | `CTRL`, `STATUS`, `ID`, section 6 |
| system | `debug_req` logic | Drives the CPU input, samples `debug_mode_i` |
| system | Bus master | Issues transactions towards `AXI_S0` |

# 4. IP used

: Upstream IP used

| From | Module | Commit | Licence |
|---|---|---|---|
| -- | -- | -- | -- |

**Nothing is instantiated.** Two upstream sources are used without being built in:

- `pulp-platform/riscv-dbg` -- read to learn what a debug module must do, and for
  the `Dm*` address constants the Ibex integration declares. Its abstract commands,
  program buffer and spec-compliant DMI are all far larger than QSOC needs.
- `pulp-platform/axi` -- `axi_from_mem` converts this block's port to AXI4 at the
  crossbar. **It is the bus owner's to deliver**, so that every protocol conversion
  in the chip has one owner; this block's testbench instantiates it only to check
  the AXI4 side. `MaxRequests = 1`, because one command is outstanding at a time.

# 5. Interface

: SYSDBG port list

| Group | Signal | Dir | Width | Notes |
|---|---|---|---:|---|
| Clock, reset | `clk_i`, `rst_ni` | in | 1 | System domain |
| JTAG | `tck_i`, `tms_i`, `tdi_i` | in | 1 | From the pads |
| | `tdo_o` | out | 1 | Driven only in a Shift state |
| | `tdo_oe_o` | out | 1 | Output enable for the pad |
| | `trst_ni` | in | 1 | Optional by the standard; provided |
| CPU | `debug_req_o` | out | 1 | Level-sensitive, held until resume |
| | `debug_mode_i` | in | 1 | From `ibex_top`, section 11 |
| Bus master | `mem_req_o`, `mem_addr_o`, `mem_we_o` | out | 1 / 32 / 1 | Request, address, direction |
| | `mem_wdata_o`, `mem_be_o` | out | 32 / 4 | Write data and its byte enables |
| | `mem_gnt_i` | in | 1 | Request accepted |
| | `mem_rsp_valid_i` | in | 1 | Response, once per request, read **or** write |
| | `mem_rsp_rdata_i`, `mem_rsp_error_i` | in | 32 / 1 | Read data, and the bus error flag |

`tdo_oe_o` exists because the standard requires `TDO` to be tri-stated outside the
Shift states so several devices can share one chain. QSOC has one TAP today;
omitting the enable would make adding a second device a change to this block rather
than to the pad ring.

The bus port names are those of `axi_from_mem` with the directions flipped, so the
instantiation is a straight connection with no renaming table to get wrong.

: SYSDBG parameters

| Parameter | Default | Meaning |
|---|---|---|
| `IdcodeValue` | `0x0515_3001` | Part number `0x5153` is hex-ASCII "QS"; manufacturer `0x000`, QSOC having no JEDEC ID; bit 0 set as the standard requires |
| `AddrWidth` | 32 | Must match `S_BUS` |
| `DataWidth` | 32 | The `ACCESS` register width follows from it |
| `RegBaseAddr` | `0xF000_0000` | Base of the `SYSDBG` register window |
| `RegAddrMatch` | `addr[31:28] == 4'hF` | The decode rule of section 7.3 |
| `SyncStages` | 2 | Flip-flops per CDC synchroniser. Raise to 3 only if timing analysis asks |
| `BusTimeout` | 1024 | System-clock cycles before an unanswered request is **reported** -- never abandoned, section 7.4 |

# 6. Register map

Reachable **over JTAG only**. They are deliberately absent from the system bus, so
software running on the CPU cannot halt itself or grant itself debug access.

: SYSDBG register map

| Address | Name | Access | Bits |
|---|---|---|---|
| `0xF000_0000` | `CTRL` | RW | `[0]` `haltreq` · `[1]` `resumereq` · `[2]` reserved, reads 0 |
| `0xF000_0004` | `STATUS` | RO | `[0]` `busy` · `[1]` `error` · `[2]` `cpu_halted` · `[3]` `bus_timeout` |
| `0xF000_0008` | `ID` | RO | Version and build identifier |

Halting the CPU is `write(0xF000_0000, 1)`; confirming it halted is
`read(0xF000_0004)` and testing bit 2.

The three `CTRL` bits **do not behave alike**, and a driver written against the
wrong assumption fails in a way that looks like the CPU ignoring the debugger:

: CTRL bit behaviour

| Bit | Behaviour | Why |
|---|---|---|
| `[0]` `haltreq` | **Held.** Written 1, stays 1, cleared only by writing `resumereq` | `debug_req_o` is level-sensitive. A self-clearing bit would drop the request before the core had acted on it |
| `[1]` `resumereq` | **Write 1, self-clearing**, reads back 0 | It is an event, not a state: its effect is to clear `haltreq` |
| `[2]` | Reserved, reads 0, writes ignored | QSOC has no debug reset -- section 7.1. The position is left unused rather than reassigned, so a host built against an earlier revision cannot trigger something else |

**Writing `resumereq` lowers `debug_req_o`; it does not restart the core.** Once in
Debug Mode the core stays there until it executes `dret` -- `ibex_controller.sv`
clears `debug_mode_d` in exactly one place, the `dret` branch. Section 7.7 gives the
mechanism and the order the two steps must be taken in.

# 7. Functional behaviour

## 7.1 Clock and reset domains

`SYSDBG` is **the only block in QSOC with a genuinely asynchronous input clock**.
It spans two clocks and three reset domains.

: SYSDBG clock and reset domains

| Domain | Clocked by | Reset by |
|---|---|---|
| JTAG | `tck_i`, supplied by the adapter and **free to stop** | `trst_ni`, plus the TAP's Test-Logic-Reset state |
| System | `clk_i`, always running | `rst_ni`, the chip power-on reset |
| The crossing | both | neither -- the handshake of 7.5 survives either reset asserting alone |

**QSOC has no debug reset, so this block cannot restart the chip.** The Day005
review of 2026-09-18 fixed the reset sources at three -- power-on, watchdog,
software -- and removed debug reset to keep the reset tree simple; `SCRC` confirms
it, its global combine having two inputs and its cause register three causes with no
`DEBUG` among them.

The cost, stated plainly: the only ways to restart QSOC are power cycling, the
watchdog, or a software reset written by the CPU. The last needs the CPU running, so
a core wedged with interrupts disabled leaves only the watchdog or removing power.

## 7.2 The ACCESS command register

![The ACCESS register, bit by bit](../img/fig_jtag_cmd.png){width=6.3in}

: ACCESS data register fields

| Field | Bits | Meaning |
|---|---:|---|
| `op` | `[67:66]` | `00` NOP · `01` READ · `10` WRITE |
| `size` | `[65:64]` | `00` byte · `01` halfword · `10` word · `11` reserved |
| `addr` | `[63:32]` | Byte address |
| `data` | `[31:0]` | Write data, or read data on the way back |

One scan is one access. **A read takes two scans**: the first delivers the command,
the second collects the result, because the answer cannot be shifted out of a
register that is still being shifted in.

**Byte enables and lane alignment.** `mem_be_o` is derived from `size` and the low
address bits, as `dm_sba` derives its `be_mask`: a byte sets one bit chosen by
`addr[1:0]`, a halfword two chosen by `addr[1]`, a word all four. Sub-word access is
not a luxury -- QSOC is RV32I**MC**, so planting a breakpoint over a compressed
instruction is a **halfword** write. The block also does the lane shift **in
hardware**: the host always puts the value in the low bits of `data` and never needs
to know the shift. Stated explicitly because a silent disagreement about it is a bug
that looks like corrupted memory.

## 7.3 Command FSM

![Command FSM](../img/fig_sysdbg_fsm.png){width=6.0in}

: Command FSM states

| State | What happens |
|---|---|
| `IDLE` | Wait for Update-DR with `op != NOP` |
| `DECODE` | Inspect `addr[31:28]`: local register file or system bus. A misaligned access or reserved `size` is rejected here, with no request issued |
| `LOCAL` | Read or write `CTRL` / `STATUS` / `ID`; one cycle |
| `BUS` | Drive `mem_req_o`; wait for `mem_gnt_i`, then `mem_rsp_valid_i` |
| `DONE` | Latch `rdata` and `status` for the next scan to collect |

`addr[31:28] = 0xF` selects the register file; **every other address is handed to
the bus master unchanged**, so the whole memory map is reachable with no special
cases.

While the FSM is not in `IDLE`, `status` reads back `BUSY`. A host that issues a
command early gets `BUSY` rather than a corrupted result, which makes the protocol
safe to drive from a program with no timing model of the target.

## 7.4 A slave that never answers is reported, not abandoned

An unmapped address, or a block whose clock is stopped, would leave the FSM waiting
forever -- and a debugger that hangs takes with it the only tool for finding out
why. The tempting fix is to give up after `BusTimeout` and return `ERROR`. **That is
wrong, and quietly so:** neither AXI, nor TL-UL, nor a `req`/`gnt` bus can cancel a
granted request. A block that stops waiting still has a response coming, and it
would be delivered to the **next** command -- the host receiving data from an
address it never asked about, with `status = OK`. A silent wrong answer from the
debugger is worse than a visible stall, because every conclusion drawn after it is
also wrong.

So on expiry the FSM latches `status = ERROR`, sets `STATUS.bus_timeout`, and
**keeps waiting**. `busy` stays high, so a further command is answered `BUSY` and
never handed a mismatched result. A late response is **discarded** and the FSM
returns to `IDLE`. If none arrives, `busy` and `bus_timeout` both stay set, and that
pair is a diagnosis rather than a hang: the host reads `STATUS` over JTAG, a path
that does not touch the system bus, and knows a slave is not answering. `dm_sba` in
`riscv-dbg` takes the same position, exposing `sbbusy_o` and never cancelling.

## 7.5 Clock domain crossing

Three rules, and **nothing else crosses the boundary**:

1. The 68-bit command is **captured once**, at Update-DR, and passed across as one
   unit with a request/acknowledge pair. The shift register is never sampled from
   the system side; it is moving.
2. `rdata` and `status` cross back the same way and are **captured at Capture-DR**,
   so the value the host shifts out is stable for the whole scan.
3. **Two-flop synchronisers** on the request and acknowledge lines.

The classic slow-to-fast handshake, in a separate module `m_sysdbg_cdc` so it can be
verified alone. The four crossing signals are named here so the figure and the
testbench agree: **`cmd_req`**, **`cmd_ack`** inbound, **`rsp_req`**, **`rsp_ack`**
outbound. Each is one bit and each is **toggled, not pulsed**, so a level-change
detector on the far side works however long `TCK` stays stopped.

**A timing constraint must accompany it**, or the tool will try to close timing
between two unrelated clocks and report failures that mean nothing:

```tcl
set_false_path -from [get_clocks tck] -to [get_clocks clk]
set_false_path -from [get_clocks clk] -to [get_clocks tck]
```

With it, the handshake is what guarantees correctness -- which is the reason only
two single-bit signals are allowed to cross.

## 7.6 Reading a CPU register

A CPU register has **no bus address**, so no amount of bus mastering reaches it. The
only defined route is to make the core **execute a store**, then read where it
stored.

: Debug memory window

| Address | Contents |
|---|---|
| `0x2000_0000` | Instruction sequence the halted core jumps to |
| `0x2000_0800` | `DmHaltAddr` -- the dispatch loop, entered on every halt |
| `0x2000_0F00` | Result word the sequence publishes |
| `0x2000_0F08` | Command word: non-zero means a sequence is waiting |
| `0x2000_0F0C` | Resume flag |

**The dispatch loop** at `DmHaltAddr` polls the command word and the resume flag.
Non-zero command: jump to `0x2000_0000`. Non-zero resume flag: clear it and execute
`dret`, which restores the PC from `dpc` and leaves Debug Mode. Both zero: spin.

**A sequence must destroy nothing**, including the register it needs for an address.
Ibex implements `dscratch0` at `0x7b2` and `dscratch1` at `0x7b3` for exactly this,
and ordinary firmware never touches them:

```asm
        csrw    dscratch0, t0       # park t0 where firmware cannot see it
        csrw    dscratch1, t1
        lui     t0, 0x20000         # window base
        csrr    t1, dpc             # the value being fetched
        sw      t1, 0xF00(t0)       # publish the result
        sw      zero, 0xF08(t0)     # clear the command word LAST
        csrr    t1, dscratch1       # restore, in reverse order
        csrr    t0, dscratch0
        j       0x2000_0800         # back to the dispatch loop
```

**The result is written before the command word is cleared**, and that order is the
handshake: the host polls the command word, and a zero means the result beside it is
already valid.

## 7.7 Resume, and why the order of the two steps matters

Resuming is two writes, and **reversing them re-halts the core immediately**:

1. Set the **resume flag** at `0x2000_0F0C`, so the dispatch loop will execute
   `dret`.
2. Then write `resumereq`, which lowers `debug_req_o`.

Do it the other way and `debug_req_o` falls while the core is still spinning in the
loop; the loop has nothing to tell it to leave, and the next thing it sees is a
fresh halt request. Ordering only, no RTL: the block cannot enforce it, so it is a
host-software obligation and a verification case in section 12.

# 8. Instances

One, instantiated in `design/top`. Parameters as section 5.

# 9. What is not provided here, and who provides it

![What one bus port can and cannot reach](../img/fig_sysdbg_ports.png){width=6.2in}

: Functions this block does not provide

| Function | Where it lives |
|---|---|
| AXI4 conversion at `AXI_S0` | `axi_from_mem`, delivered by the **bus owner** -- section 4 |
| A debug ROM | Nowhere. The dispatch loop is ordinary code in `ISRAM` -- 7.6 |
| A program buffer | Nowhere. Sequences are in `ISRAM`, not inside this block |
| `dret` | The dispatch loop executes it; this block only lowers `debug_req_o` |
| The instruction sequences, and the resume ordering | **Host software**, specified in `_DECISIONS` |
| Protection of the JTAG pins and the debug clock gate | IO MUX and SCRC owners -- section 11 |

**Every capability is delivered through one master port**, which is the point of the
figure. A standard debug module would put a program buffer inside itself and let the
core fetch from it; here the instructions go in `ISRAM` instead, so register access
needs no slave port.

# 10. Constraints this block imposes

: Constraints on synthesis, memory and host software

| On | Constraint | Consequence if missed |
|---|---|---|
| Synthesis | The two `set_false_path` statements of 7.5 | Meaningless timing failures between unrelated clocks |
| `ISRAM` | First 4 KiB reserved at `0x2000_0000` | The debug window and firmware overlap |
| Firmware | Main image linked at `0x2000_1000` | Same overlap, from the other side |
| Host software | Resume ordering of 7.7 | The core re-halts instead of resuming |

# 11. Requirements on others, and open items

: Requirements on other owners

| Item | Owner | What it blocks |
|---|---|---|
| **Export `debug_mode` from `ibex_top`** | CPU owner | How this block knows a sequence finished. Removes the need for a debug ROM |
| All four `Dm*` parameters, **not** the Ibex defaults | CPU owner | The window of 7.6 |
| `axi_from_mem` at `AXI_S0`, `MaxRequests = 1` | bus owner | Every bus access this block makes |
| `0xF000_0000` left **unmapped** on `S_BUS`, answering `DECERR` | bus owner | A slave claiming that region would shadow the registers of section 6 |
| 4 KiB reserved at `0x2000_0000`; main image at `0x2000_1000` | memory map owner, firmware owner | The window of 7.6 |
| **Debug clock gate open out of reset and not closable by software** | SCRC owner | Software able to close it disables the debugger **silently**: the TAP keeps working on `tck_i` while the FSM is frozen |
| **`SYSDBG` released from reset before the CPU** | SCRC owner | Halt-on-reset fails if `debug_req_o` is not already high when the core leaves reset |
| **IO MUX must not be able to steal the JTAG pins** | IO MUX owner | See below |

**The JTAG pins are shared with GPIO, and that is the block's worst hazard.**
`IOPAD_Pin_Summary` of 2026-09-20 places all five on `PIN_8`--`PIN_12` with **b00,
the JTAG function, as the reset default**, so the debugger works before firmware
runs. But each is shared with `GPIO0[7:3]` and the selection is a register firmware
can write: one write disconnects the adapter. **The failure is silent** -- the host
keeps shifting, nothing reports an error, `TDO` stops answering, and a dead adapter
is indistinguishable from a dead chip. With no debug reset, recovery is the watchdog
or power cycling the board.

Three acceptable answers, in order of preference:

: Acceptable rules for protecting the JTAG pins

| | Rule |
|---|---|
| Preferred | The IO MUX **ignores writes** that would move `PIN_8`--`PIN_12` out of b00 |
| Acceptable | Those five fields are writable only after a **lock bit** is cleared, the lock being set at reset |
| Minimum | Any reset reaching the IO MUX register returns the five fields to b00, so a watchdog bite restores debug access |

The minimum is listed separately because it costs nothing at design time and is the
difference between a recoverable board and one that needs its power removed.

**Accepted limits**, stated rather than hidden:

1. No debug reset. A wedged core is recovered by watchdog or power only -- 7.1.
2. A read costs two JTAG scans -- 7.2.
3. Reading a CPU register requires the core halted **and** the dispatch loop
   present; it is not available on a core that never reached `DmHaltAddr`.
4. Resume ordering cannot be enforced in RTL -- 7.7.

**Open on this block:** timing closure across the CDC, and the gate count, both of
which wait on synthesis. `SyncStages = 2` is the assumption to revisit first.

# 12. Verification

The RAM arrived with 46 tests already written. `SYSDBG` arrives with none, so the
plan is part of the design.

: SYSDBG verification plan

| Level | What is checked | How |
|---|---|---|
| `m_sysdbg_cdc` alone | No data sampled while moving; the handshake completes; `TCK` stopping mid-sequence | Two independent, deliberately unrelated clocks, including a `TCK` that stops after Update-DR |
| TAP alone | The 16-state walk from every state; `IDCODE` after reset; `BYPASS` is one bit; IR takes effect only at Update-IR | Directed `TMS` patterns |
| Command FSM alone | Every transition; `BUSY` while not `IDLE`; misaligned and reserved `size` rejected in `DECODE` | Stub slave with programmable grant and response latency |
| **`BusTimeout`** | On expiry: `ERROR` and `bus_timeout` set, `busy` stays high, no new command accepted; a response arriving **after** expiry is discarded, never returned | Stub slave answering only after `BusTimeout`. This is the test that proves the hazard of 7.4 is closed |
| Bus master port | `req` held until `gnt`; exactly one response per granted request; no second request while one is outstanding; `mem_be_o` never zero on a write and equal to the size-and-address decode | Four SVA properties, modelled on `sva/dm_sba_sva.sv` in `riscv-dbg` |
| With its adapter | AXI4 legality at `AXI_S0`; `SLVERR` and `DECERR` both arrive as `mem_rsp_error_i` and become `status = ERROR` | AXI checker applied to `SYSDBG` + `axi_from_mem` together, since that pair is what the crossbar sees |
| **Resume ordering** | The wrong order re-halts immediately; the specified order resumes once and stays running | Directed test driving both orders, checking `debug_mode_i` and `STATUS[2]` |
| Block level | One scan in produces the right transaction out; a read needs two scans; byte and halfword land in the right lane both ways; `debug_req_o` rises and is held | Behavioural JTAG driver plus a memory model |
| Lane alignment | Host always uses the low bits of `data`, both directions, for all three sizes | Part of the block-level test; called out because a disagreement here looks like memory corruption |

Two properties are **assertions, not test cases**, being invariants a directed test
can only sample:

1. `debug_req_o` never falls while `CTRL[0]` is set.
2. The system side never reads the `ACCESS` register while `shift_dr` is active.

**Acceptance criterion for the whole block:** write `CTRL.haltreq` over JTAG, poll
`STATUS[2]`, see it go high. Everything before proves a piece; that step is the
first that proves the block.

# Appendix A. Acronyms

: Acronyms

| Acronym | Description |
|---|---|
| CDC | Clock Domain Crossing |
| CSR | Control and Status Register |
| `dpc` | Debug Program Counter: the PC `dret` restores |
| `dret` | The instruction that leaves Debug Mode |
| `dscratch0`, `dscratch1` | Debug scratch CSRs, `0x7b2` and `0x7b3` |
| DMI | Debug Module Interface, in the RISC-V Debug Specification |
| `DmHaltAddr` | Address the core jumps to on halt |
| GPR | General Purpose Register |
| IR, DR | JTAG Instruction and Data Register |
| SCRC | System Clock Reset Control. Formerly `SYSCTL` on the block diagram |
| TAP | Test Access Port, IEEE 1149.1 |

# Appendix B. First review

: First review

| Item | Reviewer | Response |
|---|---|---|
| The block diagram does not show which domain the FSM is in, and puts the CDC in the wrong place | Teacher, 2026-09-23 | Correct, and it also drew the return path with no synchroniser. That figure is deleted; section 3 uses the one that was right, so two drawings cannot disagree again |
| Too long, and the redundancy causes wrong information | Teacher, 2026-09-23 | V2.0 is the answer: 998 lines to this, with the record kept whole in `_DECISIONS` |
| Does the block need a slave port for register access? | -- | No. Section 9: every capability goes through one master port |
| Should the bus timeout abandon the request? | -- | No, and section 7.4 gives the reason: a granted request cannot be cancelled, so the response would land on the next command |
