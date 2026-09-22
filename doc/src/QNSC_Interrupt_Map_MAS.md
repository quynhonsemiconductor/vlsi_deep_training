# QNSC_Interrupt_Map_MAS

**Block** `intmap` · **Owner** Nghia Van Trong · **Version** 2.0 · **2026-09-23**

Twenty-seven interrupt sources reach the CPU as twelve wires. `INTMAP` is the
combinational OR tree that does the reduction.

Why the specification says what it says — the two designs that were dropped, the
evidence read out of Ibex, the questions that closed — is in
[`QNSC_Interrupt_Map_DECISIONS.md`](QNSC_Interrupt_Map_DECISIONS.md). This file is
the contract.

---

## 1. Scope

`INTMAP` groups the interrupt sources of fourteen blocks onto the CPU's fast
interrupt lines, one line per peripheral, and passes the watchdog bark straight
through to the non-maskable input.

**It does not**: hold state, decode an address, appear on any bus, prioritise
(the core does that), or latch a pulse. It has no clock and no reset.

## 2. Block diagram

![INTMAP — 27 sources, one OR per peripheral, 12 wires to the CPU](../img/fig_intr_map.png)

One combinational layer. No sub-blocks, no clock domain, no reset domain.

## 3. IP used

| From | Module | Commit |
|------|--------|--------|
| — | — | — |

**Designed in house.** The block instantiates nothing; it is `assign` statements.

## 4. Interface

Every port. Naming follows `QNSC_RTL_Design_Naming_Rule` V1.0 section 3.6,
`i_int_<source>` / `o_int_<source>`.

| Signal | Dir | Width | Description |
|---|---|---:|---|
| `i_int_dma` | in | 1 | DMA completion. Level, held by `DMA_ISR` |
| `i_int_spi_dev` | in | 8 | `spi_device` `intr_*_o`, in declaration order |
| `i_int_spi_host` | in | 2 | `spi_host` error, event |
| `i_int_i2c` | in | 1 | I²C |
| `i_int_uart_0` | in | 1 | UART0. Driven by the IP's `INT` port |
| `i_int_uart_1` | in | 1 | UART1 |
| `i_int_timer_1` | in | 2 | TIMER1 `irq_lo_o`, `irq_hi_o` |
| `i_int_pwm` | in | 4 | PWM `events_o` |
| `i_int_wdt_wkup` | in | 1 | `aon_timer` wake-up expiry |
| `i_int_gpio` | in | 4 | one per GPIO instance |
| `i_int_timer_0` | in | 1 | TIMER0 `irq_lo_o` only — 64-bit mode |
| `i_int_wdt_bark` | in | 1 | `aon_timer` `nmi_wdog_timer_bark_o` |
| `o_int_fast` | out | 11 | to Ibex `irq_fast_i[10:0]` |
| `o_int_nm` | out | 1 | to Ibex `irq_nm_i` |

**27 inputs, 12 outputs, and no other ports.** No `i_clk_*`, no `i_rst_n_*`.

## 5. Register map

None. The block has no address and is not a bus slave, so there is nothing for
software to read or write.

Enabling and masking is done in the core: `mie` bits 16–26 for the fast lines.
Acknowledging is done at each peripheral's own status register.

## 6. Functional behaviour

### 6.1 One OR gate per peripheral

```systemverilog
assign o_int_fast[0]  =  i_int_dma;
assign o_int_fast[1]  = |i_int_spi_dev;
assign o_int_fast[2]  = |i_int_spi_host;
assign o_int_fast[3]  =  i_int_i2c;
assign o_int_fast[4]  =  i_int_uart_0;
assign o_int_fast[5]  =  i_int_uart_1;
assign o_int_fast[6]  = |i_int_timer_1;
assign o_int_fast[7]  = |i_int_pwm;
assign o_int_fast[8]  =  i_int_wdt_wkup;
assign o_int_fast[9]  = |i_int_gpio;
assign o_int_fast[10] =  i_int_timer_0;
assign o_int_nm       =  i_int_wdt_bark;
```

A peripheral with one source is wired straight through; one with several is
OR-reduced. **Zero flip-flops**, so the delay from a source asserting to the core
seeing it is combinational.

### 6.2 Line assignment

The line index **is** the priority: Ibex resolves the lowest index first. This
table therefore fixes the default priority order as well as the wiring, and
changing it requires re-synthesis.

| Line | mcause | Vector | Peripheral | Sources | Shape |
|---:|---:|---|---|---:|---|
| 0 | 16 | `mtvec + 0x40` | DMA | 1 | level |
| 1 | 17 | `mtvec + 0x44` | SPI device | 8 | level |
| 2 | 18 | `mtvec + 0x48` | SPI host | 2 | level |
| 3 | 19 | `mtvec + 0x4C` | I²C | 1 | level |
| 4 | 20 | `mtvec + 0x50` | UART0 | 1 | level |
| 5 | 21 | `mtvec + 0x54` | UART1 | 1 | level |
| 6 | 22 | `mtvec + 0x58` | TIMER1 | 2 | pulse |
| 7 | 23 | `mtvec + 0x5C` | PWM | 4 | pulse |
| 8 | 24 | `mtvec + 0x60` | WDT wake-up | 1 | level |
| 9 | 25 | `mtvec + 0x64` | GPIO0–3 | 4 | pulse |
| 10 | 26 | `mtvec + 0x68` | TIMER0 | 1 | pulse |
| 11–14 | 27–30 | — | spare, tied to 0 | 0 | — |
| — | **31** | `mtvec + 0x7C` | **WDT bark**, on `irq_nm_i` | 1 | level |

**26 sources on 11 lines, plus the NMI: 27.** Ibex provides 15 fast lines, so
four are spare.

Order follows one rule: **data loss first, human time last.** A missed SPI or UART
event loses a byte that cannot be recovered; a missed timer tick arrives again next
period. DMA takes line 0 because the rest of the system waits on a transfer
completing.

### 6.3 The core identifies the source, not a register

Fast line *n* raises `mcause` `16 + n`, and Ibex is permanently in vectored mode,
so the trap address is `mtvec + 4 × mcause`. The core therefore enters the
peripheral's own handler directly. **No claim register is read and no bus
transaction occurs on the interrupt path.**

`mcause` 16 and above is platform-use space in the RISC-V privileged
specification, so this numbering is a local convention the specification permits.

### 6.4 The NMI bypasses this block

`i_int_wdt_bark` goes to `o_int_nm` unmodified. The bark must reach the core even
if firmware has hung with interrupts disabled, and `irq_nm_i` is outside
`mstatus.MIE` and `mie`.

Ibex ignores the NMI in Debug Mode. A bark raised while `SYSDBG` has the core
halted therefore traps on resume, not when it occurs — and only because
`aon_timer` holds the bark as a level.

### 6.5 A pulse can be missed, and what that costs

`mip` in Ibex is combinational: `assign mip.irq_fast = irq_fast_i`. The core
latches nothing, and neither does this block. A one-cycle pulse arriving while
`mstatus.MIE` is clear is therefore **not seen**.

That costs an interrupt but not information, because every source either holds its
line or keeps a record:

| Source | Shape | Recovery |
|---|---|---|
| DMA | level | held by `DMA_ISR`, write-1-to-clear |
| SPI ×2, I²C, UART ×2, WDT wake-up | level | held until the handler clears it |
| GPIO | pulse | which pin fired is in the instance's own `INTSTATUS` |
| TIMER0, TIMER1, PWM | pulse | the event repeats next period |

**No source destroys information.** This is the condition the design depends on.

## 7. Instances

One. It is instantiated in `design/top` and has no parameters.

## 8. What is not provided here, and who provides it

| Function | Where it lives |
|---|---|
| Pending latch | the peripheral's status register, or nowhere — 6.5 |
| Which event fired | the peripheral's status register |
| Which peripheral fired | `mcause`, via the vectored trap address |
| Priority resolution | Ibex, by fast-line index |
| Per-source enable | `mie` bits 16–26, in the core |
| Acknowledge | writing the peripheral's status register |

## 9. Tie-offs

| Port | Tied to | Why |
|---|---|---|
| `irq_fast_i[14:11]` | `4'b0` | QSOC drives 11 of the 15 lines |
| `irq_external_i` | `0` | nothing aggregates onto it; there is no external controller |
| `irq_timer_i` | `0` | no CLINT, so `mip.MTIP` is never set. TIMER0 is an ordinary fast line |
| `irq_software_i` | `0` | permitted on a single-hart system |

**Consequence for firmware:** an RTOS ported to QSOC must supply its own timer
driver rather than the standard `mtime`/`mtimecmp` one.

## 10. Requirements on others, and open items

| Item | Owner | What it blocks |
|---|---|---|
| APB-to-TL-UL wrapper for `aon_timer` | WDT owner | two of the 27 sources, one being the NMI. Its enable is in `WDOG_CTRL` offset `0x1C`, so without a bus path the watchdog cannot be enabled and never barks |
| Watchdog stoppable while `debug_mode` is asserted, **or** firmware told to disable it | WDT owner | a long debug session otherwise ends in a reset with nothing recording why |
| Vector table at `mtvec + 0x40` … `+0x68`, plus `+0x7C`; `mie` bits 16–26 | firmware owner | — |
| Handlers installed **before** `mstatus.MIE` is set | firmware owner | the block is transparent out of reset, so every source is live from the first cycle |

**Accepted limits**, stated rather than hidden:

1. A pulse arriving while `mstatus.MIE` is clear is lost. Recoverable for every
   source — 6.5.
2. Priority is fixed at elaboration. Changing it is a re-synthesis.
3. `mcause` 16–30 is platform-use space, so the numbering is a local convention
   rather than a portable one.

## Verification

Ten checks, none requiring a bus model:

1. Each single-source input raises exactly its own line.
2. Each OR group raises its line for every member, individually.
3. No input raises a line other than its own.
4. Spare lines `[14:11]` are always 0.
5. `i_int_wdt_bark` reaches `o_int_nm` and no fast line.
6. Simultaneous inputs on one group raise the line once.
7. Simultaneous inputs on different groups raise both lines.
8. Output follows input combinationally, with no cycle of delay.
9. `mcause`/vector mapping matches section 6.2 against `qnsc_pkg`.
10. **Lint check**: the module contains no `i_clk_`, no `i_rst_n_`, and no
    `always_ff`. If any appears, the design has drifted back into being a
    controller.
