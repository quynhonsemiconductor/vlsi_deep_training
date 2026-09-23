---
title: "Interrupt Map"
subtitle: "MICRO-ARCHITECTURE SPECIFICATION -- V2.0"
author: "QUY NHON SEMICONDUCTORS -- QNSC"
---

# Revision history

`V2.0` is a rewrite, so the history starts again here. The twenty versions before
it, `V1.0` to `V11.10`, describe a document that no longer exists in this shape;
they are listed in full, with the reasoning and the evidence behind each, in
[`QNSC_Interrupt_Map_DECISIONS.md`](QNSC_Interrupt_Map_DECISIONS.md).

| Version | Date | Author | Reviewer | Description of change |
|---|---|---|---|---|
| V2.0 | 2026-09-23 | Nghia VT | -- | Rewritten as specification only. History and reasoning moved to `_DECISIONS`; tables in 7.2 and 10 generated from `util/qsoc_contract.yml` |

# 1. Overview

Twenty-seven interrupt sources reach the CPU as twelve wires. `INTMAP` is the
combinational OR tree that does the reduction: it groups the sources of twelve
peripherals, in eight blocks, onto the core's fast interrupt lines, one line per peripheral, and passes
the watchdog bark straight through to the non-maskable input.

**It does not**: hold state, decode an address, appear on any bus, prioritise
(the core does that), or latch a pulse. It has no clock and no reset.

Block directory `design/intmap`, module `m_qnsc_intmap`, owner Nghia Van Trong.
Why the specification says what it says -- the two designs that were dropped, the
evidence read out of Ibex, how each question closed -- is in
[`QNSC_Interrupt_Map_DECISIONS.md`](QNSC_Interrupt_Map_DECISIONS.md). This file is
the contract.

# 2. Features

- Twenty-seven interrupt sources reduced to **eleven fast lines plus one NMI**
- **One line per peripheral**: a peripheral owns its line and no other block
  shares it, so a handler never has to ask who interrupted
- **Combinational**: no clock, no reset, no flip-flop, no bus port. The delay
  from a source asserting to the core seeing it is one layer of logic
- **Priority is the line index**, resolved by the core, ordered data-loss-first
- **The watchdog bark bypasses the block** onto `irq_nm_i`, so it survives
  firmware having disabled interrupts
- **No state**: nothing to configure, nothing to acknowledge here, and nothing
  to save or restore across a reset

# 3. Block diagram

![INTMAP — 27 sources, one OR per peripheral, 12 wires to the CPU](../img/fig_intr_map.png)

One combinational layer. No sub-blocks, no clock domain, no reset domain.

# 4. IP used

: Upstream IP used

| From | Module | Commit | Licence |
|---|---|---|---|
| -- | -- | -- | -- |

**Designed in house.** The block instantiates nothing; it is `assign` statements.

# 5. Interface

Every port. Naming follows `QNSC_RTL_Design_Naming_Rule` V1.0 section 3.6,
`i_int_<source>` / `o_int_<source>`.

: Interrupt map interface

| Signal | Dir | Width | Description |
|---|---|---:|---|
| `i_int_dma` | in | 1 | DMA completion. Level, held by `DMA_ISR` |
| `i_int_spi_device` | in | 8 | `spi_device` `intr_*_o`, in declaration order |
| `i_int_spi_host` | in | 2 | `spi_host` error, event |
| `i_int_i2c` | in | 1 | I²C |
| `i_int_uart_0` | in | 1 | UART0. Driven by the IP's `INT` port |
| `i_int_uart_1` | in | 1 | UART1 |
| `i_int_timer_1` | in | 2 | TIMER1 `irq_lo_o`, `irq_hi_o` |
| `i_int_pwm` | in | 4 | PWM `events_o` |
| `i_int_wdt_wakeup` | in | 1 | `aon_timer` wake-up expiry |
| `i_int_gpio` | in | 4 | one per GPIO instance |
| `i_int_timer_0` | in | 1 | TIMER0 `irq_lo_o` only — 64-bit mode |
| `i_int_wdt_bark` | in | 1 | `aon_timer` `nmi_wdog_timer_bark_o` |
| `o_int_fast` | out | 11 | to Ibex `irq_fast_i[10:0]` |
| `o_int_nm` | out | 1 | to Ibex `irq_nm_i` |

**27 inputs, 12 outputs, and no other ports.** No `i_clk_*`, no `i_rst_n_*`.

# 6. Register map

None. The block has no address and is not a bus slave, so there is nothing for
software to read or write.

Enabling and masking is done in the core: `mie` bits 16–26 for the fast lines.
Acknowledging is done at each peripheral's own status register.

# 7. Functional behaviour

## 7.1 One OR gate per peripheral

```systemverilog
assign o_int_fast[0]  =  i_int_dma;
assign o_int_fast[1]  = |i_int_spi_device;
assign o_int_fast[2]  = |i_int_spi_host;
assign o_int_fast[3]  =  i_int_i2c;
assign o_int_fast[4]  =  i_int_uart_0;
assign o_int_fast[5]  =  i_int_uart_1;
assign o_int_fast[6]  = |i_int_timer_1;
assign o_int_fast[7]  = |i_int_pwm;
assign o_int_fast[8]  =  i_int_wdt_wakeup;
assign o_int_fast[9]  = |i_int_gpio;
assign o_int_fast[10] =  i_int_timer_0;
assign o_int_nm       =  i_int_wdt_bark;
```

A peripheral with one source is wired straight through; one with several is
OR-reduced. **Zero flip-flops**, so the delay from a source asserting to the core
seeing it is combinational.

## 7.2 Line assignment

**Line** is the index of the wire in `irq_fast_i[14:0]`, the fifteen-bit input
port on the core. Line 3 means `irq_fast_i[3]`, nothing more. The index **is** the
priority: Ibex resolves the lowest index first, so this table fixes the default
priority order as well as the wiring, and changing it requires re-synthesis.

**`mcause`** is the CSR the core writes when it traps, so firmware can read it and
find out why. For fast line *n* the value is `16 + n`, because Ibex maps
`irq_fast_i` onto `mip`/`mie` bits 16 to 30 (`ibex_pkg.sv`,
`CSR_MFIX_BIT_LOW = 16`). It is the same number as the `mie` bit that enables the
line, so one number serves both purposes: write `mie` bit 20 to enable UART0, and
read `mcause` 20 to learn UART0 was what interrupted.

**Vector** is where the core jumps. `mtvec` is permanently vectored, so the
address is `mtvec + 4 * mcause` -- the core reaches the peripheral's handler
directly, with no dispatch code and no register read on the way.

<!-- gen:interrupt_lines -->
: Fast interrupt line assignment

| Line | CPU port | mcause | Vector | Peripheral | Sources | Shape |
|---:|---|---:|---|---|---:|---|
| 0 | `irq_fast_i[0]` | 16 | `mtvec + 0x40` | dma | 1 | level |
| 1 | `irq_fast_i[1]` | 17 | `mtvec + 0x44` | spi_device | 8 | level |
| 2 | `irq_fast_i[2]` | 18 | `mtvec + 0x48` | spi_host | 2 | level |
| 3 | `irq_fast_i[3]` | 19 | `mtvec + 0x4C` | i2c | 1 | level |
| 4 | `irq_fast_i[4]` | 20 | `mtvec + 0x50` | uart_0 | 1 | level |
| 5 | `irq_fast_i[5]` | 21 | `mtvec + 0x54` | uart_1 | 1 | level |
| 6 | `irq_fast_i[6]` | 22 | `mtvec + 0x58` | timer_1 | 2 | pulse |
| 7 | `irq_fast_i[7]` | 23 | `mtvec + 0x5C` | pwm | 4 | pulse |
| 8 | `irq_fast_i[8]` | 24 | `mtvec + 0x60` | wdt_wakeup | 1 | level |
| 9 | `irq_fast_i[9]` | 25 | `mtvec + 0x64` | gpio | 4 | pulse |
| 10 | `irq_fast_i[10]` | 26 | `mtvec + 0x68` | timer_0 | 1 | pulse |
| 11-14 | `irq_fast_i[14:11]` | 27-30 | -- | spare, tied to 0 | 0 | -- |
| -- | `irq_nm_i` | **31** | `mtvec + 0x7C` | **wdt_bark** | 1 | level |
<!-- /gen -->

<!-- gen:interrupt_totals -->
: Interrupt source totals

|  | Count |
|---|---:|
| Sources aggregated onto fast lines | 26 |
| Sources on the non-maskable input | 1 |
| **Total interrupt sources** | **27** |
| Fast lines driven | 11 |
| Fast lines Ibex provides | 15 |
| Fast lines spare | 4 |
<!-- /gen -->


Order follows one rule: **data loss first, human time last.** A missed SPI or UART
event loses a byte that cannot be recovered; a missed timer tick arrives again next
period. DMA takes line 0 because the rest of the system waits on a transfer
completing.

## 7.3 The core identifies the source, not a register

Fast line *n* raises `mcause` `16 + n`, and Ibex is permanently in vectored mode,
so the trap address is `mtvec + 4 × mcause`. The core therefore enters the
peripheral's own handler directly. **No claim register is read and no bus
transaction occurs on the interrupt path.**

`mcause` 16 and above is platform-use space in the RISC-V privileged
specification, so this numbering is a local convention the specification permits.

## 7.4 The NMI bypasses this block

`i_int_wdt_bark` goes to `o_int_nm` unmodified. The bark must reach the core even
if firmware has hung with interrupts disabled, and `irq_nm_i` is outside
`mstatus.MIE` and `mie`.

Ibex ignores the NMI in Debug Mode. A bark raised while `SYSDBG` has the core
halted therefore traps on resume, not when it occurs — and only because
`aon_timer` holds the bark as a level.

## 7.5 A pulse can be missed, and what that costs

`mip` in Ibex is combinational: `assign mip.irq_fast = irq_fast_i`. The core
latches nothing, and neither does this block. A one-cycle pulse arriving while
`mstatus.MIE` is clear is therefore **not seen**.

That costs an interrupt but not information, because every source either holds its
line or keeps a record:

: How each source recovers a missed pulse

| Source | Shape | Recovery |
|---|---|---|
| DMA | level | held by `DMA_ISR`, write-1-to-clear |
| SPI ×2, I²C, UART ×2, WDT wake-up | level | held until the handler clears it |
| GPIO | pulse | which pin fired is in the instance's own `INTSTATUS` |
| TIMER0, TIMER1, PWM | pulse | the event repeats next period |

**No source destroys information.** This is the condition the design depends on.

## 7.6 A gated peripheral holds its line

All ten interrupt-producing peripheral blocks are in the **`peri` cluster**, which
`SCRC` may stop through `CLK_EN`. Stopping a clock **retains flip-flop state**, so a
peripheral gated with its status register set **keeps driving its line high**, and
this block passes that through -- it has no clock of its own to notice with.

The consequence is an order-of-operations rule, not a design change here:

- With `mie` set for that line, the core re-enters the handler for as long as the
  line is asserted.
- The handler clears the source by writing the peripheral's status register, and
  that write needs the peripheral's clock. Gated, it cannot complete.

**Firmware must clear a peripheral's interrupt before gating it**, and ungate before
attempting to clear one. `QSOC_HAS` already states the analogous rule for PWM in the
contract -- *never gate a running block*, because `out_filter` freezes at its current
level -- so this is the same hazard on the interrupt path rather than a new one.

This block cannot prevent it: with no clock and no register, it has nothing to
qualify the input with. Whether `SCRC` should refuse to gate a peripheral whose
interrupt is asserted is the SCRC owner's decision, recorded in section 11.

# 8. Instances

One. It is instantiated in `design/top` and has no parameters.

# 9. What is not provided here, and who provides it

: Functions this block does not provide

| Function | Where it lives |
|---|---|
| Pending latch | the peripheral's status register, or nowhere — 7.5 |
| Which event fired | the peripheral's status register |
| Which peripheral fired | `mcause`, via the vectored trap address |
| Priority resolution | Ibex, by fast-line index |
| Per-source enable | `mie` bits 16–26, in the core |
| Acknowledge | writing the peripheral's status register |

# 10. Tie-offs

<!-- gen:core_tie_offs -->
: Core interrupt inputs tied off

| Port | Tied to | Why |
|---|---|---|
| `irq_fast_i[14:11]` | `4'b0` | QSOC drives 11 of the 15 lines the core offers |
| `irq_external_i` | `0` | needs a **PLIC** -- a bus slave with priority, per-source enable and claim/complete registers. QSOC has none, and 11 lines fit in the 15 the core offers without one |
| `irq_timer_i` | `0` | needs a **CLINT** for `mtime` and `mtimecmp`. QSOC has none, so `mip.MTIP` is never set and TIMER0 is an ordinary fast line |
| `irq_software_i` | `0` | needs a second hart to send the inter-processor interrupt. QSOC has one |
<!-- /gen -->

These tie-offs are made in `design/top`, not here: this block drives eleven bits
and the core's port is fifteen wide, so the remaining four are tied where the core
is instantiated. The rows are in this specification because it is the document that
accounts for every interrupt input the core has.

**Consequence for firmware:** an RTOS ported to QSOC must supply its own timer
driver rather than the standard `mtime`/`mtimecmp` one.

# 11. Requirements on others, and open items

: Requirements on other owners

| Item | Owner | What it blocks |
|---|---|---|
| APB-to-TL-UL wrapper for `aon_timer` | WDT owner | two of the 27 sources, one being the NMI. Its enable is in `WDOG_CTRL` offset `0x1C`, so without a bus path the watchdog cannot be enabled and never barks |
| Watchdog stoppable while `debug_mode` is asserted, **or** firmware told to disable it | WDT owner | a long debug session otherwise ends in a reset with nothing recording why |
| Vector table at `mtvec + 0x40` … `+0x68`, plus `+0x7C`; `mie` bits 16–26 | firmware owner | — |
| Handlers installed **before** `mstatus.MIE` is set | firmware owner | the block is transparent out of reset, so every source is live from the first cycle |
| Decide whether `CLK_EN` may gate a peripheral whose interrupt is asserted, or whether the ordering is left to firmware | SCRC owner | nothing in RTL. If left to firmware it must be written into the programming guide, because the failure is a handler that cannot clear its own source -- section 7.6 |

**Accepted limits**, stated rather than hidden:

1. A pulse arriving while `mstatus.MIE` is clear is lost. Recoverable for every
   source — 7.5.
2. Priority is fixed at elaboration. Changing it is a re-synthesis.
3. `mcause` 16–30 is platform-use space, so the numbering is a local convention
   rather than a portable one.
4. A peripheral gated with its interrupt asserted holds the line, and this block
   cannot qualify it away — 7.6. The rule is an ordering constraint on firmware.

# 12. Verification

Eleven checks, none requiring a bus model:

1. Each single-source input raises exactly its own line.
2. Each OR group raises its line for every member, individually.
3. No input raises a line other than its own.
4. Spare lines `[14:11]` are always 0.
5. `i_int_wdt_bark` reaches `o_int_nm` and no fast line.
6. Simultaneous inputs on one group raise the line once.
7. Simultaneous inputs on different groups raise both lines.
8. Output follows input combinationally, with no cycle of delay.
9. `mcause`/vector mapping matches section 7.2 against `qnsc_pkg`.
10. A held input keeps its line asserted for as long as it is held, which is what
    makes the gating case in 7.6 behave as described.
11. **Lint check**: the module contains no `i_clk_`, no `i_rst_n_`, and no
    `always_ff`. If any appears, the design has drifted back into being a
    controller.

# Appendix A. Acronyms

: Acronyms

| Acronym | Description |
|---|---|
| CLINT | Core Local Interruptor -- the RISC-V standard timer and software interrupt block. **Not present in QSOC** |
| INTMAP | Interrupt Map -- this block |
| ISR | Interrupt Service Routine |
| `mcause` | Machine Cause register: why the core trapped |
| `mie` | Machine Interrupt Enable register: per-source mask |
| `mip` | Machine Interrupt Pending register |
| `mstatus.MIE` | The global interrupt enable bit |
| `mtvec` | Machine Trap Vector: base of the trap table |
| NMI | Non-Maskable Interrupt -- `irq_nm_i` on Ibex |
| PLIC | Platform Level Interrupt Controller. Considered in V7.0 and **rejected** |
| SCRC | System Clock Reset Control. Formerly `SYSCTL` on the block diagram |
| W1C | Write-1-to-Clear |
| WDT | Watchdog Timer |

# Appendix B. First review

: First review

| Item | Reviewer | Response |
|---|---|---|
| GPIO: one line for four instances, or four lines? | Day005, 2026-09-18 | One line. Which pin fired is in the instance's `INTSTATUS`. Closed in V11.2 |
| Is the DMA interrupt a pulse or a level? | DMA owner | Level, held by `DMA_ISR` W1C. Closed in V11.10 |
| Does this block need to latch pending? | -- | No. Section 7.5: no source destroys information |
| Priority order justified? | -- | Section 7.2: data loss first, human time last |
| What happens to a line whose peripheral is clock-gated? | -- | Section 7.6. **Open**: the ordering rule is a request on the SCRC owner |
