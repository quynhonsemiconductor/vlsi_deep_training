# `i2c` — I2C controller

**Owner:** @Vinh-OngBao   **Spec:** `Vinh_QNSC_I2C_Core_IP.docx` (kept by the owner; not yet in `doc/src/`)   **DV:** [`../../dv/i2c`](../../dv/i2c)

## What this block is

The I2C master of QSOC, on the peripheral bus at `APB_M12` (`C_I2C_BASE`). It
raises one level interrupt on fast line `C_INT_LINE_I2C` and can be fed by the DMA
through a TX and an RX request line, so a burst of bytes moves without the CPU
issuing a command per byte.

## Uses (IP)

| From | Module | Recorded in |
|------|--------|-------------|
| `pulp-platform/apb_i2c` @ `8485541`, patched | `apb_i2c`, `i2c_master_byte_ctrl`, `i2c_master_bit_ctrl` | [`vendor/manifest.yml`](../../vendor/manifest.yml) |

The upstream core is the OpenCores I2C master behind an APB slave. QSOC adds a DMA
handshake to it in
[`vendor/patches/pulp-platform_apb_i2c/0001-add-dma-request-lines.patch`](../../vendor/patches/pulp-platform_apb_i2c/0001-add-dma-request-lines.patch):

| Added | What it does |
|---|---|
| `REG_TXCMD` at `0x18` | One write loads the TX byte and issues WR. START and STOP come from `PWDATA[8]` and `PWDATA[9]` |
| `REG_RXCMD` at `0x1C` | One read returns the received byte and issues the next RD |
| `dma_tx_req_o` | Core enabled and no transfer in progress |
| `dma_rx_req_o` | A byte read through `REG_RXCMD` is waiting |
| `dma_last_i` | Driven by the DMA on the last read of a burst: the next RD is NACK+STOP |

Registers `0x00`–`0x14` behave as upstream. Facts the wrapper relies on, read from
`apb_i2c.sv`: the core decodes only `PADDR[5:2]`, `PREADY` is tied high, `PSLVERR`
is tied low, and the pad outputs are open drain (`*_pad_o` is always 0, and
`*_padoen_o` is active low).

## The wrapper is the boundary

`rtl/` holds **only code written here**. Upstream IP is listed in
[`i2c.f`](./i2c.f), never copied into `rtl/`. Reading this one directory answers
what is ours and what is borrowed.

[`rtl/m_qnsc_wrap_apb_i2c.sv`](rtl/m_qnsc_wrap_apb_i2c.sv) does the following:

- **Port map:** maps the core to `i_clk_peri` / `i_rst_n_peri`, `i_bus_apb_*`,
  `o_int_i2c` and `o_dma_*` / `i_dma_last`.
- **Pins:** hands SCL and SDA to IOMUX as input / output / output enable
  (`o_i2c_*_oe = ~*_padoen_o`, active high). The tri-state is left to the pad ring, the
  same split SYSDBG uses for `tdo_oe_o`.

The APB address width is `C_APB_PADDR_WIDTH` (12 bits) from the contract. Not yet
agreed, from `tbd:` in the contract: the `CLK_EN` / `SOFT_RST_CTRL` bit positions
(SCRC owner) and the DMA channel that serves I2C (DMA owner).

## Instances

One. `design/top` instantiates `m_qnsc_wrap_apb_i2c` once, as `u_i2c`.
