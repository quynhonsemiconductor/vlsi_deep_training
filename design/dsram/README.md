# `dsram` — data SRAM (AXI_M2)

**Owner:** @Nghia-VanTrong   **Spec:** `QNSC_RAM_MAS` (V2.5) on the team SharePoint   **DV:** [`../../dv/dsram`](../../dv/dsram)

## What this block is

The data SRAM on `AXI_M2`, an AXI4 memory controller built on
`nguyenquanicd/AXI4-SRAM-CONTROLLER` with a 32 KiB macro (`PARA_SRAM_DEPTH` = 8192).
`isram` uses the same IP with a 64 KiB macro; the two are two blocks, each with its
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
[`dsram.f`](./dsram.f), never copied into `rtl/`.

| File | Written by | What |
|---|---|---|
| `rtl/emacs/m_qnsc_wrap_dsram.src.sv` | hand | Wrapper source: ports, `AUTO_TEMPLATE`s, the three instances |
| `rtl/m_qnsc_wrap_dsram.sv` | emacs, `make wrap BLOCK=dsram` | The wrapper `dsram.f` compiles; never edited by hand |
| `waivers.vlt` | hand | Lint waivers, each with its reason |

Inside the wrapper, three instances: the vendored controller `u_sram_ctrl`
(`m_vlsi_axi4_sram`, parameters fixed at the instance, MAS section 5), `u_strbfifo`, a
vendored `m_vlsi_fifo` that holds `WSTRB` beside the controller's write-data FIFO
(MAS 7.3), and the macro `u_sram_mem` (`qnsc_sram_sp`, 8192 words, from
`design/common/tech/<TECH>/`). `w_mem_be` is the FIFO head while `w_mem_we` is high and
zero otherwise.

**The macro is in the wrapper** (review, PR #84). The controller's macro side is
internal wires, not ports: `w_mem_addr` (the controller's byte address `[14:2]`, 8192
words), `w_mem_wdata`, `w_mem_we`, `w_mem_be`, `w_mem_oe`, `w_mem_rdata`. `design/top`
instantiates this one module and nothing else for the 32 KiB RAM. With `TECH` =
`generic` the macro is a behavioural model with byte enables and no reset; the SMIC
28 nm cell ties the macro's margin and test pins inside (MAS section 10).

`w_mem_we`, `w_mem_be` and `w_mem_rdata` are declared by hand in the `.src.sv`: the
wrapper reads them inside, and the AUTOs do not declare a signal the module itself uses.
