# `timer` — general-purpose timer

**Owner:** @Nghia-VanTrong   **Spec:** `QNSC_TIMER_MAS.md` on the team SharePoint   **DV:** [`../../dv/timer`](../../dv/timer)

## What this block is

Two general-purpose counters behind one APB4 slave, built on the pulp-platform
`apb_timer_unit`. This directory holds **only the code we write** — the wrapper.
The IP itself lives in [`vendor/pulp-platform/timer_unit`](../../vendor) and is
never copied here. Read one directory, know what is ours and what is borrowed.

## Uses (IP)

| From | Module | Recorded in |
|------|--------|-------------|
| pulp-platform/timer_unit | `apb_timer_unit`, `timer_unit_counter`, `timer_unit_counter_presc` | [`vendor/manifest.yml`](../../vendor/manifest.yml) |

Two identical instances, **TIMER0** and **TIMER1**, both 64-bit (team decision
2026-11-06; TIMER1 was two 32-bit timers). `MODE_64` is bit 31 of `CFG_REG_LO`, a
register bit that resets to 0 (32-bit mode), not a parameter: firmware sets it on
both timers before use. In 64-bit mode only `irq_lo_o` fires, so the wrapper brings
out `irq_lo_o` and leaves `irq_hi_o` open. Note from reading the RTL: the comparator is
registered and *not* gated by the counter enable, and compare is on equality
(not `>=`), so one-shot mode yields a held level, not a pulse — the wrapper is
responsible for the pulse if the spec wants one.

## The wrapper is the boundary

`rtl/m_qnsc_wrap_timer.sv` instantiates the vendored modules, ties off
unused ports, and maps the APB signals to the names of the naming rule. The IP already
speaks APB, so there is no bridge. Generated with emacs from `rtl/emacs/` ([`design/README.md`](../README.md#writing-a-wrapper-with-emacs-verilog-mode)). Anything in
`rtl/` is ours; anything it instantiates from `vendor/` is not. That split is
the answer to "self-designed or IP?" — visible without opening a file.
