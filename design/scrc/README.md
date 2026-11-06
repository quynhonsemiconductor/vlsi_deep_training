# `scrc` — system clock and reset control

**Owner:** @Nam-HaoNguyen   **Spec:** `QNSC_SCRC_MAS` V3.5 on the team SharePoint   **DV:** [`../../dv/scrc`](../../dv/scrc)

## What this block is

Turns the `CLKIN` and `PORSTN` pads into one gated clock and one synchronised
reset per **domain**, not per IP (13 domains: 2 always-on, `sys` and `cpu`; 11
gateable), and the three reset
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
| `rtl/m_qnsc_scrc.sv` | the top, written by hand (in-house logic; emacs AUTOs are for the wrappers of existing IP): the instances and the bit map of `APB_BLK`/`APB_BUSY` to the guard vectors |
| `rtl/m_qnsc_scrc_ctrl.sv` | one domain: clock gate + reset synchroniser (13 instances) |
| `rtl/m_qnsc_scrc_rrc.sv` | reset request controller: WDT and SW requests, 16-cycle chip reset, reset cause to SYSCSR |
| `rtl/m_qnsc_scrc_apb_wfilter.sv` | write filter, one per master (MCPU, Ibex) |
| `rtl/m_qnsc_scrc_apb_guard.sv` | the APB guard, instantiated 11 times in `design/top` |
| `crm/crm_rom.S` | the MCPU program (power-up order, `CLK_EN` service loop) |
| `constraints/scrc.sdc` | SDC |
| `vcs/` | VCS compile on the training server (`./run_vcs`; `TECH=smic28 PDK_V=<model>` for the library cells) |

## Instances

One `m_qnsc_scrc` in `design/top`, and eleven `m_qnsc_scrc_apb_guard` there, one
per gateable APB slave, on `o_clk_sys` / `o_rst_n_sys` (MAS 7.7, 8). Guard n takes
`o_csr_blk[n]` and drives `i_csr_busy[n]`; `design/top` ties
`i_csr_busy[1:0]` (sys, cpu: no guard) to 0 (MAS 11).

| Domain (bit) | `o_clk_<d>` / `o_rst_n_<d>` feed |
|---|---|
| `sys` (0, always-on) | S_BUS, P_BUS, ROM, ISRAM, DSRAM, WDT, SYSCSR (reset: `o_rst_n_por`), SYSDBG (reset: `o_rst_n_por`), the 11 guards |
| `cpu` (1, always-on, released last) | Ibex |
| `timer_0` 2, `timer_1` 3, `uart_0` 4, `uart_1` 5, `spi` 6, `i2c` 7, `gpio_0` 8, `gpio_1` 9, `gpio_2` 10, `dma` 11, `pwm` 12 | that IP and its guard's slave side |
