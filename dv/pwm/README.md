# `dv/pwm` — PWM testbench

Testbench of `m_qnsc_wrap_pwm` against `QNSC_PWM_MAS` section 12. One test per MAS
check, in `tests/<name>.svh`, each starting from reset and self-checking.

```bash
make sim BLOCK=pwm                         # every test
make sim BLOCK=pwm TEST=pwm_005            # one test
make sim BLOCK=pwm TEST=pwm_005 WAVES=1    # and build/sim/pwm_pwm_005/waves.vcd
```

| MAS check | Test | Covered |
|---|---|---|
| `PWM_001` pad mapping | `pwm_001` | full: each of the 16 channels alone; timers 2, 3 reach no pad |
| `PWM_002` reset values | `pwm_002` | full: every register of the 4 timers, `EVENT_CFG`, `CH_EN`; outputs 0 |
| `PWM_003` `START` needs `CH_EN` | `pwm_003` | full |
| `PWM_004` period | `pwm_004` | `SAW` = 1 and 0, with `START` ≠ 0 and `PRESC` ≠ 0 |
| `PWM_005` output MODE | `pwm_005` | part: MODE 0, 2, 4, 6 with `SAW` = 1. MODE 1, 3, 5, 7 and `SAW` = 0 not yet |
| `PWM_006` channel independence, `CHn_LUT` | -- | not yet |
| `PWM_007` `STOP`, `STOP` \| `RST` | `pwm_007` | full |
| `PWM_008` events | `pwm_008` | line 0: one-cycle pulse per rising edge, none from a static channel, none with `EN` = 0. Lines 1-3 not yet |
| `PWM_009` input stage | `pwm_009` | part: `IN_MODE` 3 on each `TIM_EXT` pin. Other `IN_MODE` values and channel feedback not yet |
| `PWM_010` holes, alias, no error | `pwm_010` | full |
| `PWM_011` when new values take effect | -- | not yet; `pwm_005` records one measured fact (below) |

Measured, to be stated in the MAS (`PWM_011` is "confirm in simulation"): with
`SAW` = 1 and MODE 6 RSTSET, a channel is high `TH` + 1 cycles per period (251 of
1000 for `TH` = 250, `END` = 999); it rises at the start of the period and falls one
cycle after the counter passes `TH`. SETRST with the same `TH` is its exact complement.

Each test was checked to fail: changing its expected value makes it call `$fatal`.
