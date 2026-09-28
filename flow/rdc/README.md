# `flow/rdc/` — reset domain crossing (RDC stage)

A reset domain crossing is a flop reset by one reset whose output is sampled by a
flop that is not reset at the same time. When the first flop resets asynchronously
in the middle of a cycle, the second can capture a metastable or wrong value.
There is no mature open-source RDC checker either, so the evidence is the MAS
reset table plus review.

## Rules

1. **Every block's MAS lists its reset domains**: which reset, from which source,
   which flops. `QNSC_SYSDBG_MAS` Table 7-2 is the model.
2. **Reset is asserted asynchronously and released synchronously**, through the
   reset synchroniser in SCRC. A block never releases a reset asynchronously itself.
3. **A signal from a domain that can reset alone** (for example the `S_BUS` domain
   during a watchdog or software reset) into a domain that stays up is either
   ignored while its source is in reset, or its MAS explains why a glitch there is
   harmless.

## Reset domains already known in QSOC

| Reset | Source | Resets | Stays up during it |
|---|---|---|---|
| POR | power-on only | everything | — |
| `i_rst_n_sysbus` | POR, watchdog, software reset | `S_BUS`, the SYSDBG AXI side | SYSDBG TCK and system sides |
| CPU reset | SCRC, OR `o_dbg_cpu_hold` in debug boot | Ibex | the rest of the chip |
| per-peripheral resets | SCRC `SOFT_RST_CTRL` | one peripheral | everything else |
| `i_jtag_trst_n` AND POR | JTAG probe, power-on | SYSDBG TCK side | SYSDBG AXI and system sides |

## Reviewer checklist, for the pull request that marks RDC `done`

- [ ] The MAS reset table matches the RTL.
- [ ] Every signal leaving a domain that can reset alone is handled as rule 3 says.
