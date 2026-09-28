# `scrc` — system clock and reset control

**Owner:** @Nam-HaoNguyen   **Spec:** [`QNSC_SCRC_MAS.md`](../../doc/specs/QNSC_SCRC_MAS.md), [`QNSC_SYSCSR_MAS.md`](../../doc/specs/QNSC_SYSCSR_MAS.md)   **DV:** [`../../dv/scrc`](../../dv/scrc)

## What this block is

Turns the `CLKIN` and `PORSTN` pads into one gated clock and one synchronised
reset per domain (18 domains), and the three reset sources into one chip reset.
Sequencing is software: `MRV-CPU` runs a program from its own ROM and is the only
agent that opens a clock gate, releases a reset or opens an APB guard; Ibex only
writes requests.

This directory also holds `SYSCSR`, the status registers on `APB_M1`, and the APB
guard that `design/top` instantiates once per gateable slave.

## Uses (IP)

| From | Module | Recorded in |
|------|--------|-------------|
| `nguyenquanicd/MRV-CPU` | `m_vlsit_mrv_cpu` | [`vendor/manifest.yml`](../../vendor/manifest.yml) |
| `nguyenquanicd/APB-CSR-Generator` | generates `m_qnsc_scrc_csr`, `m_qnsc_syscsr_csr` | [`vendor/manifest.yml`](../../vendor/manifest.yml) |
| `nguyenquanicd/APB-BUS-Generator` | the internal 2-master bus -- name clash with `P_BUS`, MAS section 11 | [`vendor/manifest.yml`](../../vendor/manifest.yml) |

The reset filter, synchronisers and clock gates are library cells, instantiated
rather than inferred (MAS 7.2, 11).

## The wrapper is the boundary

`rtl/` holds **only code written here**. Upstream IP is listed in
[`scrc.f`](./scrc.f), never copied into `rtl/`.

## Instances

One `m_qnsc_scrc` in `design/top`, and eleven `m_qnsc_scrc_apb_guard` there, one
per gateable APB slave (MAS 8).
