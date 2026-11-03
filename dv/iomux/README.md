# `dv/iomux` — testbench of `m_qnsc_iomux`

`make sim BLOCK=iomux`. One simulation runs every test in `tests/`, in order;
each prints `iomux_NNN ok: ...` and the run ends with `PASS`.

The per-pad checks (`t_expect_pad`, `t_expect_idle`) are generated with the RTL
from the same table, `util/gen/iomux/iomux_pads.yml`, into
`util/gen/iomux/iomux_expect.svh` (`tb.f` adds the include path). They state the
table directly (pad k under code c: A is this signal, OE that one, Y reaches
this input), while the RTL implements it as a case per pad.

| Test | Covered |
|---|---|
| `iomux_001` | reset: PADSEL reads 0, every pad on b00, idle values |
| `iomux_002` | every pad under every code (A, OE, Y, unassigned = Hi-Z, idle values), then 20 random mixes |
| `iomux_003` | `i_dbg_en` forces PIN5-9 to JTAG, PADSEL unchanged, released again |
| `iomux_004` | PADSEL_1 reserved bits, unmapped offset, PSLVERR on misaligned address and partial PSTRB |
