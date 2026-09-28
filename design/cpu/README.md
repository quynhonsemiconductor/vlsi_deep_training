# `cpu` — CPU and its bus adapter (CPU2AXI)

**Owner:** @SinhHPT   **Spec:** [`doc/specs/QNSC_CPU_MAS.md`](../../doc/specs/QNSC_CPU_MAS.md) (build to
`.docx` via `doc/build/build_docs.py`)   **DV:** [`../../dv/cpu`](../../dv/cpu)

## What this block is

Wraps the lowRISC Ibex core (RV32IMC) and merges its two memory-style ports
(instruction, data) into one AXI4 master port toward S_BUS's `AXI_S1`. The
merge is self-designed (`m_qnsc_cpu2axi`, via two `axi_from_mem` + one
`axi_mux`) -- QSOC deliberately uses a single CPU2AXI bridge rather than one
per interface, so instruction and data traffic share one arbitrated master
port instead of needing two S_BUS slave ports.

## Uses (IP)

| From | Module | Recorded in |
|------|--------|-------------|
| lowRISC/ibex | `ibex_top` | [`vendor/manifest.yml`](../../vendor/manifest.yml) |
| lowRISC/opentitan (partial) | `prim`/`prim_generic` (ibex's own dependency), `dv_utils/dv_fcov_macros.svh` | [`vendor/manifest.yml`](../../vendor/manifest.yml) |
| pulp-platform/axi | `axi_from_mem`, `axi_mux`, `axi_id_prepend` (+ their own `axi_pkg`/`axi_lite_*`/`axi_intf` dependencies) | [`vendor/manifest.yml`](../../vendor/manifest.yml) |
| pulp-platform/common_cells (partial, pinned at the OLDER commit axi's own Bender.lock specifies) | `cc_rr_arb_tree`, `cc_spill_register` (+ their own `cc_pkg`/`cc_lzc`/`cc_fifo`/`cc_spill_register_flushable` dependencies) | [`vendor/manifest.yml`](../../vendor/manifest.yml) |

`m_qnsc_cpu2axi` (the bridge merge logic) and `cpu2axi_pkg` (its AXI struct
typedefs) are designed in house -- see `rtl/m_qnsc_cpu2axi.sv` and
`rtl/cpu2axi_pkg.sv`. `axi_from_mem`/`axi_mux`/`axi_id_prepend` themselves are
unmodified upstream IP.

## The wrapper is the boundary

`rtl/` holds **only code written here**. Upstream IP is listed in
[`cpu.f`](./cpu.f), never copied into `rtl/`. Reading this one directory answers
what is ours and what is borrowed.

The block's outward boundary is `rtl/emacs/m_qnsc_wrap_cpu.sv`, generated via
Emacs `verilog-mode` AUTOINST/AUTO_TEMPLATE from `m_qnsc_wrap_cpu.src.sv` (see
`rtl/emacs/Makefile`; `make all` regenerates all three wrapper files and
applies the same tool-limitation fixups every time, not by hand). It
instantiates two intermediate wrappers -- `m_qnsc_wrap_ibex` (boundary around
`ibex_top`) and `m_qnsc_wrap_cpu2axi` (boundary around the CPU2AXI bridge,
flattening its AXI4 master port to `i_bus_axi_*`/`o_bus_axi_*` per the naming
rule, since neither `ibex_top` nor the pulp-platform AXI IP speak that
convention natively).

`m_qnsc_wrap_cpu`'s own top-level ports:

| Port | Direction | Note |
|---|---|---|
| `i_clk_cpu`, `i_rst_n_cpu` | in | CPU clock domain |
| `i_dbg_en` | in | boot-address mux: 0 = cold boot (`0x0`), 1 = debug-ROM entry (`qnsc_pkg::C_ISRAM_DBG_BASE`) |
| `i_dbg_req` | in | from SYSDBG |
| `i_int_fast[10:0]` | in | 11 real fast-IRQ sources; padded to Ibex's 15 internally |
| `i_int_nm` | in | WDT bark (NMI), from INTMAP |
| `i_dft_test_en` | in | DFT scan bypass |
| `o_pwr_sleep` | out | core has stopped its own clock (WFI) |
| `i_bus_axi_*` / `o_bus_axi_*` | in/out | flattened AXI4 master port toward S_BUS `AXI_S1` |

## Instances

One. `design/top` instantiates `m_qnsc_wrap_cpu` once; QSOC has a single core.
