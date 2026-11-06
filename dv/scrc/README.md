# `dv/scrc` — SCRC + APB guard

`tb_scrc.sv` is self-checking. The DUT is `design/scrc/scrc.f` with the generic
technology cells: the real MRV-CPU running the generated CRM ROM, the generated APB
BUS and SCRC CSR, and one `m_qnsc_scrc_apb_guard` on uart_0 in front of a slow APB
slave clocked by the gated `o_clk_uart_0`. The delay cells of the generic
`qnsc_rst_filter` model 1 ns each, which is what `flt_001` measures against.

Models in the testbench:
- aon_timer bite request (sticky, on the `sys` domain, cleared by `o_rst_n_sys`);
- Ibex as an APB master on `APB_M0` and on the uart_0 slot;
- the pad clock, which a test can stop.

SYSCSR is tested in `dv/syscsr` with its own block.

## Running

```bash
make sim BLOCK=scrc                 # Verilator (flow/sim/run_sim.sh), all tests
make sim BLOCK=scrc TEST=rst_001    # one test
WAVES=1 make sim BLOCK=scrc         # also writes build/sim/scrc/waves.vcd
```

## Coverage of QNSC_SCRC_MAS V3.5 section 12

Domain bit n is domain n of MAS Table 6-3: 0 sys, 1 cpu (always-on), 2 timer_0, 3 timer_1,
4 uart_0, 5 uart_1, 6 spi, 7 i2c, 8-10 gpio_0..2, 11 dma, 12 pwm (gateable mask `0x1FFC`).

| Test | Checks |
|---|---|
| `rst_001` | SCRC_RST_001 (POR releases `w_rst_n_chip` 1 cycle after `o_rst_n_por`; WDT and SW resets are exactly 16 cycles), SCRC_RRC_001 (request cleared by its own reset; `o_csr_rst_cause_wdt` high for exactly 16 cycles, `_sw` 0), SCRC_RST_005 (`o_rst_n_por`, the reset of SYSCSR and SYSDBG, stays 1); MAS 7.3 joint requests: a WDT request in the cycle `SW_RST` reaches `RRC` gives one 16-cycle reset with both causes for all 16 cycles, and a WDT request two cycles after the SW load is absorbed (one reset, no WDT cause). The WDT request is forced at `u_rrc.w_wdt_req` for one cycle, aligned to the real `SW_RST` edge, so the result does not depend on where MCPU is in its loop |
| `rst_002` | SCRC_RST_002 (`o_rst_n_sys` releases on the 2nd edge of `o_clk_sys` after `RST_REL[0]`); `PORSTN` with the clock stopped asserts `o_rst_n_por` and all 13 `o_rst_n_<d>` |
| `rst_003` | Power-up order on the real MCPU program: ICG_EN = 0x0000_1FF4 ≥ 3 cycles before RST_REL; SCRC_RST_003 (non-CPU together, CPU ≥ 16 cycles later); SCRC_RST_007 (APB_BLK = 0x08 before the CPU releases); RST_REL = 0x0000_1FFF; SCRC_CLK_002; SCRC_CLK_003 and SCRC_RST_008 (timer_1 gated and in reset until CLK_EN[3]) |
| `aon_001` | SCRC_CLK_002, MAS 7.1 (V3.5): software cannot stop `sys` or `cpu`. Ibex writes CLK_EN = `0xFFFF_E003` (every gateable bit 0, bits 1:0 set): CLK_EN reads 0, ICG_EN 0, APB_BLK `0x1FFC`, every gateable clock stops, `o_clk_sys`/`o_clk_cpu` keep toggling and `o_rst_n_sys`/`o_rst_n_cpu` stay 1; Ibex writes to ICG_EN, RST_REL, APB_BLK answer `PSLVERR` and change nothing |
| `clk_001` | SCRC_CLK_001 (with every gate open, all 13 domain clocks equal the root clock, sampled after both edges) |
| `flt_001` | SCRC_FLT_001 (a 2 ns `PORSTN` glitch does not reset; a 5 ns pulse is a power-on reset) |
| `csr_001` | SCRC_CSR_001 (every row of Table 7-2), SCRC_CSR_002 (reset values, implemented bits); `0x3FFC`, `0x1000`, `0x1004` answer `PSLVERR`, and a write of 1 to `0x1000` does not reset the chip (no alias) |
| `seq_001` | SCRC_SEQ_001 (back-to-back CLK_EN writes) |
| monitor | SCRC_SEQ_002 (APB_BLK[n] = 0 only if ICG_EN[n] = 1, every cycle); SCRC_BUS_003 (ICG_EN[4] never 0 while PSEL reaches the IP; watched at the IP side, not through the guard's busy output) |
| `bus_001` | SCRC_BUS_001, SCRC_BUS_002 (stand-alone guard), SCRC_BUS_003 (a 200-wait-state transfer in flight when the clock stop is requested: it completes normally and the clock stops after it), recovery of MAS Table 7-5 |
| `wf_001` | SCRC_CSR_001, write-filter rows of Table 7-2: both filters of the DUT at the 8 word offsets, read and write, forwarded or denied with `PSLVERR`; above `0x1F` everything is forwarded. MCPU's outputs are forced for a moment, the Ibex side is the testbench's `APB_M0` |

SCRC_IMP_001 (no cell but the root buffer and one clock gate on any `o_clk_<d>`
path) is structural: `make connectivity BLOCK=scrc` and the RTL show it.

`check()` fails on X or Z as well as on 0, and an unknown `+test=` name stops the run
with `$fatal`.

Result on 2026-11-05 (V3.5): **10 tests PASS** on Verilator 5.052 (the image CI's
Simulation job uses, `verilator/verilator:v5.052`) and on 5.020 (`make sim BLOCK=scrc` in
the lint image; 5.020 once aborted while compiling with "attempted to destroy locked
Thread Pool", a Verilator crash before any simulation, and passed on the two reruns). The
Verilator lint (`make lint`, `-Wall`) gives 0 warnings with `design/scrc/waivers.vlt`.

Mutation check, to show the testbench can fail. Each of these faults, injected one
at a time, makes the named test fail:
- the reset synchroniser releases after one edge instead of two (`rst_002`);
- the glitch filter clears on the pad alone, without its delay taps (`flt_001`);
- MCPU's write filter lets it write `SW_RST` (`P_WR_DENY` = `8'b0100_0010`) (`wf_001`);
- `RRC` never captures the WDT cause (`rst_001`);
- the guard never reports busy, so MCPU stops the clock under a transfer (`bus_001`);
- the `cpu` controller's gate enable taken from `ICG_EN` (timer_0) instead of the
  constant 1 (`aon_001`; `rst_001` and `rst_003` still pass, 2026-11-05);
- a misspelled `+test=` name (`$fatal`).
