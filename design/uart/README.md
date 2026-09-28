# `uart` — serial ports

**Owner:** @Vinh-OngBao   **Spec:** [`QNSC_UART_MAS.md`](../../doc/specs/QNSC_UART_MAS.md)   **DV:** [`../../dv/uart`](../../dv/uart)

## What this block is

Two 16550A-compatible serial ports on `APB_M8` and `APB_M9`. `UART0` carries the
boot download. Upstream `apb_uart` wrapped unmodified by `m_qnsc_wrap_uart`.

## Uses (IP)

| From | Module | Recorded in |
|------|--------|-------------|
| `pulp-platform/apb_uart`, `pulp-platform/obi_peripherals` | `apb_uart` around `obi_uart` | [`vendor/manifest.yml`](../../vendor/manifest.yml) |

## The wrapper is the boundary

`rtl/` holds **only code written here**. Upstream IP is listed in
[`uart.f`](./uart.f), never copied into `rtl/`. Reading this one directory answers
what is ours and what is borrowed.

## Instances

Two, `UART0` and `UART1`, identical; they differ only in their connections.
