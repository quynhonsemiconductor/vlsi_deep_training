# `iomux` — IO pin multiplexer

**Owner:** Ong Bao Vinh (handed over from @hieu-vubuiminh, 2026-10-30)   **Spec:** `QNSC_IOMUX_MAS` on the team SharePoint   **DV:** [`../../dv/iomux`](../../dv/iomux)

## What this block is

The pins between the peripherals and the pad ring, combinational. 24 pads are
muxed: each has one bit of `IOMUX_SEL`, 0 = b0, 1 = b1. 4 pads are fixed to one
function (I2C, TIM_EXT0/1). The selected function drives the pad (A, OE, IE) and receives its
value (Y). A peripheral input that no pad selects holds its idle value. With
`IOMUX_SEL` = 0 (reset) every muxed pad is on b0 (JTAG, UART0, GPIO), enough to
boot and debug before software runs.

The select is SYSCSR `o_iomux_sel` (`QNSC_SYSCSR_MAS` V3.6, 7.8): register
`IOMUX_SEL` (0x28, RW), cleared by every chip reset, with bits [4:0] forced to 0
(JTAG on PIN5-9) while SYSDBG `o_dbg_en` = 1; `IOMUX_STATUS` (0x2C) reads what
reaches the IO MUX. So this block has no APB slave, no clock, no reset and no
debug input.

An **integration** block (`flow/lint/module_rules.yml`): it knows the chip's
pins.

## Uses (IP)

| From | Module | Recorded in |
|------|--------|-------------|
| none -- designed in house | `m_qnsc_iomux` ([`rtl/`](rtl)) | -- |
| generated from [`util/gen/iomux/iomux_pads.yml`](../../util/gen/iomux) by [`util/gen_iomux.py`](../../util/gen_iomux.py) | `m_qnsc_iomux_mux` (datapath) | this README |

`iomux_pads.yml` is the one place the pin map is written (sheet "Pad List v3"
of the IOPAD pin summary, 2026-11-04). Change it, run `make gen IP=iomux`, and
the datapath and the testbench checks change together.

## Connections

What each block's wrapper drives and receives, and where it lands. Top connects
the wrapper's `*_pad_*` port to the IO MUX port of the same function.

| Block (wrapper port) | IO MUX port | Pins | Notes |
|---|---|---|---|
| `gpio_0..2` (`o_pad_gpio`, `o_pad_gpio_oe`, `i_pad_gpio`, 8 bits) | `i_gpio_<n>_out`, `i_gpio_<n>_oe`, `o_gpio_<n>_in` | see Pads | `gpio_dir` = 1 is output. `o_pad_gpio_cfg` is not used (pad controls are constants, v1) |
| `uart_0`, `uart_1` (`o_pad_uart_tx`, `i_pad_uart_rx`) | `i_uart_<n>_tx`, `o_uart_<n>_rx` | U0 PIN10/11 (b0), U1 PIN19/20 (b1) | TX has no enable: OE = 1. RX idle 1 |
| SPI wrapper (host or device inside; not written yet) | `i_spi_{sck,csb}`, `_oe`, `o_spi_{sck,csb}`, `i_spi_sd[1:0]`, `i_spi_sd_oe[1:0]`, `o_spi_sd[1:0]` | PIN15-18 (b1) | Standard SPI only. The wrapper drives `_oe` by role. Idle: SCK 0, CSB 1, SD 0 |
| `i2c` (`o_pad_i2c_*`, `o_pad_i2c_*_oe`, `i_pad_i2c_*`) | `i_i2c_{scl,sda}`, `i_i2c_*_oe`, `o_i2c_*` | PIN21, 22 | Open drain: data 0, OE active high (inverted once, in the wrapper). Idle 1 |
| `pwm` (`o_pad_pwm[7:0]`, `i_pad_tim_ext[3:0]`) | `i_pwm[7:0]`, `o_tim_ext[3:0]` | PWM b1 (timer0 PIN23-26, timer1 PIN29-32); TIM_EXT0/1 PIN33/34, TIM_EXT2/3 b1 PIN38/39 | PWM OE = 1. TIM_EXT idle 0 (synchronised in the wrapper) |
| SYSDBG JTAG TAP | `o_jtag_{tck,tms,tdi,trst_n}`, `i_jtag_tdo`, `i_jtag_tdo_oe` | PIN5-9 (b0) | Idle TCK 0, TMS 1, TDI 1, TRSTN 0 (TAP held in reset), as SYSCSR MAS INT-14 |
| SYSCSR (`o_iomux_sel`) | `i_iomux_sel[23:0]` | -- | IOMUX_SEL with the JTAG lock applied |

Not through the IO MUX: PIN1 OSCIN and PIN4 RSTN (SCRC `i_clk_pad`,
`i_rst_n_pad`), PIN35 DBG_EN (SYSDBG and SYSCSR), and the power pins.

Facts of the vendored IP the table relies on (each with `file:line` in the
table's `evidence`):

- `apb_gpio`: `gpio_dir` = 1 is output; `gpio_in` is synchronised inside;
- `apb_uart`: `SOUT` has no enable; `SIN` = 0 is a start bit, so idle is 1;
- `apb_i2c`: `scl_padoen_o` / `sda_padoen_o` are active low and the data out is
  0 (open drain); the I2C wrapper inverts the enable for the active-high pad OE;
- `apb_adv_timer`: `ch_0_o`, `ch_1_o` reach the pads as PWM_0..7;
- `spi_host` / `spi_device`: `cio_*_o`, `cio_*_en_o`, `cio_*_i`; CSB active low.

## Pads

Vector index k of `o_pad_out` / `o_pad_oe` / `o_pad_ie` / `i_pad_in`.

| k | PIN | `IOMUX_SEL` bit | b0 (reset) | b1 |
|---|---|---|---|---|
| 0-4 | 5-9 | 0-4 | TCK TMS TDI TDO TRSTN (locked by SYSCSR while `o_dbg_en`) | GPIO0_7..3 |
| 5, 6 | 10, 11 | 5, 6 | UART0_TX, UART0_RX | GPIO0_2, GPIO0_1 |
| 7 | 12 | 7 | GPIO0_0 | -- (reserved) |
| 8-11 | 15-18 | 8-11 | GPIO1_7..4 | SPI_SCK, SPI_CSB, SPI_SD0, SPI_SD1 |
| 12, 13 | 19, 20 | 12, 13 | GPIO1_3, GPIO1_2 | UART1_TX, UART1_RX |
| 14, 15 | 21, 22 | -- | I2C_SCL, I2C_SDA | -- |
| 16-21 | 23-26, 29, 30 | 14-19 | GPIO1_1, GPIO1_0, GPIO2_7..4 | PWM_0..5 |
| 22, 23 | 31, 32 | 20, 21 | GPIO2_3, GPIO2_2 | PWM_6, PWM_7 |
| 24, 25 | 33, 34 | -- | TIM_EXT0, TIM_EXT1 | -- |
| 26, 27 | 38, 39 | 22, 23 | GPIO2_1, GPIO2_0 | TIM_EXT2, TIM_EXT3 |

PIN40 is not an IO MUX pad (VSSIO_3 proposed, else reserved in the pad ring).

IE is 1 for a function that receives (input or inout) and 0 for one that only
drives (UART TX, PWM, TDO). The other pad cell controls (IS, PE, PS, DS0, DS1,
SR of `PBIDIR_18_18_NT_DR`) are constants per pad in the pad ring, values from
the pin justification table.

## Open

- `IOMUX_SEL`: 24 bits, the bit order of `QNSC_SYSCSR_MAS` V3.6. Only the names
  change (SYSCSR owner to update Tables 6-9, 6-10): bit 7 PIN12 b1 UART1_TX ->
  reserved; bits 12/13 PIN19/20 b1 SPI_SD2/SD3 -> UART1_TX/UART1_RX
  (2026-11-05: SPI has no Dual/Quad, UART1 moved next to its pair); bits
  20-23 PIN31/32/38/39 now GPIO2_3/2_2/2_1/2_0 with b1 PWM_6/PWM_7/TIM_EXT2/
  TIM_EXT3 (timer1 = `ch_1_o`, `apb_adv_timer.sv:438`, on PIN29-32; GPIO2 in
  pin order; switching outputs away from OSCIN, ARM DDI 0555G 5-31).
- PIN40: VSSIO_3 proposed (ground on both sides of OSCIN, one more bonded
  PDVSS against SSN, ARM DDI 0555G 5-30/5-31), waiting for the mentor.
- Pad ring (not this block): ESD Rules 4, 5a, 9a of ARM DDI 0555G 5-37..5-39
  (paired I/O power cells, core clamps, top side I/O power distance) with
  unbonded power cells; drive strength and slew rate per pad from the SSN budget.
- The SPI wrapper is assumed to choose host or device and present one set.
- The pad cells (A / OE / IE / Y, and IS, PE, PS, DS, SR) are in `m_qnsc_chip`, later.

## Instances

One, in `design/top`.
