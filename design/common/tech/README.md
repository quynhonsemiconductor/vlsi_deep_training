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

No block lists these files. Every flow (lint, VCS, synthesis, GCA, connectivity)
appends them with `flow/tech/libs.sh` as **library files** (`-v`): a cell is
compiled only where a block instantiates it.

## Adding a technology

1. Copy `generic/` to `<tech>/` and `generic.f` to `<tech>.f`.
2. In each file, keep the module name and ports, and instantiate the library cell
   inside, under its own name and pin names, as `u_size_only_<function>`:
   ```systemverilog
   <ICG cell> u_size_only_icg (.CK(i_clk_src), .E(i_en), .SE(i_dft_scan_en), .ECK(o_clk_gated));  // naming-check: ignore -- library cell
   ```
3. A cell an upstream IP instantiates by its own name (`prim_clock_gating` in Ibex
   and OpenTitan, `tc_clk_gating` in common_cells, `pulp_clock_gating` in PWM) gets
   a file of that name in `<tech>/` that instantiates `qnsc_clk_gate`, so the whole
   chip uses one gate. `vendor/` is not edited; the file replaces the upstream one
   in that technology's build.
4. Synthesis preserves the cells by instance name: `set_size_only` (or
   `dont_touch`) on `*/u_size_only_*`.

The library's own data (Liberty, LEF, its Verilog models) stays where the PDK is
installed and is never copied here. Gate-level simulation reads the library's
models there; RTL simulation uses `generic/`.

This follows OpenTitan's technology primitives (`prim_generic`, one directory per
technology, same name and ports) and PULP's `tech_cells_generic` ("keep it thin").
