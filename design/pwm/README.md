# `pwm` — PWM / advanced timer

**Owner:** @nghia   **Spec:** [`doc/src/QNSC_PWM_MAS.md`](../../doc/src/QNSC_PWM_MAS.md) (build to .docx via `doc/build_docs.py`)   **DV:** [`../../dv/pwm`](../../dv/pwm)

## What this block is

PWM generation built on pulp-platform `apb_adv_timer`. This directory holds
**only the wrapper we write**; the IP lives in
[`vendor/pulp-platform/apb_adv_timer`](../../vendor) and is not copied here.

## Uses (IP)

| From | Module | Recorded in |
|------|--------|-------------|
| pulp-platform/apb_adv_timer | `apb_adv_timer` | [`vendor/manifest.yml`](../../vendor/manifest.yml) |

One instance. `TIMER_NBITS = 16`, `EXTSIG_NUM = 32`. From reading the RTL: the
four `events_o` are a 4-of-16 multiplexer over channel outputs, edge-detected to
one cycle, and **inert until `EVENT_CFG` is programmed**. `out_filter` only
updates while `ctrl_active_i` is high, so a stopped channel holds its last
level. The per-timer `status_o` is not wired to anything readable upstream — if
the spec needs it visible, the wrapper exposes it.

## The wrapper is the boundary

`rtl/qsoc_pwm_wrap.sv`: instantiate, tie off, port-map to `qsoc_pkg`. Ours in
`rtl/`, borrowed in `vendor/`.
