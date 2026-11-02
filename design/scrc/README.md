# `scrc` — system clock and reset control

**Owner:** @Nam-HaoNguyen   **Spec:** `QNSC_SCRC_MAS` V3.4 on the team SharePoint   **DV:** [`../../dv/scrc`](../../dv/scrc)

## What this block is

Turns the `CLKIN` and `PORSTN` pads into one gated clock and one synchronised
reset per domain (18 domains: 7 always-on, 11 gateable), and the three reset
sources (power-on, watchdog bite, `SW_RST`) into one chip reset. Sequencing is
software: `MRV-CPU` (MCPU) runs a program from its own ROM and is the only agent
that opens a clock gate, releases a reset or opens an APB guard; Ibex only writes
requests (`SW_RST`, `CLK_EN`). The CPU is never held (`QNSC_SYSDBG_MAS` V4.0): the
only recovery is a chip reset.

`SCRC CSR` is on `APB_M0` (`0x8000_0000`, 16 KiB; all 14 offset bits decoded,
`0x0020`-`0x3FFF` answer `PSLVERR`). The status registers are `SYSCSR`, a block of
its own (`design/syscsr`).

## Uses (IP)

| From | Module | Recorded in |
|------|--------|-------------|
| `nguyenquanicd/MRV-CPU` | `m_vlsit_mrv_cpu` | [`vendor/manifest.yml`](../../vendor/manifest.yml) |
| `nguyenquanicd/APB-BUS-Generator` | generates the internal 2-master bus `m_qnsc_scrc_apb_bus` ([`util/gen/scrc_bus`](../../util/gen/scrc_bus)) | [`vendor/manifest.yml`](../../vendor/manifest.yml) |
| `nguyenquanicd/APB-CSR-Generator` | generates `m_qnsc_scrc_csr` ([`util/gen/scrc_csr`](../../util/gen/scrc_csr)) | [`vendor/manifest.yml`](../../vendor/manifest.yml) |
| this repository | the CRM ROM `m_qnsc_scrc_crm_rom`, assembled from [`crm/crm_rom.S`](crm/crm_rom.S) ([`util/gen/crm_rom`](../../util/gen/crm_rom)) | -- |

The clock gates, the root buffer, the reset synchronisers, the WDT request
synchroniser and the `PORSTN` glitch filter are library cells, never inferred (the
mentor's rule, MAS 7.1-7.3). The RTL reaches them only through the technology cells
of [`design/common/tech`](../common/tech/README.md): `qnsc_clk_buf`, `qnsc_clk_gate`,
`qnsc_rst_sync`, `qnsc_sync_cell`, `qnsc_rst_filter`. `TECH=generic` (CI) simulates
them; `TECH=smic28` maps them onto `sc9mc_base_svt_c31`.

## Files

| File | What |
|---|---|
| `rtl/emacs/m_qnsc_scrc.src.sv` | the top, edited here; `make wrap BLOCK=scrc` writes `rtl/m_qnsc_scrc.sv` (instances only) |
| `rtl/m_qnsc_scrc_ctrl.sv` | one domain: clock gate + reset synchroniser (18 instances) |
| `rtl/m_qnsc_scrc_rrc.sv` | reset request controller: WDT and SW requests, 16-cycle chip reset, cause enables |
| `rtl/m_qnsc_scrc_apb_wfilter.sv` | write filter, one per master (MCPU, Ibex) |
| `rtl/m_qnsc_scrc_map.sv` | the bit map between the CSR fields and the guard vectors |
| `rtl/m_qnsc_scrc_apb_guard.sv` | the APB guard, instantiated 11 times in `design/top` |
| `crm/crm_rom.S` | the MCPU program (power-up order, `CLK_EN` service loop) |
| `constraints/scrc.sdc` | SDC |
| `vcs/` | VCS compile on the training server (`./run_vcs`; `TECH=smic28 PDK_V=<model>` for the library cells) |

## Instances

One `m_qnsc_scrc` in `design/top`, and eleven `m_qnsc_scrc_apb_guard` there, one
per gateable APB slave, on `o_clk_pbus` / `o_rst_n_pbus` (MAS 7.7, 8). `design/top`
ties `i_guard_busy` bits 0, 1, 2, 11, 12, 13 and 14 to 0 (MAS 11).
