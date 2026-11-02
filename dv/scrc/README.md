# `dv/scrc` — SCRC + APB guard

`tb_scrc.sv` is self-checking. The DUT is `design/scrc/scrc.f` with the generic
technology cells: the real MRV-CPU running the generated CRM ROM, the generated APB
BUS and SCRC CSR, and one `m_qnsc_scrc_apb_guard` on uart_0 in front of a slow APB
slave clocked by the gated `o_clk_uart_0`. The delay cells of the generic
`qnsc_rst_filter` model 1 ns each, which is what `flt_001` measures against.

Models in the testbench:
- aon_timer bite request (sticky, cleared by `o_rst_n_wdt`);
- Ibex as an APB master on `APB_M0` and on the uart_0 slot;
- the pad clock, which a test can stop.

SYSCSR is tested in `dv/syscsr` with its own block.

## Running

```bash
make sim BLOCK=scrc                 # Verilator (flow/sim/run_sim.sh), all tests
make sim BLOCK=scrc TEST=rst_001    # one test
WAVES=1 make sim BLOCK=scrc         # also writes build/sim/scrc/waves.vcd
```

## Coverage of QNSC_SCRC_MAS V3.4 section 12

| Test | Checks |
|---|---|
| `rst_001` | SCRC_RST_001 (POR releases `w_rst_n_sys` 1 cycle after `o_rst_n_por`; WDT and SW resets are exactly 16 cycles), SCRC_RRC_001 (request cleared by its own reset; `o_cause_we_wdt` high for exactly 16 cycles, `_sw` 0), SCRC_RST_005; a WDT bite in the cycle of an `SW_RST` write gives one 16-cycle reset and no second one |
| `rst_002` | SCRC_RST_002 (`o_rst_n_sbus` releases on the 2nd edge of `o_clk_sbus` after `RST_REL[0]`); `PORSTN` with the clock stopped asserts `o_rst_n_por` and all 18 `o_rst_n_<d>` |
| `rst_003` | Power-up order on the real MCPU program: ICG_EN = 0x0003_87E8 ≥ 3 cycles before RST_REL; SCRC_RST_003 (non-CPU together, CPU ≥ 16 cycles later); SCRC_RST_007 (APB_BLK = 0x10 before the CPU releases); SCRC_CLK_002; SCRC_CLK_003 and SCRC_RST_008 (timer_1 gated and in reset until CLK_EN[4]) |
| `clk_001` | SCRC_CLK_001 (with every gate open, all 18 domain clocks equal the root clock, sampled after both edges) |
| `flt_001` | SCRC_FLT_001 (a 2 ns `PORSTN` glitch does not reset; a 5 ns pulse is a power-on reset) |
| `csr_001` | SCRC_CSR_001 (every row of Table 7-2), SCRC_CSR_002 (reset values, implemented bits); `0x3FFC`, `0x1000`, `0x1004` answer `PSLVERR`, and a write of 1 to `0x1000` does not reset the chip (no alias) |
| `seq_001` | SCRC_SEQ_001 (back-to-back CLK_EN writes) |
| monitor | SCRC_SEQ_002 (APB_BLK[n] = 0 only if ICG_EN[n] = 1, every cycle); SCRC_BUS_003 (ICG_EN[5] never 0 while a transfer is forwarded) |
| `bus_001` | SCRC_BUS_001, SCRC_BUS_002 (stand-alone guard), SCRC_BUS_003 (IP with 30 wait states), recovery of MAS Table 7-5 |

SCRC_IMP_001 (no cell but the root buffer and one clock gate on any `o_clk_<d>`
path) is structural: `make connectivity BLOCK=scrc` and the RTL show it.

Result on 2026-11-02: **all PASS** on Verilator 5.020 (`make sim BLOCK=scrc`, the
version CI installs). The Verilator lint (`make lint`, `-Wall`) gives 0 warnings
with `design/scrc/waivers.vlt`.

Mutation check, to show the testbench can fail. Each of these faults, injected one
at a time, makes the named test fail:
- the reset synchroniser releases after one edge instead of two (`rst_002`);
- the glitch filter clears on the pad alone, without its delay taps (`flt_001`).
