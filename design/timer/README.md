# `timer` — general-purpose timer

**Owner:** @nghia   **Spec:** [`doc/QNSC_TIMER_MAS.docx`](../../doc)   **DV:** [`../../dv/timer`](../../dv/timer)

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

`rtl/qsoc_timer_wrap.sv` instantiates the vendored modules, ties off unused
ports, and maps the APB signals to QSOC's naming (`qsoc_pkg`). Anything in
`rtl/` is ours; anything it instantiates from `vendor/` is not. That split is
the answer to "self-designed or IP?" — visible without opening a file.
