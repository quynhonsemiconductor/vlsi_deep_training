# `pwm` — PWM / advanced timer

**Owner:** @Nghia-VanTrong   **Spec:** [`doc/specs/QNSC_PWM_MAS.md`](../../doc/specs/QNSC_PWM_MAS.md) (build to .docx via `doc/build/build_docs.py`)   **DV:** [`../../dv/pwm`](../../dv/pwm)

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
`rtl/`, borrowed in `vendor/`; [`pwm.f`](./pwm.f) lists both.

| File | What it is |
|---|---|
| `rtl/m_qnsc_wrap_apb_adv_timer.sv` | **the wrapper, one file**: port groups, added logic and `AUTO_TEMPLATE`s written by hand; the blocks between `// Beginning of automatic` and `// End of automatics` written by `make wrap BLOCK=pwm` in place |
| `rtl/emacs/Makefile`, `rtl/emacs/filelist_emacs.f` | how emacs is run, and the modules whose ports it reads (`apb_adv_timer`, `qnsc_sync`) |
| `rtl/pulp_clock_gating.sv` | the clock gate `apb_adv_timer` instantiates but does not ship, mapped onto OpenTitan `prim_clock_gating` |
| `waivers.vlt` | lint waivers, each with its reason |

What the wrapper adds (MAS 5, 7.3, 10): `i_pad_tim_ext[3:0]` through
`qnsc_sync` into `ext_sig_i[3:0]` (`[31:4]` = 0), `o_pad_pwm[7:0]` =
`{ch_1_o, ch_0_o}`, `ch_2_o`/`ch_3_o` open, `dft_cg_enable_i` and
`low_speed_clk_i` tied to 0.

## Instances

One, `u_pwm` in `design/top`, on `APB_M12` (`C_PWM_BASE`), interrupts to
`INTMAP` line `C_INT_LINE_PWM`.
