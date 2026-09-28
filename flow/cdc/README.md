# `flow/cdc/` — clock domain crossing (CDC stage)

There is no mature open-source CDC checker, so the CDC stage is **evidence plus
review**. The evidence is designed so that a reviewer can find every crossing
mechanically.

## Rules

1. **Every crossing is listed in the MAS** of the block that owns it: signal, from
   clock, to clock, how it crosses, constraint. `QNSC_SYSDBG_MAS` Table 7-4 is the
   model to copy.
2. **Every crossing goes through a named shared cell** in `design/common`, or through
   a handshake the MAS specifies. Instance names start with `u_sync_`, so
   `grep -rn u_sync_ design/<block>/rtl` finds every crossing.

   | Kind of signal | Cell |
   |---|---|
   | 1-bit level | `qnsc_sync_2ff` (two flops, reset value as a parameter) |
   | 1-bit event | toggle at the source, `qnsc_sync_2ff`, edge detect at the destination |
   | multi-bit bus | request/acknowledge handshake with the bus held stable, or an asynchronous FIFO |

   The shared cells are to be added to `design/common` by the maintainers. Until
   then a block writes its own, named `u_sync_*`, and says so in its MAS.
3. **A bus never crosses through per-bit synchronisers.** Its bits can arrive in
   different cycles.
4. A path that crosses without a synchroniser, because the protocol holds it stable,
   carries the `set_max_delay -datapath_only` its MAS states (see `flow/sta/README.md`).

## Reviewer checklist, for the pull request that marks CDC `done`

- [ ] Every entry in the MAS crossing table appears in the RTL, and nothing else crosses.
- [ ] Every crossing uses a rule-2 cell or the MAS handshake.
- [ ] Every stable-bus crossing has its SDC constraint.

## Crossings already known in QSOC

| Block | Crossing | Where it is specified |
|---|---|---|
| SYSDBG | `tck` ↔ `clk_cpu`: `read/write_req`, `read/write_ack`, `dbgreq`, `cpu_hold`, address and data buses | `QNSC_SYSDBG_MAS` 7.6, Table 7-4 |
| SYSDBG | `DBG_EN` pad (asynchronous) → `clk_cpu` | `QNSC_SYSDBG_MAS` 7.1 |
| PWM | `TIM_EXT` pads (asynchronous) → `clk_peri`, two flops in the wrapper | `QNSC_PWM_MAS` Table 5-1 |
| GPIO, UART, I2C, SPI | pad inputs (asynchronous) → `clk_peri`, synchronised inside the vendored IP | each IP's MAS |

`clk_cpu`, `clk_mem` and `clk_peri` share one root and are synchronous, so a path
between them is **not** a CDC crossing.
