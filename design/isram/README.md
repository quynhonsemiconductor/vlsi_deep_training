# `isram` — instruction SRAM (AXI_M1)

**Owner:** @Nghia-VanTrong   **Spec:** [`doc/specs/QNSC_RAM_MAS.md`](../../doc/specs/QNSC_RAM_MAS.md) (build to .docx via `doc/build/build_docs.py`)   **DV:** [`../../dv/isram`](../../dv/isram)

## What this block is

The instruction SRAM on `AXI_M1`, an AXI4 memory controller built on
`nguyenquanicd/AXI4-SRAM-CONTROLLER` with a 64 KiB macro (`PARA_SRAM_DEPTH` = 16384).
`dsram` uses the same IP with a 32 KiB macro; the two are two blocks, each with its
own wrapper (Tâm, 2026-09-28). One MAS covers both. The IP lives in
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

`rtl/` holds **only code written here**. Upstream IP is listed in
[`isram.f`](./isram.f), never copied into `rtl/`.

| File | Written by | What |
|---|---|---|
| `rtl/emacs/m_qnsc_wrap_isram.src.sv` | hand | Wrapper source: ports, `AUTO_TEMPLATE`s, the two instances |
| `rtl/m_qnsc_wrap_isram.sv` | emacs, `make wrap BLOCK=isram` | The wrapper `isram.f` compiles; never edited by hand |
| `waivers.vlt` | hand | Lint waivers, each with its reason |

Inside the wrapper: the vendored controller `m_vlsi_axi4_sram` (parameters fixed at
the instance, MAS Table 5-2), and `u_strbfifo`, a vendored `m_vlsi_fifo` that holds
`WSTRB` beside the controller's write-data FIFO (MAS 7.3). `o_mem_be` is the FIFO head
while `o_mem_we` is high and zero otherwise.

**The macro is not in the wrapper.** It ends at the macro's pins: `o_mem_addr` (the
controller's byte address `[15:2]`, 16384 words), `o_mem_wdata`, `o_mem_we`, `o_mem_be`,
`o_mem_oe`, `i_mem_rdata`. `design/top` places the 64 KiB single-port macro there; the
testbench in [`dv/isram`](../../dv/isram) uses a behavioural model with byte enables.

`o_mem_we` and `o_mem_be` are the two ports declared by hand in the `.src.sv`: the wrapper
reads both inside, and `AUTOOUTPUT` does not declare a signal the module itself uses.
