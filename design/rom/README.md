# `rom` — boot ROM

**Owner:** _TBD_   **Spec:** _TBD_   **DV:** [`../../dv/rom`](../../dv/rom)

## What this block is

2 KiB of read-only memory at `0x0000_0000` on `AXI_M0`, holding the serial
bootloader. With no flash, this is the only code present when the chip leaves
reset, so it is the first thing the core fetches and the only thing that can put
an application into RAM.

## Uses (IP)

| From | Module | Recorded in |
|------|--------|-------------|
| `nguyenquanicd/AXI4-SRAM-CONTROLLER` | same controller as ISRAM and DSRAM | [`vendor/manifest.yml`](../../vendor/manifest.yml) |

Read-only is achieved in the wrapper by tying the write channel to its idle state
rather than by a different controller.

## The wrapper is the boundary

`rtl/` holds **only code written here**. Upstream IP is listed in
[`rom.f`](./rom.f), never copied into `rtl/`.

## What the layout is forced by

The Ibex reset vector is `boot_addr_i + 0x80`, and the trap vector table sits at
`boot_addr_i + 0x00`. Since `mcause` 31 is the NMI, the table needs 32 entries —
128 bytes. So of 2 KiB:

| Offset | Size | Contents |
|---|---|---|
| `0x000` – `0x07F` | 128 B | trap vector table, forced by Ibex |
| `0x080` – `0x7FF` | **1920 B** | all the boot code there is |

1920 bytes is why the bootloader must use the **bitwise** CRC32: the table-driven
variant is about 2.1 KiB and does not fit.

## Instances

One, at `AXI_M0`. Separate from `design/ram/`, which instantiates the same
controller twice for ISRAM and DSRAM — the difference is this one is read-only and
carries build-time contents.
