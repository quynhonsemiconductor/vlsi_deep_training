# `ram` — RAM / ROM controller

**Owner:** @nghia   **Spec:** [`doc/QNSC_RAM_MAS.docx`](../../doc)   **DV:** [`../../dv/ram`](../../dv/ram)

## What this block is

AXI4 memory controller for on-chip RAM and ROM, built on
`nguyenquanicd/AXI4-SRAM-CONTROLLER`. The IP lives in
[`vendor/nguyenquanicd/AXI4-SRAM-CONTROLLER`](../../vendor) and is not copied
here; `rtl/` holds our wrapper and the pieces the IP is missing.

## Uses (IP)

| From | Module | Recorded in |
|------|--------|-------------|
| nguyenquanicd/AXI4-SRAM-CONTROLLER | AXI4 SRAM controller | [`vendor/manifest.yml`](../../vendor/manifest.yml) |

**Licence is unresolved** — the upstream repo carries no LICENSE file, so the
terms are undefined rather than permissive. Tracked in the manifest as an open
question for the mentor, not left invisible.

Findings from reading the RTL, handled in our wrapper:
- The controller has **no `WSTRB` path**; byte-enable handling is added here.
- `WRAP` burst type is declared but not implemented; the wrapper constrains or
  rejects it per the spec.

## The wrapper is the boundary

`rtl/qsoc_ram_wrap.sv` instantiates the vendored controller and adds the WSTRB
logic. Ours in `rtl/`, borrowed in `vendor/`.
