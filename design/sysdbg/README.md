# `sysdbg` — system debug

**Owner:** @nghia   **Spec:** [`doc/src/QNSC_SYSDBG_MAS.md`](../../doc/src/QNSC_SYSDBG_MAS.md) (build to .docx via `doc/build_docs.py`)   **DV:** [`../../dv/sysdbg`](../../dv/sysdbg)

## What this block is

**Self-designed.** SYSDBG is written in house — a debug access path that exposes
an AXI master into the system fabric so an external host can read memory and
peek at state. There is no vendored IP instantiated here; everything in `rtl/`
is ours. That the directory borrows nothing is itself the answer to
"self-designed or IP?".

## Reference (read, not instantiated)

`pulp-platform/riscv-dbg` is vendored **as reference only** and is not built
into this block. It is kept so the design claims stay checkable against a fixed
commit — its `dm_sba.sv` uses the same memory-style master port SYSDBG exposes,
and it ships an OBI wrapper but no AXI wrapper (which is part of why SYSDBG is in
house). Its default `IdcodeValue` is `32'h00000DB3`, which QSOC deliberately
does **not** reuse — QSOC's IDCODE is `0x0515_3001`.

## Fabric note

SYSDBG's master reaches ROM because `axi_xbar` (see the `bus` block) is fully
connected. It uses `axi_from_mem` with `MaxRequests = 1`.
