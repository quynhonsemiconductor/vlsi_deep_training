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
one cycle, and **inert until `EVENT_CFG` is programmed**. Each channel output is a
`comparator` flip-flop: a stopped module holds its last level, and
`CMD` = STOP | RST forces its four outputs to 0 (MAS section 7). The per-timer `status_o` is not wired to anything readable upstream — if
the spec needs it visible, the wrapper exposes it.

## The wrapper is the boundary

The IP already speaks APB, so the wrapper is the core with no bridge. Ours in
`rtl/`, borrowed in `vendor/`, and [`pwm.f`](./pwm.f) lists both.

| File | What it is |
|---|---|
| `rtl/emacs/m_qnsc_wrap_pwm.src.sv` | the source to edit: ports, logic and the `AUTO_TEMPLATE` |
| `rtl/emacs/Makefile` | `make` runs emacs verilog-mode (`AUTOINST`, `AUTOINPUT`, `AUTOWIRE`) and copies the result to `rtl/` |
| `rtl/m_qnsc_wrap_pwm.sv` | generated wrapper, compiled through `pwm.f`; never edited by hand |
| `rtl/pulp_clock_gating.sv` | the clock gate `apb_adv_timer` instantiates, mapped onto OpenTitan `prim_clock_gating` |

The wrapper ties `dft_cg_enable_i` and `low_speed_clk_i` to 0, synchronises
`i_tim_ext[3:0]` with two flip-flops into `ext_sig_i[3:0]` (`[31:4]` = 0), drives
`o_pwm[7:0]` from `ch_1_o`, `ch_0_o`, and leaves `ch_2_o`, `ch_3_o` unconnected
(MAS sections 5 and 10).

```bash
cd design/pwm/rtl/emacs && make     # regenerate after editing the .src.sv
```
