---
title: "SYSDBG"
subtitle: "MICRO-ARCHITECTURE SPECIFICATION -- V3.2"
author: "QUY NHON SEMICONDUCTORS -- QNSC"
---

# Revision history

The reasoning behind each change, and every version before V3.0, is in
[`QNSC_SYSDBG_DECISIONS.md`](QNSC_SYSDBG_DECISIONS.md).

| Version | Date | Author | Reviewer | Description of change |
|---|---|---|---|---|
| V3.0 | 2026-09-23 | Nghia VT | -- | Rewritten after the teacher's reference design: JTAG data registers, native AXI4 manager, 4-phase handshake. Adds the `DBG_EN` pin and CPU hold |
| V3.1 | 2026-09-25 | Nghia VT | -- | Port names to `QNSC_RTL_Design_Naming_Rule` V1.0: `o_dbg_req`, `o_dbg_cpu_hold`, AXI named per channel (`o_bus_axi_ar_valid`, ...). No change in behaviour |
| V3.2 | 2026-10-15 | Sinh | -- | New boot flow (`QNSC_BOOT_SPEC` V3.1): `SYSDBG` no longer captures `DBG_EN`, holds the CPU or selects the boot address. Removed `i_dbg_en`, `o_dbg_en`, `o_dbg_cpu_hold` and the `CPUHOLD` register. Debug window layout updated |

# 1. Overview

`SYSDBG` is the QSOC debugger. A JTAG TAP takes commands from the host. An AXI4
manager on `AXI_S0` reads and writes memory. A 4-phase handshake links the two. It
also drives the Ibex `debug_req` input.

`SYSDBG` has no part in starting the CPU. The CPU always runs the ROM code from
`0x0000_0080` (`QNSC_BOOT_SPEC`). For a debug boot the ROM code waits in a polling
loop while `SYSCSR.DBG_EN` is 1. During that wait the host may use `SYSDBG` to raise
the Ibex debug request, and to clear the wait by writing `SYSCSR.DBG_EN_MASK` over the
bus (7.1).

`SYSDBG` does **not** reset the chip, hold the CPU, gate a clock, or hold a debug
ROM. It has no memory-mapped registers: everything is reached through JTAG.

Block directory `design/sysdbg`, module `m_qnsc_sysdbg`, owner Nghia Van Trong.

# 2. Features

- JTAG TAP to IEEE 1149.1, 4-bit IR, seven data registers.
- AXI4 manager: one-beat, 32-bit word reads and writes to any address, **including
  while the CPU runs**. One transaction at a time.
- 4-phase request/acknowledge handshake between the TCK and AXI clock domains.
- Halt through `debug_req`, set and cleared by the host.
- Debug boot support: raise the debug request during the ROM wait, and write
  `SYSCSR.DBG_EN_MASK` through the AXI manager -- 7.1.

# 3. Block diagram

![SYSDBG block diagram](../figures/img/fig_sysdbg_block.png){width=6.5in}

Three domains, as labelled in the figure: TCK (`i_jtag_tck`, reset `i_jtag_trst_n`
AND `i_rst_n_por`), AXI (`i_clk_cpu`, reset `i_rst_n_sysbus`) and system (`i_clk_cpu`,
reset `i_rst_n_por`). `i_clk_cpu` is the `cpu` cluster clock, the same clock as
`S_BUS`, and is never gated.

# 4. IP used

: Upstream IP used

| From | Module | Commit | Licence |
|---|---|---|---|
| -- | -- | -- | -- |

In house. Nothing is instantiated.

# 5. Interface

: SYSDBG interface

| Signal | Dir | Width | Description |
|---|---|---:|---|
| `i_clk_cpu` | in | 1 | System and AXI clock, 20 MHz |
| `i_rst_n_por` | in | 1 | Power-on reset only |
| `i_rst_n_sysbus` | in | 1 | `S_BUS` domain reset. Resets the AXI domain |
| `i_jtag_tck` | in | 1 | JTAG clock. Asynchronous to `i_clk_cpu`, may stop at any time |
| `i_jtag_tms`, `i_jtag_tdi` | in | 1 | Sampled on rising `TCK` |
| `i_jtag_trst_n` | in | 1 | JTAG reset |
| `o_jtag_tdo` | out | 1 | Changes on falling `TCK` |
| `o_jtag_tdo_oe` | out | 1 | 1 in Shift-IR and Shift-DR only |
| `o_dbg_req` | out | 1 | To Ibex `debug_req_i`. Level, from a flip-flop |
| `o_bus_axi_ar_valid`, `i_bus_axi_ar_ready` | out, in | 1 | AR handshake |
| `o_bus_axi_ar_addr` | out | 32 | Read address, `[1:0]` = 0 |
| `i_bus_axi_r_valid`, `o_bus_axi_r_ready` | in, out | 1 | R handshake |
| `i_bus_axi_r_data` | in | 32 | Read data |
| `i_bus_axi_r_resp` | in | 2 | Read response |
| `o_bus_axi_aw_valid`, `i_bus_axi_aw_ready` | out, in | 1 | AW handshake |
| `o_bus_axi_aw_addr` | out | 32 | Write address, `[1:0]` = 0 |
| `o_bus_axi_w_valid`, `i_bus_axi_w_ready` | out, in | 1 | W handshake |
| `o_bus_axi_w_data` | out | 32 | Write data |
| `i_bus_axi_b_valid`, `o_bus_axi_b_ready` | in, out | 1 | B handshake |
| `i_bus_axi_b_resp` | in | 2 | Write response |
| Other AXI4 signals | -- | -- | Constant outputs or unused inputs -- section 10 |

: SYSDBG parameters

| Parameter | Default | Meaning |
|---|---|---|
| `IdcodeValue` | `0x0515_3001` | Part `0x5153` ("QS"), manufacturer `0x000`, bit 0 = 1 |
| `AxiIdWidth` | 5 | `S_BUS` slave-port ID width |
| `SyncStages` | 2 | Flip-flops per synchroniser |

# 6. Register map

No memory-mapped registers. The registers below are JTAG data registers,
selected by the IR and shifted LSB first.

: JTAG instructions and data registers

| IR | Name | Bits | Capture-DR loads | Update-DR does | Reset |
|---|---|---:|---|---|---|
| `0100` | `ADDR` | 33 | `addr_reg` | Load `addr_reg`. If bit 32 = 0 and not busy: start a read | 0 |
| `0101` | `DATA` | 32 | `rdata_hold`, the last read data | Load `wdata_reg`. If `addr_reg[32]` = 1 and not busy: start a write | 0 |
| `0110` | `STATUS` | 3 | {`busy`, `resp[1:0]`} | Nothing | 0 |
| `0111` | `CPUDBG` | 1 | `dbgreq` | Load `dbgreq` | 0 |
| `1110` | `IDCODE` | 32 | `IdcodeValue` | Nothing | -- |
| `1111` | `BYPASS` | 1 | 0 | Nothing | -- |
| others | as `BYPASS` | 1 | 0 | Nothing | -- |

- `addr_reg[32]` is the direction: 0 read, 1 write. `addr_reg[1:0]` are ignored.
- `resp` is the AXI response of the last completed transaction: `00` OKAY, `10`
  SLVERR, `11` DECERR.
- IR is 4 bits. Capture-IR loads `0001`. Test-Logic-Reset loads `IDCODE`.

# 7. Functional behaviour

## 7.1 Role in the boot flow

`SYSDBG` takes no part in reset release or in choosing the boot address. The CPU
starts in the ROM on every reset (`QNSC_BOOT_SPEC` 4). The debug boot works like this:

1. The ROM code downloads the image over `UART0`. If `DEBUG_PROG` = `0x55` this
   includes the 4 KiB debug program, written to `0x2000_0000` (7.8).
2. The ROM code reads `SYSCSR.DBG_EN`. If it is 1, the CPU stays in a ROM polling
   loop. It is not held in reset.
3. The host may raise `CPUDBG`. `o_dbg_req` goes high and the CPU enters debug mode
   and jumps to the debug program at `0x2000_0800` (7.7). After `dret` the CPU returns
   to the polling loop and reads `SYSCSR.DBG_EN` again: debug mode pauses the wait, it
   does not end it.
4. To let the user program run, the host writes `SYSCSR.DBG_EN_MASK` = 1 through the
   AXI manager (`AXI_S0`, `S_BUS`, `P_BUS`, `SYSCSR`; 7.4). `SYSCSR.DBG_EN` then reads
   0 and the ROM code jumps to `0x2000_1080`.
5. JTAG can only clear the debug state. It cannot set `SYSCSR.DBG_EN` to 1.

With `DEBUG_PROG` = `0xAA` there is no debug program in the window. The host must not
raise `CPUDBG`, because there is no dispatch loop at `0x2000_0800`; it may still write
`DBG_EN_MASK` = 1. With `DEBUG_PROG` = `0x55` the host may raise `CPUDBG` at any time,
including while the user program runs.

`CPUDBG` is not gated by `DBG_EN_MASK`: `o_dbg_req` goes straight to Ibex `debug_req_i`.

To debug the ROM code, raise `CPUDBG` while the CPU runs it, but only after a debug
program is in the window.

## 7.3 Reset behaviour

: What each reset does

| Event | TCK domain | AXI domain | System domain | CPU |
|---|---|---|---|---|
| Power-on | Reset | Reset | Reset | Per `SCRC` |
| Watchdog bite, software reset | -- | Reset. A request still held is issued again on release | -- | Per `SCRC` |
| `i_jtag_trst_n` | Reset: `dbgreq` = 0 | -- | -- | Unaffected |

## 7.4 Reading and writing memory

**Read** of address `A`:

1. IR = `ADDR`, DR = {0, `A`}. Update-DR starts the read.
2. IR = `STATUS`, scan until `busy` = 0. Check `resp`.
3. IR = `DATA`, scan. The captured value is the read data.

**Write** of `D` to address `A`:

1. IR = `ADDR`, DR = {1, `A`}. Nothing is issued.
2. IR = `DATA`, DR = `D`. Update-DR starts the write.
3. IR = `STATUS`, scan until `busy` = 0. Check `resp`.

**Rules:**

- While `busy` = 1, Update-DR of `ADDR` and `DATA` is **ignored**: no register
  changes and no transaction starts.
- While `addr_reg[32]` = 1, every Update-DR of `DATA` starts another write, to the
  same address.

`busy` = `read_req` OR synchronised `read_ack` OR `write_req` OR synchronised
`write_ack`, all on the TCK side.

## 7.5 AXI manager

![Read handshake](../figures/img/fig_sysdbg_handshake.png){width=6.5in}

`set_ar` is the rising edge of the synchronised `read_req`. `set_aw` is the same for
`write_req`.

: AXI manager behaviour

| Event | Read | Write |
|---|---|---|
| `set_ar` / `set_aw` | `arvalid` = 1, `araddr` = `addr_reg`, `rready` = 1 | `awvalid` = 1, `awaddr` = `addr_reg`, `wvalid` = 1, `wdata` = `wdata_reg`, `bready` = 1 |
| Address handshake | `arvalid` = 0 | `awvalid` = 0 |
| Data handshake | `rdata_reg` = `rdata`, `resp_reg` = `rresp`, `rready` = 0 | `wvalid` = 0 |
| Response handshake | -- | `resp_reg` = `bresp`, `bready` = 0 |
| Acknowledge | `read_ack` = synchronised `read_req` after the delay flip-flop, AND NOT `rready` | `write_ack` = synchronised `write_req` after the delay flip-flop, AND NOT `bready` |

At most one transaction is outstanding.

## 7.6 Clock domain crossing

Each transaction is one 4-phase handshake:

1. TCK side sets `req`.
2. AXI side sees `req` rise and runs the transaction.
3. AXI side raises `ack` and holds it while `req` = 1.
4. TCK side sees `ack` rise, captures `resp_reg` into `resp` (and, for a read,
   `rdata_reg` into `rdata_hold`), then clears `req`.
5. AXI side sees `req` fall and drops `ack`.
6. TCK side sees `ack` fall and is no longer busy.

: Crossing signals and constraints

| Signal | Direction | How it crosses | Constraint |
|---|---|---|---|
| `read_req`, `write_req` | TCK to AXI | `SyncStages` flip-flops, then one delay flip-flop for the edge | `set_max_delay -datapath_only`, one `i_clk_cpu` period, to the first flip-flop |
| `read_ack`, `write_ack` | AXI to TCK | `SyncStages` flip-flops, then one delay flip-flop for the edge | the same, one `TCK` period |
| `addr_reg`, `wdata_reg` | TCK to AXI | No synchroniser. Stable from `req` rising until `ack` falls | `set_max_delay -datapath_only`, one `i_clk_cpu` period |
| `rdata_reg`, `resp_reg` | AXI to TCK | No synchroniser. Stable from `ack` rising until the next `req` | `set_max_delay -datapath_only`, one `TCK` period |
| `dbgreq` | TCK to system | `SyncStages` flip-flops | `set_max_delay -datapath_only`, one `i_clk_cpu` period, to the first flip-flop |

## 7.7 Halt and resume

- **Halt.** `CPUDBG = 1` drives `o_dbg_req` high. Ibex saves the PC in `dpc`
  and jumps to `DmHaltAddr` = `0x2000_0800`. The window code sets `HALTED` = 1; the
  host reads it to confirm the halt.
- **Halt across a reset.** `CPUDBG = 1` held across a watchdog reset makes the core
  halt before its first instruction.
- **Resume.** The host writes `CPUDBG = 0` **first**, then `RESUME` = 1 in the debug
  window. The loop executes `dret`. If `debug_req` were still high, the core would
  halt again at the next instruction.

## 7.8 Debug window

The first 4 KiB of `ISRAM`. The debug program is written by the ROM code from
`DEBUG_PAYLOAD` (`QNSC_BOOT_SPEC` 6), at `0x2000_0000`. The host can also read and write
the window through the AXI manager at any time. Firmware places nothing here.

: Debug window layout

| Address | Content |
|---|---|
| `0x2000_0000`--`0x2000_07FF` | Sequence area |
| `0x2000_0800` | Dispatch loop, `DmHaltAddr`: entry on every halt |
| `0x2000_0810` | Exception handler, `DmExceptionAddr`: entry on an exception in Debug Mode |
| `0x2000_0F00` | Result |
| `0x2000_0F08` | Command word |
| `0x2000_0F0C` | Resume flag (`RESUME`) |

The layout is the one of `QNSC_BOOT_SPEC` 9. The entry of the debug program is at
offset `0x800` inside `DEBUG_PAYLOAD`. The address of the `HALTED` flag used in 7.7 is
not given by the new flow and is to be confirmed (section 11).

# 8. Instances

One, in `design/top`, with the default parameters.

# 9. What is not provided here, and who provides it

: Functions this block does not provide

| Function | Where it lives |
|---|---|
| Reset of the chip or of any domain, holding the CPU | Nowhere. `SYSDBG` does not reset or hold the CPU |
| CPU clock control | Not needed. The `cpu` cluster is never gated |
| Byte and halfword access, bursts | Nowhere. Word only; the host does read-modify-write |
| Debug ROM, program buffer | Nowhere. The debug window in `ISRAM`, 7.8 |
| `dret`, stepping, `ebreak` | Ibex, driven by code in the debug window. No hardware triggers (`DbgTriggerEn = 0`) |

# 10. Tie-offs

: Tie-offs

| Port | Tied to | Why |
|---|---|---|
| `o_bus_axi_ar_len`, `o_bus_axi_aw_len` | 0 | One beat |
| `o_bus_axi_ar_size`, `o_bus_axi_aw_size` | `3'b010` | 4 bytes, word only |
| `o_bus_axi_ar_burst`, `o_bus_axi_aw_burst` | `2'b01`, INCR | Legal for one beat |
| `o_bus_axi_ar_id`, `o_bus_axi_aw_id` | 0 | One transaction outstanding |
| `o_bus_axi_{ar,aw}_lock`, `_prot`, `_cache`, `_qos`, `_region` | 0 | No exclusive access, protection, cache hints or QoS |
| `o_bus_axi_w_strb` | `4'b1111` | Word only |
| `o_bus_axi_w_last` | 1 | One beat |
| `i_bus_axi_r_id`, `i_bus_axi_r_last`, `i_bus_axi_b_id` | Unused | One beat, one ID |

# 11. Requirements on others, and open items

: Requirements on other owners

| Item | Owner | What it blocks |
|---|---|---|
| `DBG_EN` on a dedicated input pad with a pull-down, read through `SYSCSR` (`DBG_BOOT` at `0x8000_400C`), not by `SYSDBG` | Top, pad owner, `SYSCSR` owner | The ROM debug gate |
| `SYSCSR.DBG_EN_MASK` writable over the bus from `AXI_S0` | `SYSCSR` owner | 7.1 step 4 |
| `DmHaltAddr = 0x2000_0800`, `DmExceptionAddr = 0x2000_0810`. `DmBaseAddr`/`DmAddrMask` act only with PMP, which is off | CPU owner | 7.8 |
| `fetch_enable_i` tied to `IbexMuBiOn` | CPU owner | The CPU running from reset release |
| `AXI_S0` connected to `SYSDBG` directly, AXI4, ID width `AxiIdWidth`. No `axi_from_mem` | Bus owner | Every bus access |
| Remove the `0xF000_0000` `SYSDBG` register region from HAS Table 7-1 (already gone from `qsoc_contract.yml`) | HAS owner | Consistency. There are no memory-mapped registers |
| The five JTAG pads kept on JTAG while a debug boot is in progress. `o_dbg_en` no longer exists; the IO MUX owner decides the condition (for example `SYSCSR.DBG_EN`) | IO MUX owner | Debug boot with firmware that remaps pins |
| `ISRAM` array has no reset and no clear-on-reset | RAM owner | Image surviving a watchdog or software reset |
| Image linked at `0x2000_1000`, reset entry `0x2000_1080`; the bootloader jumps to `0x2000_1080` | Firmware owner | The user program starting after the ROM |
| Address of the `HALTED` flag in the debug window, and the debug program built to the layout of 7.8 | Debug program owner | 7.7 |

**Accepted limits:**

1. No timeout: a slave that never answers keeps `busy` = 1 until an `S_BUS` reset
   or power-on.
2. Once the user program runs, it can take the JTAG pins unless the IO MUX owner prevents it (section 11).

# 12. Verification

1. TAP: all 16 states from every state; `IDCODE` after reset; `BYPASS` and unused
   IR codes are 1 bit; IR changes only at Update-IR; Capture-IR loads `0001`.
2. Each data register of section 6: length, capture value, update effect, reset value.
3. Read and write sequences of 7.4 against an AXI slave model with random
   `ready`/`valid` delays. Every transaction issued exactly once, with the fixed
   fields of section 10.
4. Update-DR of `ADDR` or `DATA` while busy changes nothing.
5. `SLVERR` and `DECERR` reach `STATUS.resp`.
6. AXI protocol checker on the manager port for every test.
7. CDC: `TCK` from 10x slower to 10x faster than `i_clk_cpu`, and `TCK` stopped
   mid-handshake for 10,000 cycles. CDC lint: only the signals of the crossing
   table cross.
8. `i_rst_n_sysbus` asserted during a transaction: the transaction is issued
   again after release, and completes.
9. With Ibex, debug boot (`DEBUG_PROG` = `0x55`, `SYSCSR.DBG_EN` = 1): `CPUDBG` = 1
   sends the CPU to `0x2000_0800`. `CPUDBG` = 0 and `RESUME` = 1: the core executes
   `dret`, returns to the ROM polling loop and reads `DBG_EN` again.
10. Writing `SYSCSR.DBG_EN_MASK` = 1 through the AXI manager makes `DBG_EN` read 0 and
    the CPU leave the loop for `0x2000_1080`.
11. With Ibex running the user program and `DEBUG_PROG` = `0x55`: attach, halt,
    resume.

**Acceptance:** in debug boot, load an image that toggles a GPIO, halt the CPU in the
polling loop, read `dpc`, resume it, write `DBG_EN_MASK` = 1, and see the GPIO
toggle.

# Appendix A. Acronyms

: Acronyms

| Acronym | Description |
|---|---|
| CDC | Clock Domain Crossing |
| DR, IR | JTAG Data and Instruction Register |
| `dpc` | Debug PC: where `dret` returns |
| `dret` | Instruction that leaves Debug Mode |
| POR | Power-On Reset |
| SCRC | System Clock Reset Control |
| TAP | Test Access Port, IEEE 1149.1 |

# Appendix B. First review

: First review

| Item | Reviewer | Response |
|---|---|---|
| The block diagram does not show where the FSM and the CDC are | Teacher, 2026-09-23 | Section 3 separates the three domains. 7.6 gives the handshake, its signals and its constraints |
| Too long, and the repetition causes errors | Teacher, 2026-09-23 | Rewritten as V3.0. The reasoning moved to `_DECISIONS` |
| Who loads the 4 KiB debug program, and when? | Teacher, 2026-09-23 | V3.0: the host, over JTAG. V3.2: the ROM code, from `DEBUG_PAYLOAD` over `UART0`; the host can still read and write it -- 7.8 |
| The debugger must control the CPU reset, selected by an external pin | Teacher, 2026-09-23 | Done in V3.0 with `DBG_EN` and `CPUHOLD`. Dropped in V3.2: the boot flow of 2026-10-12 starts the CPU in ROM and gates the user program with `SYSCSR.DBG_EN` -- 7.1 |
| Reference design `VLSI_SYSDBG.drawio` | Teacher, 2026-09-23 | Used as the pattern and adapted to QSOC -- `_DECISIONS` D18 |
| CPU clock under debugger control | Teacher, 2026-09-23 | Not needed: the `cpu` cluster is never gated |
| IP list names `axi_from_mem` for the debugger | Owner, 2026-09-25 | An early pick from the V1.x memory-style port. The block is self-designed, as the teacher asks: its own AXI4 manager (7.5) connects to `AXI_S0` directly, and no IP is instantiated -- `_DECISIONS` D21 |
