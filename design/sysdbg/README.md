# `sysdbg` — system debug

**Owner:** @nghia   **Spec:** [`doc/src/QNSC_SYSDBG_MAS.md`](../../doc/src/QNSC_SYSDBG_MAS.md) (build to .docx via `doc/build_docs.py`)   **DV:** [`../../dv/sysdbg`](../../dv/sysdbg)

## What this block is

**Self-designed.** SYSDBG is written in house. It is a JTAG TAP (TCK domain) and a
single-beat AXI4 manager on `AXI_S0` (system clock), linked by a 4-phase
handshake. It also drives the Ibex `debug_req`, and it holds the CPU in reset in
debug boot (`DBG_EN` pin). No vendored IP is instantiated here: everything in
`rtl/` is ours.

## Reference (read, not instantiated)

- `doc/drawio/VLSI_SYSDBG.drawio` — the teacher's reference design, drawn for a
  different SoC. The MAS follows its structure and adapts it to QSOC; the
  differences are recorded in `QNSC_SYSDBG_DECISIONS.md`, D18.
- `pulp-platform/riscv-dbg` — vendored for reference only. Its default
  `IdcodeValue` (`32'h00000DB3`) is deliberately **not** reused; QSOC's IDCODE is
  `0x0515_3001`.

## Fabric note

SYSDBG speaks AXI4 natively, so `AXI_S0` needs no adapter. Its manager reaches
ROM, both RAMs and the peripheral window, because `axi_xbar` (see the `bus` block)
is fully connected.
