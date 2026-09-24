# `pwm` — PWM / advanced timer

**Owner:** @Nghia-VanTrong   **Spec:** [`doc/src/QNSC_PWM_MAS.md`](../../doc/src/QNSC_PWM_MAS.md) (build to .docx via `doc/build_docs.py`)   **DV:** [`../../dv/pwm`](../../dv/pwm)

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
one cycle, and **inert until `EVENT_CFG` is programmed**. Each channel output is a
`comparator` flip-flop: a stopped module holds its last level, and
`CMD` = STOP | RST forces its four outputs to 0 (MAS section 7). The per-timer `status_o` is not wired to anything readable upstream — if
the spec needs it visible, the wrapper exposes it.

## The wrapper is the boundary

`rtl/m_qnsc_wrap_apb_adv_timer.sv`: instantiate, tie off, port-map to the names in
`qnsc_pkg`. The IP already speaks APB, so there is no bridge. Generated with emacs from `rtl/emacs/` ([`design/README.md`](../README.md#writing-a-wrapper-with-emacs-verilog-mode)).
Ours in `rtl/`, borrowed in `vendor/`.
