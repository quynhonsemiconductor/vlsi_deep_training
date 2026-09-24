# `flow/sta/` — SDC and constraint checking (SDC and GCA stages)

## Where constraints live

| File | Owner | Holds |
|---|---|---|
| `design/<block>/constraints/<block>.sdc` | block owner | the block's clocks, I/O delays and any CDC constraint its MAS states |
| `design/top/constraints/qsoc.sdc` | lead | chip clocks, pad I/O, clock groups; sources the block files |

Write SDC in the subset OpenSTA and Yosys both read: `create_clock`,
`create_generated_clock`, `set_clock_groups`, `set_input_delay`, `set_output_delay`,
`set_false_path`, `set_max_delay -datapath_only`, `set_multicycle_path`.

## Clock names — use exactly these

| Clock | Port | Period | Relation |
|---|---|---|---|
| `clk_cpu` | `i_clk_cpu` | 50 ns (20 MHz) | chip root; CPU, buses, SYSDBG system side |
| `clk_mem` | `i_clk_mem` | 50 ns | same root as `clk_cpu`, synchronous to it |
| `clk_peri` | `i_clk_peri` | 50 ns | same root, gated per peripheral by SCRC; synchronous |
| `tck` | `i_jtag_tck` | 100 ns (10 MHz assumed) | from the JTAG probe; **asynchronous** to every other clock |

All chip clocks come from one pad clock with no PLL (contract `meta.clock_mhz`), so
`clk_cpu`, `clk_mem` and `clk_peri` are one clock group. `tck` is its own group:

```tcl
set_clock_groups -asynchronous -group {clk_cpu clk_mem clk_peri} -group {tck}
```

A path between the groups is constrained only by what the owning MAS states, for
example the `set_max_delay -datapath_only` of `QNSC_SYSDBG_MAS` Table 7-4.

## Running the GCA stage

```bash
LIBERTY=<open liberty, e.g. sky130_fd_sc_hd__tt_025C_1v80.lib> bash flow/sta/run_gca.sh <block>
```

The SMIC 28 nm library is not open; an open library is used only so OpenSTA has
cells to time. The stage checks the constraints, not the timing numbers.
