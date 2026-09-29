# `syscsr` — system status registers

**Owner:** @Nam-HaoNguyen   **Spec:** [`QNSC_SYSCSR_MAS.md`](../../doc/specs/QNSC_SYSCSR_MAS.md)   **DV:** [`../../dv/syscsr`](../../dv/syscsr)

## What this block is

Three read-only views of the chip, on `APB_M1` (`0x8000_4000`):

| Offset | Register | Access | What |
|---|---|---|---|
| `0x00` | `RESET_CAUSE` | W1C | Which reset happened: power-on, watchdog, software. Survives WDT and software resets |
| `0x04` | `DOMAIN_RST_STATUS` | RO | Which clock/reset domains are in reset now, bit map of `QNSC_SCRC_MAS` Table 6-3 |
| `0x08` | `CHIP_ID_REV` | RO | `'QSOC'`, from `i_cfg_chip_id` |

It is a separate APB slave from `SCRC`; `SCRC` feeds it the reset-cause set
enables and the domain reset states, and `design/top` connects the two.

## Uses (IP)

| From | Module | Recorded in |
|------|--------|-------------|
| `nguyenquanicd/APB-CSR-Generator` | generates `m_qnsc_syscsr_csr` from [`util/gen/syscsr/syscsr_workbook.xlsx`](../../util/gen/syscsr) | [`vendor/manifest.yml`](../../vendor/manifest.yml) |

## The wrapper is the boundary

`rtl/` holds **only code written here**. The generated register block is listed
in [`syscsr.f`](./syscsr.f), never copied into `rtl/`.

| File | Written by | What |
|---|---|---|
| `rtl/emacs/m_qnsc_wrap_syscsr.src.sv` | hand | Wrapper source: port groups, `AUTO_TEMPLATE` |
| `rtl/m_qnsc_wrap_syscsr.sv` | emacs, `make wrap BLOCK=syscsr` | The wrapper `syscsr.f` compiles; never edited by hand |

The wrapper is IP: no `qnsc_pkg`, no parameter. `CHIP_ID_REV` comes in on
`i_cfg_chip_id`, which `design/top` ties to `qnsc_pkg::C_CHIP_ID`.

## Clock and reset

`i_clk_cpu` is `SCRC` `o_clk_pbus` (`cpu` cluster in the contract, never gated).
`i_rst_n_por` is `SCRC` `o_rst_n_por`, **never** `o_rst_n_pbus`: a watchdog or
software reset must leave `RESET_CAUSE` for the code that runs after it.

## Instances

One `m_qnsc_wrap_syscsr` in `design/top`, at `APB_M1`.
