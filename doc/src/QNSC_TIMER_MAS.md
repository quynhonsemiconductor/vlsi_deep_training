---
title: "TIMER"
subtitle: "MICRO-ARCHITECTURE SPECIFICATION -- V2.0"
author: "QUY NHON SEMICONDUCTORS -- QNSC"
---

# Revision history

`V2.0` is a rewrite. The reasoning behind each decision, and how every open question
closed, is in [`QNSC_TIMER_DECISIONS.md`](QNSC_TIMER_DECISIONS.md).

| Version | Date | Author | Reviewer | Description of change |
|---|---|---|---|---|
| V2.0 | 2026-09-23 | Nghia VT | -- | Rewritten as specification only, onto the template the other blocks follow. Tables and figures are numbered by the build |

# 1. Overview

`TIMER0` and `TIMER1` are the two general-purpose timers of QSOC, each an integration
of `pulp-platform/apb_timer_unit` behind an APB4 slave. One instance holds **two
32-bit counters** that can be **chained into one 64-bit counter**.

**QSOC has no CLINT, so there is no `mtime`.** `TIMER0` is the chip's timebase, and
firmware reaches it through these registers rather than through the RISC-V standard
machine timer -- section 11.

Block directory `design/timer`, module `m_qnsc_wrap_apb_timer_unit`, owner Nghia Van
Trong.

: Instance assignment

| Instance | Region | APB port | Mode | Interrupt lines |
|---|---|---|---|---|
| `TIMER0` | `0x8001C000` | `APB_M7` | **64-bit**, both counters chained | 1 -- `irq_lo_o` only |
| `TIMER1` | `0x80020000` | `APB_M8` | **two independent 32-bit** | 2 -- `irq_lo_o`, `irq_hi_o` |

# 2. Features

- **Two 32-bit counters** per instance, chainable into **one 64-bit** counter.
- **8-bit prescaler** ahead of each counter, and an optional **reference-clock** input
  sampled as data.
- **Periodic or one-shot** at the compare, selected per counter.
- **Hardware start** from an event input, with no CPU action.
- **No status register and no interrupt flag** -- section 6, and the fact
  `QNSC_Interrupt_Map_MAS` depends on.

# 3. Block diagram

![The timer block and its two counters](../img/fig_timer_block.png){width=6.2in}

: TIMER sub-modules

| Sub-module | Count | Function |
|---|---:|---|
| `timer_unit_counter` | 2 | the 32-bit counters, `lo` and `hi` |
| `timer_unit_counter_presc` | 2 | 8-bit prescaler ahead of each counter |
| APB register file | 1 | ten addresses, section 6 |
| Interrupt logic | 1 | combinational, section 7.3 |

In 64-bit mode the two counters are chained, and the RTL raises the carry explicitly:

```systemverilog
s_enable_count_hi = ( s_timer_val_lo == 32'hFFFFFFFF );
```

so `counter_hi` advances **exactly once per wrap** of `counter_lo` -- a true 64-bit
count, not two loosely coupled halves.

# 4. IP used

: Upstream IP used

| From | Module | Commit | Licence |
|---|---|---|---|
| `pulp-platform/apb_timer_unit` | `apb_timer_unit` and three sub-modules | pinned in `vendor/manifest.yml` | SolderPad 0.51 |

**Why not the PWM IP**, which QSOC also instantiates. An earlier revision specified
`apb_adv_timer` for this role; it cannot perform it, and the reason is arithmetic:

: Why the PWM IP cannot serve as the timer

| | `apb_adv_timer` (PWM) | `apb_timer_unit` (this block) |
|---|---|---|
| Counter width | **16-bit** | 32-bit, or **64-bit** combined |
| Wrap at 20 MHz, no prescaler | **3.2768 ms** | 214.7 s, or ~29 000 years at 64-bit |
| Channel output pins | 16 | **none** |
| Suited to | short repeating waveforms | a timebase that must not wrap |

A timebase wrapping every 3.28 ms forces firmware to count wraps continuously, and one
missed wrap corrupts every later measurement. A PWM block never needs a long count.
**The two roles want opposite counter widths, which is why QSOC instantiates both IPs.**

# 5. Interface

: Block interface

| Signal | Dir | Width | Note |
|---|---|---:|---|
| `HCLK` | in | 1 | `peri` cluster clock, gateable by `SCRC` -- section 10 |
| `HRESETn` | in | 1 | active low |
| `PADDR` | in | 12 | **only `PADDR[5:0]` is decoded** -- section 7.6 |
| `PWDATA` | in | 32 | |
| `PWRITE`, `PSEL`, `PENABLE` | in | 1 each | |
| `PRDATA` | out | 32 | |
| `PREADY` | out | 1 | **tied** to `PSEL & PENABLE` inside the IP |
| `PSLVERR` | out | 1 | **tied 0** inside the IP |
| `ref_clk_i` | in | 1 | sampled as data, **not used as a clock** |
| `event_lo_i`, `event_hi_i` | in | 1 each | start a counter without CPU action |
| `irq_lo_o`, `irq_hi_o` | out | 1 each | to `INTMAP` |
| `busy_o` | out | 1 | either counter enabled |

`PREADY` tied and `PSLVERR` tied pull in opposite directions:

- **The block can never stall `P_BUS`.** No access can hang the bus, which removes it
  from the list of blocks a watchdog must protect against.
- **The block can never report an error.** A write to an unimplemented offset is
  accepted silently and a read returns zero, so firmware gets no signal that it
  addressed the block wrongly.

# 6. Register map

Ten addresses per instance, at the region base.

: Register map of one instance

| Offset | Name | Access | Function |
|---|---|---|---|
| `0x00` | `CFG_REG_LO` | RW | configuration of `lo`; also holds the 64-bit mode bit |
| `0x04` | `CFG_REG_HI` | RW | configuration of `hi` |
| `0x08` | `TIMER_VAL_LO` | RW | current count of `lo`; a write loads it |
| `0x0C` | `TIMER_VAL_HI` | RW | current count of `hi`; a write loads it |
| `0x10` | `TIMER_CMP_LO` | RW | compare target for `lo` |
| `0x14` | `TIMER_CMP_HI` | RW | compare target for `hi` |
| `0x18` | `TIMER_START_LO` | WO | any write starts `lo` |
| `0x1C` | `TIMER_START_HI` | WO | any write starts `hi` |
| `0x20` | `TIMER_RESET_LO` | WO | any write clears `lo` |
| `0x24` | `TIMER_RESET_HI` | WO | any write clears `hi` |

**Reads return only six of the ten** -- the two `CFG`, the two `VAL`, the two `CMP`.
The four command addresses are write-only and read as zero.

**There is no status register and no interrupt flag.** This is the fact section 11 and
`QNSC_Interrupt_Map_MAS` both depend on: nothing in this block records that an
interrupt happened, so nothing here can acknowledge one either.

: CFG_REG_LO and CFG_REG_HI bit fields

| Bit | Name | Function |
|---:|---|---|
| 0 | `ENABLE` | counter runs |
| 1 | `RESET` | clears the counter; self-clearing |
| 2 | `IRQ_EN` | allows the compare to raise the interrupt |
| 3 | `IEM` | lets `event_*_i` set `ENABLE` |
| 4 | `CMP_CLR` | on compare, clear the counter -- this is what makes it periodic |
| 5 | `ONE_SHOT` | on compare, clear `ENABLE` |
| 6 | `PRESC_EN` | insert the prescaler |
| 7 | `REF_CLK_EN` | count `ref_clk_i` edges instead of every core clock |
| 15:8 | `PRESC` | 8-bit prescaler divisor |
| 31 | `MODE_64` | **`CFG_REG_LO` only**: chain both counters into one 64-bit timer |

`MODE_64` is read from `CFG_REG_LO` everywhere the RTL uses it, including the paths
controlling the `hi` counter. **Writing bit 31 of `CFG_REG_HI` has no effect** and must
not be relied on.

# 7. Functional behaviour

## 7.1 Counting rate

: Counting rate options

| `REF_CLK_EN` | `PRESC_EN` | Counter advances | Wrap of 32 bits at 20 MHz |
|---|---|---|---|
| 0 | 0 | every core clock | 214.7 s |
| 0 | 1 | every `PRESC`+1 core clocks | up to 256 x that |
| 1 | 0 | on each rising edge of `ref_clk_i` | set by `ref_clk_i` |
| 1 | 1 | prescaled `ref_clk_i` edges | set by both |

`ref_clk_i` passes through a four-stage shift register and an edge detector inside the
IP. **It is sampled as data, never used as a clock**, so it creates no second clock
domain and needs no CDC constraint.

## 7.2 One counting tick is the interrupt pulse width

One counting tick is one `HCLK` cycle with no prescaler and no reference clock,
`PRESC`+1 cycles with the prescaler, or one `ref_clk_i` period with `REF_CLK_EN` set.
**The narrowest case is one core clock, and that is the case `INTMAP` must assume.**

## 7.3 The interrupt is combinational, and 64-bit mode drives only one line

```systemverilog
if ( s_cfg_lo_reg[`MODE_64_BIT] == 1'b0 ) begin       // 32-bit mode
   irq_lo_o = s_target_reached_lo & s_cfg_lo_reg[`IRQ_BIT];
   irq_hi_o = s_target_reached_hi & s_cfg_hi_reg[`IRQ_BIT];
end else begin                                        // 64-bit mode
   irq_lo_o = s_target_reached_lo & s_target_reached_hi & s_cfg_lo_reg[`IRQ_BIT];
end
```

**In 64-bit mode `irq_hi_o` is never driven**, so the instance contributes one source,
not two. That is why `TIMER0` contributes one line and `TIMER1` two.

**The AND is correct, though it looks as though two unrelated events must coincide.**
`target_reached_hi` is high for the whole epoch in which `counter_hi` equals its target
-- one full wrap of `counter_lo` -- and within that epoch `counter_lo` equals its own
target for exactly one tick. So the AND gives **exactly one pulse**, at the intended
64-bit value.

## 7.4 The compare is equality, not greater-or-equal

`target_reached` is asserted when the counter **equals** the compare value. The
standard RISC-V machine timer is specified the other way -- pending while
`mtime >= mtimecmp` -- specifically so that a target already passed still fires.

**This block has no such protection, and the failure is silent:**

| Mode | If firmware writes a target the counter has just passed |
|---|---|
| 32-bit at 20 MHz | next hit after a full wrap, **214.7 s** late |
| **64-bit at 20 MHz** | next hit after a 64-bit wrap, **~29 000 years** -- never |

**Firmware must compute the next target from the current count with enough margin to
cover its own interrupt latency, and must not write a target derived from a count it
read earlier.** In 64-bit mode this is a correctness matter, not a performance one.
Section 12 turns it into a test.

## 7.5 One-shot mode holds the interrupt as a level

The comparator is a flop **not gated by the counter enable**:

```systemverilog
// timer_unit_counter.sv -- COMPARATOR
always_ff@(posedge clk_i, negedge rst_ni)
   if ( s_count == compare_value_i ) target_reached_o <= 1'b1;
   else                              target_reached_o <= 1'b0;
```

and when the counter is stopped, `s_count` holds its value. So a mode that **stops the
counter on the compare** leaves `s_count == compare_value_i` true indefinitely, and the
interrupt is held rather than pulsed.

: Interrupt shape by mode

| `CMP_CLR` | `ONE_SHOT` | What happens at the target | Shape | Width |
|---|---|---|---|---|
| 1 | 0 | counter clears and runs on -- periodic | **pulse** | 1 counting tick |
| 0 | 0 | counter runs past the target | **pulse** | 1 tick; next hit after a full wrap |
| x | **1** | `ENABLE` cleared, **counter stops on the target** | **held level** | until firmware clears or restarts it |

**The held level is useful rather than awkward.** One-shot is exactly the mode in which
"the event repeats next period" is *not* available as a recovery mechanism. Because the
IP holds the line, a one-shot alarm missed while `mstatus.MIE` was clear is still
pending when interrupts are re-enabled. `QNSC_Interrupt_Map_MAS` classifies the two
modes separately for this reason.

**Firmware must clear a one-shot interrupt by acting on the block** -- writing
`TIMER_RESET_*`, moving `TIMER_CMP_*`, or clearing `IRQ_EN`. Returning from the handler
without doing so re-enters it immediately.

## 7.6 The register file aliases 256 times across its region

: Address decode against region size

| Item | Value |
|---|---|
| Registers implemented | 10 addresses, `0x00` to `0x24` |
| Address bits decoded | `PADDR[5:0]` |
| Span actually decoded | **64 bytes** |
| Region assigned | **16 KiB** |
| Consequence | the 64 bytes **alias 256 times** across the region |

So `0x80020000` and `0x80020040` are the same register. Harmless if firmware uses the
base address, and a trap if anyone assumes an access above the first 64 bytes will
fault -- it will not, `PSLVERR` being tied low.

**The recommendation is to accept the aliasing and document it**, rather than narrow
the decode in the wrapper: narrowing costs logic and buys only a fault firmware has no
way to observe.

# 8. Instances

Two, differing in the mode firmware selects rather than in any parameter -- see the
table in section 1. `TIMER0` is configured 64-bit as the chip timebase; `TIMER1` is
left as two independent 32-bit counters.

# 9. What is not provided here, and who provides it

: Functions this block does not provide

| Function | Where it lives |
|---|---|
| Interrupt status or flag | **Nowhere.** The block has none -- section 6 |
| Interrupt acknowledge | Firmware acting on the block: `TIMER_RESET_*`, `TIMER_CMP_*` or `IRQ_EN` -- 7.5 |
| Error response on a bad offset | Nowhere. `PSLVERR` is tied 0 -- section 5 |
| Greater-or-equal compare | Nowhere. Firmware must add the margin -- 7.4 |
| `mtime` and `mtimecmp` | Nowhere. QSOC has no CLINT -- section 11 |
| Aggregation onto a CPU interrupt line | `INTMAP` |

# 10. Constraints this block imposes

: Constraints on firmware and integration

| On | Constraint | Consequence if missed |
|---|---|---|
| Firmware | Compute the next compare target from the **current** count, with margin | A target just passed is missed for a full wrap -- 214.7 s, or never in 64-bit mode |
| Firmware | Clear a one-shot interrupt by acting on the block | The handler re-enters immediately -- 7.5 |
| Firmware | Do not write `MODE_64` in `CFG_REG_HI` | Silently ignored -- section 6 |
| Firmware | Use the region base; do not rely on a fault above `0x24` | Aliasing, silent -- 7.6 |
| `SCRC` | Do not gate `peri` while a timer interrupt is asserted | The handler cannot clear its own source |

# 11. Requirements on others, and open items

: Requirements on other owners

| Item | Owner | What it blocks |
|---|---|---|
| APB paddr width for the wrapper | bus owner | The wrapper's port list. The IP declares 12 bits; the region is 16 KiB, so 14 |
| `CLK_EN` bit position for this block | SCRC owner | The wrapper's clock port |
| `TIMER0` on line 10, `TIMER1` on line 6 of `irq_fast_i` | INTMAP owner (this author) | Settled in `util/qsoc_contract.yml` |
| What drives `event_lo_i` and `event_hi_i`, if anything | top-level owner | Hardware start. Tied 0 if nothing drives them |
| What drives `ref_clk_i`, if anything | top-level owner | The reference-clock counting modes of 7.1 |
| Timer driver in place of the standard `mtime` one | firmware owner | Any RTOS port -- see below |

**What QSOC gives up by having no `mtime`.** The RISC-V privileged specification puts
the machine timer at `mtime`/`mtimecmp` in a CLINT, and every RTOS port and most bare
metal examples assume it. QSOC has no CLINT, so `mip.MTIP` is never set and
`irq_timer_i` is tied off. The consequence is confined to software: firmware drives
`TIMER0` through the registers of section 6 instead, and an RTOS port must supply its
own timer driver. Nothing in hardware is missing -- a 64-bit counter with a compare is
exactly what `mtime` is -- but the **interface** is this block's, not the standard one.

**Accepted limits**, stated rather than hidden:

1. Equality compare, with no catch-up -- 7.4. The most serious limit in the block.
2. No interrupt status anywhere -- section 6.
3. No error response -- section 5.
4. 64 bytes aliasing across 16 KiB -- 7.6.
5. `irq_hi_o` unused in 64-bit mode -- 7.3.

**Open on this block:** whether `event_*_i` and `ref_clk_i` are driven at all, and the
gate count, which waits on synthesis.

# 12. Verification

The IP arrives with no testbench, so all of this is QSOC's to write.

: Verification QSOC must add

| What is checked | Why it matters |
|---|---|
| **A target written just after the counter passed it is missed**, and the documented margin rule avoids it | The block's most serious limit -- 7.4. The test exists to prove the rule is necessary, not that the hardware is wrong |
| 64-bit chaining: `counter_hi` advances exactly once per wrap of `counter_lo` | The carry of section 3 |
| 64-bit mode raises **one** pulse at the intended value, and `irq_hi_o` stays low | 7.3 |
| One-shot holds the line until firmware acts; periodic pulses for one tick | 7.5, and the shape `INTMAP` assumes |
| Pulse width is one counting tick in each of the four rate modes | 7.1, 7.2 |
| `MODE_64` in `CFG_REG_HI` has no effect | Section 6 |
| Reads of the four command offsets return zero | Section 6 |
| `0x00` and `0x40` are the same register | 7.6 |
| No APB access can stall `P_BUS`, for any offset in the 16 KiB region | Section 5 |

**Acceptance criterion:** `TIMER0` in 64-bit mode raises exactly one interrupt at a
programmed 64-bit target, and a target written late is proven to be missed -- because a
timebase that silently stops being a timebase is the failure this block can cause.

# Appendix A. Acronyms

: Acronyms

| Acronym | Description |
|---|---|
| APB | Advanced Peripheral Bus, AMBA APB4 |
| CLINT | Core Local Interruptor -- the RISC-V standard timer block. **Not present in QSOC** |
| `CMP_CLR` | Clear the counter on compare, making it periodic |
| `IEM` | Interrupt Event Mask: lets `event_*_i` start the counter |
| `MODE_64` | `CFG_REG_LO` bit 31: chain both counters |
| `mtime`, `mtimecmp` | The RISC-V standard machine timer registers, in a CLINT |
| `ONE_SHOT` | Clear `ENABLE` on compare, stopping the counter |
| `PRESC` | Prescaler divisor |
| `PSLVERR` | APB slave error response. **Tied 0 by this IP** |

# Appendix B. First review

: First review

| Item | Reviewer | Response |
|---|---|---|
| Too long, and the redundancy causes wrong information | Teacher, 2026-09-23 | V2.0: 571 lines to this, with the record kept whole in `_DECISIONS` |
| Why two different timer IPs in one chip? | -- | Section 4: 16-bit wraps in 3.28 ms, which cannot be a timebase. The roles want opposite counter widths |
| Is the 64-bit compare expression correct? | -- | Yes, and 7.3 shows why the AND of two conditions still gives exactly one pulse |
| Does the block need an interrupt status register? | -- | It has none and cannot be given one -- it is IP. Section 9 says where acknowledgement happens instead |
