# QNSC_WDT — design decisions and record

**This is not the specification.** That is [`QNSC_WDT_MAS.md`](QNSC_WDT_MAS.md).

The specification is written from the research draft V0.1 of Quach Huynh Huu Tai,
the first owner, kept whole below; the block is now owned by Vu Bui Minh Hieu. The
draft's IP choice, register map and bus-integrity finding hold at the pinned
commit. Its figure, the upstream block diagram, is not reproduced.

---

# 1. Research draft V0.1 to MAS V1.0

| Change | Why |
|---|---|
| One 20 MHz clock on `clk_i` and `clk_aon_i`; timeout up to 214.7 s | QSOC has no slow always-on oscillator (contract `meta.clock_mhz`, cluster `wdt`); the draft assumed OpenTitan's ~200 kHz, up to about 6 hours |
| Bark to `INTMAP` `i_int_wdt_bark` (NMI), wake-up to line 8, bite to `SCRC` `i_wdt_rst_req`; `intr_wdog_timer_bark_o` and `wkup_req_o` open | QSOC has no PLIC, `pwrmgr` or `rstmgr`; contract `interrupts` |
| APB bridge on the upstream `tlul_adapter_host` (`MAX_REQS` = 1, `EnableDataIntgGen` = 1) | The draft mapped every TL-UL field by hand and added `tlul_cmd_intg_gen`; the adapter already does both and contains that module. What stays in house is the APB handshake. Shared with SPI in `design/common` |
| `lc_escalate_en_i` tied to `lc_ctrl_pkg::Off` | The draft had it driven by a life-cycle controller QSOC does not have. Tied to 0 the counters never run: checked in simulation |
| Five OpenTitan packages listed as still to vendor | `aon_timer` and `tlul_adapter_host` do not compile without `lc_ctrl_pkg`, `lc_ctrl_state_pkg`, `lc_ctrl_reg_pkg`, `top_pkg`, `top_racl_pkg`; with them they lint and simulate |
| Access behaviour: 2 wait states, `PSLVERR` at `0x38`--`0x3C` and for partial writes, alias every 64 bytes | Measured in simulation; not in the draft |
| `sleep_mode_i` = 0; `pause_in_sleep` has no effect | QSOC has no sleep mode |
| Rule `WDOG_BARK_THOLD` < `WDOG_BITE_THOLD`; pet before clearing the bark | Mentor rule (bark first, then bite); the bark bit is set again on every count above the threshold |
| Watchdog counting during a debug halt, accepted limit | `aon_timer` has no debug pause input |
| "Clock order: `clk_aon_i` before `clk_i`" dropped | Both are the same clock |

## Simulation used as evidence

Verilator 5, `aon_timer` with the tie-offs of MAS section 10, `tlul_adapter_host`
and the bridge of MAS 7.5 in a testbench, 20 MHz: every APB access 4 cycles;
`BARK` = 100 gives the NMI 107 cycles after the enable write; `BITE` = 200 gives the
reset request at 203 cycles, held until reset; pet then W1C drops the NMI; offset
`0x38` and a byte write to `WDOG_BARK_THOLD` answer an error; offset `0x5C` reads
`WDOG_CTRL`; with `lc_escalate_en_i` = 0 the counter stays 0.

---

# Research draft as issued

## Reversion and History

| Version | Date (mm/dd/yyyy) | Author | Reviewer | Description of Change |
|----|----|----|----|----|
| V0.1 | 09/06/2026 | Tai | \- | Initial draft based on GitHub source research |
| V0.2 |  |  |  |  |
| V0.3 |  |  |  |  |
| V0.4 |  |  |  |  |

Record of ChangesThis table provides the following information about each change to this document: Version Number Date Author/Owner Description of Change

## Overview

Overview

This document specifies the Watchdog Timer (WDT) IP selected for the QNSC training MCU: the AON Timer (aon_timer), sourced from the open-source repository lowRISC/opentitan, distributed under the Apache License 2.0. The IP List assessment rates this IP as "Silicon-proven" - documented as integrated and taped out in the Earl Grey chip (OpenTitan) - the highest readiness rating in the catalogue, with royalty-free commercial use permitted.

aon_timer bundles two independent free-running counters that operate on a slow, always-on (~200 kHz) clock domain so they keep running even while the main system clock/CPU is stopped: a 32-bit watchdog counter (this document's primary subject) and a 64-bit wakeup counter (bundled in the same IP; documented here for completeness since both share one register block and one bus interface).

GitHub source: https://github.com/lowRISC/opentitan, directory hw/ip/aon_timer (RTL: rtl/aon_timer.sv, rtl/aon_timer_core.sv; register block auto-generated from data/aon_timer.hjson; official documentation: doc/theory_of_operation.md, doc/registers.md, doc/programmers_guide.md, doc/interfaces.md).

Project note: the QNSC training SoC uses an AXI4/APB4 bus hierarchy (see the System Bus and Peripheral Bus specifications) while aon_timer's native bus device interface is TileLink-UL (TL-UL), the bus protocol of its origin project (OpenTitan). Connecting this IP therefore requires a small APB4-to-TL-UL protocol wrapper between the Peripheral Bus and aon_timer's tl_i/tl_o ports. Section “APB4-to-TL-UL Protocol Wrapper (Integration Bridge)” below documents the signal mapping and design considerations for this wrapper; its RTL implementation is scoped as a separate, in-house IP block (Training Plan Module 3, IP Implementation).

## Feature

### Independent Watchdog and Wakeup Counters

• WDOG_COUNT: 32-bit watchdog counter, enabled by WDOG_CTRL.enable; maximum timeout window of roughly 6 hours at the ~200 kHz AON clock.

• {WKUP_COUNT_HI, WKUP_COUNT_LO}: 64-bit wakeup counter, enabled by WKUP_CTRL.enable, accessed through two 32-bit registers since a single atomic 64-bit access is not possible.

### Dual-Threshold Watchdog Bark/Bite Scheme

• WDOG_BARK_THOLD: when the watchdog counter reaches this threshold, an interrupt (intr_wdog_timer_bark_o) and a direct non-maskable interrupt copy (nmi_wdog_timer_bark_o) are raised - an early, software-recoverable warning.

• WDOG_BITE_THOLD: if software fails to respond (does not "pet" the watchdog) and the counter keeps rising to this second, higher threshold, aon_timer_rst_req_o is asserted to the reset manager, forcing a hardware reset.

### Configuration Lock (WDOG_REGWEN)

• After the watchdog is configured and enabled, software can write 0 to WDOG_REGWEN (a write-one/zero-to-clear bit) to permanently lock WDOG_CTRL, WDOG_BARK_THOLD and WDOG_BITE_THOLD until the next reset, preventing runaway or malicious software from silently disabling the safety watchdog.

### Sleep-Mode Pause

• WDOG_CTRL.pause_in_sleep, together with the sleep_mode_i input, lets the watchdog stop counting during an intentional low-power sleep period so it does not expire purely because the system is (correctly) asleep.

### Wakeup Timer with Programmable Prescaler

• WKUP_CTRL.prescaler (12 bits) divides the ~200 kHz AON clock down to a software-chosen tick period before the 64-bit counter increments, letting software match the tick to a convenient time unit (e.g. milliseconds); a write to WKUP_CTRL resets the internal prescaler count.

• When the wakeup counter reaches WKUP_THOLD, wkup_req_o is asserted to the power manager and WKUP_CAUSE records that this timer caused the wakeup.

### Life-Cycle and Security Integration

• Both counters stop counting while lc_escalate_en_i indicates the life-cycle/alert-handler subsystem has put the chip into a security-escalated ("killed") state.

• A dedicated fatal_fault alert (via ALERT_TEST / alert_rx_i / alert_tx_o) is raised on a fatal TL-UL bus-integrity fault; countermeasure AON_TIMER.BUS.INTEGRITY provides end-to-end integrity checking on the register interface.

## Interface and Signal Description

| Port | Dir | Width | Description |
|----|----|----|----|
| clk_i | in | 1 | Main (SYS-domain) clock for the register interface. |
| clk_aon_i | in | 1 | Always-on ~200 kHz clock; must be started before clk_i when integrating this IP. |
| rst_ni | in | 1 | Asynchronous active-low reset, SYS domain. |
| rst_aon_ni | in | 1 | Asynchronous active-low reset, AON domain. |
| tl_i / tl_o | in/out | tlul_pkg::tl_h2d_t / tl_d2h_t | Native TL-UL bus device (register) interface. In this project, reached from the Peripheral Bus through the APB4-to-TL-UL wrapper (see Overview note). |
| alert_rx_i / alert_tx_o | in/out | 1 (NumAlerts=1) | Differential alert-handler wires carrying the fatal_fault alert. |
| racl_policies_i / racl_error_o | in/out | 1 | Optional Role-based Access Control List policy/error interface (enabled by parameter EnableRacl; not required for the training MCU). |
| lc_escalate_en_i | in | lc_ctrl_pkg::lc_tx_t | Life-cycle escalation-enable input; halts both counters when asserted. |
| intr_wkup_timer_expired_o | out | 1 | Interrupt: wakeup counter reached WKUP_THOLD (routed to the PLIC). |
| intr_wdog_timer_bark_o | out | 1 | Interrupt: watchdog counter reached WDOG_BARK_THOLD (routed to the PLIC). |
| nmi_wdog_timer_bark_o | out | 1 | Non-maskable copy of the watchdog bark event, wired directly to the CPU's NMI input. |
| wkup_req_o | out | 1 | Wakeup request to the power manager (AON domain). |
| aon_timer_rst_req_o | out | 1 | Reset request to the reset manager (AON domain) - the watchdog "bite". |
| sleep_mode_i | in | 1 | Indicates the system is in a low-power sleep state; used with WDOG_CTRL.pause_in_sleep. |

### Connections within the SoC

tl_i/tl_o reach the register interface through the APB4-to-TL-UL wrapper fed by one APB4 master port of the Peripheral Bus (see the companion Peripheral Bus specification). intr_wkup_timer_expired_o and intr_wdog_timer_bark_o connect to the PLIC (interrupt controller), which in turn signals the Ibex CPU; nmi_wdog_timer_bark_o connects directly to the CPU's NMI input, bypassing the PLIC. wkup_req_o and aon_timer_rst_req_o connect to the power manager (pwrmgr) and reset manager (rstmgr) respectively. lc_escalate_en_i is driven by the life-cycle controller / alert-handler subsystem.

## APB4-to-TL-UL Protocol Wrapper (Integration Bridge)

This section is a preliminary interface-level design assessment of the APB4-to-TL-UL wrapper referenced in the Overview, prepared ahead of RTL coding (Training Plan Module 3, IP Implementation). It documents the signal mapping, protocol-compatibility reasoning, and the one integration requirement that is not optional, so the wrapper's RTL can be written directly against this specification.

### Signal Mapping

The wrapper is an APB4 slave (facing the Peripheral Bus master port assigned to WDT) and, at the same time, a TL-UL host (facing aon_timer's tl_i/tl_o device port). The table below maps each side.

| APB4 signal (wrapper as slave) | TL-UL signal (wrapper as host) | Mapping rule |
|----|----|----|
| PSEL, PENABLE (Access phase) | a_valid (h2d) | Wrapper asserts a_valid for exactly the one cycle both PSEL and PENABLE are high; tl_o.a_ready from aon_timer must be high in that same cycle, or the wrapper holds PREADY low and extends the Access phase by one cycle. |
| PWRITE | a_opcode (h2d) | PWRITE=0 -\> Get. PWRITE=1 -\> PutFullData if PSTRB=4'b1111, else PutPartialData. |
| PADDR\[5:0\] | a_address\[5:0\] (h2d) | Only the low 6 bits matter (aon_timer_reg_top parameter RegAw=6). The Peripheral Bus per-master decoder has already subtracted the base offset before this port sees the address (see the companion Peripheral Bus specification), so the wrapper performs no further address decoding. |
| PWDATA\[31:0\] | a_data\[31:0\] (h2d) | Direct passthrough; both sides are 32-bit. |
| PSTRB\[3:0\] | a_mask\[3:0\] (h2d) | Direct 1:1 byte-lane mapping, same bit order (byte-enable). |
| PRDATA\[31:0\] | d_data\[31:0\] (d2h) | Direct passthrough on the cycle tl_o.d_valid is asserted. |
| PSLVERR | d_error (d2h) | Direct passthrough. |
| PREADY | d_valid (d2h), gates it | Wrapper holds PREADY low until aon_timer asserts d_valid for the outstanding request, then pulses PREADY high for one cycle to close the APB Access phase. |
| (not applicable - fixed word access) | a_size = 2'b10 (h2d) | Constant: this project's APB4 peripherals are always accessed as a single 32-bit word, so no variable-size logic is needed. |
| (not applicable) | a_source (h2d) / d_source (d2h) | Latched to a fixed constant (e.g. all-zero) on each request and simply echoed back unchanged in d_source; no ID-tracking FIFO is needed because only one transaction is ever outstanding (see below). |
| (not applicable) | a_user.cmd_intg / a_user.data_intg (h2d) | Not computed by the wrapper's own FSM logic; generated by instantiating lowRISC's existing tlul_cmd_intg_gen module as the final stage before driving tl_i (see Bus-Integrity Requirement below). |

Both sides of this bridge are single-outstanding protocols: APB accepts one Setup/Access transaction at a time, and aon_timer's TL-UL device port (via tlul_adapter_reg, instantiated inside aon_timer_reg_top) never asserts tl_o.a_ready for a new request while a previous one is still awaiting its response (signal outstanding_q in tlul_adapter_reg.sv). Neither side ever has more than one transaction in flight, so - unlike the axi_to_axi_lite bridge documented in the companion AXI2APB Bridge specification, which must split AXI4 bursts and track multiple in-flight IDs through a FIFO - this wrapper needs no burst-splitting logic and no ID-tracking FIFO. Its core logic is a small 2-3 state FSM of the same shape as the APB master FSM already used in axi_lite_to_apb.sv.

### Bus-Integrity Requirement (Not Optional)

aon_timer_reg_top unconditionally instantiates tlul_cmd_intg_chk on every incoming request (this instantiation is not gated by any parameter). If the wrapper drives tl_i with a_user.cmd_intg / a_user.data_intg fields that do not match the SECDED-based encoding TL-UL requires, every transaction will be flagged as a bus-integrity fault. This is not a transactional error: the fault latches permanently until the next reset and drives the IP's fatal_fault alert (countermeasure AON_TIMER.BUS.INTEGRITY, alert_tx_o), the same hardware security-alert path used elsewhere in the chip's alert-handler infrastructure. The wrapper must not compute this encoding by hand: lowRISC already provides the module for it, tlul_cmd_intg_gen (hw/ip/tlul/rtl/tlul_cmd_intg_gen.sv, Apache License 2.0) - a purely combinational module that takes a TL-UL request with placeholder integrity fields and returns the same request with correctly computed cmd_intg / data_intg fields, using the prim_secded_inv_64_57_enc / prim_secded_inv_39_32_enc primitives already vendored into this project's OpenTitan sources. The wrapper's FSM only needs to build the plain request fields from the APB signals and pass the result through this one existing module before presenting it on tl_i; no equivalent check is needed on the return path, since APB itself has no bus-integrity concept and the wrapper only reads d_data / d_error / d_opcode from the response.

### Clocking Note

aon_timer's own integration guidance requires its always-on clock (clk_aon_i) to be started before its main clock (clk_i). This is a system-level reset/clock-sequencing requirement on the SoC's clock and reset manager, not a property of the wrapper's protocol logic, but it must be respected wherever the wrapper and aon_timer are instantiated together.

## Register Map

aon_timer exposes 14 software-visible registers on its TL-UL bus interface. Table below lists offset, access type, reset value and description for each register, taken from the IP's official register documentation (doc/registers.md, auto-generated from data/aon_timer.hjson).

| Offset | Register | Access | Reset | Description |
|----|----|----|----|----|
| 0x00 | ALERT_TEST | WO | 0x0 | Alert Test - write 1 to bit\[0\] (fatal_fault) to trigger a test alert. |
| 0x04 | WKUP_CTRL | RW | 0x0 | Wakeup Timer Control - bit\[0\] enable, bits\[12:1\] prescaler. Each write resets the internal prescaler count. |
| 0x08 | WKUP_THOLD_HI | RW | 0x0 | Wakeup Timer Threshold, bits \[63:32\]. |
| 0x0c | WKUP_THOLD_LO | RW | 0x0 | Wakeup Timer Threshold, bits \[31:0\]. |
| 0x10 | WKUP_COUNT_HI | RW | 0x0 | Wakeup Timer Count, bits \[63:32\]. |
| 0x14 | WKUP_COUNT_LO | RW | 0x0 | Wakeup Timer Count, bits \[31:0\]. |
| 0x18 | WDOG_REGWEN | RW0C | 0x1 | Watchdog Write-Enable - clearing bit\[0\] locks WDOG_CTRL/BARK/BITE until next reset. |
| 0x1c | WDOG_CTRL | RW (gated by REGWEN) | 0x0 | Watchdog Control - bit\[0\] enable, bit\[1\] pause_in_sleep. |
| 0x20 | WDOG_BARK_THOLD | RW (gated) | 0x0 | Watchdog Bark Threshold - count at which the early-warning interrupt/NMI fires. |
| 0x24 | WDOG_BITE_THOLD | RW (gated) | 0x0 | Watchdog Bite Threshold - count at which aon_timer_rst_req_o (hardware reset) fires. |
| 0x28 | WDOG_COUNT | RW | 0x0 | Watchdog Counter - current count; write 0 to "pet" (feed) the watchdog. |
| 0x2c | INTR_STATE | RW1C | 0x0 | Interrupt State - bit\[0\] wkup_timer_expired, bit\[1\] wdog_timer_bark; write 1 to clear. |
| 0x30 | INTR_TEST | WO | x | Interrupt Test - write 1 to force the corresponding interrupt for test purposes. |
| 0x34 | WKUP_CAUSE | RW0C | 0x0 | Wakeup Cause - bit\[0\] set when this timer requested a wakeup; write 0 to clear. |

Table. AON Timer register map (source: lowRISC/opentitan doc/registers.md)

## Block Diagram

*[figure not reproduced]*


## Acronyms

| Acronym | Description |
|----|----|
| WDT | Watchdog Timer |
| AON | Always-On (clock/power domain that stays active during low-power modes) |
| TL-UL | TileLink Uncached Lightweight (bus protocol) |
| NMI | Non-Maskable Interrupt |
| PLIC | Platform-Level Interrupt Controller |
| RACL | Role-based Access Control List |
| CDC | Clock-Domain Crossing |
| SECDED | Single Error Correction, Double Error Detection (ECC code used for TL-UL bus integrity) |

## First Review

| Acronyms | Reviewer | Response |
|----------|----------|----------|
|          |          |          |
|          |          |          |

Record of ChangesThis table provides the following information about each change to this document: Version Number Date Author/Owner Description of Change
