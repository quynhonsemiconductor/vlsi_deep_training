# `dv/dsram` — DSRAM testbench

`tb_dsram.sv` instantiates `m_qnsc_wrap_dsram` and a behavioural macro of 8192 words
(13 word-address bits, controller byte address `[14:2]`). The body of the testbench and
the tests are shared with the other RAM and live in [`../ram_common`](../ram_common); this
directory sets the depth and nothing else.

```bash
make sim BLOCK=dsram                 # every test
make sim BLOCK=dsram TEST=ram_005    # one test
```

| Test | MAS 12 item | Checks |
|---|---|---|
| `RAM_001` | 1 | 15 non-zero `WSTRB` patterns write only their bytes, `0000` none |
| `RAM_002` | 2 | `STRBFIFO` and `WFIFO` hold the same number of entries in every cycle (also checked in every other test); the FIFOs are filled on purpose |
| `RAM_004` | 4 | every value of the timing table of MAS 7.1, at the block ports |
| `RAM_005` | 5 | `B` and `R` in acceptance order with the request's ID, through full FIFOs |
| `RAM_006` | 6 | WRAP and the reserved burst code give INCR addresses (accepted limit) |
| `RAM_007` | 7 | `o_mem_addr` is the byte address word index; unaligned beats hit their word; upper address bits ignored |
| `RAM_008` | 8 | `BRESP` and `RRESP` are `00`; `RLAST` on the last beat only |
| `RAM_009` | 9 | reset values; contents survive a reset pulse; an in-flight read is dropped |
| `RAM_012` | added | INCR of 1 to 256 beats, FIXED of 1 to 16, 300 random bursts against a reference memory, `B`/`R` stalled at random |
| `RAM_013` | added | 8 held write responses are all delivered; a ninth is dropped (accepted limit) |

Not simulated: item 3 (a C program on the CPU), item 10 (macro pins; the testbench has a
model, not the macro), item 11 (the vendored files, checked by CI).
