# `iomux` — IO pin multiplexer

**Owner:** Ong Bao Vinh (handed over from @hieu-vubuiminh, 2026-10-30)   **Spec:** `QNSC_IOMUX_MAS` on the team SharePoint   **DV:** [`../../dv/iomux`](../../dv/iomux)

## What this block is

The pins between the peripherals and the pad ring. Each of the 28 muxed pads
has a 2-bit select in `PADSEL`: the selected function drives the pad (A, OE)
and receives its value (Y); a peripheral input that no pad selects holds its
idle value. After reset every select is b00 (JTAG, UART0, I2C, GPIO), enough to
boot and debug before software runs. While SYSDBG's `o_dbg_en` is 1 the five
JTAG pads stay on JTAG whatever `PADSEL` holds.

An **integration** block (`flow/lint/module_rules.yml`): it knows the chip's
pins.

## Uses (IP)

| From | Module | Recorded in |
|------|--------|-------------|
| none -- designed in house | `m_qnsc_iomux` ([`rtl/`](rtl)) | -- |
| generated from [`util/gen/iomux/iomux_pads.yml`](../../util/gen/iomux) by [`util/gen_iomux.py`](../../util/gen_iomux.py) | `m_qnsc_iomux_mux` (datapath) | this README |
| `nguyenquanicd/APB-CSR-Generator`, output committed in [`util/gen/iomux`](../../util/gen/iomux) | `m_qnsc_iomux_csr` (PADSEL) | [`vendor/manifest.yml`](../../vendor/manifest.yml) |

`iomux_pads.yml` is the one place the pin map is written (sheet "Pad List v2"
of the IOPAD pin summary, 2026-11-03). Change it, run `make gen IP=iomux`, and
the datapath, the registers and the testbench checks change together.

Facts of the vendored IP the table relies on (each with `file:line` in the
table's `evidence`):

- `apb_gpio`: `gpio_dir` = 1 is output; `gpio_in` is synchronised inside;
- `apb_uart`: `SOUT` has no enable; `SIN` = 0 is a start bit, so idle is 1;
- `apb_i2c`: `scl_padoen_o` / `sda_padoen_o` are active low and the data out is
  0 (open drain), so the IO MUX inverts the enable for the active-high pad OE;
- `apb_adv_timer`: `ch_0_o`, `ch_1_o` reach the pads as PWM_0..7;
- `spi_host` / `spi_device`: `cio_*_o`, `cio_*_en_o`, `cio_*_i`; CSB active low.

## Registers

| Offset | Register | Bits | Reset |
|---|---|---|---|
| `0x0` | `PADSEL_0` | `[2k+1:2k]` select of pad k, k = 0..15 | `0` |
| `0x4` | `PADSEL_1` | `[2k+1:2k]` select of pad 16+k, k = 0..11; `[31:24]` reserved, read 0 | `0` |

Other offsets read 0 and ignore writes. A misaligned address or a partial
`PSTRB` answers `PSLVERR`. `PPROT` is connected, not checked.

## Pads

| Pad | PIN | b00 | b01 |
|---|---|---|---|
| 0-4 | 5-9 | TCK TMS TDI TDO TRSTN (forced while `i_dbg_en`) | GPIO0_7..3 |
| 5, 6 | 10, 11 | UART0_TX, UART0_RX | GPIO0_2, GPIO0_1 |
| 7 | 12 | GPIO0_0 | UART1_TX |
| 8-13 | 15-20 | GPIO1_7..2 | SPI_SCK, SPI_CSB, SPI_SD0..3 |
| 14, 15 | 21, 22 | I2C_SCL, I2C_SDA | UART1_RX, -- |
| 16-21 | 23-26, 29, 30 | GPIO1_1, GPIO1_0, GPIO2_7..4 | PWM_0..5 |
| 22-25 | 31-34 | GPIO2_1, GPIO2_0, TIM_EXT2, TIM_EXT3 | TIM_EXT0, TIM_EXT1, --, -- |
| 26, 27 | 38, 39 | GPIO2_3, GPIO2_2 | PWM_6, PWM_7 |

b10 and b11 are unassigned on every pad: OE = 0. Dedicated pins, not muxed:
PIN1 OSCIN and PIN4 RSTN (SCRC), PIN35 DBG_EN (SYSDBG and SYSCSR). PIN40 is
open in Pad List v2.

## Open

- P_BUS slot (proposed APB_M14, `0x8003_8000`) and clock cluster: not in the
  contract yet. The ports follow every APB slave (`i_clk_peri`, `i_rst_n_peri`).
- The SPI wrapper is assumed to choose host or device and present one set.
- The pad cells (A / OE / Y, and IE, PE, PS, DS, SR) are in `m_qnsc_chip`, later.

## Instances

One, in `design/top`.
