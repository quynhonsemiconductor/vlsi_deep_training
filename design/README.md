# `design/` — RTL, one directory per block

One directory per block, one owner per directory, one wrapper module per block.
Everything below is the convention every block follows, so that a reviewer can open
any directory and know what to expect.

## Structure of a block

```
design/<block>/
  rtl/               code written here, and nothing else
  <block>.f          filelist: what builds this block, in what order
  waivers.vlt        lint waivers owned by this block (optional)
  README.md          what it is, which IP, link to the spec, owner
  dv -> ../../dv/<block>
```

`design/common/` holds RTL instantiated by **more than one** block. It is owned by
the maintainers, because a change there affects every block that instantiates it.

`design/top/` is the chip top level plus the shared contract package. It instantiates
every wrapper, so it is a shared surface and not a block owner's file.

## The wrapper is the boundary

`rtl/` contains **only code written here**. Upstream IP is **listed** in `<block>.f`,
never copied into `rtl/`. That is what makes "self-designed or IP?" answerable by
reading one directory.

A wrapper has four jobs: map ports to the names in `qsoc_pkg`, tie off what QSOC does
not use, adapt the protocol if the IP speaks a different one, and add what the IP is
missing — the byte-enable path the RAM controller lacks is the example.

## Instances are decided in `design/top`, not here

A block directory does **not** know how many times it is instantiated. The UART owner
writes **one** wrapper; `design/top` instantiates it twice. What differs between
instances is passed as a **parameter** — never a forked file.

| Block | Ports on the block diagram | Instances |
|---|---|---:|
| `uart` | `APB_M9/10` | 2 |
| `gpio` | `APB_M3/4/5/6` | 4 |
| `timer` | `APB_M7/8` | 2 (64-bit vs two 32-bit) |
| `ram` | `AXI_M1`, `AXI_M2` | 2 (ISRAM, DSRAM — differ only in depth) |
| `pwm`, `i2c`, `spi`, `dma` | one port each | 1 |

Reading the port name on the diagram tells you the count: `APB_M9/10` is two ports,
so two instances.

## The filelist is not optional

CI lints each block **through `<block>.f`**. A file not listed there is not compiled
and not checked. `find` is not used, for three reasons that are already true here:

1. A wrapper instantiates IP under `vendor/`, which `find design/<block>` cannot see.
2. Vendor trees define the same module name twice **on purpose**, as mutually
   exclusive alternatives — `dmi_jtag_tap` exists in both `dmi_jtag_tap.sv` and
   `dmi_bscane_tap.sv`, and `tlul_adapter_vh` is defined twice in OpenTitan. Verilog
   has one flat module namespace, so exactly one of each pair may be compiled and
   only an explicit list can choose.
3. Compile order matters — a package must precede whatever imports it — and `find`
   returns alphabetical order.

The same convention is used by the reference workspace (`MCU_guide_ws` ships
`filelist.f` for its CPU and VCS setups) and by the mentor's own IP.

## Naming

**`QNSC_RTL_Design_Naming_Rule` V1.0 is mandatory.** The full document is
`DM/RULES/FE/Release/QNSC_RTL_Design_Naming_Rule.pdf` in `MCU_guide_ws`. The rules
that come up most:

| Thing | Form | Example |
|---|---|---|
| Module, in house | `m_qnsc_<function>` | `m_qnsc_intmap` |
| Module, wrapper around IP | `m_qnsc_wrap_<ip_module>` | `m_qnsc_wrap_timer` |
| Module, generic and shared | `qnsc_<function>` (no `m_`) | `qnsc_fifo_sync` |
| Port | `i_` / `o_` / `io_` prefix | `i_clk_sys`, `o_int_timer_0` |
| Clock, reset | `i_clk_<domain>`, `i_rst_n_<domain>` | `i_rst_n_sys` |
| APB, AXI | `i_bus_apb_<sig>`, `i_bus_axi_<ch>_<sig>` | `i_bus_apb_paddr` |
| Registered signal | `r_<function>` | `r_timer_count` |
| Combinational signal | `w_<function>` | `w_timer_done` |
| Parameter, constant, state | `P_` / `C_` / `S_` uppercase | `P_DATA_WIDTH`, `S_IDLE` |
| Instance | `u_<function>[_<index>]` | `u_timer_0` |
| Memory array | `mem_<function>` | `mem_data` |
| Index | underscore before the digit | `timer_0`, never `timer0` |
| Vocabulary | `int` not `irq`, `clk` not `clock`, `rst` not `reset` | `o_int_fast` |

`flow/lint/naming_check.py` enforces these in CI and reports each violation **inline
on the pull request diff**. Run it before pushing:

```bash
python3 flow/lint/naming_check.py            # whole design/ tree
python3 flow/lint/naming_check.py design/timer
```

It checks `design/**/rtl` only. **Vendored IP is out of scope** — it follows its
upstream's conventions (`data_i`, `clk_i`) and renaming it would break the rule that
`vendor/` is never edited.

A deliberate exception needs a reason on the line:

```systemverilog
logic clk_i;  // naming-check: ignore -- port of a vendored module
```
