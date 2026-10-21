# `dma` — DMA engine

**Owner:** @Nghia-VanTrong   **Spec:** `QNSC_DMA_MAS` (V4 pending) on the team SharePoint   **DV:** [`../../dv/dma`](../../dv/dma)

## What this block is

Copies blocks of data between any two addresses without a CPU load and store per
word. Configured on `APB_M13`, moves data as an AXI master on `AXI_S2`; two
channel interrupts (`INT[1:0]`, levels cleared by `INT_CLEAR`) on fast line 0
(the contract, `interrupts`). Every job is started by software.

> **The IP is `freecores/dma_axi` (Provartec PR200), vendored 2026-10-21; the
> earlier `pulp-platform/idma` entry is removed.** `QNSC_DMA_MAS` V4 will
> specify it against the TRM (`doc/PR200_trm_rev1.6.pdf` upstream); until then
> no RTL is written.

## Uses (IP)

| From | Module | Recorded in |
|------|--------|-------------|
| `freecores/dma_axi` | `dma_axi32` and its 53 sub-modules (32-bit variant only) | [`vendor/manifest.yml`](../../vendor/manifest.yml) |

Unmodified; only `src/dma_axi32/` is vendored. Verilog-2001, LGPL-2.1 by the
source-file headers.

What the wrapper will owe the IP (all in `vendor/manifest.yml` notes):

- **AXI3 to AXI4 adaptation** onto `S_BUS`: `WID` dropped, `AxLEN` zero-extended
  4 to 8 bits, `AWLOCK[1]` tied 0, and `BID`/`RID` stripped of the crossbar's
  2-bit master index — the IP's ID width is 1.
- **APB3** register interface, `paddr` 13 bits (the contract's 14-bit window
  aliases), no `PSTRB`: word writes only.
- `pclken` tied 1 (QSOC has one clock), `scan_en` tied 0.
- `periph_tx/rx_req[31:1]` tied 0 unless a peripheral handshake is added.

## The wrapper is the boundary

`rtl/` holds **only code written here**. Upstream IP is listed in
[`dma.f`](./dma.f), never copied into `rtl/`. Reading this one directory answers
what is ours and what is borrowed.

## Instances

One, in `design/top`.
