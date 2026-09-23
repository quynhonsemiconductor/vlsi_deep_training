---
title: "PWM"
subtitle: "MICRO-ARCHITECTURE SPECIFICATION -- V2.1"
author: "QUY NHON SEMICONDUCTORS -- QNSC"
---

# Revision history

The reasoning behind each change is in
[`QNSC_PWM_DECISIONS.md`](QNSC_PWM_DECISIONS.md).

| Version | Date | Author | Reviewer | Description of change |
|---|---|---|---|---|
| V2.0 | 2026-09-23 | Nghia VT | -- | Rewritten as specification only, onto the template |
| V2.1 | 2026-09-24 | Nghia VT | -- | Corrected against the RTL (`CH_EN`, output MODE, events, input stage, decode); full register fields; tie-off table; new block diagram |

# 1. Overview

`PWM` is one instance of `pulp-platform/apb_adv_timer` on `APB_M13`, at `0x80034000`,
16 KiB. It has four timer modules of four channels each, so sixteen channel outputs.
The eight channels of modules 0 and 1 drive pads `PWM_0` to `PWM_7`. Four event
lines drive `INTMAP` fast line 7.

The block has no event status register, no period-end interrupt and no DMA request.

Block directory `design/pwm`, module `m_qnsc_wrap_apb_adv_timer`, owner Nghia Van
Trong.

# 2. Features

- Four timer modules, each with a 16-bit up or up-down counter, 16-bit start and end
  values and an 8-bit prescaler -- 7.1.
- Four channels per module, each with a 16-bit compare value and a 3-bit output action
  -- 7.2.
- Eight channel outputs at pads, modules 0 and 1 -- 7.3.
- Per-module count source selected from 48 signals: four `TIM_EXT` pads, 28 constant
  zeros and the sixteen channel outputs -- 7.4.
- Four event lines, each the rising edge of one selected channel -- 7.5.
- A clock gate per module under `CH_EN`, all four closed out of reset -- 7.7.

# 3. Block diagram

![PWM block: register file, clock gates, four timer modules, event multiplexer](../img/fig_pwm_block.png){width=6.5in}

Clock `i_clk_peri` (`peri` cluster, gated by `SCRC` `CLK_EN`), reset
`i_rst_n_peri`. The register file and the event multiplexer run on `i_clk_peri`.
Timer module `i` runs on `i_clk_peri` gated by `CH_EN[i]`.

# 4. IP used

: Upstream IP used

| From | Module | Commit | Licence |
|---|---|---|---|
| `pulp-platform/apb_adv_timer` | `apb_adv_timer`, `adv_timer_apb_if`, `timer_module`, `timer_cntrl`, `input_stage`, `prescaler`, `up_down_counter`, `comparator` | `c8faec1e` | SolderPad 0.51 |

`lut_4x4.sv` and `out_filter.sv` are in the vendor directory and are not instantiated.
`pulp_clock_gating` is supplied in `design/pwm/rtl` as a wrapper of OpenTitan
`prim_clock_gating`, which has the same ports and is the cell Ibex already uses.

# 5. Interface

Names follow `QNSC_RTL_Design_Naming_Rule` V1.0. `o_pwm` and `o_int_pwm` are 0 in reset.

: PWM interface

| Signal | Dir | Width | Description |
|---|---|---:|---|
| `i_clk_peri` | in | 1 | `peri` cluster clock, to `HCLK` |
| `i_rst_n_peri` | in | 1 | asynchronous active-low reset, to `HRESETn` |
| `i_bus_apb_paddr` | in | 12 | only `[9:2]` decoded -- 7.6 |
| `i_bus_apb_pwdata` | in | 32 | write data |
| `i_bus_apb_pwrite`, `i_bus_apb_psel`, `i_bus_apb_penable` | in | 1 each | APB4 control |
| `o_bus_apb_prdata` | out | 32 | read data; 0 at unimplemented offsets |
| `o_bus_apb_pready` | out | 1 | constant 1, zero wait states |
| `o_bus_apb_pslverr` | out | 1 | constant 0 |
| `i_tim_ext` | in | 4 | pads `TIM_EXT0`-`3` through IO MUX. Two flip-flops in the wrapper synchronise it to `i_clk_peri`, then `ext_sig_i[3:0]` |
| `o_pwm` | out | 8 | `[3:0]` = `ch_0_o[3:0]`, `[7:4]` = `ch_1_o[3:0]`, to IO MUX -- 7.3 |
| `o_int_pwm` | out | 4 | `events_o[3:0]`, one-cycle pulses, to `INTMAP` line 7 -- 7.5 |

# 6. Register map

`M` is the module base: `0x000`, `0x040`, `0x080` or `0x0C0` for modules 0 to 3.
`n` is the channel, 0 to 3. Reserved bits read 0 and ignore writes.

: Register map

| Offset | Register | Field | Bits | Access | Reset | Description |
|---|---|---|---|---|---|---|
| `M+0x00` | `CMD` | START | 0 | WO | 0 | load START, END, SAW into the counter and run |
| | | STOP | 1 | WO | 0 | stop; outputs hold their level |
| | | UPDATE | 2 | WO | 0 | load START, END, SAW into the counter |
| | | RST | 3 | WO | 0 | counter to START, prescaler to 0, all four outputs to 0 |
| | | ARM | 4 | WO | 0 | arm the input stage for `IN_MODE` 6 and 7 |
| `M+0x04` | `CFG` | IN_SEL | 7:0 | RW | 0 | count source index -- 7.4 |
| | | IN_MODE | 10:8 | RW | 0 | count source qualifier -- 7.4 |
| | | CLK_SEL | 11 | RW | 0 | 1: count only on rising edges of `low_speed_clk_i` |
| | | SAW | 12 | RW | 1 | 1: up (sawtooth); 0: up-down |
| | | PRESC | 23:16 | RW | 0 | prescaler; divide by `PRESC + 1` |
| `M+0x08` | `TH` | START | 15:0 | RW | 0 | counter start value |
| | | END | 31:16 | RW | 0 | counter end value |
| `M+0x0C+4n` | `CHn_TH` | TH | 15:0 | RW | 0 | compare value of channel `n` |
| | | MODE | 18:16 | RW | 0 | output action of channel `n` -- 7.2 |
| `M+0x1C+4n` | `CHn_LUT` | LUT, FLT | 15:0, 17:16 | RW | 0 | stored and read back; no effect on any output |
| `M+0x2C` | `COUNTER` | COUNT | 15:0 | RO | 0 | current counter value |
| `0x100` | `EVENT_CFG` | SEL0 .. SEL3 | 15:0 | RW | 0 | 4 bits per event line `k` at `[4k+3:4k]`: channel index `4 x module + n` |
| | | EN | 19:16 | RW | 0 | `EN[k]` enables event line `k` |
| `0x104` | `CH_EN` | CLK_EN | 3:0 | RW | 0 | `CLK_EN[i]` opens the clock gate of module `i` |

`CMD` bits are held for the duration of the write and clear on the next cycle without
a write. `CMD` reads 0.

# 7. Functional behaviour

## 7.1 Counter and period

The counter advances once per prescaler output event.

- `SAW` = 1: counts START, START+1, ... END, then reloads START. Period =
  (END - START + 1) x (PRESC + 1) count events.
- `SAW` = 0: counts START up to END, then down to START, then up. Period =
  2 x (END - START) x (PRESC + 1) count events.

With `IN_MODE` = 0 there is one count event per `i_clk_peri` cycle. At 20 MHz the
sawtooth period ranges from 100 ns (END - START = 1, PRESC = 0) to 838.9 ms
(65 536 x 256 cycles).

## 7.2 Output action

Each channel output is a flip-flop in its `comparator`. A match is COUNTER equal to
`CHn_TH.TH` on a count event. The "second event" is the counter reaching END when
`SAW` = 1, and the next match when `SAW` = 0.

: Channel output action, `CHn_TH.MODE`

| MODE | Name | On match | On second event |
|---|---|---|---|
| 0 | SET | set | -- |
| 1 | TOGRST | toggle | clear |
| 2 | SETRST | set | clear |
| 3 | TOG | toggle | -- |
| 4 | RST | clear | -- |
| 5 | TOGSET | toggle | set |
| 6 | RSTSET | clear | set |
| 7 | -- | hold | hold |

MODE 2 with `SAW` = 1 gives an edge-aligned output; MODE 2 with `SAW` = 0 gives a
centre-aligned output. `CMD.RST` drives the output to 0 in every MODE.

## 7.3 Channel outputs and pads

`ch_i_o[n]` is channel `n` of module `i`. Modules 0 and 1 drive the pads, so the pins
carry two independent periods with four channels under each.

: Channel outputs against pads

| Pad | Channel | Pin | Shared with |
|---|---|---|---|
| `PWM_0` | `ch_0_o[0]` | PIN_27 | `GPIO1_1` |
| `PWM_1` | `ch_0_o[1]` | PIN_28 | `GPIO1_0` |
| `PWM_2` | `ch_0_o[2]` | PIN_29 | `GPIO2_7` |
| `PWM_3` | `ch_0_o[3]` | PIN_30 | `GPIO2_6` |
| `PWM_4` | `ch_1_o[0]` | PIN_33 | `GPIO2_5` |
| `PWM_5` | `ch_1_o[1]` | PIN_34 | `GPIO2_4` |
| `PWM_6` | `ch_1_o[2]` | PIN_35 | `GPIO2_3` |
| `PWM_7` | `ch_1_o[3]` | PIN_36 | `GPIO2_2` |

`ch_2_o` and `ch_3_o` reach only the event multiplexer and the input pool.

## 7.4 Input stage and external triggers

Each module's `input_stage` picks one signal from a 48-signal pool with `CFG.IN_SEL`
and qualifies it with `CFG.IN_MODE`. Start and stop come only from `CMD`.

: Input pool index, `CFG.IN_SEL`

| IN_SEL | Signal |
|---|---|
| 0 -- 3 | `ext_sig_i[3:0]` = `TIM_EXT0`-`3` |
| 4 -- 31 | `ext_sig_i[31:4]`, tied 0 |
| 32 + 4 x module + n | `ch_<module>_o[n]` |
| 48 -- 255 | constant 0 |

: Count source qualifier, `CFG.IN_MODE`

| IN_MODE | A count event occurs |
|---|---|
| 0 | every cycle; the selected signal is ignored |
| 1 | every cycle the signal is 0 |
| 2 | every cycle the signal is 1 |
| 3 | on each rising edge |
| 4 | on each falling edge |
| 5 | on each rising or falling edge |
| 6 | after `CMD.ARM`, every cycle from the first rising edge until the counter reaches END |
| 7 | as 6, from the first falling edge |

`CFG.CLK_SEL` = 1 additionally requires a rising edge of `low_speed_clk_i`, which
is tied 0, so a module with `CLK_SEL` = 1 does not count.

## 7.5 Event lines

Event line `k` is `EN[k] & new & ~old`, where `new` and `old` are two successive
`i_clk_peri` samples of channel `SELk` of `{ch_3_o, ch_2_o, ch_1_o, ch_0_o}`.

- Each event is a pulse of exactly one `i_clk_peri` cycle.
- A falling edge of the selected channel produces no event.
- `EVENT_CFG` resets to 0, so no event occurs until firmware sets a selection and
  `EN[k]`.
- The first enable after reset of a line whose selected channel is already 1
  produces one event.
- The event does not identify the module or channel; firmware knows which it selected.

The block has no software-readable event status. `timer_module.status_o` is not
connected to the register file. An event that the core does not take is not
recorded anywhere.

## 7.6 Address decode

The register index is `PADDR[9:2]`, so the decoded window is 1 KiB and repeats
every `0x400` across the 16 KiB region. Offsets with no register -- `M+0x30` to
`M+0x3C` and `0x108` to `0x3FC` -- read 0 and ignore writes. No access returns an
error: `PSLVERR` is 0 and `PREADY` is 1.

## 7.7 Clock gating and safe stop

Two gates are in series: `SCRC` `CLK_EN` gates `i_clk_peri` for the whole block, and
`CH_EN[i]` gates module `i`.

- `CH_EN` resets to 0: every module is stopped and unclocked out of reset.
- While `CH_EN[i]` = 0, module `i` holds its counter and outputs, and a `CMD` write to
  it has no effect.
- A gated module freezes its outputs at their current level.
- Safe stop: with `CH_EN[i]` = 1, write `CMD` = STOP | RST (`0x0A`). All four
  outputs of module `i` go to 0; the clock may then be gated.

# 8. Instances

One, on `APB_M13`, with `APB_ADDR_WIDTH` = 12, `EXTSIG_NUM` = 32 and
`TIMER_NBITS` = 16. The four timer modules are internal to the IP.

# 9. What is not provided here, and who provides it

: Functions this block does not provide

| Function | Where it lives |
|---|---|
| Event status, flag or acknowledge | Nowhere -- 7.5 |
| Period-end interrupt | Nowhere; events are channel rising edges -- 7.5 |
| Merging the four events onto one core line | `INTMAP`, fast line 7 |
| Pad multiplexing of `PWM_n` and `TIM_EXTn` with GPIO | IO MUX |

# 10. Tie-offs

: Tie-offs

| Port | Tied to | Why |
|---|---|---|
| `dft_cg_enable_i` | 0 | no test-mode source in the pad ring; the four clock gates follow `CH_EN` only |
| `low_speed_clk_i` | 0 | no slow clock source; `CFG.CLK_SEL` = 1 stops the module counting |
| `ext_sig_i[31:4]` | 0 | four `TIM_EXT` pads exist; `IN_SEL` 4-31 select 0 |
| `ch_2_o`, `ch_3_o` | unconnected at the wrapper boundary | modules 2 and 3 have no pads |

# 11. Requirements on others, and open items

: Requirements on other owners

| Item | Owner | What it blocks |
|---|---|---|
| `i_bus_apb_paddr[11:0]` = offset within the region (`P_BUS` subtracts the base) | bus owner | register decode |
| `CLK_EN` and `SOFT_RST_CTRL` bit positions for PWM | SCRC owner | firmware clock and reset control |
| `SCRC` closes the PWM clock only after firmware's safe stop -- 7.7 | firmware owner | outputs frozen at a non-zero level at a power stage |
| IO MUX default for PIN_27-30, PIN_33-36 and PIN_37-40 | IO MUX owner | pin owner out of reset |

**Accepted limits:**

1. No event status; a missed event is not recorded -- 7.5.
2. Events are rising edges of one selected channel, not period ends -- 7.5.
3. The 1 KiB register window aliases across 16 KiB without an error -- 7.6.
4. Pads carry modules 0 and 1 only: two independent periods -- 7.3.
5. `CHn_LUT` has no effect -- section 6.

**Open:** gate count, after synthesis.

# 12. Verification

The IP has no testbench.

1. `ch_i_o[n]` is channel `n` of module `i`; `o_pwm[3:0]` = `ch_0_o`, `o_pwm[7:4]` =
   `ch_1_o`.
2. Every register field resets to the value in section 6; reserved bits and `CMD`
   read 0.
3. Out of reset, `CMD.START` has no effect until `CH_EN[i]` = 1.
4. `SAW` = 1 period is (END - START + 1) x (PRESC + 1); `SAW` = 0 period is
   2 x (END - START) x (PRESC + 1).
5. Each `CHn_TH.MODE` value 0-7 gives the action of the MODE table, in both `SAW`
   settings; MODE 2 with `SAW` = 0 is centre-aligned.
6. Changing one `CHn_TH` changes no other channel and not `TH`; `CHn_LUT` writes
   read back and change no output.
7. `CMD.STOP` holds all four outputs; `CMD` = STOP | RST drives them to 0.
8. An event fires on a rising edge of the selected channel only, is one
   `i_clk_peri` cycle wide, and never fires while `EN[k]` = 0.
9. Each `IN_MODE` 0-7 with `ext_sig_i[3:0]` and with a channel feedback source;
    `IN_SEL` 4-31 and 48-255 never count except in `IN_MODE` 0 and 1.
10. Holes read 0 and ignore writes; offset `+0x400` aliases offset 0; `PSLVERR` = 0.
11. Confirm in simulation: when a new `TH` takes effect (at `CMD.START`, at
    `CMD.UPDATE` while stopped, at the period end after `CMD.UPDATE` while running),
    and when new `CHn_TH`, `IN_SEL`, `IN_MODE` and `PRESC` values take effect while
    running.

**Acceptance criterion:** eight pads carry two independent periods with four
independently set compare values under each, and each event arrives one
`i_clk_peri` cycle wide on a rising edge of the channel firmware selected.

# Appendix A. Acronyms

: Acronyms

| Acronym | Description |
|---|---|
| APB | Advanced Peripheral Bus, AMBA APB4 |
| DFT | Design For Test |
| ICG | Integrated Clock Gating cell |
| PWM | Pulse Width Modulation |

# Appendix B. First review

: First review

| Item | Reviewer | Response |
|---|---|---|
| Too long; redundancy causes wrong information | Teacher, 2026-09-23 | Rewritten to the template; reasoning in `_DECISIONS` |
| Do the four event lines mean four periods elapsed? | -- | No: each is a rising edge of one selected channel -- 7.5 |
| Is 16 bits enough? | -- | Period range at 20 MHz in 7.1 |
| `ch_i_o` mapping | RTL | All four channels of module `i` -- 7.3 |
