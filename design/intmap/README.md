# `intmap` — interrupt map

**Owner:** @nghia   **Spec:** [`doc/QNSC_INTMAP_MAS.docx`](../../doc)   **DV:** [`../../dv/intmap`](../../dv/intmap)

## What this block is

**Self-designed.** INTMAP collects interrupt sources from across the chip and
maps them onto the CPU's fast interrupt lines. There is no vendored IP here;
everything in `rtl/` is ours. The empty vendor column is the answer to
"self-designed or IP?".

## The contract it depends on

INTMAP is a contract surface: the source count and per-source index are shared
with the CPU and with `qsoc_pkg`. This is exactly the kind of thing that drifted
before (eleven sources vs twelve). The source list is defined once in the
system contract under `util/` and generated into `design/top/qsoc_pkg.sv` — do
not hand-edit the index list in this block.

Facts it must agree with:
- ibex `irq_fast_i` is **15 bits**, fast-line priority resolves **lowest index
  first**, and `mip` is combinational (the core latches no pending bit — INTMAP
  holds pending state where the spec needs it).
- Each `apb_gpio` instance OR's to one fast line; `aon_timer` contributes
  `intr_wkup_timer_expired_o` and `nmi_wdog_timer_bark_o`.
