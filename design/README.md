# `design/` — RTL, one directory per block

One directory per block, one owner per directory, one wrapper module per block.
Everything below is the convention every block follows, so that a reviewer can open
any directory and know what to expect.

## Structure of a block

```
design/<block>/
  rtl/               code written here, and nothing else
    m_qnsc_wrap_<ip_module>.sv   the wrapper; generated when rtl/emacs/ exists
    emacs/                       only for a wrapper generated with emacs
      m_qnsc_wrap_<ip_module>.src.sv  the source you edit
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
status of every block is in [`doc/TRACKER.md`](../doc/TRACKER.md).

`design/common/` holds RTL instantiated by **more than one** block. It is owned by
the maintainers, because a change there affects every block that instantiates it.

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

A wrapper has four jobs: map ports to the names in `qnsc_pkg`, tie off what QSOC does
not use, adapt the protocol (the bridge) if the IP speaks a different one, and add
what the IP is missing — the byte-enable path the RAM controller lacks is the example.

## Writing a wrapper with emacs verilog-mode

The mentors ask for wrappers generated with emacs `verilog-mode`, as industry does.
You write the port groups and an `AUTO_TEMPLATE` that maps each IP port to its QNSC
name; `AUTOINST`, `AUTOINPUT`, `AUTOOUTPUT` and `AUTOWIRE` write the port list and
the instance. The references are [`doc/rules/EMACS_quick_guide.pdf`](../doc/rules/EMACS_quick_guide.pdf)
(template and every template function), `flow/emacs/template.src.sv` which follows
it, and the I2C demo on the `share_review` branch.

```bash
make new-wrap BLOCK=pwm IP=vendor/pulp-platform/apb_adv_timer/rtl/apb_adv_timer.sv
#   scaffolds design/pwm/rtl/emacs/ from flow/emacs/template.src.sv
vim design/pwm/rtl/emacs/m_qnsc_wrap_apb_adv_timer.src.sv   # fill the AUTO_TEMPLATE
make wrap BLOCK=pwm                                 # expand, copy to rtl/
make check                                          # lint, naming, wrap-check, ...
```

Rules:

1. Edit only the `.src.sv`. Commit it together with the generated files; CI
   regenerates every wrapper and fails if the committed result differs.
2. The **Others** group must end empty. A port that lands there has no template
   line, and it will also fail the naming check.
3. Internal signals are `w_*` or `r_*`. The template ignores `w_*` for ports, so an
   IP output mapped to `w_<name>` becomes a wire (`AUTOWIRE`), not a port.
4. `verilog-auto-inst-param-value` is `t`, as in the guide: a parameter set in the
   instance, `#(.APB_ADDR_WIDTH(C_APB_PADDR_WIDTH))`, is substituted into the
   generated widths, so no `sed` is needed. `PARAM_FIX` in the block Makefile (a
   `sed` script run after the expansion) is only for what this cannot express.
5. `filelist_emacs.f` is read only by emacs. `<block>.f` is still the filelist that
   builds and lints the block.

## Instances are decided in `design/top`, not here

A block directory does **not** know how many times it is instantiated. The UART owner
writes **one** wrapper; `design/top` instantiates it twice. What differs between
instances is passed as a **parameter** — never a forked file.

| Block | Ports on the block diagram | Instances |
|---|---|---:|
| `uart` | `APB_M8/9` | 2 |
| `gpio` | `APB_M3/4/5` | 3 (GPIO3 dropped with the 40-pin package; the ports after it moved up one) |
| `timer` | `APB_M6/7` | 2 (64-bit vs two 32-bit) |
| `ram` | `AXI_M1`, `AXI_M2` | 2 (ISRAM, DSRAM — differ only in depth) |
| `pwm`, `i2c`, `spi`, `dma` | one port each | 1 |

Reading the port name on the diagram tells you the count: `APB_M8/9` is two ports,
so two instances.

For the same reason, a shared wrapper never uses a per-instance constant:
`C_UART_0_SIZE` inside a wrapper that also serves UART1 is wrong, even when the two
values happen to be equal. Use a chip-wide constant (`C_APB_PADDR_WIDTH`) or a
parameter that `design/top` sets per instance.

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

## Never retype a shared number — import it

Base addresses, region sizes, interrupt line indices and clock-domain reset bits
are **shared between blocks**. Import them from `qnsc_pkg` instead of typing the
number into your wrapper:

```systemverilog
import qnsc_pkg::*;
// ... C_UART_0_BASE, C_INT_LINE_UART_0, C_SOFT_RST_BIT_D13
```

`design/top/rtl/qnsc_pkg.sv` is **generated** from `util/qsoc_contract.yml`, which is
the single source of truth. To change a number:

```bash
vim util/qsoc_contract.yml
make pkg                            # regenerate the package
# commit both files together
```

CI regenerates and compares, so the committed package cannot drift from the
contract. That check exists because every cross-block defect this project has paid
for was one fact written twice: ROM 8 KiB against 2 KiB, `APB_M11` against
`APB_S11`, eleven interrupt sources against twelve, `apb_adv_timer` against
`apb_timer_unit`. Generating makes the disagreement impossible rather than merely
detectable.

Numbers not yet agreed are listed under `tbd:` in the contract, named rather than
omitted so the gap is visible instead of being filled in by whoever needs it first.

## APB slave conventions

Every APB peripheral wrapper follows these, so P_BUS and firmware see one
behaviour across the chip.

| Item | Rule |
|---|---|
| `i_bus_apb_paddr` | `C_APB_PADDR_WIDTH` = 12 bits: the low 12 bits of the offset inside the 16 KiB window, after P_BUS subtracts the base. Offsets the IP does not decode alias, and that is accepted |
| `PSTRB`, `PPROT` | Connect them if the IP has them. If the IP has no `PSTRB`, leave the port unconnected and state in the MAS that a sub-word write writes the whole word |
| `PREADY`, `PSLVERR` | Pass the IP's through. A wrapper that adds its own decode error states it, and the reason, in its MAS |
| Clock, reset | `i_clk_peri`, `i_rst_n_peri`: the `peri` cluster, gateable by `SCRC` |

## Naming

**`QNSC_RTL_Design_Naming_Rule` V1.0 is mandatory.** The full document is
[`doc/rules/QNSC_RTL_Design_Naming_Rule.pdf`](../doc/rules/QNSC_RTL_Design_Naming_Rule.pdf). The rules
that come up most:

| Thing | Form | Example |
|---|---|---|
| Module, in house | `m_qnsc_<function>` | `m_qnsc_intmap` |
| Module, wrapper around IP | `m_qnsc_wrap_<ip_module>` | `m_qnsc_wrap_apb_uart`, `m_qnsc_wrap_apb_adv_timer` |
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
| Wrapper name: block or IP module? | The IP module: `m_qnsc_wrap_apb_i2c`, `m_qnsc_wrap_apb_adv_timer`. A vendor prefix is dropped: `m_vlsi_axi4_sram` gives `m_qnsc_wrap_axi4_sram` | Rule 2.1 and its example `m_qnsc_wrap_apb_uart`. The I2C demo's `m_qnsc_wrap_i2c` predates this table |

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
