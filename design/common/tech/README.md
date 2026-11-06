# `common/tech` — technology cells

Cells that RTL cannot describe portably: a clock gate, a clock buffer at a
known point, and later pads and memory macros. RTL instantiates only these
modules, never a library cell (Naming Rule 2.8). Each technology implements every
module with the **same name and ports**, and the build chooses one with `TECH`:

```
design/common/tech/
  generic/        behavioural: simulation, CI, FPGA, open synthesis (default)
  generic.f
  <tech>/         an ASIC library: the same modules on its cells
  <tech>.f
```

```bash
make lint                  # TECH=generic
TECH=<tech> make vcs BLOCK=scrc
```

| Module | Ports | Generic behaviour |
|---|---|---|
| `qnsc_clk_gate` | `i_clk_src`, `i_en`, `i_dft_scan_en`, `o_clk_gated` | enable latched while the clock is low; scan enable forces it on |
| `qnsc_clk_buf` | `i_clk_src`, `o_clk_buf` | wire |
| `qnsc_clk_inv` | `i_clk_src`, `o_clk_inv` | inverter |
| `qnsc_clk_and` | `i_clk_src`, `i_en`, `o_clk_and` | AND |
| `qnsc_dly` | `i_sig`, `o_sig_dly` | 1 ns delay, simulation model only (lint and synthesis ignore it) |
| `qnsc_rst_sync` | `i_clk_dst`, `i_rst_n_src`, `i_dft_scan_en`, `o_rst_n_dst` | asynchronous assert, release on the second rising edge; scan enable bypasses the flip-flops |
| `qnsc_sync_cell` | `i_clk_dst`, `i_rst_n_dst`, `i_d`, `o_q` | two flip-flops, cleared asynchronously |
| `qnsc_rst_filter` | `i_rst_n_raw`, `o_rst_n_filt` | clockless glitch filter: three delay taps, set when all four are 1, clear when all four are 0 |

The last four exist for SCRC (`QNSC_SCRC_MAS` 7.1--7.3): its mentor rule is that the
clock gates, delays, synchronisers and the filter flip-flop are library cells, never
inferred. `qnsc_sync_cell` is that rule's synchroniser; a data crossing that needs no
library cell uses the behavioural `qnsc_sync` of `../rtl`. `qnsc_rst_filter` carries its
three delay cells inside (in `smic28/` the same `DLY4_X1M` as `qnsc_dly`), so that each
technology's filter is one file that lints on its own; `qnsc_dly` is the delay cell for
any other use and is not instantiated by SCRC.

No block lists these files. Every flow (lint, VCS, synthesis, GCA, connectivity, sim)
appends them, and the shared RTL of [`../common.f`](../common.f), with
`flow/tech/libs.sh` as **library files** (`-v`): a cell is compiled only where a block
instantiates it, and once when several blocks do.

## `smic28`: SMIC 28HKMG

`smic28/` maps every module onto ARM `sc9mc_base_svt_c31` r1p0 (cell suffix
`_A9TS_C31`; on the server under
`/tools/pdk_libraries/SMIC/SMIC28NM/SMIC28HKMG/SMIC-28HKMG-9-Track-c31-Standard-Cell-Library/arm/smic/28hkmg/sc9mc_base_svt_c31/r1p0/`).
Nine tracks and svt: the chip runs at 20 MHz, so speed is not the constraint; nine
tracks route more easily than seven and are smaller than twelve.

| Module | Cells |
|---|---|
| `qnsc_clk_gate` | `PREICG_X1B` |
| `qnsc_clk_buf` | `BUFH_X4M` (size to be set by physical design) |
| `qnsc_clk_inv`, `qnsc_clk_and` | `INV_X1M`, `AND2_X1M` |
| `qnsc_dly` | `DLY4_X1M` |
| `qnsc_rst_sync` | `INV_X1M` + `SDFFYRPQ2D_X1M` (D = 1) + `MX2_X1B` |
| `qnsc_sync_cell` | `INV_X1M` + `SDFFYRPQ2D_X1M` |
| `qnsc_rst_filter` | 3 x `DLY4_X1M` + `NAND4_X1M` + `OR4_X1M` + `INV_X1M` + `DFFSRPQ_X1M` |

The library has no active-low reset pin, hence the inverter in front of each
synchroniser's `R`. `TECH=smic28` builds only where the PDK's Verilog model is read as
well (the training server); CI lints and simulates `generic/`.

## Adding a technology

1. Copy `generic/` to `<tech>/` and `generic.f` to `<tech>.f`.
2. In each file, keep the module name and ports, and instantiate the library cell
   inside, under its own name and pin names, as `u_size_only_<function>`:
   ```systemverilog
   <ICG cell> u_size_only_icg (.CK(i_clk_src), .E(i_en), .SE(i_dft_scan_en), .ECK(o_clk_gated));  // naming-check: ignore -- library cell
   ```
3. A cell an upstream IP instantiates by its own name gets a module of that name that
   instantiates `qnsc_clk_gate`, so the whole chip uses one gate. `vendor/` is not
   edited. If the upstream tree ships the cell (`prim_clock_gating` in Ibex and
   OpenTitan, `tc_clk_gating` in common_cells), the file in `<tech>/` replaces the
   upstream one in that technology's build. If it does not ship it (`pulp_clock_gating`,
   which `apb_adv_timer` instantiates), the block that needs it writes the module in
   its own `rtl/`, as `design/pwm/rtl/pulp_clock_gating.sv`.
4. Synthesis preserves the cells by instance name: `set_size_only` (or
   `dont_touch`) on `*/u_size_only_*`.

The library's own data (Liberty, LEF, its Verilog models) stays where the PDK is
installed and is never copied here. Gate-level simulation reads the library's
models there; RTL simulation uses `generic/`.

This follows OpenTitan's technology primitives (`prim_generic`, one directory per
technology, same name and ports) and PULP's `tech_cells_generic` ("keep it thin").
