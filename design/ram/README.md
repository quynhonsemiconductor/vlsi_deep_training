# `ram` — RAM / ROM controller

**Owner:** @nghia   **Spec:** [`doc/src/QNSC_RAM_MAS.md`](../../doc/src/QNSC_RAM_MAS.md) (build to .docx via `doc/build_docs.py`)   **DV:** [`../../dv/ram`](../../dv/ram)

## What this block is

AXI4 memory controller for on-chip RAM and ROM, built on
`nguyenquanicd/AXI4-SRAM-CONTROLLER`. The IP lives in
[`vendor/nguyenquanicd/AXI4-SRAM-CONTROLLER`](../../vendor) and is not copied
here; `rtl/` holds our wrapper and the pieces the IP is missing.

## Uses (IP)

| From | Module | Recorded in |
|------|--------|-------------|
| nguyenquanicd/AXI4-SRAM-CONTROLLER | AXI4 SRAM controller | [`vendor/manifest.yml`](../../vendor/manifest.yml) |

**Licence:** `MentorProvided-QNSC-Course`, as recorded in the manifest. The
upstream repo carries no LICENSE file; it is the course mentor's own repository,
provided for this training.

Findings from reading the RTL, handled in our wrapper:
- The controller has **no `WSTRB` path**; the wrapper adds a strobe FIFO that
  drives the macro byte enables (MAS 7.3).
- `WRAP` burst type is declared but not implemented; masters must not issue it
  (MAS 7.4).

## The wrapper is the boundary

`rtl/m_qnsc_wrap_axi4_sram.sv` (module `m_qnsc_wrap_axi4_sram`) instantiates the
vendored controller unmodified and adds the WSTRB logic. Ours in `rtl/`, borrowed in `vendor/`.
