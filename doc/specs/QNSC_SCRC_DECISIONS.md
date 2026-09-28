# QNSC_SCRC — design decisions and record

**This is not the specification.** That is [`QNSC_SCRC_MAS.md`](QNSC_SCRC_MAS.md).

This file holds what the specification leaves out: why V3.0 differs from V2.3,
why the design departs from the HAS, the pseudo-assembly of the CRM ROM program,
and the V2.3 document by Nguyen Hao Nam, kept whole below. Nothing was removed
from the specification without being kept here first.

The V2.3 figures are in Nam's `SCRC_NguyenHaoNam.docx` and are not reproduced:
they were in colour and several had drifted from the text (listed below). The
mentor's reference diagram is `doc/reference/VLSI_SCRC.drawio`.

---

# 1. V2.3 to V3.0

V3.0 is a move onto the MAS template by the lead. The design is V2.3's; the
changes are names, structure, and the gaps a reviewer or DV would hit.

| Change | Why |
|---|---|
| `APB_S0`, `APB_S1` renamed `APB_M0`, `APB_M1` | The contract calls the `P_BUS` subordinate ports `APB_Mn`. Its header lists "APB_M11 against APB_S11" as a defect the project has already paid for |
| Ports and modules renamed: `m_scrc_*` to `m_qnsc_scrc_*`; `o_rst_<d>_n` to `o_rst_n_<d>`; `uart0` to `uart_0`; `i_clkin`/`i_porstn` to `i_clk_pad`/`i_rst_n_pad`; `i_cpu_hold` to `i_dbg_cpu_hold`; `i_apb_busy`/`o_apb_blk` to `i_guard_busy`/`o_guard_blk`; `o_rst_por_n` to `o_rst_n_por`; `o_prdata` to `o_bus_apb_prdata` | Naming Rule 1.2--1.5 and 2.1, checked by `flow/lint/naming_check.py`. V2.3 said "each integrator renames at their own wrapper boundary", which the rule does not allow. `i_int_*` is the interrupt prefix, so `i_int_clkin` would read as an interrupt. The `SYSDBG` port is `o_dbg_cpu_hold` (`QNSC_SYSDBG_MAS` 5) |
| Figure 1-1 (old system diagram) dropped | It showed `GPIO3`, AXI2APB on `AXI_M2` and no `DSRAM` or `INTMAP`. The current chip diagram is `doc/figures/img/fig_qsoc_full_mono.png` |
| Clock-tree and reset-tree figures dropped | They restated Table 6-2 and the reset table as 19 boxes each. The clock-tree figure also drew double-headed wires that read as CPU connected to UART1 |
| Block diagram redrawn after the mentor's layout, plus `RRC`, write filters, `busy`, `APB_BLK` and the CPU hold | V2.3 Figure 3-1 had no write filters (added V2.2), no `busy` (V2.1), no hold input, and drew `SYSDBG` outside the always-on group |
| RRC figure: "WDT request is combinational" removed | V2.2 had already found it is a sticky flip-flop in `aon_timer.sv` |
| Reset Filter drawn from the mentor's diagram | V2.3 described it in words only |
| Register access columns per master; masks stated | Template access types; DV generates access tests from them |
| `PSLVERR` sources as one table | V2.3 spread them over three paragraphs |
| `timer_1` status after boot stated, `SCRC_RST_008` | It is gated with `RST_REL[4]` = 1, so its synchroniser never releases; `DOMAIN_RST_STATUS[4]` reads 1. A DV engineer would file it as a bug |
| `RRC` reset values on power-on stated | V2.3 claimed 16 cycles for POR as well without saying what makes it so |
| "20 MHz, to be confirmed against the PDK" removed | Fixed in the contract, `meta.clock_mhz` |
| Tie-offs of other IPs removed (Ibex scan, GPIO `dft_cg_enable_i`, SPI device scan, TIMER `ref_clk_i`, PWM `low_speed_clk_i`) | They are those IPs' ports, and TIMER and PWM already carry theirs. The WDT one stays, as a requirement, because `RRC` depends on it |
| Section 6.4 (SYSCSR), 7.7 (debug hold) cut to references | Owned by `SYSCSR` and `QNSC_SYSDBG_MAS` |
| Open items added: generator name clash, library cells, CRM ROM depth, IO MUX domain | Found in review, below |
| Timing diagrams added: RRC, power-up, clock gating, APB guard | The mentor asks the owner to present from the figures; a sequence is read from a waveform, not from a numbered list |
| Sub-block table restored, with module, clock and reset per block | V2.3 Table 3-1 carried it; it is what a reviewer reads next to the top diagram |
| Domain figure and table "what each output drives" | The clock-tree and reset-tree figures are replaced by one figure of the 18 domains and their bits, and a table of which wrapper port each pair reaches |
| Firmware sequences as one table (7.10) | V2.3 section 8 was prose; "done when" is what a driver polls |
| `RRC` POR behaviour: `CNT` resets to 15, flip-flop to 0 | V2.3 claimed a 16-cycle reset for POR too without saying what makes it so. This is one way; the other is no stretch after POR, and `SCRC_RST_001` changes with it. **Owner to confirm** |
| Guard reset `o_rst_n_pbus` | V2.3 gave the guard a clock only. **Owner to confirm** |
| `SW_RST` write "completes before the reset"; response may not reach Ibex | V2.3 implied Ibex sees the response; it is reset two cycles later, with the response still in AXI2APB |
| Data synchroniser `m_qnsc_scrc_sync` named | The mentor's diagram has a 2-FF data synchroniser separate from RST SYNC; `RRC` uses it on `i_wdt_rst_req` |
| `spi_device` domain removed; bit 13 reserved; 18 domains, 12 gateable; masks `0x0003_87FC`, `0x8003_9FFF`, `CLK_EN` reset `0x0003_87EC` | The SPI MAS (Hieu, V1.3, section 5) feeds SPI Host and SPI Device from one `PCLK`/`PRESETn`, so a second domain had no wire to drive. It also removes the shared-guard OR and the two-bit `busy`. Cost: SPI Host and SPI Device are gated together |
| `o_cause_we_*` held for the whole chip reset instead of a one-cycle pulse | Found writing `QNSC_SYSCSR_MAS` V3.0: the generated `w1c` field gives an APB write priority over the hardware set in the same cycle, so a firmware clear meeting the pulse would lose the cause. Held as a level, the later cycles set the bit while `P_BUS` is in reset. Costs nothing: `CAUSE` is already a flip-flop |
| Per-peripheral soft reset removed: `SOFT_RST_CTRL` (`0x08`) reserved, soft-reset sequences, `SCRC_RST_006` and the firmware rows deleted; reset-tree figure added | The mentor's later lesson: hang handling has two levels only, reset of the rest and reset of the CPU, because no IP can report that it is hung. A dead IP is seen by the CPU as a bus error, which is a different matter from reset. QSOC maps this to the chip reset (watchdog bite or `SW_RST`) and the `SYSDBG` CPU hold. Removing it also removes the DMA hazard: resetting an AXI master mid-burst would leave `S_BUS` with an unfinished transaction |
| `wdt` made always-on: bit 2 no longer in `CLK_EN`/`ICG_EN`/`APB_BLK`; 11 guards; `CLK_EN` reset `0x0003_87E8`, gateable mask `0x0003_87F8`; contract puts `wdt` in a cluster of its own, `wdt`, not gateable (PR #36) | The mentor: the watchdog supervises the whole chip. Gateable, a runaway firmware could stop it by writing `CLK_EN[2]` = 0, bypassing `aon_timer`'s own `WDOG_REGWEN` lock. Reverses V2.1 "WDT stays gateable". Checked in `aon_timer_core.sv`: two thresholds, bark (`nmi_wdog_timer_bark_o`, to `INTMAP` and `irq_nm_i`) and bite (`aon_timer_rst_req_o`, to `RRC`), as the mentor's two-timeout rule requires |
| Upstream facts re-read at the pinned commits | MRV: 13 instructions in `docs/MRV-CPU-SPEC.md`, BIU IDLE/SETUP/ACCESS/DONE. CSR generator: `PSLVERR` = `PADDR[1:0]` != 0 or partial-strobe write, `CSR_Generation.py` line 234 |

## Found in review, not in V2.3

- **APB-BUS-Generator name clash.** `apb_bus_generator.py` writes the top as
  `m_vlsi_apb_router` and the leaves as `m_vlsi_decoder_<name>`,
  `m_vlsi_arbiter_<name>` with no option to change it. `P_BUS` is generated by the
  same tool, so the SCRC internal bus and `P_BUS` would be two different modules
  with one name. `vendor/manifest.yml` still describes the V1.x plan, "MRV-CPU and
  AXI2APB share P_BUS"; V2.0 moved `MCPU` onto a private bus.
- **`MCPU` has no `PSTRB`, `PPROT` or `PSLVERR`.** Its strobe must be tied `4'hF`
  or the CSR's partial-strobe check rejects every `MCPU` write; a dropped `MCPU`
  write is silent.
- **Library cells cannot be inferred.** `flow/syn/run_syn.sh` fails on any latch;
  the ICG is latch-based and the filter flip-flop has asynchronous set and clear.
  They have to be instantiated cells, which needs the SMIC 28 nm cell names, and
  a behavioural model for Verilator.

# 2. Where the design departs from the HAS

**Software reset resets the CPU too.** The HAS keeps the CPU alive "to observe the
result". V1.2 aligned with the Day005 review on one `SW_RST` bit that resets the
whole chip, and firmware already learns the cause from `RESET_CAUSE` after the
restart. A reset that spares the CPU would need a second release path for the CPU
alone.

**The sources are latched, not ORed.** `aon_timer` clears its bite request with
the WDT reset, and `SW_RST` is cleared by the chip reset. ORed directly into the
reset tree, either would produce a pulse of a few nanoseconds that no domain
synchroniser can rely on. `RRC` breaks the loop by latching the request, driving
the reset from a flip-flop and being reset by POR only; 16 cycles cover the two a
domain synchroniser needs plus the time for the request to drop.

**Polling, not an interrupt.** The MRV interrupt is a one-cycle edge that replaces
the current instruction with `jalr x1, INT_VECTOR(x0)`, with no masking and no
`mret`. An edge during a BIU stall is lost while `x1` is still overwritten, and a
second Ibex write during the handler loops forever. The HAS answer is a firmware
rule ("do not write back to back"); polling a desired-state register removes the
rule and needs no MRV change.

**The guard follows `APB_BLK`, not `CLK_EN`.** `CLK_EN` is what Ibex wants, not
what the hardware is. A guard that followed it would open before the clock had
started and close after the clock had already stopped. `APB_BLK` is written by
`MCPU` in the order the invariant needs, and the guard sits at the top so no
wrapper and no generated `P_BUS` RTL changes.

# 3. CRM ROM program

Pseudo-assembly of the power-up program (V2.3 section 7.2). Constants are built
with `lui` + `ori`; cycle counts are to be tuned in simulation.

```
RESET_VECTOR:                      ; 0x1000, s0 = 0 (SCRC CSR base on the internal bus)
  lw   t0, CLK_EN(s0)
  sw   t0, ICG_EN(s0)              ; step 1; the sw itself takes >= 3 cycles (step 2)
  lui/ori t1, 0x0003_9FFF          ; every domain except the CPU; bits 13, 14 reserved
  sw   t1, RST_REL(s0)             ; step 3
  addi t2, x0, WAIT16
W16:
  addi t2, t2, -1                  ; step 4
  beq  t2, x0, REL_CPU
  jal  x0, W16
REL_CPU:
  addi t3, x0, -1                  ; 0xFFFF_FFFF
  sub  t3, t3, t0                  ; NOT CLK_EN (no xor in MRV)
  lui/ori t4, 0x0003_87FC          ; gateable mask
  and  t3, t3, t4
  sw   t3, APB_BLK(s0)             ; step 5: guards open first
  lui/ori t1, 0x8003_9FFF
  sw   t1, RST_REL(s0)             ; step 6: CPU released last
  add  s1, t0, x0                  ; applied CLK_EN
IDLE:
  lw   t0, CLK_EN(s0)
  beq  t0, s1, IDLE
GATE:                              ; off = s1 & ~t0, on = t0 & ~s1; stop, start; s1 = t0
  jal  x0, IDLE
```

`NOT x` is `(-1) - x` because MRV has no `xor`.

# 4. Proposals under review

Raised by the lead on 2026-09-28, not yet accepted. The specification describes
the V2.3 design until the SCRC owner decides.

**Two CSRs instead of one CSR behind a 2-master bus.** Today one `SCRC CSR` has two
masters, Ibex and `MCPU`, so it needs an arbiter (the generated APB BUS) and a
write filter per master, because the generator cannot tell the masters apart.
Splitting it gives each master its own register block, wired directly:

| Block | Master | Writable | Read-only (wired from the other block) |
|---|---|---|---|
| `CSR_I` | Ibex, `APB_M0` | `SW_RST`, `CLK_EN` | `ICG_EN`, `RST_REL`, `APB_BLK`, `APB_BUSY` |
| `CSR_M` | `MCPU` | `ICG_EN`, `RST_REL`, `APB_BLK` | `CLK_EN`, `APB_BUSY` |

A generator `ro` field is a live input with no write logic (`CSR_Generation.py`,
`gen_port_logic`), so the access rights hold by construction. Offsets and reset
values seen by Ibex do not change. Removed: APB BUS, two WFs, the name clash with
`P_BUS`, the arbitration. Changed: a wrong-side write is ignored, not answered with
`PSLVERR` (`SCRC_CSR_001`); `vendor/manifest.yml` drops `design/scrc` from
APB-BUS-Generator. The mentor's `VLSI_SCRC.drawio` draws an APB BUS with "APB
Decoder Generator", so the mentor may want the generator used; ask before
adopting.

**No stretch after POR.** The stretch exists because a WDT or SW request is cleared
by the reset it causes. After POR nothing needs it: when `w_rst_n_sys` releases,
only `MCPU` and its registers leave reset, and every domain is still held by
`RST_REL` = 0 until the power-up program releases it. With every `RRC` flip-flop
reset to 0 the counter needs no special reset value and `SCRC_RST_001` covers WDT
and SW only. The CPU starts about 16 cycles earlier after POR; `o_dbg_cpu_hold`
still falls about 5 cycles after POR, well before the >= 30-cycle power-up
program releases the CPU. Booting Flow Table 4-1 row 1 would drop "POR" from the
16-cycle sentence.

Checked against every other specification and the contract: none depends on the
POR stretch or on `SCRC` answering a wrong-side write with `PSLVERR`.

---

# V2.3 as issued

## Reversion and History

| Version | Date (mm/dd/yyyy) | Author | Reviewer | Description of Change |
|:---|:---|:---|:---|:---|
| V1.0 | 09/16/2026 | Nguyen Hao Nam | \- | Initial clock manager and reset manager architecture (hardwired, single frequency, no PLL/Flash). |
| V1.1 | 09/20/2026 | Nguyen Hao Nam | Nguyen Hung Quan | Replaced the hardwired manager with the small-MCU model (MRV-CPU + CRM ROM + APB-BUS-Gen + CSR). |
| V1.2 | 09/21/2026 | Nguyen Hao Nam | Nguyen Hung Quan | Aligned with the Day005 review: three reset sources, no external reset pin, no test-mode pin, never-gate domains defined. |
| V1.3 | 09/21/2026 | Nguyen Hao Nam | Nguyen Hung Quan | Bus Error Responder simplified to an immediate PSLVERR with software retry. |
| V1.4 | 09/21/2026 | Nguyen Hao Nam | Nguyen Hung Quan | Removed the Watch-Logic naming; rewritten in English. |
| V1.5 | 09/21/2026 | Nguyen Hao Nam | Huynh Phuoc Truong Sinh | Boot vector ROM base + 0x80; CHIP_ID_REV = 0x51534F43; MRV_BUSY removed. |
| V2.0 | 09/24/2026 | Nguyen Hao Nam | \- | Rewritten on the QNSC document template to match VLSI_SCRC_v2.drawio: MRV-CPU polling (interrupt tied 0); RRC with 16-cycle stretch and POR-only flip-flops; single SCRC CSR with request (SW_RST, CLK_EN, SOFT_RST_CTRL) and execution (ICG_EN, RST_REL, APB_BLK) registers; release all domains together and the CPU last; APB Guard per gateable slave; SYSDBG POR-only reset and always-on clock; CPU hold from SYSDBG; TIMER0/1, UART0/1 and GPIO0–3 as separate domains; 19-bit domain bit map; old D00–D18 domain numbering and SYSCTL naming removed. |
| V2.1 | 09/24/2026 | Nguyen Hao Nam | \- | All open issues closed: APB Guard at the SoC top; fixed 16-cycle wait replaced by the APB_BUSY register (0x18) and guard busy outputs; WDT stays gateable; register offsets final; Reset Filter = 3 DLY cells; debug hold per SYSDBG MAS V3.0 (DBG_EN capture, CPUHOLD); GPIO3 removed (40-pin package), bit 18 reserved, 13 gateable domains; TIMER ref_clk_i = 0, PWM low_speed_clk_i tie-off; PWM safe stop and WDT rules for firmware; figures translated to English. |
| V2.2 | 09/24/2026 | Nguyen Hao Nam | \- | Corrections after reading the generated RTL: access rights enforced by two write filters m_scrc_apb_wfilter (the CSR generator cannot distinguish masters); PSLVERR sources stated exactly (filters for wrong-master writes and 0x1C, router for offsets \>= 0x20, CSR for misaligned or partial-strobe accesses); aon_timer_rst_req_o described as the sticky flip-flop it is; SCRC CSR regenerated. |
| V2.3 | 09/24/2026 | Nguyen Hao Nam | \- | Power-up order fixed: APB_BLK ← ~CLK_EN now precedes RST_REL\[CPU\] ← 1, so the first UART0 access of the boot ROM cannot receive PSLVERR; requirement SCRC_RST_007 added; operation-flow figure updated. |


## Overview

SCRC (System Clock & Reset Controller) is the clock manager and reset manager of QSOC, the single-core RV32IMC (Ibex) training microcontroller of QNSC. It receives the only two dedicated chip-level control pins — the clock input CLKIN and the power-on reset input PORSTN — and generates an independent clock and reset for every IP domain in the chip.

Two project constraints shape the design. QSOC has **no PLL**, so the whole chip runs from the single external clock at one frequency (working default 20 MHz, to be confirmed against the SMIC 28 nm PDK) and SCRC needs no clock divider or frequency switching. QSOC has **no Flash**, so after every reset the boot ROM downloads the application into RAM over UART; SCRC therefore runs the same power-up sequence after every reset, not only after power-on.

SCRC is built around a small controller: a mini RISC-V CPU (MRV-CPU) executes a sequencing program stored in a dedicated ROM (CRM ROM) and drives the clock-enable and reset-release controls of every domain through an internal CSR block (SCRC CSR). Changing the release order or the gating policy only requires a change to the CRM ROM program, not to the RTL. Hardware logic is kept for the functions that must work without software: reset filtering and synchronization, reset-request latching, per-domain clock gating and reset synchronization, and bus-error response for gated peripherals.

The key operating rule is that **Ibex only writes requests** (SW_RST, CLK_EN, SOFT_RST_CTRL) and **MRV-CPU is the only agent that executes them** (ICG_EN, RST_REL, APB_BLK). No field is written by both.

*[Figure 1‑1. QSOC system block diagram — SCRC is APB_S0 and SYSCSR is APB_S1 on P_BUS -- not reproduced, see the note at the top]*

Companion documents: the SYSCSR register specification (RESET_CAUSE, DOMAIN_RST_STATUS, CHIP_ID_REV), the Booting Flow specification (what Ibex does after SCRC releases it) and the ROM specification. The editable source of every SCRC figure in this document is SCRC_ClockReset_Design/VLSI_SCRC_v2.drawio.

## Feature

- Single clock input, single frequency, no PLL, no divider; one root buffer and one clock gate (CG) per domain.

- 19 clock/reset output domains: 6 always-on (CPU, S_BUS, P_BUS, ROM, RAM, SYSDBG) and 13 gateable peripheral domains (UART0, UART1, SPI, SPI_DEV, DMA, WDT, I2C, PWM, TIMER0, TIMER1, GPIO0, GPIO1, GPIO2). GPIO3 no longer exists (40-pin package, GPIO MAS V1.2).

- Three chip-level reset sources: power-on reset (PORSTN), watchdog bite (aon_timer reset request) and software reset (SW_RST, one bit that resets the whole chip). No external reset pin, no debug reset, no test-mode pin.

- Reset Request Controller (RRC): latches the watchdog/software request, stretches the system reset to 16 clock cycles and captures the reset cause for SYSCSR. RRC is reset by power-on reset only.

- Per-domain reset synchronizer: asynchronous assertion, synchronous de-assertion on the domain's own clock.

- Reset release order held in software: all domains are released together, the APB guards are opened, then the CPU is released last (at least 16 cycles later).

- Runtime clock gating of the 13 peripheral domains on request from Ibex (CLK_EN), executed by MRV-CPU with a fixed guard-before-gate sequence.

- Runtime soft reset of each peripheral domain on request from Ibex (SOFT_RST_CTRL, level-sensitive).

- APB Guard (bus-error responder) per gateable APB slave: an access to a gated or soft-reset peripheral completes immediately with PSLVERR, so the bus never hangs.

- Debug support: SYSDBG keeps its reset across watchdog/software resets and can hold the CPU in reset through i_cpu_hold.

- MRV-CPU runs in polling mode (its interrupt input is tied to 0): requests are never lost and back-to-back writes from Ibex need no handshake.

## Block Diagram

Figure 3-1 shows the SCRC top level. The dotted line separates the hardware input stage (top) from the MRV-CPU subsystem and the per-domain controllers (bottom). SYSCSR is drawn for context; it is a separate APB slave on P_BUS and is not part of the SCRC module.

*[Figure 3‑1. SCRC block diagram -- not reproduced, see the note at the top]*

| Block | Function | Clock | Reset |
|:---|:---|:---|:---|
| Reset Filter | Removes glitches and bounce on i_porstn (delay-line filter from library cells). | none (asynchronous) | — |
| Reset Synchronizer | 2-FF synchronizer: asynchronous assertion, synchronous release of the internal power-on reset i_int_porstn. | i_int_clkin | filtered i_porstn |
| RRC | Latches WDT/SW reset requests, stretches o_sys_rst_n to 16 cycles, generates reset-cause write enables and the POR-only reset o_rst_por_n. | i_int_clkin | i_int_porstn (POR only) |
| MRV-CPU (MCPU) | Mini RISC-V CPU that runs the CRM ROM program: power-up sequence, then a polling loop that services Ibex requests. | i_int_clkin | o_sys_rst_n |
| CRM ROM | Instruction memory of MRV-CPU (Harvard, combinational read). | — | — |
| APB BUS | Internal APB interconnect generated by APB-BUS-Generator: master \#1 = MRV-CPU, master \#2 = P_BUS slave port (Ibex), slave = SCRC CSR. | i_int_clkin | o_sys_rst_n |
| SCRC CSR | Control registers generated by APB-CSR-Generator (Section 6). | i_int_clkin | o_sys_rst_n |
| CTRL × 19 | Per-domain controller: clock gate (enable = ICG_EN\[n\] or 1) and reset synchronizer (input = RST_REL\[n\]). | root clock | RST_REL\[n\] |

Table 3‑1. SCRC sub-blocks

The APB Guard (Section 5.7) is designed and delivered with SCRC but is instantiated at the SoC top, between P_BUS and each gateable peripheral wrapper.

## Interface

Port names follow the SCRC convention o_clk\_\<domain\> / o_rst\_\<domain\>\_n; each IP integrator renames at their own wrapper boundary. All reset outputs are active-low. The APB slave port uses APB4 signalling as produced by P_BUS.

| Signal | Width | Source | Description |
|:---|:---|:---|:---|
| i_clkin | 1 | CLKIN pad (dedicated, not muxed) | Root clock of the whole chip. |
| i_porstn | 1 | PORSTN pad (dedicated, not muxed) | Power-on reset, active-low. Filtered and synchronized inside SCRC. |
| i_wdt_rst_req | 1 | WDT (aon_timer_rst_req_o) | Watchdog bite request, active-high. In aon_timer it is a sticky flip-flop cleared only by the WDT reset (aon_timer.sv); RRC synchronizes it (2-FF) because it comes from the WDT clock domain. |
| i_cpu_hold | 1 | SYSDBG (o_cpu_hold) | Holds the CPU in reset while 1 (debug entry). Combined with RST_REL\[CPU\] before the CPU reset synchronizer. |
| i_psel, i_penable, i_pwrite | 1 each | P_BUS (APB_S0) | APB control. |
| i_paddr | 12 | P_BUS | Register offset; offsets 0x00–0x14 are implemented (Section 6). |
| i_pwdata | 32 | P_BUS | Write data. |
| i_pstrb, i_pprot | 4, 3 | P_BUS | APB4 strobe/protection, forwarded to SCRC CSR. |
| i_apb_busy | 18 | APB Guards (SoC top) | Bit n = 1 while the guard of domain n has a transfer in progress; read by MRV-CPU as APB_BUSY (Section 5.7). |

Table 4‑1. SCRC input ports

| Signal | Width | Destination | Description |
|:---|:---|:---|:---|
| o_prdata, o_pready, o_pslverr | 32, 1, 1 | P_BUS | APB response of the SCRC register port. |
| o_clk_cpu, o_rst_cpu_n | 1, 1 | Ibex | Always-on clock. Reset = RST_REL\[CPU\] & ~i_cpu_hold, synchronized; released last. |
| o_clk_sbus, o_rst_sbus_n | 1, 1 | S_BUS and SYSDBG i_rst_n_sysbus | Always-on. |
| o_clk_pbus, o_rst_pbus_n | 1, 1 | P_BUS, SYSCSR (clock), APB Guards (clock) | Always-on. |
| o_clk_rom, o_rst_rom_n | 1, 1 | ROM controller | Always-on. |
| o_clk_ram, o_rst_ram_n | 1, 1 | RAM controller (I-RAM + D-RAM) | Always-on. |
| o_clk_sysdbg, o_rst_sysdbg_por_n | 1, 1 | SYSDBG i_rst_n_por | Always-on clock. Reset is derived from o_rst_por_n (POR only), not from RST_REL. |
| o_clk\_\<p\>, o_rst\_\<p\>\_n | 1, 1 each | Peripheral wrappers | 13 gateable domains, \<p\> = uart0, uart1, spi, spi_device, dma, wdt, i2c, pwm, timer0, timer1, gpio0, gpio1, gpio2. |
| o_apb_blk | 18 | APB Guards (SoC top) | Copy of APB_BLK\[17:0\]; bit n blocks the APB slave of domain n. |
| o_rst_por_n | 1 | SYSCSR i_bus_rstn, SYSDBG | POR-only reset from RRC. SYSCSR must use it so that RESET_CAUSE survives WDT/SW resets. |
| o_cause_we_wdt, o_cause_we_sw | 1, 1 | SYSCSR | One-cycle write enables that set RESET_CAUSE.WDT / RESET_CAUSE.SOFT. |

Table 4‑2. SCRC output ports

DOMAIN_RST_STATUS\[n\] in SYSCSR is driven at the SoC top as the inverse of each o_rst\_\<domain\>\_n; it needs no extra SCRC port.

## Functional Description

### Clock Architecture

i_clkin enters through a dedicated pad and a single root buffer, then fans out to one CTRL per domain. There is no combinational logic on the clock path other than the library clock-gate cell of each CTRL.

- **Always-on group** — CPU, S_BUS, P_BUS, ROM, RAM, SYSDBG and the SCRC internal logic (MRV-CPU, CRM ROM, APB BUS, SCRC CSR, RRC). The clock-gate enable is tied to 1. These clocks can never be stopped: gating the CPU or a bus leaves nothing to restart it, and SYSDBG must keep running for the debugger to stay alive.

- **Gateable group** — the 13 peripheral domains. The clock-gate enable is ICG_EN\[n\], written only by MRV-CPU. After reset every peripheral clock runs except TIMER1 (Section 6.2).

Because every domain derives from the same root, all SCRC outputs are synchronous to each other (skew is closed by clock-tree synthesis). The internal APB BUS and the P_BUS register port therefore need no clock-domain crossing.

*[Figure 5‑1. Clock tree (13 gateable peripheral domains) -- not reproduced, see the note at the top]*

### Reset Input Stage

The Reset Filter follows the mentor's template: three library delay cells (DLY) in series and a set/reset latch. A change on i_porstn is accepted only when it has been stable for the whole chain, so glitches shorter than 3 × t(DLY) are rejected. The window in nanoseconds is simply the delay of the chosen library cell; no other parameter exists. The Reset Synchronizer then produces i_int_porstn, which asserts asynchronously and releases on the second rising edge of i_int_clkin. All cells of this stage (DLY, AND, OR, flip-flops, synchronizer) must be technology-library cells.

### Reset Request Controller (RRC)

RRC merges the three reset sources into the system reset o_sys_rst_n that resets the whole SCRC internal logic (MRV-CPU, APB BUS, SCRC CSR). Every flip-flop in RRC is reset by i_int_porstn only, so a watchdog or software reset can never clear RRC itself.

*[Figure 5‑2. Reset Request Controller -- not reproduced, see the note at the top]*

1.  i_wdt_rst_req is synchronized by a 2-FF synchronizer (wdt_s). i_sw_rst_req comes from the SW_RST bit, which is already synchronous.

2.  req = wdt_s \| sw. When req = 1 and the counter is 0, start is asserted and a 4-bit counter is loaded.

3.  While the counter is non-zero the output flip-flop holds o_sys_rst_n = 0; the counter counts 16 cycles down to 0, then the output releases.

4.  On start, o_cause_we_wdt = start & wdt_s and o_cause_we_sw = start & sw pulse for one cycle to set the matching RESET_CAUSE bit in SYSCSR. The POR bit needs no write: its reset value is 1.

5.  o_rst_por_n (= i_int_porstn) is exported for the blocks that must survive WDT/SW resets: SYSCSR and SYSDBG.

RRC fixes two problems of a direct connection. aon_timer captures the bite condition wdog_incr & (count \>= bite_thold) in a sticky flip-flop that drives aon_timer_rst_req_o and is cleared only by rst_aon_ni, which QSOC ties to o_rst_wdt_n. Used directly as the chip reset, the request would therefore be cleared by the very reset it causes, as soon as that reset reaches the WDT: the result is a reset pulse of a few nanoseconds that no domain synchronizer can rely on. The SW_RST bit has the same problem because the reset it causes clears the bit. Latching the request, stretching the reset from a flip-flop and resetting RRC only from POR removes both the loop and the glitch. Sixteen cycles cover the two cycles each domain synchronizer needs plus margin for the request to drop; the stretch reuses a 4-bit counter.

### MRV-CPU Subsystem

The controller consists of MRV-CPU, CRM ROM, the internal APB BUS and SCRC CSR, all clocked by i_int_clkin and reset by o_sys_rst_n.

- **MRV-CPU** (m_vlsit_mrv_cpu, github.com/nguyenquanicd/MRV-CPU) — single-cycle RV32I subset of 13 instructions (add, sub, and, or, addi, andi, ori, lw, sw, jal, jalr, beq, lui), Harvard architecture. PARA_RESET_VECTOR = 0x1000. The APB master is its BIU; every lw/sw takes at least 3 cycles (SETUP, ACCESS, DONE) and stalls the pipeline until the access completes.

- **Interrupt input tied to 0** — MRV-CPU is used in polling mode only (see Section 9 for the reason). PARA_INT_VECTOR is unused.

- **CRM ROM** — combinational-read program memory holding the power-up sequence and the runtime polling loop (Section 7). The program is a few dozen instructions.

- **APB BUS** — generated with APB-BUS-Generator: master \#1 is MRV-CPU, master \#2 is the P_BUS slave port (APB_S0) through which Ibex reaches the registers, and the single slave is SCRC CSR (window 0x00–0x1F; the router answers PSLVERR above it). Each master path has a write filter m_scrc_apb_wfilter in front of the router that enforces the access rights of Section 6.1.

- **SCRC CSR** — generated with APB-CSR-Generator from the SCRC workbook. It holds both the request registers written by Ibex and the execution registers written by MRV-CPU (Section 6). ICG_EN, RST_REL and APB_BLK are wired directly to the CTRL blocks and APB Guards.

### Domain Controller (CTRL)

Every output domain has one CTRL: a library clock-gate cell followed by a reset synchronizer clocked by the gated clock.

*[Figure 5‑3. Domain controller (CTRL) -- not reproduced, see the note at the top]*

- Clock gate enable: ICG_EN\[n\] for gateable domains, tied to 1 for always-on domains.

- Reset synchronizer input: RST_REL\[n\]. RST_REL resets to 0 on o_sys_rst_n, so every domain asserts its reset asynchronously as soon as a chip reset occurs, and the output comes from a flip-flop, so it is glitch-free.

- Release rule: because the synchronizer runs on the gated clock, ICG_EN\[n\] must be 1 for at least 3 cycles before RST_REL\[n\] is set to 1.

- CPU exception: the synchronizer input is RST_REL\[CPU\] & ~i_cpu_hold, combined before the synchronizer (SYSDBG MAS V3.0: CPU reset = SCRC CPU reset OR o_cpu_hold).

- SYSDBG exception: the synchronizer input is o_rst_por_n, not RST_REL; the clock is always on.

- The synchronizer is a library cell with a scan bypass mux; i_scan_en is tied to 0 (QSOC v1 has no scan).

### Reset Tree

*[Figure 5‑4. Reset tree -- not reproduced, see the note at the top]*

| Domain | Reset input of the synchronizer | Cleared by POR | Cleared by WDT / SW_RST | Soft reset |
|:---|:---|:---|:---|:---|
| SCRC internal (MRV-CPU, APB BUS, SCRC CSR) | o_sys_rst_n | Yes | Yes | No |
| RRC, SYSCSR | i_int_porstn / o_rst_por_n | Yes | No | No |
| SYSDBG | o_rst_por_n | Yes | No (JTAG session survives) | No |
| CPU | RST_REL\[CPU\] & ~i_cpu_hold | Yes | Yes | No |
| S_BUS, P_BUS, ROM, RAM | RST_REL\[n\] | Yes | Yes | No |
| 13 peripheral domains | RST_REL\[n\] | Yes | Yes | Yes (SOFT_RST_CTRL\[n\]) |

Table 5‑1. Reset source of each domain

A peripheral soft reset is not a fourth reset source: it does not pass through RRC and does not update RESET_CAUSE. It only makes MRV-CPU clear RST_REL\[n\] of one domain.

### APB Guard (Bus Error Responder)

An APB access to a peripheral whose clock is stopped would never receive PREADY and would hang Ibex. The APB Guard prevents this. m_scrc_apb_guard is one module, designed and delivered with SCRC, and instantiated once per gateable APB slave in design/top, between the P_BUS slave port and the peripheral wrapper. Placing it at the top keeps every wrapper unchanged and keeps the generated P_BUS RTL unchanged. It runs on o_clk_pbus, which is never gated.

*[Figure 5‑5. APB Guard -- not reproduced, see the note at the top]*

- blk_q samples i_blk = APB_BLK\[n\] in the APB SETUP phase (psel & !penable), so a transfer is never cut in half by a change of APB_BLK.

- If blk_q = 1: PREADY = 1, PSLVERR = 1, PRDATA = 0 in the ACCESS phase and PSEL towards the IP is held at 0.

- Otherwise the guard is a pass-through.

- o_busy = 1 from the SETUP phase of a forwarded transfer until the cycle in which the IP completes it (PENABLE & PREADY). The SoC top connects it to i_apb_busy\[n\] of SCRC.

- The error propagates as P_BUS PSLVERR → AXI2APB SLVERR → Ibex load/store access fault. The P_BUS router already has a PSLVERR input per slave, so the generated P_BUS RTL does not change.

- Guard instances (12): WDT, TIMER0, TIMER1, UART0, UART1, GPIO0, GPIO1, GPIO2, SPI, I2C, PWM and the DMA configuration port. The SPI wrapper contains both SPI host and SPI device behind one APB slave, so its guard uses APB_BLK\[SPI\] \| APB_BLK\[SPI_DEV\] and drives both i_apb_busy\[7\] and i_apb_busy\[13\].

MRV-CPU keeps the invariant APB_BLK\[n\] = ~(clock enabled\[n\] & ~soft reset\[n\]): the guard blocks before a clock stops or a reset asserts and opens only after the clock runs again and the reset is released. Before it stops a clock or asserts a reset, MRV-CPU waits until APB_BUSY\[n\] = 0, i.e. until the last transfer that passed the guard has completed. A fixed wait would not be safe: the pulp APB IPs answer in one cycle, but an IP behind a TL-UL adapter can hold PREADY low for a long time (for example an SPI host FIFO window write while the FIFO is full).

## Register Description

### Register Map

SCRC CSR is reached by Ibex through P_BUS slave APB_S0 at base address **0x8000_0000** (16 KiB window, SoC contract util/qsoc_contract.yml) and by MRV-CPU through the internal APB BUS. Offsets are the same from both masters. All registers are 32-bit; unused and reserved bits read as 0.

| Offset | Register | Ibex | MRV-CPU | Reset value | Description |
|:---|:---|:---|:---|:---|:---|
| 0x00 | SW_RST | RW | R | 0x0000_0000 | Bit 0: write 1 to reset the whole chip. Cleared by the reset it triggers. |
| 0x04 | CLK_EN | RW | R | 0x0003_A7EC | Requested clock state per peripheral domain (1 = on). |
| 0x08 | SOFT_RST_CTRL | RW | R | 0x0000_0000 | Requested soft reset per peripheral domain (1 = hold in reset). Level, not self-clearing. |
| 0x0C | ICG_EN | R | RW | 0x0000_0000 | Clock-gate enable of each gateable domain. |
| 0x10 | RST_REL | R | RW | 0x0000_0000 | Reset release of each domain (1 = released). Bit 31 = CPU. |
| 0x14 | APB_BLK | R | RW | 0x0003_A7FC | APB Guard block of each gateable domain (1 = block). |
| 0x18 | APB_BUSY | R | R | 0x0000_0000 | Transfer in progress through the guard of each gateable domain (hardware input). |

Table 6‑1. SCRC CSR register map

Access rights are enforced in hardware by the two write filters in front of the internal APB BUS: a write from a master to a register it may only read is dropped and answered with PSLVERR, and an access to offset 0x1C (no register) returns PSLVERR. The internal router returns PSLVERR for any offset from 0x20 to the end of the 16 KiB window. SCRC CSR itself (generator option i_slverr_en = 1) returns PSLVERR for a misaligned address or a write with incomplete byte strobes. Decoding uses i_paddr\[11:0\], so any P_BUS address width of 12 bits or more works.

### Domain Bit Map

One bit map is shared by CLK_EN, SOFT_RST_CTRL, ICG_EN, RST_REL, APB_BLK and SYSCSR DOMAIN_RST_STATUS. Bits 0–13 keep the positions of the earlier SYSCSR specification; bits 14–17 were added in v2.0. Bit 18 is reserved: it was GPIO3, which was removed with the 40-pin package. Bits of always-on domains are reserved in CLK_EN, SOFT_RST_CTRL, ICG_EN and APB_BLK.

| Bit | Domain | Type | CLK_EN reset | SOFT_RST_CTRL | RST_REL | APB_BLK reset |
|:---|:---|:---|:---|:---|:---|:---|
| 0 | S_BUS | always-on | reserved | reserved | yes | reserved |
| 1 | P_BUS | always-on | reserved | reserved | yes | reserved |
| 2 | WDT | gateable | 1 | yes | yes | 1 |
| 3 | TIMER0 | gateable | 1 | yes | yes | 1 |
| 4 | TIMER1 | gateable | **0** | yes | yes | 1 |
| 5 | UART0 | gateable | 1 | yes | yes | 1 |
| 6 | UART1 | gateable | 1 | yes | yes | 1 |
| 7 | SPI (host) | gateable | 1 | yes | yes | 1 |
| 8 | I2C | gateable | 1 | yes | yes | 1 |
| 9 | GPIO0 | gateable | 1 | yes | yes | 1 |
| 10 | DMA | gateable | 1 | yes | yes | 1 |
| 11 | ROM | always-on | reserved | reserved | yes | reserved |
| 12 | RAM | always-on | reserved | reserved | yes | reserved |
| 13 | SPI_DEV | gateable | 1 | yes | yes | 1 |
| 14 | SYSDBG | always-on | reserved | reserved | reserved (POR only) | reserved |
| 15 | PWM | gateable | 1 | yes | yes | 1 |
| 16 | GPIO1 | gateable | 1 | yes | yes | 1 |
| 17 | GPIO2 | gateable | 1 | yes | yes | 1 |
| 30:18 | — | — | reserved | reserved | reserved | reserved |
| 31 | CPU | always-on | reserved | reserved | yes | reserved |

Table 6‑2. Domain bit map

TIMER0 runs after reset because it is the software timebase and must count before firmware first reads it. TIMER1 starts gated to save power; firmware enables it when needed.

### Register Fields

**SW_RST (0x00)**

Bit 0 sw_rst (RW, Ibex): writing 1 requests a chip reset through RRC, with the same effect as a watchdog bite and cause RESET_CAUSE.SOFT. The bit needs no self-clear logic: the resulting o_sys_rst_n resets SCRC CSR and returns it to 0. Bits 31:1 are reserved.

**CLK_EN (0x04)**

Bits 17:0 (RW, Ibex): desired clock state of each gateable domain, 1 = clock on. MRV-CPU polls this register and applies changes with the gating sequence (Section 7.4). Only the last value written matters, so Ibex may write it any number of times without waiting. Reserved bits read 0 and ignore writes.

**SOFT_RST_CTRL (0x08)**

Bits 17:0 (RW, Ibex): desired soft-reset state of each peripheral domain, 1 = hold in reset, 0 = release. Level-sensitive and not self-clearing, so a polling controller can never miss a request. MRV-CPU applies changes with the soft-reset sequence (Section 7.5). Firmware writes 1, waits for DOMAIN_RST_STATUS\[n\] = 1, writes 0 and waits for DOMAIN_RST_STATUS\[n\] = 0. CLK_EN\[n\] must be 1 before the release is written, because the reset synchronizer needs a running clock to release.

**ICG_EN (0x0C)**

Bits 17:0 (RW, MRV-CPU; R, Ibex): clock-gate enable driven to i_clkin_en of each gateable CTRL. Reset value 0; the power-up program loads it from CLK_EN.

**RST_REL (0x10)**

Bits 17:0 and bit 31 (RW, MRV-CPU; R, Ibex): reset release driven to the reset synchronizer input of each CTRL (bit 31 = CPU, bit 14 reserved because SYSDBG uses the POR-only reset). Reset value 0, so a chip reset asserts every domain reset.

**APB_BLK (0x14)**

Bits 17:0 (RW, MRV-CPU; R, Ibex): block control of each APB Guard, exported as o_apb_blk. Reset value 1 for every gateable domain, so no peripheral can be accessed before the power-up program has enabled its clock and released its reset.

**APB_BUSY (0x18)**

Bits 17:0 (R, both masters): live value of i_apb_busy, 1 while a transfer that passed the guard of domain n is still in progress. MRV-CPU waits for 0 before it stops the clock or asserts the reset of that domain. Always-on bits read 0.

### Related Status Registers (SYSCSR)

Status is kept in SYSCSR, a separate APB slave (APB_S1, base 0x8000_4000) specified in the SYSCSR register specification: RESET_CAUSE (POR/WDT/SOFT, sticky, W1C, reset only by o_rst_por_n), DOMAIN_RST_STATUS (1 = domain held in reset, same bit map as Table 6-2, bit 31 = CPU) and CHIP_ID_REV (0x51534F43, 'QSOC').

## Operation

Figure 7-1 summarises the complete behaviour: the chip reset, the power-up sequence, and the runtime polling loop with its gating and soft-reset branches.

*[Figure 7‑1. SCRC operation flow -- not reproduced, see the note at the top]*

### Chip Reset

1.  A reset source occurs: POR, a watchdog bite, or Ibex writing SW_RST = 1.

2.  RRC drives o_sys_rst_n = 0 for 16 cycles and records the cause in SYSCSR (WDT/SW via o_cause_we\_\*; POR by reset value).

3.  SCRC CSR returns to its reset values: RST_REL = 0, ICG_EN = 0, APB_BLK = all gateable bits 1, SOFT_RST_CTRL = 0, CLK_EN = default.

4.  Because RST_REL = 0, every domain reset — including the CPU — asserts asynchronously. SYSDBG is not affected by WDT/SW resets; only its bus side (i_rst_n_sysbus = o_rst_sbus_n) is reset with S_BUS, so no half-finished bus handshake remains.

### Power-up Sequence

When o_sys_rst_n releases, MRV-CPU starts at RESET_VECTOR (0x1000). The same program runs after every chip reset.

1.  ICG_EN ← CLK_EN — start the clocks of every peripheral whose default is on (all except TIMER1).

2.  Wait at least 3 cycles, so every enabled clock reaches its reset synchronizer.

3.  RST_REL ← all domains except the CPU — every domain is released at the same time.

4.  Wait 16 cycles (an addi/beq loop).

5.  APB_BLK ← ~CLK_EN — open the guards of the running peripherals (TIMER1 stays blocked).

6.  RST_REL\[CPU\] ← 1 — the CPU is released last. Ibex needs 2 more clk_i cycles before its first instr_req_o and fetches from {boot_addr_i\[31:8\], 8'h80} = ROM base + 0x80. Initialise x_cur ← CLK_EN and x_rst ← 0, then enter the polling loop.

Releasing all domains together keeps the sequence simple: there is no known dependency that requires ROM or RAM to be released before other domains. The only ordering that matters is that the CPU, the only master that starts on its own, begins after its buses and memories are out of reset. The order lives in CRM ROM, so changing it needs no RTL change. With no PLL there is no lock time to wait for.

The guards are opened **before** the CPU is released (step 5 before step 6). The boot ROM programs UART0 within its first instructions; if the guard of UART0 were still closed at that moment, the access would receive PSLVERR, Ibex would take a store access fault and the boot ROM would stop in its trap handler. Opening the guards first removes this race: when Ibex fetches its first instruction, every peripheral that is enabled by default is already clocked, out of reset and reachable.

Pseudo-assembly of the power-up program (constants such as ALL_BUT_CPU are built with lui + ori; cycle counts are to be tuned in simulation):

> RESET_VECTOR: ; 0x1000
>
> lw t0, CLK_EN(s0) ; s0 = SCRC CSR base
>
> sw t0, ICG_EN(s0) ; step 1
>
> ; wait \>= 3 cycles ; step 2 (the sw above already takes 3)
>
> lui/ori t1, ALL_BUT_CPU ; bits 17:0 without 14
>
> sw t1, RST_REL(s0) ; step 3
>
> addi t2, x0, WAIT16
>
> W16: addi t2, t2, -1 ; step 4
>
> beq t2, x0, REL_CPU
>
> jal x0, W16
>
> REL_CPU:
>
> addi t3, x0, -1 ; t3 = 0xFFFF_FFFF
>
> sub t3, t3, t0 ; ~CLK_EN (no xor in MRV-CPU)
>
> lui/ori t4, MASK_GATEABLE ; gateable bits 0x0003_A7FC
>
> and t3, t3, t4
>
> sw t3, APB_BLK(s0) ; step 5: guards open first
>
> lui/ori t1, ALL_WITH_CPU ; add bit 31
>
> sw t1, RST_REL(s0) ; step 6: CPU released last
>
> add s1, t0, x0 ; x_cur = CLK_EN
>
> add s2, x0, x0 ; x_rst = 0

### Runtime Polling Loop

After power-up MRV-CPU stays in a polling loop. It keeps two state registers: x_cur, the CLK_EN value already applied, and x_rst, the SOFT_RST_CTRL value already applied. A change of CLK_EN is served first; a change of SOFT_RST_CTRL is served on the next pass.

> IDLE: lw t0, CLK_EN(s0)
>
> lw t1, SOFT_RST_CTRL(s0)
>
> beq t0, s1, CHKR ; CLK_EN unchanged
>
> jal x0, GATE
>
> CHKR: beq t1, s2, IDLE ; nothing to do
>
> jal x0, SRST
>
> GATE: ; gating sequence (7.4), then s1 = t0 ; jal x0, IDLE
>
> SRST: ; soft-reset sequence (7.5), then s2 = t1 ; jal x0, IDLE

### Clock Gating Sequence

With off = x_cur & ~t0 (domains to stop) and on = t0 & ~x_cur (domains to start):

- **Stop**: APB_BLK \|= off → wait until (APB_BUSY & off) = 0, so the last transfer that passed the guard finishes on the running clock → ICG_EN &= ~off.

- **Start**: ICG_EN \|= on → wait 3 cycles → APB_BLK &= ~(on & ~x_rst) (a domain that is still in soft reset stays blocked).

- x_cur ← t0.

### Peripheral Soft-reset Sequence

With asrt = t1 & ~x_rst (domains to put in reset) and rel = x_rst & ~t1 (domains to release):

- **Assert**: APB_BLK \|= asrt → wait until (APB_BUSY & asrt) = 0 → RST_REL &= ~asrt.

- **Release**: RST_REL \|= rel → wait 3 cycles → APB_BLK &= ~(rel & x_cur) (a domain whose clock is off stays blocked).

- x_rst ← t1.

Asserting the soft reset of a gated domain takes effect immediately because reset assertion is asynchronous. The release of a gated domain completes only when its clock runs again, because the synchronizer needs clock edges.

### Access to a Blocked Peripheral

If Ibex accesses a peripheral that is gated or in soft reset, the APB Guard answers with PSLVERR, Ibex takes a load/store access fault, and the handler (or the application) writes CLK_EN\[n\] = 1 or SOFT_RST_CTRL\[n\] = 0 and retries the access. There is no automatic clock restart and no hardware retry.

A soft reset cannot recover a peripheral that hangs the bus itself (its PREADY never rises while it is unblocked): Ibex stalls in that access and cannot write any register. That case is recovered by the watchdog.

### Debug Hold

SYSDBG (MAS V3.0, 7.1) captures the DBG_EN pin once, SyncStages + 1 = 3 cycles after its POR-only reset releases. Its o_cpu_hold is a flip-flop output with reset value 1 and follows !captured \| (DBG_EN & CPUHOLD):

- **Normal boot (\`DBG_EN = 0\`)** — o_cpu_hold falls to 0 three cycles after POR, long before MRV-CPU releases the CPU (16 RRC cycles plus the power-up program), so the normal release order is not delayed.

- **Debug boot (\`DBG_EN = 1\`)** — o_cpu_hold stays 1 until the host clears CPUHOLD over JTAG. SCRC releases every other domain as usual, so the host can load the debug window and the image into ISRAM; the CPU then starts at 0x2000_1080 (the CPU owner muxes boot_addr_i with o_dbg_en).

- o_cpu_hold only holds the CPU: it is not a reset source and sets no RESET_CAUSE bit. Because SYSDBG is reset by POR only, the captured mode and the hold survive watchdog and software resets.

### Timing Summary

| Parameter | Value | Reason |
|:---|:---|:---|
| System reset stretch (RRC) | 16 cycles | ≥ 2 cycles per domain synchronizer plus margin for WDT/SW request to drop; 4-bit counter. |
| Domain reset release after async source | 2 cycles of the domain clock | 2-FF reset synchronizer. |
| Clock enable before reset release | ≥ 3 cycles | Synchronizer runs on the gated clock. |
| Other domains released → CPU released | ≥ 16 cycles | Buses and memories settle before the first fetch; the APB_BLK write (a few cycles) sits between the wait and the CPU release. |
| CPU reset release → first fetch | 2 cycles | Ibex internal (clock-gate latch, RESET → BOOT_SET). |
| APB_BLK set → clock stopped / reset asserted | until APB_BUSY\[n\] = 0 | The last transfer through the guard completes on the running clock; no fixed bound is assumed. |
| Clock started / reset released → APB_BLK cleared | 3 cycles | Clock and synchronizer settle before access. |
| MRV-CPU APB access | ≥ 3 cycles | BIU SETUP, ACCESS, DONE. |

Table 7‑1. SCRC timing parameters

## Software Programming Guidelines

- Write only SW_RST, CLK_EN and SOFT_RST_CTRL. ICG_EN, RST_REL and APB_BLK are read-only for Ibex and show the state MRV-CPU has applied.

- CLK_EN and SOFT_RST_CTRL may be written back-to-back; only the last value matters. To know that a request has been applied, poll ICG_EN (clock) or DOMAIN_RST_STATUS (reset).

- Before stopping a peripheral clock, clear or mask that peripheral's pending interrupts; SCRC does not touch interrupts.

- Before stopping or soft-resetting DMA, make sure the DMA is idle; the guard protects only the DMA configuration port, not transfers already issued on S_BUS.

- Enable the clock (CLK_EN\[n\] = 1) before releasing a soft reset (SOFT_RST_CTRL\[n\] = 0); otherwise DOMAIN_RST_STATUS\[n\] never returns to 0.

- Enable TIMER1 before its first use; it is gated after reset.

- Do not gate PWM while it is running: a gated channel freezes at its current level. Write PWM CMD = STOP \| RST (all four outputs to 0) before clearing CLK_EN\[PWM\].

- Gating or soft-resetting WDT disables the watchdog, exactly like clearing its enable in aon_timer. Do it only when the watchdog is not wanted — for example for a debug session, where the watchdog must be disabled anyway because Ibex ignores the NMI in Debug Mode.

- Handle load/store access faults from peripheral addresses: enable the clock or release the reset, then retry.

- After any reset, read and clear RESET_CAUSE in SYSCSR to tell POR, watchdog and software resets apart.

## Design Rationale

| Decision | Reason |
|:---|:---|
| Sequencing in MRV-CPU software (CRM ROM) instead of a hardware FSM | The release order and gating policy can change without RTL change or full re-simulation of the RTL. |
| MRV-CPU in polling mode, interrupt tied to 0 | MRV-CPU's interrupt is a one-cycle edge that replaces the current instruction with jalr x1, INT_VECTOR(x0), with no masking and no mret. An edge that arrives during a BIU stall is lost while x1 is still overwritten; a second Ibex write during the handler sets x1 inside the handler and the return loops forever. Polling a desired-state register cannot lose a request and needs no MRV-CPU RTL change. |
| Ibex writes requests, MRV-CPU writes the controls | No field has two writers, so there is no race between the two CPUs. |
| Software reset = one bit that resets the whole chip; per-domain soft reset only for peripherals | If Ibex could reset S_BUS, ROM or RAM while using them, the chip would hang. |
| RRC with POR-only flip-flops | Removes the loop in which the WDT request is cleared by the reset it causes, and the same problem for SW_RST; the reset output is glitch-free. |
| Access rights by two write filters | APB-CSR-Generator sees one slave and cannot tell the masters apart; a small filter per master makes the rights of Table 6-1 a hardware guarantee (firmware cannot reset the CPU through RST_REL). |
| All domains released together, CPU last | No known dependency requires ROM/RAM first; the CPU is the only self-starting master. |
| CPU, buses, memories and SYSDBG never gated | Gating the CPU or a bus leaves nothing to restart it; a gated SYSDBG makes the debugger fail silently. |
| APB Guard blocks before gating and opens after enabling | An access to a stopped peripheral returns an error instead of hanging the bus. |
| SYSCSR and SYSDBG reset only by POR | RESET_CAUSE must survive WDT/SW resets; a JTAG session must survive them too. |
| One domain per instance (TIMER0/1, UART0/1, GPIO0–2) | Each instance is a separate APB slave with its own guard and can be gated or reset alone. |
| APB Guard instantiated at the SoC top, delivered by SCRC | No wrapper and no generated P_BUS RTL has to change; one module serves every gateable slave. |
| Wait on APB_BUSY instead of a fixed 16 cycles | PREADY latency is not bounded for every IP (TL-UL adapters, FIFO windows); waiting on the real transfer state is correct for any latency. |
| WDT stays gateable and soft-resettable | It is in the peri cluster of the SoC contract. Gating it is equivalent to disabling it in aon_timer, which software can already do, so no new failure mode is added. |
| Register offsets 0x00–0x18, RST_REL\[31\] = CPU, PSLVERR on illegal writes | Fixed by the SCRC owner in V2.1; the SoC contract leaves the SCRC register map to SCRC. |
| Reset Filter = 3 delay cells + latch | The mentor's template; the only free quantity is the library cell delay. |

Table 9‑1. Design decisions

## Verification Requirements

| ID | Requirement |
|:---|:---|
| SCRC_CLK_001 | Every output clock has the root clock frequency when its CTRL is enabled. |
| SCRC_CLK_002 | The clocks of CPU, S_BUS, P_BUS, ROM, RAM and SYSDBG never stop, for any register value. |
| SCRC_CLK_003 | After reset every peripheral clock runs except TIMER1. |
| SCRC_RST_001 | POR, WDT bite and SW_RST each assert o_sys_rst_n for exactly 16 cycles and assert every domain reset except SYSDBG (WDT/SW). |
| SCRC_RST_002 | Every domain reset releases on its own clock, 2 edges after its synchronizer input rises. |
| SCRC_RST_003 | After a chip reset all non-CPU domains release in the same cycle and the CPU releases at least 16 cycles later, after APB_BLK has been written. |
| SCRC_RST_004 | With i_cpu_hold = 1 the CPU reset stays asserted regardless of RST_REL\[CPU\]. |
| SCRC_RST_005 | SYSDBG and SYSCSR are reset by POR only; WDT and SW_RST do not change them. |
| SCRC_RST_006 | SOFT_RST_CTRL\[n\] resets only domain n; the bits of always-on domains have no effect. |
| SCRC_RST_007 | After a chip reset APB_BLK equals ~CLK_EN (gateable bits) before the CPU reset releases; the first APB access of the boot ROM to UART0 completes without PSLVERR. |
| SCRC_RRC_001 | A watchdog request that is cleared by the WDT reset it causes still produces one clean 16-cycle reset and one o_cause_we_wdt pulse. |
| SCRC_CSR_001 | Ibex writes to ICG_EN, RST_REL, APB_BLK, APB_BUSY are dropped and return PSLVERR; MRV-CPU writes to SW_RST, CLK_EN, SOFT_RST_CTRL, APB_BUSY are dropped. |
| SCRC_CSR_002 | An access to 0x1C or to any offset from 0x20 returns PSLVERR; a misaligned access or a partial-strobe write returns PSLVERR. |
| SCRC_SEQ_001 | Any sequence of CLK_EN writes, including back-to-back writes, ends with ICG_EN equal to the last value written. |
| SCRC_SEQ_002 | At no time is a peripheral's clock stopped or its reset asserted while its APB_BLK bit is 0. |
| SCRC_BUS_001 | An access to a blocked peripheral completes in one APB transfer with PSLVERR = 1 and does not reach the IP. |
| SCRC_BUS_002 | A change of APB_BLK during an APB transfer does not change the response of that transfer. |
| SCRC_BUS_003 | With an IP that holds PREADY low for N cycles, MRV-CPU stops the clock only after the transfer completes, for any N. |
| SCRC_DBG_001 | With DBG_EN = 0 the CPU is released at the same time as without SYSDBG; with DBG_EN = 1 it stays in reset until CPUHOLD = 0. |

Table 10‑1. Verification requirements

## RTL Implementation

| Module | Content | Source |
|:---|:---|:---|
| m_scrc_top | SCRC top: ports of Section 4, instantiates the modules below. | in-house |
| m_scrc_reset_filter | Delay-line glitch filter on i_porstn. | in-house, library cells |
| m_scrc_rst_sync | 2-FF reset synchronizer with scan bypass (i_scan_en = 0). | library cell wrapper |
| m_scrc_rrc | Reset Request Controller. | in-house |
| m_vlsit_mrv_cpu | MRV-CPU. | github.com/nguyenquanicd/MRV-CPU |
| m_scrc_crm_rom | CRM ROM, image built with the MRV-CPU toolchain. | in-house |
| internal APB BUS | 2 masters, 1 slave, window 0x00–0x1F. | APB-BUS-Generator |
| m_scrc_apb_wfilter × 2 | Write filter per master (Ibex: no writes to 0x0C–0x18; MRV-CPU: no writes to 0x00–0x08, 0x18; both: 0x1C is an error). | in-house |
| m_scrc_csr | SCRC CSR. | APB-CSR-Generator (SCRC workbook) |
| m_scrc_ctrl × 19 | Clock gate + reset synchronizer per domain. | in-house, library ICG |
| m_scrc_apb_guard × 12 | APB Guard, instantiated at the SoC top; o_busy to i_apb_busy. | in-house |

Table 11‑1. RTL modules

Vendor DFT and auxiliary pins are tied at integration: Ibex scan_rst_ni = 1, test_en_i = 0; GPIO dft_cg_enable_i = 0; SPI device scanmode_i = 0, mbist_en_i = 0, scan_rst_ni = 1, scan_clk_i = 0; WDT clk_aon_i = o_clk_wdt, rst_aon_ni = o_rst_wdt_n; TIMER (apb_timer_unit) ref_clk_i = 0 (no reference clock in QSOC, TIMER MAS section 10); PWM (apb_adv_timer) low_speed_clk_i = its own o_clk_pwm. The clock-gate cell must be the library ICG (latch-based), never a plain AND gate on the clock path.

## Acronyms

| Acronyms       | Description                                       |
|:---------------|:--------------------------------------------------|
| APB            | Advanced Peripheral Bus                           |
| BIU            | Bus Interface Unit                                |
| CG / ICG       | Clock Gate / Integrated Clock Gating cell         |
| CPU            | Central Processing Unit (Ibex)                    |
| CRM ROM        | Clock/Reset Manager ROM (MRV-CPU program memory)  |
| CSR            | Control and Status Register                       |
| DMA            | Direct Memory Access                              |
| MRV-CPU / MCPU | Mini RISC-V CPU used as the SCRC controller       |
| P_BUS / S_BUS  | Peripheral bus (APB) / System bus (AXI4)          |
| POR            | Power-On Reset                                    |
| RRC            | Reset Request Controller                          |
| SCRC           | System Clock & Reset Controller                   |
| SYSCSR         | System Control and Status Register block (status) |
| SYSDBG         | System Debugger                                   |
| W1C            | Write 1 to Clear                                  |
| WDT            | Watchdog Timer                                    |

## First Review

| Comment | Reviewer | Response |
|:---|:---|:---|
| Boot vector must be ROM base + 0x80: boot_addr_i also feeds mtvec and Ibex fetches {boot_addr_i\[31:8\], 8'h80}. | Sinh | Accepted (V1.5). Section 7.2 step 5. |
| CHIP_ID_REV constant misspelled 'QCOS'. | Sinh | Accepted (V1.5): 0x51534F43 'QSOC', kept in SYSCSR. |
| MRV_BUSY bit was premature and not approved. | Sinh | Accepted (V1.5): removed. V2.0 goes further: MRV-CPU uses polling, so no busy flag is needed. |
| No reason to release ROM/RAM before other domains; keep it simple. | Quan (mentor) | Accepted (V2.0): all domains released together, CPU last. |
| Per-peripheral soft reset is allowed. | Quan (mentor) | Accepted (V2.0): SOFT_RST_CTRL, level, peripherals only. |
| SYSDBG must survive WDT/SW reset and its clock must not be gated; the CPU must be holdable from SYSDBG. | SYSDBG owner | Accepted (V2.0): POR-only reset, always-on clock, i_cpu_hold. |
| TIMER0 must run after reset; TIMER1 may start gated. | TIMER owner | Accepted (V2.0): CLK_EN reset value, separate TIMER0/TIMER1 domains. |
| CPU reset = SCRC CPU reset OR o_cpu_hold; SYSDBG reset from POR only. | SYSDBG owner (MAS V3.0) | Accepted (V2.1): Sections 5.5 and 7.7. |
| PWM must be stopped (CMD = STOP \| RST) before its clock is gated. | PWM owner | Accepted (V2.1): Section 8. |
| Polarity of aon_timer_rst_req_o. | RTL check (V2.2) | Active-high, sticky flip-flop cleared only by rst_aon_ni (aon_timer.sv); Sections 4 and 5.3. |
| Race between the CPU release and the guard opening at power-up. | Review (V2.3) | Guards opened before RST_REL\[CPU\]; Section 7.2, SCRC_RST_007. |
| Can the CSR generator enforce the per-master rights? | RTL check (V2.2) | No: it sees one slave. Two write filters added; Sections 5.4, 6.1 and 11. |
