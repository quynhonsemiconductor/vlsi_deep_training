# Ibex RTL (vendored from lowRISC/ibex)

RISC-V 32-bit CPU core RTL imported from [lowRISC/ibex](https://github.com/lowRISC/ibex),
plus the OpenTitan `prim` primitives the core needs to elaborate.

## Provenance

| Item | Value |
| --- | --- |
| Upstream | https://github.com/lowRISC/ibex |
| Branch | `master` |
| Commit | `405c6d1d8220a18b2f9196141167a5875422dee4` |
| Date | 2026-09-08 |
| License | Apache-2.0 (see `LICENSE`, `NOTICE`, `CREDITS.md`) |

Sources are unmodified copies. Only the `filelist/*.f` files and this README are
local additions.

## Layout

```
design/ibex/
  rtl/                                  Ibex core, top, tracer, icache, regfiles
  shared/rtl/                           bus, ram_1p/ram_2p wrappers, timer, sim ctrl, Xilinx clkgen
  vendor/lowrisc_ip/ip/prim/rtl/        technology-independent primitives (assert, fifo, lfsr, secded, ram_1p_scr, ...)
  vendor/lowrisc_ip/ip/prim_generic/rtl/  generic (ASIC/simulation) primitive implementations
  vendor/lowrisc_ip/ip/prim_xilinx/rtl/   Xilinx FPGA primitive implementations
  vendor/lowrisc_ip/dv/sv/dv_utils/     dv_fcov_macros.svh (included by RTL for functional coverage)
  formal/                               formal_tb_frag.svh fragments (used only under `FORMAL`/`YOSYS`)
  lint/                                 Verilator and Verible waivers
  filelist/                             ready-to-use compile filelists
  ibex_configs.yaml                     upstream named parameter configurations
  src_files.yml                         upstream source grouping metadata
```

`prim_generic` and `prim_xilinx` define the same module names (`prim_buf`,
`prim_clock_gating`, `prim_clock_mux2`, `prim_flop`, `prim_ram_1p`). Compile
exactly one of the two sets.

## Filelists

Paths inside each `.f` are relative to `design/ibex/`. Each file starts with the
required `+incdir+` lines.

| Filelist | Use |
| --- | --- |
| `filelist/ibex_generic.f` | Ibex + generic primitives. Toplevel `ibex_top`. |
| `filelist/ibex_xilinx.f` | Ibex + Xilinx primitives. Toplevel `ibex_top`. |
| `filelist/shared_generic.f` | bus, RAM wrappers, timer, sim control. Pair with `ibex_generic.f`. |
| `filelist/shared_xilinx.f` | Above plus `clkgen_xil7series`. Pair with `ibex_xilinx.f`. |

Verilator lint example:

```sh
cd design/ibex
verilator --lint-only -Wall --unroll-count 72 \
  -DSYNTHESIS -DRVFI \
  -f filelist/ibex_generic.f --top-module ibex_top
```

VCS / Xcelium example:

```sh
cd design/ibex
vcs -sverilog -f filelist/ibex_generic.f -top ibex_top
xrun -sv -f filelist/ibex_generic.f -top ibex_top
```

Use `ibex_top_tracing` instead of `ibex_top` when the RVFI tracer output is
wanted; it is already in the filelists.

## Key parameters

Set on `ibex_top`. Full list and named presets are in `ibex_configs.yaml`.

- `RV32M` — multiplier/divider variant (`RV32MNone`, `RV32MSlow`, `RV32MFast`, `RV32MSingleCycle`)
- `RV32B` — bitmanip variant (`RV32BNone`, `RV32BBalanced`, `RV32BOTEarlGrey`, `RV32BFull`)
- `RegFile` — `RegFileFF`, `RegFileFPGA`, `RegFileLatch`
- `ICache`, `ICacheECC`, `ICacheScramble` — instruction cache options
- `BranchTargetALU`, `WritebackStage`, `BranchPredictor` — performance options
- `PMPEnable`, `PMPGranularity`, `PMPNumRegions` — memory protection
- `SecureIbex`, `DbgTriggerEn`, `MHPMCounterNum`, `MHPMCounterWidth`

## Updating

Re-copy from an upstream checkout at the new commit, then regenerate the
filelists if the primitive dependency set changed, and update the commit hash in
the table above.

## Not imported

Upstream simulation/verification infrastructure lives outside this directory's
scope: `dv/` (UVM, cosim, Verilator TB), `examples/`, `syn/`, `doc/`, `ci/`,
`nix/`, and the toolchain vendor trees (`riscv-tests`, `riscv-isa-sim`,
`google_riscv-dv`, `eembc_coremark`). FuseSoC `.core` files were dropped because
they reference upstream dependency graph paths that are not vendored here; the
`filelist/*.f` files replace them.
