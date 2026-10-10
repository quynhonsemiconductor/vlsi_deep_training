# `dma` — DMA engine

**Owner:** @Nghia-VanTrong   **Spec:** [`QNSC_DMA_MAS.md`](../../doc/specs/QNSC_DMA_MAS.md)   **DV:** [`../../dv/dma`](../../dv/dma)

## What this block is

Copies blocks of data between any two addresses without a CPU load and store per
word. Configured on `APB_M13`, moves data as an AXI4 master on `AXI_S2`, one
interrupt (`o_int_dma`, idle) on line 0. Every job is started by software.

> **IP change pending.** The mentor chose `dma_axi` (OpenCores,
> Provartec PR200) instead of iDMA. `QNSC_DMA_MAS` V4.0 will specify it; until then
> the MAS and the table below describe iDMA (V3.3) and no RTL is written.

## Uses (IP)

| From | Module | Recorded in |
|------|--------|-------------|
| `pulp-platform/iDMA` | `idma_reg32_2d` (frontend `reg`), `idma_nd_midend`, `idma_transfer_id_gen`, `idma_backend_rw_axi` | [`vendor/manifest.yml`](../../vendor/manifest.yml) |

All upstream and unmodified. The frontend and the backend are generated from the
upstream templates at the pinned commit; the files and the commands that made them
go in `util/gen/idma/` (MAS 7.6).

## The wrapper is the boundary

`rtl/` holds **only code written here**. Upstream IP is listed in
[`dma.f`](./dma.f), never copied into `rtl/`. Reading this one directory answers
what is ours and what is borrowed.

## Instances

One, in `design/top`.
