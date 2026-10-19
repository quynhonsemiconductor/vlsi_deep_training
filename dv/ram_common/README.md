# `dv/ram_common` — what `tb_isram` and `tb_dsram` share

Not a block: no `design/ram_common`, no `tb_ram_common.sv`. A change here runs both
RAM testbenches in CI (`flow/sim/ci_sim.sh`).

| File | What |
|---|---|
| `ram_tb.svh` | The testbench body, included inside `tb_isram` and `tb_dsram`: clock, reset, an AXI4 master (`send_aw`, `send_w`, `send_ar`, `wr1`, `rd1`, `wr_burst`, `rd_burst`), the response monitors, the FIFO occupancy check, the watchdog |
| `tb_sram_model.sv` | The macro: byte write enables, read data in the cycle after `oe`, **no reset** (QNSC_RAM_MAS 7.6). The IP's own model has no byte enables and resets its array |
| `tests/ram_NNN.svh` | One test per MAS 12 item, `NNN` the item |
| `tb.f` | The model; each block's `tb.f` points here |

**Driving.** The testbench drives 1 ns after a clock edge with blocking assignments and
samples at the edge. A cycle number is the cycle a handshake is sampled in, and a timing
figure is the difference of two. A first version used nonblocking assignments, and a burst
of back-to-back beats stalled after the first beat: the second beat's data arrived and its
`valid` did not (observed with Verilator 5.052, with and without an intra-assignment delay;
not isolated further). Blocking assignments 1 ns after the edge do not have the problem.
Every handshake wait now has a limit and the whole run a watchdog, so a hang is a failure.

**What the tests have found.** `RAM_012` found that a 256-beat burst is dropped by the
controller unless `PARA_LEN_WD` is 9 (QNSC_RAM_MAS 7.2). `RAM_013` states the other finding:
the write-response FIFO drops a ninth pending response (7.1). Mutations the tests catch: `o_mem_be`
not gated by the strobe, the strobe FIFO popped by a read, `o_mem_addr` one bit off, and
`PARA_LEN_WD` back at 8.
