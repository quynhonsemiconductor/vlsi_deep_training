# `design/` — RTL, one directory per block

One directory per block, one owner per directory, one wrapper module per block.
Everything below is the convention every block follows, so that a reviewer can open
any directory and know what to expect.

## Structure of a block

```
design/<block>/
  rtl/               code written here, and nothing else
    m_qnsc_wrap_<block>.sv       the wrapper; generated when rtl/emacs/ exists
    emacs/                       only for a wrapper generated with emacs
      m_qnsc_wrap_<block>.src.sv      the source you edit
      Makefile                     DESIGN = ..., include flow/emacs/wrap.mk
      filelist_emacs.f             the IP file whose ports verilog-mode reads
  <block>.f          filelist: what builds this block, in what order
  constraints/
    <block>.sdc      clocks, I/O delays, CDC constraints (SDC stage)
  waivers.vlt        lint waivers owned by this block (optional)
  README.md          what it is, which IP, link to the spec, owner
  dv -> ../../dv/<block>
```

The testbench lives in `dv/<block>/` (see [`dv/README.md`](../dv/README.md)); the
shared scripts for each sign-off stage live in `flow/`. What each stage requires is
in [`CONTRIBUTING.md`, "Sign-off stages"](../CONTRIBUTING.md#sign-off-stages), and the
directory, owner and specification of every block are in [`doc/BLOCKS.md`](../doc/BLOCKS.md).

`design/common/` holds RTL instantiated by **more than one** block. It is owned by
the maintainers, because a change there affects every block that instantiates it.

`design/common/tech/` holds the technology cells (clock gate, clock buffer, later pads
and macros): RTL instantiates `qnsc_clk_gate`, never a library cell, and `TECH`
chooses the implementation ([`common/tech/README.md`](common/tech/README.md)).

`design/top/` is the chip top level plus the shared contract package. It instantiates
every wrapper, so it is a shared surface and not a block owner's file.

## The wrapper is the boundary

`rtl/` contains **only code written here**. Upstream IP is **listed** in `<block>.f`,
never copied into `rtl/`. That is what makes "self-designed or IP?" answerable by
reading one directory.

**Wrapper = core + bridge.** The wrapper is the layer around an existing IP that
lets it fit into QSoC. The **core** is the IP itself. The **bridge** sits inside the
wrapper and converts the IP's protocol to the chip bus; it exists only when the two
differ — APB to TL-UL for SPI and WDT, APB to OBI for UART, none for PWM, whose IP
already speaks APB. One wrapper per IP, and the IP owner owns it. `design/top`
connects every wrapper by the naming rule.

A block built from several IPs has one **boundary** wrapper, `m_qnsc_wrap_<block>`,
which is what `design/top` instantiates. If composing the IPs is easier as
separate sub-modules, one may get its own nested wrapper,
`m_qnsc_wrap_<block>_<part>`, instantiated inside the boundary wrapper -- but
prefer one flat wrapper directly instantiating every IP when that's simple
enough (`design/cpu` connects `ibex_top` to its bridge directly, no nesting).
A nested wrapper follows the same rules as the boundary one.

A wrapper has four jobs: map ports to the names of the naming rule, tie off what QSOC
does not use, adapt the protocol (the bridge) if the IP speaks a different one, and add
what the IP is missing — the byte-enable path the RAM controller lacks is the example.

A wrapper is **IP** in the sense of "Shared numbers" below: it does not use
`qnsc_pkg` and declares no parameter. The IP owner fixes the IP's configuration inside
the wrapper; `design/top` only connects.

## Writing a wrapper with emacs verilog-mode

Wrappers, and any module that mainly instantiates others, are written with emacs
`verilog-mode` AUTOs: `make new-wrap BLOCK=<block> IP=<ip top .sv>` scaffolds it,
`make wrap BLOCK=<block>` expands it, CI checks the result. The full guide -- the
files, the five parts you write, what emacs writes, the rules and the failure table
-- is [`doc/guides/EMACS_AUTO.md`](../doc/guides/EMACS_AUTO.md).

Two rules come from verilog-mode itself:

- **A file expanded by emacs has no `import`.** The parser does not resolve package
  declarations. Name a package item where it is used: `ibex_pkg::RV32MFast` in an
  instance parameter, `qnsc_pkg::C_ISRAM_BASE` at a connection in `design/top`.
- **An IP's package-typed ports and parameters are handled by the flow.** For a port
  such as `prim_ram_1p_pkg::ram_1p_cfg_req_t [N-1:0] x`, or a parameter such as
  `parameter ibex_pkg::rv32m_e RV32M`, verilog-mode emits a connection that is not
  valid SystemVerilog. `make wrap` removes those lines after the expansion
  (`flow/emacs/fix_pkg_ports.py`), so nobody edits the generated file by hand. Set a
  parameter you need in the instance's `#( ... )`.

## Instances are decided in `design/top`, not here

A block directory does **not** know how many times it is instantiated. The UART owner
writes **one** wrapper; `design/top` instantiates it twice. What differs between
instances:

- **A value** (a boot address, a hart id, an instance number): an `i_cfg_*` input
  port of the wrapper, which `design/top` ties per instance.
- **A structure** (a depth, a width, a number of channels) cannot be a port and is
  not a parameter either, because the wrapper declares none. The two configurations
  are **two blocks, each with its own wrapper** named after its contract name: the
  two RAMs are `design/isram` (`m_qnsc_wrap_isram`, depth 16384) and `design/dsram`
  (`m_qnsc_wrap_dsram`, depth 8192), both around the same IP (Tâm, 2026-09-28).

| Block | Ports on the block diagram | Instances |
|---|---|---:|
| `uart` | `APB_M8/9` | 2 |
| `gpio` | `APB_M3/4/5` | 3 (GPIO3 dropped with the 40-pin package; the ports after it moved up one) |
| `timer` | `APB_M6/7` | 2 (64-bit vs two 32-bit, chosen by firmware) |
| `isram`, `dsram` | `AXI_M1`, `AXI_M2` | 1 each: one IP, two configurations (depth), so two blocks |
| `pwm`, `i2c`, `spi`, `dma` | one port each | 1 |

Reading the port name on the diagram tells you the count: `APB_M8/9` is two ports,
so two instances.

For the same reason, a shared wrapper never holds a per-instance value: the size of
UART0 inside a wrapper that also serves UART1 is wrong, even when the two values
happen to be equal.

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

## Shared numbers: who may use `qnsc_pkg`

Base addresses, region sizes, interrupt line indices and clock-domain reset bits are
**shared between blocks**. Each is written **once**, in `util/qsoc_contract.yml`.
Which module may read it depends on what the module is:

| Kind | Blocks | Rule |
|---|---|---|
| **IP** — bought or designed here | every wrapper (`cpu`, `uart`, `i2c`, `spi`, `gpio`, `timer`, `pwm`, `wdt`, `dma`, `rom`, `isram`, `dsram`), `sysdbg`, and `design/common` | **Does not use `qnsc_pkg`.** Its own configuration is written as fixed values. A wrapper declares no parameter |
| **Integration** — exists only to put this chip together | `top`, `bus`, `intmap`, `iomux`, `scrc` | Uses `qnsc_pkg`: this is where the chip's numbers are consumed |

The list is data, in [`flow/lint/module_rules.yml`](../flow/lint/module_rules.yml);
`make module-rules` enforces it. The reason: an IP that knows the chip cannot be
reused in the next chip, and a chip number inside it is a second copy of the
contract.

When an IP needs a number the chip decides, there are two cases:

| Case | Example | How |
|---|---|---|
| **A value** | boot and debug addresses, hart id | An `i_cfg_*` input port. `design/top` ties it from `qnsc_pkg` — the way Ibex itself takes `boot_addr_i` |
| **A structure** that must equal the contract | the APB address width, a RAM size | Write the number and tag the line with the contract entry it copies |

```systemverilog
apb_adv_timer #(
  .APB_ADDR_WIDTH (12),               // contract: meta.apb_paddr_width
  .EXTSIG_NUM     (32),               // the IP owner's choice: no tag
  .TIMER_NBITS    (16)
) u_apb_adv_timer (/*AUTOINST*/);
```

`make contract-tags` fails every tagged line whose number no longer equals the
contract (a literal equal to the value, or a range `[value-1:0]`). The key is a path
into the contract; a list is entered by an item's `name`: `meta.apb_paddr_width`,
`memory_map.isram.size`. A tagged line is not reported by `make hardcode`.

An integration module takes the constant from the package:

```systemverilog
import qnsc_pkg::*;                              // hand-written integration module
// ... C_UART_0_BASE, C_INT_LINE_UART_0, C_SOFT_RST_BIT_D13
.i_cfg_boot_addr (qnsc_pkg::C_ROM_BASE),         // design/top, generated by emacs: no import
```

`design/top/rtl/qnsc_pkg.sv` is **generated** from `util/qsoc_contract.yml`, which is
the single source of truth. To change a number:

```bash
vim util/qsoc_contract.yml
make pkg                            # regenerate the package
# commit both files together
```

CI regenerates and compares, so the committed package cannot drift from the
contract, and `make contract-tags` does the same for the numbers IP writes. Those
checks exist because every cross-block defect this project has paid for was one fact
written twice: ROM 8 KiB against 2 KiB, `APB_M11` against `APB_S11`, eleven interrupt
sources against twelve, `apb_adv_timer` against `apb_timer_unit`.

Numbers not yet agreed are listed under `tbd:` in the contract, named rather than
omitted so the gap is visible instead of being filled in by whoever needs it first.

## APB slave conventions

Every APB peripheral wrapper follows these, so P_BUS and firmware see one
behaviour across the chip.

| Item | Rule |
|---|---|
| `i_bus_apb_paddr` | 12 bits (`[11:0]`, contract `meta.apb_paddr_width`): the low 12 bits of the offset inside the 16 KiB window, after P_BUS subtracts the base. Set with the IP's parameter, tagged `// contract: meta.apb_paddr_width`. Offsets the IP does not decode alias, and that is accepted |
| `PSTRB`, `PPROT` | Connect them if the IP has them. If the IP has no `PSTRB`, leave the port unconnected and state in the MAS that a sub-word write writes the whole word |
| `PREADY`, `PSLVERR` | Pass the IP's through. A wrapper that adds its own decode error states it, and the reason, in its MAS |
| Clock, reset | `i_clk_peri`, `i_rst_n_peri`: the `peri` cluster, gateable by `SCRC` |

## Naming

**`QNSC_RTL_Design_Naming_Rule` V1.2 is mandatory.** The full document is
[`doc/rules/QNSC_RTL_Design_Naming_Rule.pdf`](../doc/rules/QNSC_RTL_Design_Naming_Rule.pdf). The rules
that come up most:

| Thing | Form | Example |
|---|---|---|
| Module, in house | `m_qnsc_<function>` | `m_qnsc_intmap` |
| Module, wrapper around IP | `m_qnsc_wrap_<block>`: the block's name in the contract, without an index | `m_qnsc_wrap_pwm`, `m_qnsc_wrap_uart` (for `uart_0`, `uart_1`), `m_qnsc_wrap_timer` |
| Module, generic and shared | `qnsc_<function>` (no `m_`) | `qnsc_fifo_sync` |
| Chip top (2.1) | `m_qnsc_top` (every wrapper), `m_qnsc_chip` (pads + `m_qnsc_top`), in `design/top/rtl/` only. A block's top is its wrapper: no `_top` | `m_qnsc_top` |
| Nested wrapper (2.1) | `m_qnsc_wrap_<ip>_<part>` | `m_qnsc_wrap_cpu_ibex` |
| Package (2.1) | `qnsc_<function>_pkg` | `qnsc_pkg`, `qnsc_cpu2axi_pkg` |
| Type (2.6) | `<function>_t`; enum members `S_` / `C_` | `state_t` = `{S_IDLE, S_BUSY}` |
| File (2.7) | one module, package or interface, named after it; emacs source `<module>.src.sv` | `m_qnsc_wrap_uart.sv` |
| Technology cell (2.8) | RTL instantiates `qnsc_<function>` only; the library cell, under its own name, only inside it, instance `u_size_only_<function>` | `qnsc_clk_gate` |
| Port | `i_` / `o_` / `io_` prefix | `i_clk_sys`, `o_int_timer_0` |
| Clock, reset | `i_clk_<domain>`, `i_rst_n_<domain>`; in a `qnsc_` cell the domain is the role | `i_rst_n_sys`, `i_clk_src`, `o_clk_gated` |
| APB, AXI | `i_bus_apb_<sig>`, `i_bus_axi_<ch>_<sig>` | `i_bus_apb_paddr` |
| Several bus ports (3.3, 3.4) | the port after the protocol, as the contract names it; inside a block a struct `_req` / `_rsp` | `i_bus_axi_s_0_aw_addr`, `o_bus_apb_m_8_psel`, `o_bus_axi_req` |
| Registered signal | `r_<function>` | `r_timer_count` |
| Combinational signal | `w_<function>` | `w_timer_done` |
| Parameter, constant, state | `P_` / `C_` / `S_` uppercase | `P_DATA_WIDTH`, `S_IDLE` |
| Instance | `u_<function>[_<index>]` | `u_timer_0` |
| Memory array | `mem_<function>` | `mem_data` |
| Index | underscore before the digit | `timer_0`, never `timer0` |
| Vocabulary | `int` not `irq`, `clk` not `clock`, `rst` not `reset` | `o_int_fast` |
| Interrupt (3.6) | `o_int_<source>`, `i_int_<source>` | `o_int_timer_0`, `o_int_pwm` |
| Pad (3.8) | `i_pad_<function>`, `o_pad_<function>`, `io_pad_<function>` | `i_pad_i2c_scl`, `o_pad_i2c_scl`, `o_pad_pwm` |
| Output enable of a pad | the IP's polarity; active low ends in `_n` | `o_pad_i2c_scl_oe_n` |
| JTAG (3.11) | `i_jtag_<function>`, `o_jtag_<function>` | `i_jtag_tck`, `o_jtag_tdo` |
| Debug (3.12) | `i_dbg_<function>`, `o_dbg_<function>` | `o_dbg_req`, `o_dbg_cpu_hold` |
| Memory (3.9) | `i_mem_<function>`, `o_mem_<function>` | `o_mem_addr`, `o_mem_be`, `i_mem_rdata` |
| DMA (3.10) | `i_dma_<function>`, `o_dma_<function>` | `o_dma_tx_req`, `i_dma_last` |
| CSR, boot (3.5, 3.13) | `i_csr_*`, `o_csr_*`, `i_boot_*` | `i_boot_addr` |
| DFT, test, power, analog (3.14-3.17) | `i_dft_*`, `i_test_*`, `i_pwr_*`, `i_ana_*` | `i_dft_scan_en` |

A pad port carries `pad` and then the **function**, not the package pin:
`i_pad_i2c_scl`, never `i_pad_pin_17`. Which package pin carries the function is
the IO pad owner's table, never the wrapper's. The section numbers above are those
of the rule document.

### Decided where the rule and the demos leave a choice

Agreed on 2026-09-25 and sent to Tâm; if the rule's author asks otherwise, this
table changes first.

| Question | Decision | Basis |
|---|---|---|
| Where does the generated wrapper live? | `make wrap` copies it to `rtl/<wrapper>.sv`, the file `<block>.f` compiles; `rtl/emacs/` keeps the source and the intermediate copy | The I2C demo on `share_review`, made for this repository. The CPU demo keeps it in `EMACS/` only |
| JTAG and `DBG_EN` pins: `i_pad_*` or their own prefix? | Their own: `i_jtag_tck`, `o_jtag_tdo`, `i_dbg_en`. Every other pad-bound port is `i_pad_*` / `o_pad_*` | The rule has dedicated sections 3.11 (JTAG) and 3.12 (Debug); a dedicated section wins over the general 3.8 (Pad) |
| Wrapper name: block or IP module? | **The block** (rule 2.1, V1.1), as named in the contract, without an index: `m_qnsc_wrap_pwm` (IP `apb_adv_timer`), `m_qnsc_wrap_uart` (`apb_uart`, used by `uart_0` and `uart_1`), `m_qnsc_wrap_i2c`, `m_qnsc_wrap_timer`, `m_qnsc_wrap_isram` and `m_qnsc_wrap_dsram` (one IP, two configurations, two blocks). The name stays when the IP is replaced | Tâm's review of PR #26 (2026-09-28): a short IP name, `m_qnsc_wrap_pwm` or `m_qnsc_wrap_timer_pwm`, not the IP module's. `pwm` is chosen because it is the contract's name, and `timer_pwm` reads as one of `timer_0`/`timer_1`. His I2C demo is `m_qnsc_wrap_i2c`. Tâm confirmed it on 2026-09-28, with `m_qnsc_wrap_isram`/`m_qnsc_wrap_dsram` for the two RAMs; rule 2.1 is updated in V1.1 |
| Package and parameters in a wrapper? | None: no `import`, no parameter; the IP's configuration is fixed at the instance. Chip values arrive on `i_cfg_*` ports; a copied contract number is tagged `// contract: <key>` | Tâm's review of PR #26 (2026-09-28) and his I2C demo, `apb_i2c #(.P_APB_ADDR_WIDTH(12))`. Extended to all IP and to every emacs file in "Shared numbers" above |

`flow/lint/naming_check.py` enforces these in CI and reports each violation **inline
on the pull request diff**. Run it before pushing:

```bash
make naming                  # whole design/ tree
make naming BLOCK=timer
```

It checks `design/**/rtl` only. **Vendored IP is out of scope** — it follows its
upstream's conventions (`data_i`, `clk_i`) and renaming it would break the rule that
`vendor/` is never edited.

A deliberate exception needs a reason on the line:

```systemverilog
logic clk_i;  // naming-check: ignore -- port of a vendored module
```

### Fixing a naming finding

Each finding starts with the rule number of the document. The usual ones:

| Finding | Example | Fix |
|---|---|---|
| `1.2 port prefix` ... must match the direction | `input logic o_ready` | the prefix states the direction: `i_ready` |
| `3.1 clock` / `3.2 reset` | `i_clk`, `i_rstn`, `i_rst_sys` | `i_clk_<domain>`, `i_rst_n_<domain>`; in a `qnsc_` cell the role: `i_clk_src` |
| `1.3 active low` | `w_sys_rstn` | `w_rst_n_sys` |
| `3.3/3.4 bus` | `i_axi_s_0_aw_id`, `i_paddr`, `o_axi_req` | `i_bus_axi_s_0_aw_id`, `i_bus_apb_paddr`, `o_bus_axi_req` (a struct inside a block) |
| `2.3 signal` | `logic a, b;`, `axi_pkg::resp_t resp;` | `r_` if a flop, `w_` if combinational, `mem_` if an array |
| `2.6 type` | `t_state`, `{IDLE, BUSY}` | `state_t`, `{S_IDLE, S_BUSY}` |
| `2.1 module` (package) | `package s_bus_pkg` | `qnsc_s_bus_pkg`, and rename the file |
| `2.1 module` (chip top) | `m_qnsc_top` outside `design/top/rtl/` | only the chip top uses that name |
| `2.7 file` | two modules in one file, or `foo.sv` holding `bar` | one per file; the file is the module name |
| `1.5 vocabulary` | `o_irq_x`, `w_clock_en` | `o_int_x`, `w_clk_en` |

A finding you believe is wrong: say so in the pull request and fix the checker
(`flow/lint/naming_check.py`, patterns in `naming_rules.yml`, a case in
`test_naming_check.py`, which `make naming` runs first). Until then the line takes
`// naming-check: ignore -- <reason>`.

**In the editor**, Verible (the recommended VS Code extension) shows part of the rule
while you type: file and package names, one module per file, type names
(`.rules.verible_lint`). It does not know the rest; `make naming` is the check
that counts.
