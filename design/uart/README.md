# `uart` — serial ports

**Owner:** _TBD_   **Spec:** _not written yet_   **DV:** [`../../dv/uart`](../../dv/uart)

## What this block is

The two 16550-style UARTs of QSOC, on the peripheral bus at `APB_M9` and
`APB_M10` (`C_UART_0_BASE`, `C_UART_1_BASE`). `uart_0` carries the boot download.
Each raises one level interrupt (`C_INT_LINE_UART_0` / `C_INT_LINE_UART_1`) and has
TX and RX request lines to the DMA.

## Uses (IP)

| From | Module | Recorded in |
|------|--------|-------------|
| `pulp-platform/obi_peripherals` v0.1.1, patched | `obi_uart` and its submodules | [`vendor/manifest.yml`](../../vendor/manifest.yml) |
| `pulp-platform/obi` v0.1.7 | `obi_pkg`, `apb_to_obi`, `obi/typedef.svh` | [`vendor/manifest.yml`](../../vendor/manifest.yml) |
| `pulp-platform/apb` v0.2.4 | `apb_pkg`, `apb/typedef.svh` | [`vendor/manifest.yml`](../../vendor/manifest.yml) |
| `pulp-platform/common_cells` v1.38.0 | `fifo_v3`, `sync`, `counter`, `delta_counter`, `cf_math_pkg` | [`vendor/manifest.yml`](../../vendor/manifest.yml) |
| `pulp-platform/apb_uart` @ `8182a85` | reference only, not compiled | [`vendor/manifest.yml`](../../vendor/manifest.yml) |

The versions are the ones `apb_uart` @ `8182a85` depends on in its `Bender.yml`.
The wrapper is derived from upstream's `apb_uart_wrap.sv`, but instantiates
`apb_to_obi` + `obi_uart` directly, because `apb_uart_wrap` has no DMA ports.

QSOC adds the DMA handshake to `obi_uart` in
[`vendor/patches/pulp-platform_obi_peripherals/0001-add-dma-request-lines.patch`](../../vendor/patches/pulp-platform_obi_peripherals/0001-add-dma-request-lines.patch):

| Added | What it does |
|---|---|
| `dma_tx_req_o` | TX holding register / FIFO has room (`~thr_full_q`) |
| `dma_rx_req_o` | RX FIFO has reached its trigger level (`rx_fifo_trigger`) |

The registers sit at slot offsets `0x00`–`0x1C`, 32-bit aligned.

## The wrapper is the boundary

`rtl/` holds **only code written here**. Upstream IP is listed in
[`uart.f`](./uart.f), never copied into `rtl/`. Reading this one directory answers
what is ours and what is borrowed.

[`rtl/m_qnsc_wrap_apb_uart.sv`](rtl/m_qnsc_wrap_apb_uart.sv) does the following:

- **Port map:** maps the core to `i_clk_peri` / `i_rst_n_peri`, `i_bus_apb_*`
  (APB4), `o_int_uart` and `o_dma_*`.
- **Protocol:** adapts APB to OBI with `apb_to_obi`.
- **Tie-offs:** ties the modem inputs inactive and leaves the modem outputs open.
- **Added decode:** answers `PSLVERR` for any slot offset at or above `0x20`
  (`P_STRICT_DECODE`), which the core does not do.

The APB address width is `C_APB_PADDR_WIDTH` (12 bits) from the contract, the same
for both instances. Not yet agreed, from `tbd:` in the contract: the `CLK_EN` /
`SOFT_RST_CTRL` bit positions (SCRC owner) and the DMA channels that serve the UARTs
(DMA owner).

## Instances

Two. `design/top` instantiates `m_qnsc_wrap_apb_uart` as `u_uart_0` (`APB_M9`) and
`u_uart_1` (`APB_M10`). Both use the same parameters. What differs is only which
bus port, interrupt line and DMA channel each is wired to.
