# `cpu` — CPU and its bus adapter (CPU2AXI)

**Owner:** @SinhHPT   **Spec:** `QNSC_CPU_MAS` on the team SharePoint   **DV:** [`../../dv/cpu`](../../dv/cpu)

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

`m_qnsc_cpu2axi` (the bridge merge logic) and `qnsc_cpu2axi_pkg` (its AXI struct
typedefs) are designed in house -- see `rtl/m_qnsc_cpu2axi.sv` and
`rtl/qnsc_cpu2axi_pkg.sv`. `axi_from_mem`/`axi_mux`/`axi_id_prepend` themselves are
unmodified upstream IP.

## The wrapper is the boundary

`rtl/` holds **only code written here**. Upstream IP is listed in
[`cpu.f`](./cpu.f), never copied into `rtl/`. Reading this one directory answers
what is ours and what is borrowed.

The block's outward boundary is `rtl/m_qnsc_wrap_cpu.sv`, generated via
Emacs `verilog-mode` AUTOINST/AUTO_TEMPLATE from `rtl/emacs/m_qnsc_wrap_cpu.src.sv`
by the shared flow (`make wrap BLOCK=cpu`, `flow/emacs/wrap.mk`), never edited by hand. It directly instantiates
`ibex_top` and `m_qnsc_cpu2axi`, connected to each other in this one file --
the core's two memory-style ports wire straight to the bridge's own ports
(leader review 2026-09-28: connect the core to the bridge first, then wrap
the pair in one module, not two sub-wrapper modules composed by a third) -- and flattens the bridge's AXI4 master
port to `i_bus_axi_*`/`o_bus_axi_*` per the naming rule at this same
boundary, since neither `ibex_top` nor the pulp-platform AXI IP speak that
convention natively.

`m_qnsc_wrap_cpu`'s own top-level ports:

| Port | Direction | Note |
|---|---|---|
| `i_clk_cpu`, `i_rst_n_cpu` | in | CPU clock domain |
| `i_dbg_req` | in | from SYSDBG |
| `i_int_fast[10:0]` | in | 11 real fast-IRQ sources; padded to Ibex's 15 internally |
| `i_int_nm` | in | WDT bark (NMI), from INTMAP |
| `o_pwr_sleep` | out | core has stopped its own clock (WFI) |
| `o_crash_dump[159:0]` | out | to SYSCSR; `ibex_pkg::crash_dump_t` flattened, 5 x 32 bits (current_pc, next_pc, last_data_addr, exception_pc, exception_addr). Declared with `$bits(ibex_pkg::crash_dump_t)`, so it follows the struct. Only the last two keep their value: SYSCSR captures on `o_double_fault_seen` or an NMI/reset |
| `o_double_fault_seen` | out | to SYSCSR; one-cycle pulse, so SYSCSR needs a sticky bit |
| `i_bus_axi_*` / `o_bus_axi_*` | in/out | flattened AXI4 master port toward S_BUS `AXI_S1` |

Tied inside the wrapper, so not ports: `boot_addr_i` to the ROM base, `hart_id_i` to 0, `test_en_i` to 0
(the project has no scan chain, so the core clock gate is never bypassed), `scan_rst_ni` to 1, and the
Ibex `irq_software_i`, `irq_timer_i`, `irq_external_i` to 0.

**AXI ID width: 2 bits (was 5).** `axi_lite_to_axi` drives every leaf ID to 0, so the four
low bits of the old 5-bit ID never carried anything. `P_LEAF_ID_W` is now 1 (the narrowest an
AXI ID type can be) and `axi_mux` adds the port bit above it, giving a 2-bit ID on
`o_bus_axi_*_id` / `i_bus_axi_*_id`: bit 1 is 0 for the instruction port and 1 for the data
port, bit 0 is always 0. **Not yet followed elsewhere:** S_BUS still has a 5-bit slave-port
ID (`P_SLV_ID_W`, `AxiIdUsedSlvPorts`) and 7-bit master ports, and ROM, ISRAM, DSRAM take
7 bits. When S_BUS is reworked, set its slave-port ID to 2 bits and `AxiIdUsedSlvPorts` to 2
(master ports 4 bits), and bring ROM, ISRAM, DSRAM and SYSDBG to the same width. Until
then the CPU does not connect to the current S_BUS as is.

## VCS compile

`vcs/` holds the compile of this block, as the mentor's `design/gpio/vcs` sample: `filelist.f`
(points to `../cpu.f`) and `run_vcs` (tcsh). On a compute node of the training server:
`cd design/cpu/vcs ; ./run_vcs`. The result is `comp.log`; read `Error-` (must be 0) and every `Lint-`
on our files. Last run, commit `df5cd98`: Error 0, Lint 0 on our files, 531 on `vendor/`.

## Instances

One. `design/top` instantiates `m_qnsc_wrap_cpu` once; QSOC has a single core.
