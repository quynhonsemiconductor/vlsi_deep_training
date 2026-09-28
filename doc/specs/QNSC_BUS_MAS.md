---
title: "BUS"
subtitle: "MICRO-ARCHITECTURE SPECIFICATION -- V1.0"
author: "QUY NHON SEMICONDUCTORS -- QNSC"
---

# Revision history

The reasoning behind each change is in
[`QNSC_BUS_DECISIONS.md`](QNSC_BUS_DECISIONS.md).

| Version | Date | Author | Reviewer | Description of change |
|---|---|---|---|---|
| V1.0 | 2026-09-28 | SinhHPT | -- | First issue: `S_BUS` crossbar and the `AXI2APB` bridge, ending at a flat APB4 port. `P_BUS`'s own router is not yet covered -- see section 9 |

# 1. Overview

`bus` is the chip's two buses and the bridge between them. `S_BUS` is a
fully-connected AXI4 crossbar (`axi_xbar`) that routes three masters to four
destinations by address; `AXI2APB` converts the one destination that is not a
memory into APB4 and hands it to `P_BUS`. This document covers `S_BUS` and
`AXI2APB` only: `P_BUS`'s own router (`m_vlsi_apb_router`, generated from the
current peripheral map) is not yet generated or wired in -- section 9.

# 2. Features

- AXI4 crossbar, fully connected: every slave port reaches every master port
  through one shared address map -- 7.1.
- Three slave ports (masters issuing transactions): `AXI_S0` SYSDBG, `AXI_S1`
  CPU, `AXI_S2` DMA -- 7.2.
- Four master ports (destinations): `AXI_M0` ROM, `AXI_M1` ISRAM, `AXI_M2`
  DSRAM, `AXI_M3` the `AXI2APB` bridge -- 7.3.
- Every slave port has its own private decode-error responder: an unmapped
  address always answers `DECERR`, on every port, unconditionally -- 7.4.
- `AXI2APB`: two IP modules in series (`axi_to_axi_lite`, `axi_lite_to_apb`),
  ending at one flat APB4 port -- 7.5.
- No packed structs cross `m_qnsc_wrap_bus`'s own boundary: every AXI channel
  is flattened field by field, matching `design/cpu`'s own convention -- 7.6.

# 3. Block diagram

No diagram yet. In words: three AXI4 masters (`AXI_S0`/`AXI_S1`/`AXI_S2`) enter
`axi_xbar`; three of its four master ports (`AXI_M0`/`AXI_M1`/`AXI_M2`) leave
this block directly as flattened AXI4; the fourth (`AXI_M3`) stays internal,
passing through `axi_to_axi_lite` then `axi_lite_to_apb` before leaving as one
flat APB4 port. `axi_xbar` is clocked from `sbus`; the AXI2APB bridge
(`axi_to_axi_lite` + `axi_lite_to_apb`) is clocked from `pbus` -- each its own
hardwired-on domain (`qnsc_pkg`'s "sbus"/"pbus" clusters), a separate CTRL
instance from `cpu`'s own, per `QNSC_SCRC_MAS` V3.0 Table 5-2.

# 4. IP used

: Upstream IP used

| From | Module | Commit | Licence |
|---|---|---|---|
| pulp-platform/axi | `axi_xbar` (+ `axi_demux`, `axi_mux`, `axi_multicut`, `axi_err_slv`, `axi_atop_filter`, `axi_burst_splitter`), `axi_to_axi_lite`, `axi_lite_to_apb` | `70b8e54fd460e3308e58be596ceb3566a6e3576e` | SHL-0.51 |
| pulp-platform/common_cells | `cc_addr_decode`, `cc_rr_arb_tree`, `cc_fifo`, `cc_counter`, `cc_id_queue` (+ their own dependencies) | `db42769334b4589b4b3fc671b34513bdb98be565` | SHL-0.51 |

`s_bus_pkg` (the AXI/AXI4-Lite/APB4 struct typedefs, `axi_xbar`'s `Cfg` and
address map) is designed in house. See `vendor/manifest.yml` for the full
per-file dependency reasoning, traced from the pinned commit's actual source.

# 5. Interface

: `m_qnsc_wrap_bus` interface

| Signal | Dir | Width | Description |
|---|---|---:|---|
| `i_clk_sbus` | in | 1 | S_BUS's own domain; hardwired on, never gated; clocks `axi_xbar` |
| `i_rst_n_sbus` | in | 1 | Active-low reset, same domain; also reaches SYSDBG as `i_rst_n_sysbus` |
| `i_clk_pbus` | in | 1 | P_BUS's own domain; hardwired on; clocks the AXI2APB bridge |
| `i_rst_n_pbus` | in | 1 | Active-low reset, same domain |
| `i_axi_s_0_*` | in | AXI4 | From SYSDBG (`AXI_S0`), 5-bit ID, no protocol adapter needed (SYSDBG's own AXI4 manager since V3.0) |
| `i_axi_s_1_*` | in | AXI4 | From CPU's CPU2AXI bridge (`AXI_S1`), 5-bit ID |
| `i_axi_s_2_*` | in | AXI4 | From DMA (`AXI_S2`), 5-bit ID assumed -- open item, section 11 |
| `o_axi_m_0_*` | out | AXI4 | To ROM (`AXI_M0`), 7-bit ID (5 + ceil(log2(3))) |
| `o_axi_m_1_*` | out | AXI4 | To ISRAM (`AXI_M1`), covers both the debug window and the application region as one contiguous rule |
| `o_axi_m_2_*` | out | AXI4 | To DSRAM (`AXI_M2`) |
| `o_apb_paddr` | out | 32 | `AXI2APB`'s output; P_BUS's single master-input port |
| `o_apb_pprot` | out | 3 | |
| `o_apb_psel`, `o_apb_penable`, `o_apb_pwrite` | out | 1 each | |
| `o_apb_pwdata` | out | 32 | |
| `o_apb_pstrb` | out | 4 | |
| `i_apb_pready` | in | 1 | |
| `i_apb_prdata` | in | 32 | |
| `i_apb_pslverr` | in | 1 | |

Every AXI4 port above carries the full per-channel field set (`aw_id`/`addr`/
`len`/`size`/`burst`/`lock`/`cache`/`prot`/`qos`/`region`/`atop`/`user`/`valid`,
`w_data`/`strb`/`last`/`user`/`valid`, `b_id`/`resp`/`user`/`valid`/`ready`,
`ar_*` mirroring `aw_*` without `atop`, `r_id`/`data`/`resp`/`last`/`user`/
`valid`/`ready`), flattened field by field -- see `rtl/m_qnsc_wrap_bus.sv`.

# 6. Register map

None. `bus` is not a bus slave; it has no reset logic of its own (its two
clock/reset pairs are tied from SCRC, per section 5), and no registers.

# 7. Functional behaviour

## 7.1 Fully-connected crossbar

`axi_xbar`'s `Connectivity` parameter is left at its default `'1`: every slave
port reaches every master port through one shared address map. This is what
lets SYSDBG's debug master read ROM, and what lets any master reach any
memory or the peripheral window without a per-pair decision.

## 7.2 Slave ports (masters)

Three masters issue transactions on `S_BUS`. None needs a protocol adapter at
this level: SYSDBG's own AXI4 manager drives `AXI_S0` directly since
`QNSC_SYSDBG_MAS` V3.0; CPU's CPU2AXI bridge already presents one merged AXI4
master port to `AXI_S1`; DMA's own 3:1 multiplexer (register job, descriptor
chain, peripheral channels) already presents one merged AXI4 master port to
`AXI_S2`. All ID-width adaptation and merging is each master's own block's
job, not this one's.

## 7.3 Master ports (destinations)

Four destinations answer them. Three (`AXI_M0` ROM, `AXI_M1` ISRAM, `AXI_M2`
DSRAM) leave this block directly as flattened AXI4. The fourth (`AXI_M3`)
never leaves as AXI at all -- see 7.5. `AXI_M1`'s address rule spans both the
4 KiB debug window (`isram_dbg`) and the 60 KiB application region (`isram`)
as one contiguous range, since both reach the same physical RAM instance
through the same wrapper port and the two regions are adjacent
(`isram_dbg` ends exactly where `isram` begins).

`axi_xbar` treats a rule's `end_addr` as **exclusive**. `qnsc_pkg`'s
`C_*_BASE`/`C_*_SIZE` pairs already give an exclusive bound directly as
`base + size`, so no off-by-one correction is applied.

## 7.4 Decode error, always

No slave port enables `en_default_mst_port_i`. An address that matches no
rule always reaches the crossbar's own private decode-error responder for
that slave port, on every port, unconditionally -- never a guessed
destination. This is what lets a firmware bug that walks off the end of a
region fail loudly (a bus error) rather than silently reading or writing the
wrong device.

## 7.5 AXI2APB

`AXI_M3`'s AXI4 traffic passes through two IP modules in series:
`axi_to_axi_lite` (strips the ID and the ATOP field, since AXI4-Lite has
neither) then `axi_lite_to_apb` (the actual protocol conversion,
`NoApbSlaves = 1`, one address rule covering the whole 256 KiB window). The
struct types between these two modules, and between `axi_lite_to_apb` and
this block's own `o_apb_*`/`i_apb_*` ports, are private to `s_bus_pkg` and
never cross a block boundary -- this block's own ports are flat APB4 signals,
not a struct.

`axi_lite_to_apb`'s `NoApbSlaves = 1` is deliberate: this block hands P_BUS
exactly one address window and lets P_BUS's own generated router do the real
fan-out to fourteen peripherals, a separate step -- section 9.

## 7.6 No packed structs at the boundary

Every AXI4 channel is flattened field by field on this module's own ports,
matching the naming rule and `design/cpu`'s established convention. Internal
signals between `axi_xbar`, `axi_to_axi_lite` and `axi_lite_to_apb` do use
the packed AXI/AXI4-Lite/APB4 structs `s_bus_pkg` defines -- AUTOINST would
not apply here regardless (this wrapper is hand-written; `axi_xbar`'s own
ports are already arrayed structs, not individual flat signals AUTOINST could
decompose), so the pack/unpack glue at the boundary is hand-written, the same
reason `design/cpu/rtl/emacs/m_qnsc_wrap_cpu_cpu2axi.sv` gives for its own.

# 8. Instances

One. `design/top` instantiates `m_qnsc_wrap_bus` once; QSOC has a single
instance of each bus.

# 9. What is not provided here, and who provides it

: Functions this block does not provide

| Function | Where it lives |
|---|---|
| `P_BUS`'s actual per-peripheral fan-out (14 APB slaves) | Not yet built. `nguyenquanicd/APB-BUS-Generator` generates `m_vlsi_apb_router` from an Excel memory map; a future PR wires its single input to this block's `o_apb_*`/`i_apb_*` port and its 14 outputs to the peripheral blocks |
| ID-width adaptation / merging for any of the three slave-port masters | Each master's own block (CPU's CPU2AXI bridge, DMA's own 3:1 mux, SYSDBG's native AXI4 manager) |
| The `AXI2APB` naming in `design/*/README.md` cross-references (e.g. `AXI_M3`) | This block; those references describe *this* block's own port, not a separate one |

# 10. Tie-offs

: Tie-offs

| Port | Tied to | Why |
|---|---|---|
| `axi_xbar`'s `en_default_mst_port_i` | `'0`, every bit | No slave port gets a default/guessed destination; an unmapped address always hits the private decode-error responder (7.4) |
| `axi_xbar`'s `default_mst_port_i` | `'0` | Unused since `en_default_mst_port_i` is all zero; tied rather than left floating |
| `axi_xbar`'s `ATOPs` | `1'b0` | No evidence any of the three masters here issues AXI5 atomic operations |

# 11. Requirements on others, and open items

: Requirements on other owners

| Item | Owner | What it blocks |
|---|---|---|
| Confirm DMA's actual `AXI_S2` ID width | DMA owner | This block assumes 5-bit for uniformity with SYSDBG/CPU; if DMA's real width differs, `s_bus_pkg::P_SLV_ID_W` and every ID-width-dependent field need revisiting. `HAS` para 852's "identifier width 7" more likely describes this crossbar's own auto-widened master-port ID (5 + ceil(log2(3)) = 7) than DMA's own port width -- flagged, not resolved, by reading the HAS text alone (design/README.md's own caution against closing an ambiguity by reading only one's own RTL applies here to reading only the HAS, too) |
| Generate and wire in `P_BUS`'s router | This block's owner | Every peripheral block is unreachable from the CPU until this lands |
| Confirm the AXI2APB bridge belongs on `pbus`, not `sbus` | Bus/SCRC owner | A judgement call, not yet confirmed (`QNSC_BUS_DECISIONS.md`); not a functional risk either way since both domains are the same physical clock when ungated, but the block's own domain-boundary claim should still be settled |

Accepted limits:

- `AxiIdUsedSlvPorts` is left at full width (`P_SLV_ID_W`) rather than a
  narrower value, for safety, until CPU/DMA/debug ID uniqueness is confirmed
  chip-wide.
- `UniqueIds` is left at `1'b0` (the safe default) for the same reason.
- Neither is a correctness bug at these settings; both are conservative
  defaults a real ID-uniqueness analysis could later tighten.

# 12. Verification

1. `axi_xbar`'s `Cfg.NoSlvPorts`/`NoMstPorts` equal 3/4, matching this
   document's port list and `util/qsoc_contract.yml`'s S_BUS topology.
2. `s_bus_pkg::P_ADDR_MAP`'s four rules' `start_addr`/`end_addr` match
   `qnsc_pkg`'s `C_ROM_*`, `C_ISRAM_DBG_BASE`/`C_ISRAM_*`, `C_DSRAM_*` and
   `C_AXI2APB_*` exactly (`flow/lint/contract_tag.py`-style cross-check,
   though these are integration-block values, not tagged literals).
3. No slave port's `en_default_mst_port_i` bit is ever set.
4. `axi_lite_to_apb`'s `NoApbSlaves`/`NoRules` both equal 1.
5. No packed struct type appears in `m_qnsc_wrap_bus`'s own port list
   (`flow/lint/naming_check.py` plus a manual port-list read).
6. `flow/lint/lint_all.sh bus` reports `ok` with zero Verilator errors.

# Appendix A. Acronyms

: Acronyms

| Acronym | Description |
|---|---|
| S_BUS | System Bus -- the AXI4 crossbar this document covers |
| P_BUS | Peripheral Bus -- the APB4 router this document does not yet cover |
| AXI2APB | The AXI4 -> AXI4-Lite -> APB4 bridge chain between S_BUS and P_BUS |
| ATOP | Atomic Operation (AXI5 extension to AXI4) |
| DECERR | AXI4 decode error response |

# Appendix B. First review

: First review

| Item | Reviewer | Response |
|---|---|---|
| Reference material found in a prior sandbox (`BUS_CONFIG_GUIDE.md`, a partially-written `S_BUS` package/top) assumed a RISC-V PLIC as a 5th `S_BUS` master port | Self-caught, cross-referenced against `QNSC_Interrupt_Map_DECISIONS.md` V11.2 | That reference material was built against HAS v1.3; the PLIC was later rejected (V11.2, 2026-09-21: "no PLIC, peripheral interrupts wired straight to the CPU"). This document uses the current, no-PLIC, four-master-port topology throughout |
