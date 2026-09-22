# `dma` — DMA engine

**Owner:** _TBD_   **Spec:** _TBD_   **DV:** [`../../dv/dma`](../../dv/dma)

## What this block is

_One or two sentences: what it does in QSOC._

## Uses (IP)

| From | Module | Recorded in |
|------|--------|-------------|
| _upstream, or "none -- designed in house"_ | | [`vendor/manifest.yml`](../../vendor/manifest.yml) |

_If this block instantiates upstream IP, say which facts the design depends on and
where they were read from. If it is designed in house, say so -- an empty vendor
column is itself the answer to "self-designed or IP?"._

## The wrapper is the boundary

`rtl/` holds **only code written here**. Upstream IP is listed in
[`dma.f`](./dma.f), never copied into `rtl/`. Reading this one directory answers
what is ours and what is borrowed.

## Instances

_How many times `design/top` instantiates this wrapper, and what differs between
them (parameters only -- do not fork the file)._
