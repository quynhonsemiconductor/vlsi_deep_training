# `intmap` — interrupt map

**Owner:** @Nghia-VanTrong   **Spec:** [`doc/src/QNSC_Interrupt_Map_MAS.md`](../../doc/src/QNSC_Interrupt_Map_MAS.md) (build to .docx via `doc/build_docs.py`)   **DV:** [`../../dv/intmap`](../../dv/intmap)

## What this block is

**Self-designed.** INTMAP collects interrupt sources from across the chip and
maps them onto the CPU's fast interrupt lines. There is no vendored IP here;
everything in `rtl/` is ours. The empty vendor column is the answer to
"self-designed or IP?".

## The contract it depends on

INTMAP is a contract surface: the source count and per-source index are shared
with the CPU and with `qnsc_pkg`. This is exactly the kind of thing that drifted
before (eleven sources vs twelve). The source list is defined once in
`util/qsoc_contract.yml` and generated into `design/top/rtl/qnsc_pkg.sv` — do
not hand-edit the index list in this block.

Facts it must agree with:
- ibex `irq_fast_i` is **15 bits**, fast-line priority resolves **lowest index
  first**, and `mip` is combinational. Neither the core nor INTMAP latches a
  pending bit: INTMAP is a combinational OR tree, and each source holds its level
  until firmware clears it at the peripheral.
- Each `apb_gpio` instance OR's to one fast line; `aon_timer` contributes
  `intr_wkup_timer_expired_o` and `nmi_wdog_timer_bark_o`.
