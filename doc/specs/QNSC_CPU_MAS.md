---
title: "CPU"
subtitle: "MICRO-ARCHITECTURE SPECIFICATION -- V1.0"
author: "QUY NHON SEMICONDUCTORS -- QNSC"
---

# Revision history

The reasoning behind each change is in
[`QNSC_CPU_DECISIONS.md`](QNSC_CPU_DECISIONS.md).

| Version | Date | Author | Reviewer | Description of change |
|---|---|---|---|---|
| V1.0 | 2026-09-28 | Sinh HPT | -- | First issue: lowRISC Ibex + self-designed CPU2AXI bridge, on the MAS template |

# 1. Overview

The `cpu` block wraps a single lowRISC Ibex core (`ibex_top`, RV32IMC, "small"
configuration: 2-stage pipeline, no icache, no branch predictor, no PMP, no
writeback stage) and merges its two memory-style ports (instruction fetch, data
read/write) into **one** AXI4 master port toward S_BUS's `AXI_S1` -- a single
merged bridge by design, not one bridge per interface, so instruction and data
traffic share one arbitrated master port instead of needing two S_BUS slave
ports. This block does not provide SCRC, SYSDBG, INTMAP or S_BUS themselves;
their interfaces are exposed as top-level ports, described in Section 9.

# 2. Features

- RV32IMC: RV32I base, M extension (`RV32MFast`), Zca compressed -- 7.1.
- 2-stage pipeline, no writeback stage, no branch-target ALU, no branch
  predictor -- 7.1.
- Debug support always present (`dcsr`/`dpc`); 2 hardware breakpoints via the
  trigger module, in addition to `ebreak` and an external debug request -- 7.2.
- Sleep on WFI: the core gates its own clock, and wakes on an enabled
  interrupt, NMI, debug request, already being in debug mode, or a single
  step -- 7.3.
- Boot address: cold boot fetches from ROM (`0x0000_0000`); debug boot fetches
  from the downloaded application in ISRAM instead (`qnsc_pkg::C_ISRAM_BASE`),
  bypassing ROM entirely. `cpu` is IP, so it does not resolve this itself --
  it takes the already-resolved address on `i_cfg_boot_addr`, tied by
  `design/top` from `qnsc_pkg` -- 7.4.
- CPU2AXI merge: two Ibex memory-style ports arbitrated round-robin onto one
  AXI4 master port, with the port index folded into the AXI ID so responses
  return unambiguously -- 7.5.
- DFT bypass: `i_dft_test_en` reaches the core's own internal clock gate,
  which has no scan chain of its own -- 7.6.

# 3. Block diagram

No diagram yet. In words: `m_qnsc_wrap_cpu` directly instantiates `ibex_top`
and `m_qnsc_cpu2axi` (the CPU2AXI merge), connected to each other in this one
module -- the core to the bridge first, then the pair wrapped once (leader
review 2026-09-28; see `QNSC_CPU_DECISIONS.md`) -- and flattens the bridge's
AXI4 master port to the naming rule's `i_bus_axi_*`/`o_bus_axi_*` at this same
boundary. The two memory-style ports run point to point between `ibex_top`
and `m_qnsc_cpu2axi` as internal wires and never leave `m_qnsc_wrap_cpu`.

# 4. IP used

: Upstream IP used

| From | Module | Commit | Licence |
|---|---|---|---|
| lowRISC/ibex | `ibex_top` | `e9f55342edbd27e9e17a0e41b1c95a81abb5eac8` | Apache-2.0 |
| lowRISC/opentitan (partial: `prim`/`prim_generic`, one `dv_utils` header) | -- | `aecc39ba9a49e277662fd528a6b3018a05b7d06f` | Apache-2.0 |
| pulp-platform/axi | `axi_from_mem`, `axi_mux`, `axi_id_prepend` | `70b8e54fd460e3308e58be596ceb3566a6e3576e` | SHL-0.51 |
| pulp-platform/common_cells (partial, pinned at the commit axi's own Bender.lock specifies for this axi commit) | `cc_rr_arb_tree`, `cc_spill_register` | `db42769334b4589b4b3fc671b34513bdb98be565` | SHL-0.51 |

`m_qnsc_cpu2axi` (the merge logic) and `qnsc_cpu2axi_pkg` (its AXI struct typedefs)
are designed in house. See `vendor/manifest.yml` for the full per-file
reasoning, including why `pulp-platform/common_cells` is vendored at an older,
pre-rename commit rather than a current release.

# 5. Interface

: `m_qnsc_wrap_cpu` interface

| Signal | Dir | Width | Description |
|---|---|---|---|
| `i_clk_cpu` | in | 1 | CPU clock domain, always-on |
| `i_rst_n_cpu` | in | 1 | Active-low reset, already released together with the other domains by SCRC |
| `i_cfg_boot_addr` | in | 32 | Resolved boot address, tied by `design/top`: `i_dbg_en ? qnsc_pkg::C_ISRAM_BASE : 32'h0` (cold boot fetches ROM at `0x0`; debug boot fetches the downloaded application in ISRAM) |
| `i_cfg_hart_id` | in | 32 | Tied by `design/top`; `32'h0` while QSOC has one core |
| `i_dbg_req` | in | 1 | From SYSDBG; requests debug mode |
| `i_int_fast` | in | 11 | From INTMAP, `mcause` 16-26; padded to Ibex's 15-bit port internally |
| `i_int_nm` | in | 1 | Watchdog bark (NMI), from INTMAP |
| `i_dft_test_en` | in | 1 | DFT scan bypass |
| `o_pwr_sleep` | out | 1 | Core has stopped its own clock (WFI) |
| `i_bus_axi_aw_ready` | in | 1 | AXI4 AW channel, from S_BUS |
| `o_bus_axi_aw_id` | out | 5 | AXI4 AW channel, to S_BUS |
| `o_bus_axi_aw_addr` | out | 32 | AXI4 AW channel, to S_BUS |
| `o_bus_axi_aw_len`, `_size`, `_burst`, `_lock`, `_cache`, `_prot`, `_qos`, `_region`, `_atop`, `_user`, `_valid` | out | per-field | AXI4 AW channel, to S_BUS |
| `i_bus_axi_w_ready` | in | 1 | AXI4 W channel, from S_BUS |
| `o_bus_axi_w_data`, `_strb`, `_last`, `_user`, `_valid` | out | per-field | AXI4 W channel, to S_BUS |
| `o_bus_axi_b_ready` | out | 1 | AXI4 B channel, to S_BUS |
| `i_bus_axi_b_id`, `_resp`, `_user`, `_valid` | in | per-field | AXI4 B channel, from S_BUS |
| `i_bus_axi_ar_ready` | in | 1 | AXI4 AR channel, from S_BUS |
| `o_bus_axi_ar_id`, `_addr`, `_len`, `_size`, `_burst`, `_lock`, `_cache`, `_prot`, `_qos`, `_region`, `_user`, `_valid` | out | per-field | AXI4 AR channel, to S_BUS |
| `o_bus_axi_r_ready` | out | 1 | AXI4 R channel, to S_BUS |
| `i_bus_axi_r_id`, `_data`, `_resp`, `_last`, `_user`, `_valid` | in | per-field | AXI4 R channel, from S_BUS |

Every AXI4 signal above is flattened per the naming rule; no packed struct
crosses the wrapper boundary. Internally, `ibex_top` and `m_qnsc_cpu2axi`
connect through a memory-style port pair per side (instruction:
`req`/`gnt`/`rvalid`/`addr`/`rdata`/`err`; data: adds `we`/`be`/`wdata`) as
plain internal wires, wired directly by `m_qnsc_wrap_cpu`'s own AUTO_TEMPLATE
blocks -- no intermediate wrapper module in between.

# 6. Register map

None. This block has no APB interface and no memory-mapped configuration
registers of its own; `ibex_top`'s own CSRs are RISC-V-architectural, not part
of this interface.

# 7. Functional behaviour

## 7.1 Instruction set and pipeline

RV32I base with the M extension (`RV32MFast`: 3-cycle multiply, iterative
divide) and Zca compressed instructions -- the encodings the default
`rv32imc` toolchain target emits, so no custom compiler is needed. The
register file is flip-flop based (`RegFileFF`), which synthesises on every
technology and maps into FPGA fabric unmodified, unlike the latch-based
alternative. The pipeline is 2 stages (IF, ID/EX); with no writeback stage,
every data access stalls the core completely until the response returns --
there is no forwarding path to hide it. No branch-target ALU and no branch
predictor: a taken branch pays a bubble either way, and this size class does
not carry the extra adder or predictor state to remove it.

## 7.2 Debug support

The debug request pin, debug mode, and the `dcsr`/`dpc` registers are always
present -- not a configuration choice. `DbgTriggerEn = 1'b1` and
`DbgHwBreakNum = 2` (leader review 2026-09-28) enable 2 hardware breakpoints
via the trigger module, in addition to the `ebreak`-in-memory and external
`i_dbg_req` paths already available. A hardware breakpoint needs no write into
instruction memory to fire, so unlike a software `ebreak` it also works in
code that cannot be modified, such as the ROM bootloader -- materially more
useful for GDB/OpenOCD firmware debugging than the single breakpoint (or the
zero breakpoints) this design carried before the review.

## 7.3 Sleep and wake

The core gates its own internal clock on WFI (`core_clock_gate_i`, inside
`ibex_top`); this wrapper must never gate `i_clk_cpu` externally, since an
internal status flop is ahead of that gate and an external gate would leave
the core permanently asleep. Wake sources: an enabled interrupt, NMI, a debug
request, already being in debug mode, or a single step. Clearing every bit of
`mie` before `wfi` does not by itself prevent wake -- NMI and debug request
still work, since neither is gated by `mie`.

## 7.4 Boot address

`cpu` is IP (design/README.md, "Shared numbers: who may use `qnsc_pkg`"), so
it does not import `qnsc_pkg` or compute this mux itself. `design/top` ties
`i_cfg_boot_addr` directly to Ibex's `boot_addr_i`:

```
i_cfg_boot_addr = i_dbg_en ? qnsc_pkg::C_ISRAM_BASE : 32'h0000_0000
```

Ibex forms its own reset entry point as `{boot_addr_i[31:8], 8'h80}`, so cold
boot's first instruction is at `0x0000_0080` (inside ROM, per `QNSC_ROM_MAS`)
and debug boot's is at `0x2000_1080` (inside ISRAM's program region, per
`util/qsoc_contract.yml`'s `isram` entry) -- **not** `0x2000_0080`, inside the
4 KiB `isram_dbg` debug/DM window at `0x2000_0000`. `mtvec` resets from the
same port, so a debug boot's trap-vector table lives in ISRAM as well, not
ROM. `DmBaseAddr`/`DmAddrMask`/`DmHaltAddr`/`DmExceptionAddr` are a separate,
unrelated set of `ibex_top` parameters (Section 10): they configure the RISC-V
Debug Module's own halt/exception entry points inside the 4 KiB debug window,
not the boot-address mux. Being IP, `m_qnsc_wrap_cpu` writes `DmBaseAddr`
as the fixed value `32'h2000_0000` tagged `// contract: memory_map.isram_dbg.base`
rather than importing `qnsc_pkg::C_ISRAM_DBG_BASE`; `contract_tag.py` still
checks the literal against `util/qsoc_contract.yml` so it cannot drift.

## 7.5 CPU2AXI merge

`m_qnsc_cpu2axi` instantiates two `axi_from_mem` (one per Ibex memory-style
port, protocol-converting request/grant/valid to AXI4-Lite to AXI4) feeding
one `axi_mux`, which round-robin arbitrates them onto a single AXI4 master
port and widens the ID by one bit (`axi_id_prepend`, folded into `axi_mux`) so
the port index becomes the top ID bit -- responses return to the correct port
unambiguously, and within one port every request uses the same ID so
responses return in request order. The instruction port has no write path at
all: `i_data_we`/`i_data_be`/`i_data_wdata` exist only on the data side, by
construction, not by a tie-off that could be bypassed. Both memory-style ports
transfer one 32-bit word at a time; neither `axi_from_mem` instance issues
bursts, so `o_bus_axi_aw_len`/`o_bus_axi_ar_len` are always 0.

## 7.6 DFT

`i_dft_test_en` bypasses `ibex_top`'s own internal clock gate
(`core_clock_gate_i`). Ibex has no scan chain of its own (`scan_in`/`scan_out`/
`shift_en` do not exist in its source); the chain is inserted by the DFT tool
at synthesis and needs this gate bypassed ahead of it before it can shift.

# 8. Instances

One. `design/top` instantiates `m_qnsc_wrap_cpu` once; QSOC has a single core.

# 9. What is not provided here, and who provides it

: Functions this block does not provide

| Function | Where it lives |
|---|---|
| Clock generation, reset sequencing and release order | SCRC |
| Debug request generation, ISRAM debug-window load, halt/resume control | SYSDBG |
| Interrupt aggregation onto `i_int_fast`/`i_int_nm` | INTMAP |
| AXI4 crossbar arbitration and address decode beyond this one master port | S_BUS |
| Boot code itself (what runs at `0x0000_0080`) | ROM (`design/rom`), see `QNSC_ROM_MAS` |
| Memory protection enforcement of the debug-window/application-region split | Nobody: `PMPEnable = 1'b0`, so the split is a firmware convention only, not hardware-enforced (Section 11) |

# 10. Tie-offs

: Tie-offs

| Port | Tied to | Why |
|---|---|---|
| `i_cheriot_enable` | `ibex_pkg::IbexMuBiOff` | `BaseIsa = BaseIsaRV32I`; CHERIoT is not used |
| `i_fetch_enable`, `i_mcounteren_writable` | `ibex_pkg::IbexMuBiOn` | Core is held by SCRC's own reset/hold, not by fetch enable; performance-counter access left writable |
| `i_hart_id` | `32'h0` | Single core; value only needs to be unique among cores |
| `i_trvk_*`, `o_trvk_*` (CHERIoT revocation bitmap) | `'0` / open | `BaseIsa = BaseIsaRV32I`; CHERIoT ports unused |
| `i_scramble_*`, `o_scramble_req` | `1'b0` / `'0` / open | `ICacheScramble = 1'b0`; no icache to scramble |
| `i_mem_icache_*_cfg`, `o_mem_icache_*_cfg` | `'{default: prim_ram_1p_pkg::RAM_1P_CFG_REQ_DEFAULT}` / open | `ICache = 1'b0` |
| `i_mem_instr_rdata_intg`, `i_mem_data_rdata_intg` | `7'h0` | `MemECC` follows `SecureIbex = 1'b0`; no integrity checking |
| `i_mem_data_tag`, `o_mem_data_tag`, `o_mem_data_wdata_intg`, `o_mem_data_wdata_intg_shadow` | `1'b0` / open | No CHERIoT, no `MemECC` |
| `o_mem_*_shadow` (lockstep diagnostic outputs) | open | `SecureIbex = 1'b0`; lockstep not present |
| `o_alert_minor`, `o_alert_major_internal`, `o_alert_major_bus`, `o_crash_dump`, `o_double_fault_seen`, `o_lockstep_cmp_en` | open | Diagnostic-only outputs, no alert handler or lockstep in QSOC |
| `i_dft_scan_rst_n` | `1'b1` | Only used by the lockstep branch, which is absent (`SecureIbex = 1'b0`) |

# 11. Requirements on others, and open items

: Requirements on other owners

| Item | Owner | What it blocks |
|---|---|---|
| `AXI_S1` slave-port ID width at S_BUS must equal this block's 5-bit master ID | S_BUS owner | Cannot be checked from this block alone; flag at S_BUS integration review |
| SYSDBG must load the ISRAM application and the debug window before releasing `i_dbg_req`/asserting `i_dbg_en` for a debug boot | SYSDBG owner | Debug boot's first fetch at `0x2000_1080` returning garbage otherwise |

Accepted limits, stated rather than hidden:

- The 4 KiB debug window and the 60 KiB application region share the same
  ISRAM block, and `PMPEnable = 1'b0`, so nothing in hardware stops firmware
  from writing into the debug window or past the end of its own region. The
  linker script is the only boundary today.
- Taken-branch penalty, multiply and divide cycle counts are per upstream IP
  documentation, not confirmed by simulation on this build.

# 12. Verification

1. `ibex_config_tb`-equivalent: a hand-assembled RV32IM program (`addi`,
   `add`, `mul`, `sw`, `lw`, `csrrs`, `jal`) executes correctly against
   `ibex_top` directly, confirming the parameter set boots and runs.
2. Full-hierarchy TB: the same program, driven through `m_qnsc_wrap_cpu`'s
   complete path (`ibex_top` -> `m_qnsc_cpu2axi` -> flattened AXI4 -> a
   behavioural AXI4 memory responder), confirming the CPU2AXI merge preserves
   data correctness end to end.
3. Bridge-only TB: `m_qnsc_cpu2axi` driven directly on both memory-style
   ports, checking round-robin arbitration under simultaneous instruction and
   data requests, byte-enable correctness on partial writes, AXI error
   propagation, and that every AW/AR beat length is 0 (single-beat only).
4. `flow/lint/naming_check.py`, `flow/lint/hardcode_check.py` and
   `flow/lint/filelist_check.py` against `design/cpu`: clean.
5. `bash flow/lint/lint_all.sh cpu`: 0 `%Error`.
6. A check that would fail if the design drifts from Section 7.4: debug boot's
   first fetch address must equal `qnsc_pkg::C_ISRAM_BASE + 32'h80`, not
   `qnsc_pkg::C_ISRAM_DBG_BASE + 32'h80` -- this exact confusion was found and
   fixed once already (2026-09-28), by cross-referencing this section against
   `QNSC_ROM_MAS` rather than by any automated check.

# Appendix A. Acronyms

: Acronyms

| Acronym | Description |
|---|---|
| AXI | Advanced eXtensible Interface |
| CSR | Control and Status Register |
| DFT | Design For Test |
| DM | Debug Module (RISC-V Debug spec) |
| ISRAM | Instruction SRAM |
| NMI | Non-Maskable Interrupt |
| PMP | Physical Memory Protection |
| WFI | Wait For Interrupt |

# Appendix B. First review

: First review

| Item | Reviewer | Response |
|---|---|---|
| Ibex parameter table: 35-row review of every `ibex_top` parameter against the "small MCU" configuration | Lead engineer | 3 changes accepted (`DbgTriggerEn`, `DbgHwBreakNum`, `CsrMimpId`); all other 32 rows confirmed already correct as configured |
| Debug-boot address used `C_ISRAM_DBG_BASE` instead of `C_ISRAM_BASE` | Found while implementing the above review, cross-checked against `QNSC_ROM_MAS` and the QSOC HAS report | Fixed 2026-09-28: both `C_ISRAM_BASE` and `C_ISRAM_DBG_BASE` are valid contract constants, so no automated check could have told these apart; only reading the two specs together caught it |
