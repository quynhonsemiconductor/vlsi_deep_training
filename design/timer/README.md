# `timer` — general-purpose timer

**Owner:** @Nghia-VanTrong   **Spec:** [`doc/specs/QNSC_TIMER_MAS.md`](../../doc/specs/QNSC_TIMER_MAS.md) (build to .docx via `doc/build/build_docs.py`)   **DV:** [`../../dv/timer`](../../dv/timer)

## What this block is

Two general-purpose counters behind one APB4 slave, built on the pulp-platform
`apb_timer_unit`. This directory holds **only the code we write** — the wrapper.
The IP itself lives in [`vendor/pulp-platform/timer_unit`](../../vendor) and is
never copied here. Read one directory, know what is ours and what is borrowed.

## Uses (IP)

| From | Module | Recorded in |
|------|--------|-------------|
| pulp-platform/timer_unit | `apb_timer_unit`, `timer_unit_counter`, `timer_unit_counter_presc` | [`vendor/manifest.yml`](../../vendor/manifest.yml) |

Two instances: **TIMER0** with `MODE_64 = 1` (64-bit via chained counters),
**TIMER1** with `MODE_64 = 0`. Note from reading the RTL: the comparator is
registered and *not* gated by the counter enable, and compare is on equality
(not `>=`), so one-shot mode yields a held level, not a pulse — the wrapper is
responsible for the pulse if the spec wants one.

## The wrapper is the boundary

`rtl/m_qnsc_wrap_apb_timer_unit.sv` instantiates the vendored modules, ties off
unused ports, and maps the APB signals to the names in `qnsc_pkg`. The IP already
speaks APB, so there is no bridge. Generated with emacs from `rtl/emacs/` ([`design/README.md`](../README.md#writing-a-wrapper-with-emacs-verilog-mode)). Anything in
`rtl/` is ours; anything it instantiates from `vendor/` is not. That split is
the answer to "self-designed or IP?" — visible without opening a file.
