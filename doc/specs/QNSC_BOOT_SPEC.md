---
title: "BOOT"
subtitle: "BOOT FLOW SPECIFICATION -- V3.0"
author: "QUY NHON SEMICONDUCTORS -- QNSC"
---

# Revision history

The reasoning behind each change, the V1.0--V2.2 history and the V2.2 text are in
[`QNSC_BOOT_DECISIONS.md`](QNSC_BOOT_DECISIONS.md).

| Version | Date | Author | Reviewer | Description of change |
|---|---|---|---|---|
| V3.0 | 2026-09-28 | Nghia VT (lead), for Nguyen Hao Nam | -- | V2.2 moved onto the template: `UART0` address corrected to `0x8002_0000`, hardware sequencing referenced to `SCRC`/`SYSDBG`, bootloader image limits moved here from the ROM, timing recomputed, monochrome figures |

# 1. Overview

QSOC has no Flash. After every reset the boot ROM downloads the application from a
PC into `ISRAM` over `UART0`, checks it, and jumps to it. This specification is the
bootloader, the frame and handshake between it and the PC loader, and what the
application can rely on.

It is not a block and has no RTL. The hardware it runs on is `QNSC_ROM_MAS`,
`QNSC_SCRC_MAS` (reset and release order) and `QNSC_SYSDBG_MAS` (debug boot).

Source `design/rom/boot/`, output `rom_image.hex`; owner Nguyen Hao Nam.

# 2. Features

- The same flow after every reset: power-on, watchdog, software -- 4.
- `UART0` at 113 636 baud 8N1, polled -- 5.
- Frame: 20-byte header with its own CRC, payload, payload CRC -- 6.
- A 4-byte token answers every step; any failure returns to `QRDY` -- 7.
- Nothing written to RAM before the header is checked -- 7.1.
- Application up to 60 KiB, from `0x2000_1000` -- 9.

# 3. Boot path

![Blocks on the boot path](../figures/img/fig_boot_path.png){width=6.4in}

<!-- gen:memory_map ports=AXI_M0,AXI_M1,AXI_M2,APB_M8 -->
: Memory map, regions behind APB_M8 and AXI_M0 and AXI_M1 and AXI_M2

| Base | Size | Region | Port | Kind | Note |
|---|---|---|---|---|---|
| `0x00000000` | 2 KiB | `rom` | AXI_M0 | memory | Boot code, read-only, executable |
| `0x20000000` | 4 KiB | `isram_dbg` | AXI_M1 | memory | The debug window: the first 4 KiB of ISRAM, not a block of its own |
| `0x20001000` | 60 KiB | `isram` | AXI_M1 | memory | The downloaded application |
| `0x30000000` | 32 KiB | `dsram` | AXI_M2 | memory | Stack, heap and variables |
| `0x80020000` | 16 KiB | `uart_0` | APB_M8 | peripheral | Carries the boot download |
<!-- /gen -->

The bootloader runs from the ROM, keeps its stack in `DSRAM`, writes `ISRAM` only
from `0x2000_1000`, and accesses no peripheral other than `UART0`.

# 4. Sequence

![Reset to application](../figures/img/fig_boot_top.png){width=6.4in}

: Boot stages

| Stage | Done by | Specified in | Ends when |
|---|---|---|---|
| 1. Chip reset | `SCRC` `RRC` | `QNSC_SCRC_MAS` 7.3 | chip reset releases |
| 2. Power-up | `SCRC` `MCPU` | `QNSC_SCRC_MAS` 7.5 | CPU released; `UART0` clocked and reachable |
| 3. Mode | `SYSDBG` | `QNSC_SYSDBG_MAS` 7.1 | `o_dbg_cpu_hold` = 0 |
| 4. ROM start | Ibex, `crt0.S` | `QNSC_ROM_MAS` 6, section 8 | `boot_main` called |
| 5. Download | bootloader | section 7 | `ACKP` sent |
| 6. Jump | bootloader | 7.5 | first instruction at `ENTRY` |

With `DBG_EN` = 1 stages 4 to 6 do not run: the host loads the image through
`SYSDBG` and the CPU starts at `0x2000_1080` (`QNSC_SYSDBG_MAS` 7.1). The layout of
section 9 is the same in both modes, so one image serves both.

# 5. UART0 configuration

`UART0` is `pulp-platform/apb_uart` around `obi_uart`: 16550 registers at byte
offset 4 x *n*, 16-byte RX FIFO.

: `UART0` registers used, base `0x8002_0000`

| Offset | Register | Use |
|---|---|---|
| `0x00` | `RBR` / `THR` / `DLL` | receive, transmit; `DLL` = 11 while `DLAB` = 1 |
| `0x04` | `IER` / `DLM` | `IER` = 0; `DLM` = 0 while `DLAB` = 1 |
| `0x08` | `FCR` | `0x07`: FIFOs on, both cleared |
| `0x0C` | `LCR` | `0x80` (`DLAB`) while writing the divisor, then `0x03`: 8 bits, no parity, 1 stop |
| `0x14` | `LSR` | bit 0 data ready; bits 1--3 overrun, parity, framing; bit 5 `THRE`; bit 6 `TEMT` |

Divisor 11: 20 MHz / (16 x 11) = 113 636 baud, 1.36 % below 115 200, inside the
8N1 tolerance. One byte takes 88.0 µs, 1760 cycles.

# 6. Frame format

![Boot frame; every field little-endian](../figures/img/fig_boot_frame.png){width=6.4in}

: Frame fields

| Offset | Field | ROM check |
|---|---|---|
| `0x00` | `MAGIC` | the bytes 'Q', 'S', 'O', 'C' in that order |
| `0x04` | `LENGTH` | multiple of 4, 4 to 61 440 |
| `0x08` | `LOAD_ADDR` | multiple of 4, >= `0x2000_1000`, `LOAD_ADDR` + `LENGTH` <= `0x2001_0000` |
| `0x0C` | `ENTRY` | even, `LOAD_ADDR` <= `ENTRY` < `LOAD_ADDR` + `LENGTH` |
| `0x10` | `HDR_CRC` | CRC32 of bytes `0x00`--`0x0F` |
| `0x14` | `PAYLOAD` | `LENGTH` bytes of the application binary, zero-padded by the PC |
| `0x14` + `LENGTH` | `PAY_CRC` | CRC32 of `PAYLOAD` |

CRC32 is the zlib variant: reflected polynomial `0xEDB88320`, initial value and
final XOR `0xFFFF_FFFF`. The ROM computes it bitwise.

# 7. Bootloader behaviour

![Bootloader flow](../figures/img/fig_boot_flow.png){width=5.0in}

## 7.1 Handshake

![PC loader and boot ROM](../figures/img/fig_boot_seq.png){width=5.6in}

: Tokens, 4 ASCII bytes, sent by the ROM

| Token | Sent when |
|---|---|
| `QRDY` | after `UART0` initialisation, and after every failure once the line is drained |
| `ACKH` | header received, `HDR_CRC` correct, every field in range |
| `ACKP` | `PAY_CRC` correct |
| `FHCR` | `HDR_CRC` wrong |
| `FHDR` | `LENGTH`, `LOAD_ADDR` or `ENTRY` out of range |
| `FPCR` | `PAY_CRC` wrong |
| `FTMO` | more than `RX_TIMEOUT` between two bytes after `MAGIC` |
| `FUAR` | `LSR` overrun, parity or framing error |

- FAIL in Figure 7-2 is any failure token; Figure 7-1 shows which step sends which.
- Bytes before `MAGIC` get no reply, so line noise, or a PC that opens the port
  after `QRDY`, is harmless.
- Nothing is written to `ISRAM` before `ACKH`.

## 7.2 Failure and retry

After a failure token the ROM clears its RX FIFO, discards bytes until the line
has been quiet for `DRAIN_IDLE`, sends `QRDY` and waits for a new frame; the PC
resends the whole frame. Words already in `ISRAM` are overwritten by the next one.
The watchdog is off after reset (`aon_timer` `WDOG_CTRL` resets to 0), so a
download that never completes waits for the PC or a reset.

## 7.3 Timeouts

The bootloader uses no timer: a timeout is a count of `LSR` polls, each an APB
read estimated at 10 cycles or more.

: Timeouts

| Constant | Polls | At 10 cycles per poll | Meaning |
|---|---:|---|---|
| `RX_TIMEOUT` | 200 000 | 100 ms | between two bytes of a frame, after `MAGIC` |
| `DRAIN_IDLE` | 20 000 | 10 ms | quiet line that ends a drain |
| `MAGIC` hunt | -- | -- | no limit |

A slower poll only lengthens a timeout. The PC waits 2 s for each token, plus the
payload time for `ACKP`, so the counts need no tuning.

## 7.4 Writing ISRAM

The payload is written one 32-bit word per four received bytes.

## 7.5 Jump

After `ACKP` the ROM waits for `LSR.TEMT` = 1, so the token has left `UART0`,
executes `fence.i`, and jumps to `ENTRY`. It does not return.

# 8. Bootloader image

: Limits, enforced by the build

| Limit | Value | Enforced by |
|---|---|---|
| Image | 2048 bytes, vector table included (`QNSC_ROM_MAS` 6) | `link.ld`, `util/gen_rom.py` |
| Code | 1 KiB after the vector table (Day005 review) | `make size` |
| Sections | `.text` only: no `.data`, `.bss` or `.rodata` | `link.ld` |

- `crt0.S` holds the 32 vectors and `_start` at `0x80`: `sp` = `0x3000_8000`, the
  top of `DSRAM`, then `boot_main`.
- Built with `-march=rv32imc_zicsr_zifencei`, which `fence.i` needs.

: Source, `design/rom/boot/`

| File | Content |
|---|---|
| `boot.h` | Frame, tokens, timeouts; addresses from the generated `qnsc_map.h` |
| `crt0.S`, `boot.c` | Vectors and `_start`; the bootloader |
| `link.ld` | Layout and the limits above |
| `Makefile` | `make`, `make size`, `make test`; output `rom_image.hex` |
| `tools/qsoc_image.py` | Packs an application binary into a frame; `--load` default `0x2000_1000`, `--entry` default load + `0x80` |
| `tools/qsoc_loader.py` | Sends a frame over a serial port and follows the handshake, with retries |
| `tools/rom_model.py`, `tools/test_protocol.py` | Python model of `boot.c`, and the loader run against it for every token (`make test`) |

# 9. Application contract

- Link at `LOAD_ADDR` >= `0x2000_1000`.
- Put a 128-byte vector table at `LOAD_ADDR` and set `mtvec` to it; put `_start` at
  `LOAD_ADDR` + `0x80`, so `ENTRY` = `0x2000_1080` by default.
- Set up its own stack and data in `DSRAM`.
- Find `UART0` configured (113 636 baud 8N1, FIFOs on, interrupts off, transmitter
  empty), every peripheral clock running except `TIMER1`, and the watchdog off.
- Read and clear `SYSCSR` `RESET_CAUSE` (`QNSC_SYSCSR_MAS` 7.5).

Download time: 60 KiB in 5.4 s, 22 KiB in 2.0 s.

# 10. Requirements on others, and open items

: Requirements on other owners

| Item | Owner | What it blocks |
|---|---|---|
| `qnsc_map.h` generated from the contract, as `qnsc_pkg.sv` is | lead | `boot.h` without typed addresses |

Open items: `design/rom/boot/` is not yet in the repository. ROM owner.

# 11. Verification

1. `BOOT_001` After each reset source the ROM sends `QRDY` and accepts a correct
   frame: `ACKH`, `ACKP`, then execution at `ENTRY`.
2. `BOOT_002` Bytes before `MAGIC` get no reply.
3. `BOOT_003` A wrong `HDR_CRC` gives `FHCR`, a field out of range gives `FHDR`;
   neither writes `ISRAM`.
4. `BOOT_004` A wrong `PAY_CRC` gives `FPCR` and no jump.
5. `BOOT_005` A gap longer than `RX_TIMEOUT` after `MAGIC` gives `FTMO`; a UART error
   gives `FUAR`.
6. `BOOT_006` After every failure the ROM sends `QRDY` and accepts a resent frame.
7. `BOOT_007` After `ACKP`, `ISRAM` from `LOAD_ADDR` equals the payload word for word.
8. `BOOT_008` The build fails when a limit of Table 8-1 is broken.
9. `BOOT_009` `make test` passes against `rom_model.py` for every token.

# Appendix A. Acronyms

: Acronyms

| Acronym | Description |
|---|---|
| CRC | Cyclic Redundancy Check |
| DLAB | Divisor Latch Access Bit, `LCR[7]` |
| LSR | Line Status Register |
| THRE, TEMT | Transmit holding register empty, transmitter empty |

# Appendix B. First review

: First review

| Item | Reviewer | Response |
|---|---|---|
| Handshake mandatory: ACK or failure per step | Quan (mentor), Day006 | 7.1 |
| Header checked separately from payload | Quan (mentor), Day006 | 6, `HDR_CRC` |
| Why `LOAD_ADDR` and `ENTRY` are separate | Quan (mentor) | DECISIONS |
| First fetch is ROM base + `0x80` | Sinh | `QNSC_ROM_MAS` 6 |
| `UART0` at `0x8002_4000`, "APB slave 9" | lead, V3.0 | `0x8002_0000`, `APB_M8`, map generated in 3 |
| Byte time 86.8 µs, 1736 cycles | lead, V3.0 | 88.0 µs, 1760 cycles at the real baud rate |
| Word writes justified by "no byte-strobe path" | lead, V3.0 | `ISRAM` has byte strobes (`QNSC_RAM_MAS` 7.3); reason removed |
