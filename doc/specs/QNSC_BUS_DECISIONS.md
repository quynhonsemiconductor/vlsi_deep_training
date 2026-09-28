# BUS -- design decisions

Reasoning, rejected designs and the history behind numbers in
[`QNSC_BUS_MAS.md`](QNSC_BUS_MAS.md). The MAS states what is true; this file
states why.

## Scope: S_BUS and AXI2APB now, P_BUS later

`design/bus` covers three things by its own README: "S_BUS crossbar, P_BUS
router, AXI2APB". This PR delivers the first and third. P_BUS's own router
is generator-driven RTL from a completely different tool
(`nguyenquanicd/APB-BUS-Generator`, an Excel-config-in RTL-out generator) with
its own separate config/regenerate workflow, unlike S_BUS's hand-written
crossbar instantiation -- different enough in provenance and process that
finishing S_BUS/AXI2APB to a fully verified state first, rather than rushing
both halves through in one pass, was judged the safer order. The block's own
README and this PR's description both say so plainly rather than silently
shipping a half-connected bus.

## Reference material found, and why it was not used as-is

A prior sandbox session (evidenced by a `BUS_CONFIG_GUIDE.md`, a partially
written `S_BUS/rtl/qsoc_s_bus_{pkg,top}.sv`, and a working
`P_BUS/APB-BUS-Generator` checkout) had already worked out the mechanics of
building both buses: `axi_xbar`'s `Cfg` fields, the adapter pattern per
master (`axi_from_mem` + `axi_mux` for CPU, a single `axi_from_mem` for
debug, `axi_rw_join` for DMA), the Excel-driven P_BUS generator flow, and a
Bender-based dependency resolution for the vendored tree.

That material was built against **HAS v1.3**, which specified five S_BUS
master ports including a RISC-V PLIC (`AXI_M4`) and four GPIO instances. Both
have since changed: `QNSC_Interrupt_Map_DECISIONS.md` V11.2 (2026-09-21)
explicitly reversed the PLIC adoption ("no PLIC, peripheral interrupts wired
straight to the CPU... the interrupt map removed from the memory map"), and
GPIO dropped to three instances earlier still. Cross-checked independently
against `QNSC_RAM_DECISIONS.md`, `QNSC_SYSDBG_DECISIONS.md`,
`QNSC_TIMER_DECISIONS.md` and `QNSC_PWM_DECISIONS.md` -- all four agree on
the current topology: four S_BUS master ports (ROM, ISRAM, DSRAM, AXI2APB),
three slave ports (SYSDBG, CPU, DMA), no PLIC.

The guide's assumption that S_BUS itself needs to merge DMA's read/write
ports (via `axi_rw_join`) was also stale: the current architecture has DMA
merge its own three engines (register job, descriptor chain, peripheral
channels) internally via a 3:1 multiplexer before reaching `AXI_S2`
(`QSOC_HAS` DMA section, Table 10-2 row 10), the same pattern CPU's own
CPU2AXI bridge already uses for its two memory-style ports. Neither
`axi_from_mem` nor `axi_rw_join` is needed inside this block at all: all
three slave-port masters already present a clean, single AXI4 port by the
time they reach S_BUS.

The mechanical knowledge (Cfg field meanings, the W-channel shared-struct
gotcha, how to trace `axi_xbar`'s real dependency chain from its pinned-commit
source) carried over and is credited above; every port count, address, and ID
width was rebuilt from the current `util/qsoc_contract.yml` and cross-checked
decision documents, not copied from the stale guide.

## Dependency tracing, not a blanket vendor import

The reference material's own Bender-resolved filelist pulled in nearly all of
`common_cells` and `tech_cells_generic` (Bender resolves whole declared
package dependencies, not usage-based). This project's own convention is the
opposite: vendor exactly what is instantiated, with a manifest note
explaining why each file is there (see `design/cpu`'s own PR for the same
principle). Every file this PR adds was traced by reading the real,
pinned-commit source of `axi_xbar` and its transitive dependencies file by
file, not assumed from `doc/axi_xbar.md` or copied wholesale from a Bender
run. Two files added along the way that this block does not actually need
were caught and removed before commit (`axi_id_prepend.sv` was briefly added
by habit from the CPU PR's own vendor list, then correctly re-added once
Verilator's real elaboration showed `axi_mux` itself needs it -- see below).

## `axi_xbar`'s real dependency closure

Traced transitively from `axi_xbar.sv` and `axi_lite_to_apb.sv`/
`axi_to_axi_lite.sv`, confirmed by an actual Verilator elaboration (not
assumed from the docs):

```
axi_xbar
  -> axi_xbar_unmuxed
       -> cc_addr_decode -> cc_addr_decode_dync
       -> axi_demux -> axi_demux_simple -> axi_demux_id_counters -> cc_delta_counter
       -> axi_multicut -> axi_cut
       -> axi_err_slv -> cc_counter -> cc_delta_counter; cc_fifo
  -> axi_mux -> axi_id_prepend
axi_to_axi_lite
  -> axi_atop_filter -> cc_stream_register
  -> axi_burst_splitter -> axi_burst_splitter_gran -> cc_id_queue -> cc_lzc, cc_onehot_to_bin
                                                    -> axi_demux_simple, axi_err_slv, axi_multicut
                                                    -> cc_spill_register
axi_lite_to_apb
  -> cc_addr_decode
  -> cc_fall_through_register -> cc_fifo
```

`axi_pkg.sv` is needed by everything above (`axi_pkg::resp_t`, `xbar_cfg_t`,
`xbar_rule_32_t`, ...) but, like `design/cpu`'s own branch found
independently, was missing from `vendor/manifest.yml`'s files list and from
the vendored tree on `main` before this PR -- the same pre-existing gap,
found and fixed on two branches independently for the same reason. `axi_mux`
and `axi_intf` are vendored for the same two reasons `design/cpu`'s manifest
entry gives for its own copy: `design/cpu`'s CPU2AXI bridge needs `axi_mux`
directly, and this block needs it directly too, inside `axi_xbar` itself;
both need `axi_intf` because `axi_mux.sv` bundles an interface-based
`axi_mux_intf` sibling module in the same file that Verilator elaborates as a
parentless root without `--top-module`.

Real, working elaboration (`verilator --lint-only`, zero errors) is the
source of truth here, not the API documentation -- `axi_id_prepend.sv` was
initially removed as apparently-unused (it is not part of this block's own
port-facing logic), then correctly restored once elaboration itself showed
`axi_mux.sv` instantiates it internally.

## `AxiIdWidthSlvPorts = 5`, and the DMA open item

CPU (`cpu2axi_pkg::P_MST_ID_W`) and SYSDBG (`AxiIdWidth`, per
`QNSC_SYSDBG_DECISIONS.md`) both confirm 5-bit AXI IDs at their own S_BUS
ports. DMA has no MAS yet to confirm its own `AXI_S2` ID width, so this
block assumes 5-bit for uniformity (`axi_xbar` requires one shared
`AxiIdWidthSlvPorts` across every slave port) rather than guessing a
different value and leaving it unrecorded. `QSOC_HAS`'s DMA section states
"identifier width 7" for the `AXI_S2` port, which reads, at first glance,
like a conflict -- but 7 is also exactly this crossbar's own auto-widened
*master*-port ID width (5 + ceil(log2(3)) = 7, computed by `axi_mux` inside
`axi_xbar`, never set by hand). The more likely reading is that the HAS is
describing the crossbar's internal master-port width, not DMA's own port
width, but this is a reading of one document against another, not a
confirmation from the DMA owner -- recorded as an open item (MAS section 11),
not silently resolved either way.

## `AxiIdUsedSlvPorts` and `UniqueIds`: safe defaults, not answers

Neither has a chip-level requirement forcing a specific value yet.
`AxiIdUsedSlvPorts` is left at the full slave-port ID width (conservative:
using fewer bits only matters for area/performance tuning, and using the
full width is never functionally wrong). `UniqueIds` is left at `1'b0` (also
conservative: `1'b1` would only be correct if every one of CPU, DMA and
SYSDBG is independently confirmed to always issue globally-unique IDs, which
has not been checked). Recorded as open items rather than silently assumed.

## Exclusive vs. inclusive address-map ends

`axi_xbar` treats a rule's `end_addr` as exclusive (`addr < end_addr`). The
BUS_CONFIG_GUIDE reference material's own note said its source table's end
addresses needed a "+1" correction to become exclusive -- but that note was
about a *different* source table (one expressed as inclusive last-byte
addresses). `util/qsoc_contract.yml`'s own `memory_map` entries are
`base`/`size` pairs, so `base + size` is already the correct exclusive bound
directly; applying the guide's "+1" correction here would have been a real,
newly-introduced off-by-one bug, imported by pattern-matching the guide's
prose instead of checking what this project's own contract format actually
means. Caught by reading the contract's own field semantics, not by assuming
the guide's caveat carried over unchanged.

## `NoApbSlaves = 1`, not 14

`axi_lite_to_apb` supports fanning out to multiple APB slaves directly
(`NoApbSlaves`/`NoRules` parameters, an array of APB ports). This block sets
both to 1: it hands P_BUS exactly one address window (the whole 256 KiB
`AXI2APB` region) and lets P_BUS's own generated router do the real
fourteen-way fan-out, a separate step (MAS section 9). Setting `NoApbSlaves`
to 14 here and skipping P_BUS's own router entirely was considered and
rejected: it would duplicate the peripheral address decode P_BUS's generator
already owns and is the authoritative source for (driven from
`QSOC_PBUS_Config.xlsx`, not retyped here), and would leave two places
disagreeing about the peripheral map exactly the way `util/qsoc_contract.yml`
exists to prevent for every other shared number in this project.

## A new shared contract value: the AXI2APB window

`util/qsoc_contract.yml` had per-peripheral base/size pairs (`scrc`,
`syscsr`, ...) but no single number for the *aggregate* AXI2APB window S_BUS
needs to size its own `AXI_M3` address rule. Added `meta.apb_window_base`
(`0x8000_0000`, matching `scrc`'s own base) and `meta.apb_window_size`
(`0x40000`, 256 KiB = 16 slots of 16 KiB) rather than hardcoding the literal
in this block's own package: P_BUS's own future router will need the same
two numbers to size its own master-side address decoder, so this is exactly
the kind of number the contract exists to hold once. Not added as a
`memory_map` row: that list's own documented invariant is that every address
belongs to exactly one row, and the AXI2APB window covers the *same*
addresses as the fourteen `APB_M*` rows beneath it, not a disjoint region.
`design/top/rtl/qnsc_pkg.sv` regenerated via `util/gen_qnsc_pkg.py`
accordingly (`C_AXI2APB_BASE`/`C_AXI2APB_SIZE` added).

## Struct literal vs. function initializer for `Cfg` and the address map

`axi_pkg::xbar_cfg_t`'s fields were first written as a single named-field
struct literal (`'{NoSlvPorts: ..., ...}`), the more idiomatic-looking form.
Verilator flagged several fields with `WIDTHCONCAT` ("Unsized numbers/
parameters not allowed in concatenations") even when every value was an
explicitly-sized `32'(...)` cast or a `32'd`-prefixed literal -- inconsistently:
some fields were flagged, structurally identical neighbors were not.
Rather than accept self-introduced lint warnings (this project's own
convention, established on the CPU PR, is a clean `lint_all.sh` pass with no
warnings attributable to the block's own files), both `Cfg` and the two
address-map arrays are built by an `automatic` function with plain
field-by-field assignment instead, which Verilator does not treat as a
concatenation at all. Confirmed clean by re-running the same lint after the
change.
