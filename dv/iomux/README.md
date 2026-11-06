# `dv/iomux` — testbench of `m_qnsc_iomux`

`make sim BLOCK=iomux`. The DUT is combinational: the testbench drives
`i_iomux_sel` (SYSCSR `o_iomux_sel`, debug force applied there) directly. One
simulation runs every test in `tests/`, in order; each prints `iomux_NNN ok: ...` and the run ends with `PASS`.

The per-pad checks (`t_expect_pad`, `t_expect_idle`) are generated with the RTL
from the same table, `util/gen/iomux/iomux_pads.yml`, into
`util/gen/iomux/iomux_expect.svh` (`tb.f` adds the include path). They state the
table directly (pad k using code b00, b01 or b10: A is this signal, OE that
one, IE, Y reaches this input), while the RTL implements it as a `case` per pad.
An unassigned code (b11, or b10 outside PIN23-26; `f_max_code` in the
testbench) is checked as OE = 0, IE = 0.

| Test | Covered |
|---|---|
| `iomux_001` | IOMUX_SEL = 0 (reset): every muxed pad on b00, fixed pads, idle values |
| `iomux_002` | every assigned code of every pad (A, OE, IE, Y, idle values): all b01, b10 on PIN23-26, each field alone on each code, 40 random assigned selects |
| `iomux_003` | unassigned codes: all b11, each unassigned code of each field alone, 40 fully random selects; PIN11 b11 keeps UART0 RX at idle 1 |
| `iomux_004` | by name, not through the table: I2C open drain, IE of output-only pads, UART1 on PIN19/20 (RX idle 1), TIM_EXT0 on PIN33, SPID on PIN23-26 b10 (MISO enable, CSB idle 1) |
