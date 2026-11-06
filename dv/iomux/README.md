# `dv/iomux` — testbench of `m_qnsc_iomux`

`make sim BLOCK=iomux`. The DUT is combinational: the testbench drives
`i_iomux_sel` (SYSCSR `o_iomux_sel`, debug force applied there) directly. One
simulation runs every test in `tests/`, in order; each prints `iomux_NNN ok: ...` and the run ends with `PASS`.

The per-pad checks (`t_expect_pad`, `t_expect_idle`) are generated with the RTL
from the same table, `util/gen/iomux/iomux_pads.yml`, into
`util/gen/iomux/iomux_expect.svh` (`tb.f` adds the include path). They state the
table directly (pad k using b0 or b1: A is this signal, OE that one, IE, Y
reaches this input), while the RTL implements it as an `if` per pad.

| Test | Covered |
|---|---|
| `iomux_001` | IOMUX_SEL = 0 (reset): every muxed pad on b0, fixed pads, idle values |
| `iomux_002` | both functions of every pad (A, OE, IE, Y, idle values): all 1, each bit alone, 40 random selects |
| `iomux_003` | the SYSCSR JTAG lock (`o_iomux_sel[4:0]` = 0): JTAG on PIN5-9, other pads free; JTAG idle values (TCK 0, TMS 1, TDI 1, TRSTN 0) |
| `iomux_004` | by name, not through the table: I2C open drain, IE of output-only pads, UART1 on PIN19/20 (RX idle 1), reserved PIN12 b1, fixed TIM_EXT0 on PIN33 |
