---
title: "PWM"
subtitle: "MICRO-ARCHITECTURE SPECIFICATION -- V2.0"
author: "QUY NHON SEMICONDUCTORS -- QNSC"
---

# Revision history

`V2.0` is a rewrite. The six versions before it, and the reasoning behind each
decision, are in [`QNSC_PWM_DECISIONS.md`](QNSC_PWM_DECISIONS.md).

| Version | Date | Author | Reviewer | Description of change |
|---|---|---|---|---|
| V2.0 | 2026-09-23 | Nghia VT | -- | Rewritten as specification only, onto the template the other blocks follow. Tables and figures are numbered by the build. The stale `D18` / bit 15 clock-domain numbering is replaced by the `peri` cluster the contract defines |

# 1. Overview

`PWM` is the pulse-width modulation block of QSOC, an integration of
`pulp-platform/apb_adv_timer` behind an APB4 slave. It contains **four independent
timer modules of four channels each -- sixteen channels** -- of which **eight leave the
chip**.

`0x80034000`, 16 KiB, on `APB_M13`. One interrupt line, line 7 of `irq_fast_i`,
carrying four event sources.

Block directory `design/pwm`, module `m_qnsc_wrap_apb_adv_timer`, owner Nghia Van
Trong.

# 2. Features

- **Four timer modules**, each with its own 16-bit counter, period and 8-bit
  prescaler.
- **Four channels per module**, each with an independent duty threshold and an output
  shape LUT.
- **Up or up-down counting**, the latter giving centre-aligned output.
- **32 external trigger inputs** for start, stop and gate without CPU action.
- **Four event lines** to `INTMAP` -- but they are a **multiplexer over the channel
  outputs**, not four comparators, section 7.3.
- **No software-readable event status** anywhere in the block, section 7.4.

# 3. Block diagram

![The PWM block: four timer modules behind one APB register file](../img/fig_pwm_block.png){width=6.2in}

: PWM sub-modules, within one timer module

| Sub-module | Count | Function |
|---|---:|---|
| `prescaler` | 1 | 8-bit divider, field `PRESC`, ahead of the counter |
| `up_down_counter` | 1 | the 16-bit counter; up, or up then down for centre-aligned output |
| `comparator` | 4 | one per channel, count against that channel's threshold |
| `lut_4x4` | 4 | turns the comparator result plus the current output into the next output |
| `out_filter` | 1 | output conditioning |
| `timer_cntrl` | 1 | start, stop, reset, from APB or from an external trigger |

Four such modules sit behind one APB register file, with **independent counters,
periods and prescalers**. Two channels on the **same** module share a time base and can
be phase-related; channels on **different** modules are not, unless firmware arranges
it -- which it can, because a module's trigger pool includes the other modules' channel
outputs, section 7.6.

# 4. IP used

: Upstream IP used

| From | Module | Commit | Licence |
|---|---|---|---|
| `pulp-platform/apb_adv_timer` | `apb_adv_timer`, `timer_module` and six sub-modules | pinned in `vendor/manifest.yml` | SolderPad 0.51 |

**Why 16 bits is the right width here**, where it would be wrong for a timebase. At
20 MHz a 16-bit counter gives a maximum period of **3.2768 ms**, so **305 Hz** without
the prescaler and **1.19 Hz** with it at maximum divide:

: Achievable frequency and resolution at 20 MHz

| Intended use | Frequency | Counts per period | Duty steps available |
|---|---|---:|---:|
| LED dimming | 1 kHz | 20 000 | **20 000** |
| Motor drive | 20 kHz | 1 000 | **1 000** |
| Audio-rate output | 44.1 kHz | 454 | **454** |
| Slowest without prescaler | 305 Hz | 65 536 | 65 536 |
| Slowest with prescaler | 1.19 Hz | 65 536 x 256 | 65 536 |

The human eye resolves a few dozen brightness levels, so 20 000 steps is far beyond
what PWM needs. The same 16 bits **would** be a serious limitation for a timebase,
which is why the timebase is a different IP -- `QNSC_TIMER_MAS` section 4.

# 5. Interface

: Block interface

| Signal | Dir | Width | Note |
|---|---|---:|---|
| `HCLK` | in | 1 | `peri` cluster clock -- section 7.7 |
| `HRESETn` | in | 1 | active low |
| `PADDR` | in | 12 | decoded as a register index -- section 7.5 |
| `PWDATA` | in | 32 | |
| `PWRITE`, `PSEL`, `PENABLE` | in | 1 each | |
| `PRDATA` | out | 32 | |
| `PREADY`, `PSLVERR` | out | 1 each | |
| `low_speed_clk_i` | in | 1 | **sampled as data, not used as a clock** |
| `dft_cg_enable_i` | in | 1 | bypass for the internal clock gates -- section 10 |
| `ext_sig_i` | in | **32** | external start, stop and gate triggers |
| `events_o` | out | **4** | to `INTMAP`; one-cycle pulses -- 7.3 |
| `ch_0_o` … `ch_3_o` | out | 4 each | **sixteen channel outputs**; `ch_i_o` is module `i` |

# 6. Register map

An 8-bit register index. Each timer module occupies `0x40` bytes; two global registers
follow the four modules.

: Register map

| Offset range | Contents |
|---|---|
| `0x000` -- `0x02C` | timer module 0 |
| `0x040` -- `0x06C` | timer module 1 |
| `0x080` -- `0x0AC` | timer module 2 |
| `0x0C0` -- `0x0EC` | timer module 3 |
| `0x100` | `EVENT_CFG` -- selects and enables the four event lines |
| `0x104` | `CH_EN` -- channel output enables |

: Registers of one timer module

Offsets relative to the module base, which is `0x000`, `0x040`, `0x080` or `0x0C0`.

| Offset | Name | Function |
|---|---|---|
| `+0x00` | `CMD` | start, stop, update, reset, arm |
| `+0x04` | `CFG` | clock source, prescaler, up or up-down mode |
| `+0x08` | `TH` | period threshold -- the value the counter counts to |
| `+0x0C` … `+0x18` | `CH0_TH` … `CH3_TH` | compare threshold per channel -- the duty cycle |
| `+0x1C` … `+0x28` | `CH0_LUT` … `CH3_LUT` | output shape per channel |
| `+0x2C` | `COUNTER` | current count, readable |

**Period is `TH`, duty is `CHn_TH`.** They are separate registers, so changing the duty
of one channel disturbs neither the period nor the other three channels on the same
module.

# 7. Functional behaviour

## 7.1 Eight of the sixteen channels reach pads, and they are two whole modules

In the RTL the channels are grouped **by module**: `u_tim0.pwm_o -> ch_0_o`,
`u_tim1.pwm_o -> ch_1_o`, and so on, so **`ch_i_o[3:0]` is the four channels of module
`i`**.

Bringing out `ch_0_o` and `ch_1_o` therefore means all four channels of module 0 and
all four of module 1 -- **two modules at the pads**. Since channels within a module
share that module's counter and prescaler, firmware gets **two independent base
frequencies** at the pins, with four channels of independent duty and phase under each.

: Channel outputs against pads

| Pad | Pin | Shared with |
|---|---|---|
| `PWM_0` | PIN_27 | `GPIO1_1` |
| `PWM_1` | PIN_28 | `GPIO1_0` |
| `PWM_2` | PIN_29 | `GPIO2_7` |
| `PWM_3` | PIN_30 | `GPIO2_6` |
| `PWM_4` | PIN_33 | `GPIO2_5` |
| `PWM_5` | PIN_34 | `GPIO2_4` |
| `PWM_6` | PIN_35 | `GPIO2_3` |
| `PWM_7` | PIN_36 | `GPIO2_2` |

The other eight channels, modules 2 and 3, stay inside the chip and remain useful: any
of the sixteen can be selected as an event source, 7.3.

## 7.2 Output shape comes from a LUT, not from a polarity bit

Each channel's `CHn_LUT` turns the comparator result **plus the current output** into
the next output. That is what makes centre-aligned and inverted outputs a
configuration rather than extra hardware, and it is why the register is called a LUT
rather than a polarity bit.

## 7.3 The four event lines are a multiplexer over the channel outputs

**The fact most likely to be assumed wrongly.** The four event lines are not four
dedicated comparators. They are four selections from the sixteen channel outputs, each
followed by an edge detector:

```systemverilog
assign s_event_signals = {ch_3_o, ch_2_o, ch_1_o, ch_0_o};      // 16 bits

assign events_o[0] = s_event_en[0] & r_event_sync_0[1] & ~r_event_sync_0[0];
assign events_o[1] = s_event_en[1] & r_event_sync_1[1] & ~r_event_sync_1[0];
assign events_o[2] = s_event_en[2] & r_event_sync_2[1] & ~r_event_sync_2[0];
assign events_o[3] = s_event_en[3] & r_event_sync_3[1] & ~r_event_sync_3[0];
```

Three consequences, all firmware-visible:

- **An interrupt means "a channel I chose has just changed state".** It does not mean
  a period elapsed, and it does not identify which module or channel unless firmware
  remembers what it selected.
- **The pulse is exactly one `HCLK` cycle** -- the classic edge detector, present value
  AND the inverse of the previous. `INTMAP` provides no latch, so **these are the
  narrowest interrupt sources in QSOC**, and `QNSC_Interrupt_Map_MAS` classifies them
  as pulses on that basis.
- **Out of reset the block raises no interrupt at all.** `s_event_en` comes from
  `EVENT_CFG`, which resets to zero, so nothing fires until firmware writes both a
  selection and an enable.

## 7.4 There is no software-readable event status

Each `timer_module` exposes an 8-bit `status_o`. In the top level it appears **exactly
twice** -- once declared, once connected:

```systemverilog
logic [7:0] s_timer0_status;
...
    .status_o         ( s_timer0_status       )
```

and then nothing reads it. `adv_timer_apb_if` has **no port whose name contains
`status`**, so the signal is not reachable by software in this version of the IP.

**Consequence:** a PWM event arriving while `mstatus.MIE` is clear is lost, and
**nothing anywhere records that it happened**. No flag to poll, no counter to compare.

**Why that is acceptable here.** A PWM channel is periodic by construction: it changes
state again on the next period, between 23 microseconds and 1 millisecond away at the
frequencies of section 4. **The recovery mechanism is periodicity, not a status
register** -- which is why `QNSC_Interrupt_Map_MAS` states its pulse-recovery argument
in terms of periodicity.

It fails in exactly one case: a module configured for a single shot, or stopped
immediately after the event. **Firmware must not use PWM events as one-off
notifications.**

## 7.5 The register file aliases across its region

: Address decode against region size

| Item | Value |
|---|---|
| Registers implemented | 4 modules x 12 registers, plus 2 global |
| Span actually decoded | **264 bytes**, `0x000` to `0x107` |
| Region assigned | **16 KiB** |
| Consequence | the decoded span **aliases** across the region |

As with the timers, an access beyond the implemented span neither faults nor reports an
error. Same recommendation: accept the aliasing, document it, and do not spend logic on
a fault firmware cannot observe.

## 7.6 External triggers

`ext_sig_i` is 32 bits of start, stop and gate triggers, selected per module. A
module's trigger pool includes **the other modules' channel outputs**, which is the
mechanism by which firmware can phase-relate channels on different modules despite
their independent counters -- section 3.

What drives `ext_sig_i` at the top level is not settled; see section 11.

## 7.7 `low_speed_clk_i` is not a clock

The block **samples** it rather than clocking from it, so it introduces no clock domain
crossing and needs no `set_false_path`. Tie it to the domain clock unless a slower
counting rate is wanted. `QSOC_HAS` already records this treatment.

# 8. Instances

One, on `APB_M13`. The four timer modules are internal to the IP, not four instances
of this block.

# 9. What is not provided here, and who provides it

: Functions this block does not provide

| Function | Where it lives |
|---|---|
| Event status or flag | **Nowhere.** `status_o` is not wired to the APB interface -- 7.4 |
| Event acknowledge | Nothing to acknowledge; the recovery is periodicity -- 7.4 |
| Which module or channel raised an event | Firmware, by remembering what it selected in `EVENT_CFG` -- 7.3 |
| A period-elapsed interrupt | Nowhere. Events are channel state changes, not period ends -- 7.3 |
| Aggregation onto a CPU interrupt line | `INTMAP`, line 7 |
| Pad multiplexing between `PWM_n` and GPIO | IO MUX -- 7.1 |

# 10. Constraints this block imposes

: Constraints on firmware, integration and DFT

| On | Constraint | Consequence if missed |
|---|---|---|
| Firmware | **Stop the modules through `CMD` and let the outputs reach idle before the clock is gated** | A gated channel freezes at its current level, and for a power stage a held level is not a neutral state |
| Firmware | Do not use PWM events as one-off notifications | A missed single-shot event is unrecoverable -- 7.4 |
| Firmware | Write both a selection and an enable in `EVENT_CFG` | No interrupt at all -- 7.3 |
| `SCRC` | **Never gate a running block** -- recorded in `util/qsoc_contract.yml` as this block's special clock rule | Same as the first row, from the other side |
| Integration | `dft_cg_enable_i` **tied low for QSOC v1** | See below |
| Integration | `low_speed_clk_i` tied to the domain clock unless a slower rate is wanted | 7.7 |

**`dft_cg_enable_i` and DFT.** The IP instantiates clock gating cells internally and
brings out this input to bypass them so scan can shift through otherwise gated logic.
**For v1 it is tied low, because there is nothing to drive it from**: the pad table
originally listed a combined test-mode / JTAG pin, and the Day005 review of 2026-09-18
established that entry had been **copied from another chip** and removed it. With no
test-mode pin in the pad ring, a tie-off is the only option.

This is **not** a claim that QSOC has no scan. The same review ruled that a
specification must not assert the absence of test mode or scan, because DFT may be
added later. If it is, this tie-off becomes the first thing to revisit, and the input
already exists for it.

# 11. Requirements on others, and open items

: Requirements on other owners

| Item | Owner | What it blocks |
|---|---|---|
| APB paddr width for the wrapper | bus owner | The wrapper's port list. The IP declares 12 bits; the 16 KiB region is 14 |
| `CLK_EN` bit position for this block | SCRC owner | The wrapper's clock port |
| **Which eight channels reach the pads**, confirmed as `ch_0_o` and `ch_1_o` | pad owner | Fixed here as modules 0 and 1, giving two base frequencies -- 7.1 |
| IO MUX default for `PIN_27` … `PIN_36` | IO MUX owner | Whether PWM or GPIO owns the pin out of reset |
| What drives `ext_sig_i`, if anything | top-level owner | External triggers. Tied 0 if nothing drives them -- 7.6 |
| PWM on line 7 of `irq_fast_i`, four sources, pulse | INTMAP owner (this author) | Settled in `util/qsoc_contract.yml` |

**Accepted limits**, stated rather than hidden:

1. No event status anywhere; recovery is periodicity alone -- 7.4.
2. Events are channel state changes, not period ends -- 7.3.
3. One-cycle pulses, the narrowest sources in QSOC -- 7.3.
4. 264 bytes aliasing across 16 KiB -- 7.5.
5. Eight of sixteen channels reach pads, and they are two whole modules rather than
   eight freely chosen channels -- 7.1.
6. `dft_cg_enable_i` tied low for v1 -- section 10.

**Open on this block:** what drives `ext_sig_i`, and the gate count, which waits on
synthesis.

# 12. Verification

The IP arrives with no testbench, so all of this is QSOC's to write.

: Verification QSOC must add

| What is checked | Why it matters |
|---|---|
| **`ch_i_o` carries the four channels of module `i`** | The pad decision of 7.1 rests on it, and an earlier revision of this document had it backwards |
| Two modules at the pads give **two** base frequencies, four channels each | 7.1 |
| An event fires on a **channel state change**, not at the end of a period | 7.3, the fact most likely to be assumed wrongly |
| The event pulse is exactly one `HCLK` cycle in every configuration | 7.3, and the width `INTMAP` assumes |
| No event fires until `EVENT_CFG` has both a selection and an enable | 7.3 |
| Period and duty are independent: changing `CHn_TH` disturbs neither `TH` nor the other channels | Section 6 |
| Up-down mode produces a centre-aligned output | Section 2 |
| Gating the clock mid-run freezes the output at its current level | The hazard of section 10, proven rather than assumed |
| An access beyond `0x107` neither faults nor corrupts | 7.5 |

**Acceptance criterion:** eight pads carry two independent base frequencies with four
independently adjustable duty cycles under each, and an event interrupt arrives one
`HCLK` cycle wide on a channel edge that firmware selected.

# Appendix A. Acronyms

: Acronyms

| Acronym | Description |
|---|---|
| APB | Advanced Peripheral Bus, AMBA APB4 |
| `CH_EN` | Channel output enable register |
| DFT | Design For Test |
| `dft_cg_enable_i` | Input that bypasses the IP's internal clock gates for scan |
| `EVENT_CFG` | Register selecting and enabling the four event lines |
| LUT | Look-Up Table; here the per-channel output shaping table |
| PWM | Pulse Width Modulation |
| `TH` | Period threshold; `CHn_TH` is the duty threshold |

# Appendix B. First review

: First review

| Item | Reviewer | Response |
|---|---|---|
| Too long, and the redundancy causes wrong information | Teacher, 2026-09-23 | V2.0: 634 lines to this, with the record kept whole in `_DECISIONS` |
| Do the four event lines mean four periods elapsed? | -- | No. They are a multiplexer over channel outputs -- 7.3, given its own section for that reason |
| Is 16 bits enough? | -- | Yes for PWM, and section 4 gives the numbers. It would not be for a timebase, which is why that is a different IP |
| **`ch_i_o` mapping** | RTL, against V1.5 of this document | V1.5 had it as channel `i` of every module, which was wrong. It is all four channels of module `i`, so eight pads are **two** base frequencies, not four. Corrected in V1.6 |
