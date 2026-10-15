---
title: "BOOT"
subtitle: "BOOT FLOW SPECIFICATION -- V3.4"
author: "QUY NHON SEMICONDUCTORS -- QNSC"
---

# Revision history

The reasoning behind each change, the V1.0--V2.2 history and the V2.2 text are in
[`QNSC_BOOT_DECISIONS.md`](QNSC_BOOT_DECISIONS.md).

| Version | Date | Author | Reviewer | Description of change |
|---|---|---|---|---|
| V3.4 | 2026-10-14 | Nguyen Hao Nam | -- | Mentor feedback of 14/10 (Appendix B): the ROM loads the debug program when `DEBUG_PROG` is `0x0000_0055` and skips it for any other value; `0xAA` is no longer checked, so `FHDR` is for `LENGTH` only; Figures 6-1 and 7-1, Tables 6-1, 7-1, 7-2 and 11 with them |
| V3.3 | 2026-10-12 | Nguyen Hao Nam | -- | Mentor's debug boot flow of 12/10 (Appendix B): the ROM loads the debug program too, over `UART0`; JTAG no longer loads the image or holds the CPU, and the boot address mux is gone, so both modes run the ROM; header 16 bytes with `DEBUG_PROG` (`0x55`: a 4 096-byte debug program and its `DBG_CRC` follow the header and go to `0x2000_0000`; `0xAA`: none); tokens `ACKD` and `FDCR`; after `ACKP` the ROM waits while `SYSCSR` `DBG_BOOT.dbg_en` = 1, which the `DBG_EN` pin sets and the host clears over JTAG; a debug request during the wait enters the debug program at `DmHaltAddr` `0x2000_0800` and `dret` returns to the wait; the debug program follows the `SYSDBG` debug window layout (9); Figures 4-1, 6-1, 7-1, 7-2 redrawn and Tables 4-2, 7-1 with them |
| V3.2 | 2026-10-09 | Nguyen Hao Nam | -- | Mentor review of V3.1 (Appendix B): `ENTRY` dropped from the header, for the same entry as debug boot; `LOAD_ADDR` dropped with it, so the payload always goes to `0x2000_1000` and the ROM jumps to `0x2000_1080`; header 12 bytes; `LENGTH` 132 to 61 440; `FUAR` dropped and the UART error bits no longer read, since a CRC or the timeout catches every UART error; Figure 4-1 redrawn (two `SCRC` steps, the `DBG_EN` pin, no CRC test) and Table 4-2 with it |
| V3.1 | 2026-09-30 | Nguyen Hao Nam | -- | Mentor review 29/09 (Appendix B): no `QRDY` after reset, only after a failure; 19 200 baud; Figure 4-1 shows the CPU release and tests CRC pass; debug boot explained by the boot address mux; steps of Figures 4-1 and 7-1 described (Tables 4-2, 7-1); how each failure is detected; timeouts given as minimums; UART errors before `MAGIC` get no reply; Figure 7-1 redrawn with one decision per check; the PC stops on a failure token; `RX_TIMEOUT` and `DRAIN_IDLE` raised |
| V3.0 | 2026-09-28 | Nghia VT (lead), for Nguyen Hao Nam | -- | V2.2 moved onto the template: `UART0` address corrected to `0x8002_0000`, hardware sequencing referenced to `SCRC`/`SYSDBG`, bootloader image limits moved here from the ROM, timing recomputed, monochrome figures |

# 1. Overview

QSOC has no Flash. After every reset the boot ROM downloads the application from a
PC into `ISRAM` over `UART0`, checks it, and jumps to it. In debug boot it also
downloads a debug program, and waits for the debugger before it jumps. This
specification is the bootloader, the frame and handshake between it and the PC
loader, and what the application can rely on.

It is not a block and has no RTL. The hardware it runs on is `QNSC_ROM_MAS`,
`QNSC_SCRC_MAS` (reset and release order), `QNSC_SYSCSR_MAS` (`DBG_BOOT`, the
`DBG_EN` pin) and `QNSC_SYSDBG_MAS` (the JTAG access to the chip).

Source `design/rom/boot/`, output `rom_image.hex`; owner Nguyen Hao Nam.

# 2. Features

- The same flow after every reset, in both modes: power-on, watchdog, software -- 4.
- `UART0` at 19 231 baud (19 200 nominal) 8N1, polled -- 5.
- Frame: 16-byte header with its own CRC; an optional 4 096-byte debug program
  with its own CRC; payload, payload CRC -- 6.
- A 4-byte token answers every step; any failure returns to `QRDY` -- 7.
- Nothing written to RAM before the header is checked -- 7.1.
- Application up to 60 KiB, loaded at `0x2000_1000` and entered at `0x2000_1080`;
  debug program up to 4 KiB, loaded at `0x2000_0000` -- 9.
- Debug boot: with the `DBG_EN` pin at 1 the ROM waits after `ACKP` until the host
  releases it over JTAG; the CPU runs the whole time -- 7.5.

# 3. Boot path

![Blocks on the boot path](../figures/img/fig_boot_path.png){width=6.4in}

<!-- gen:memory_map ports=AXI_M0,AXI_M1,AXI_M2,APB_M1,APB_M8 -->
: Memory map, regions behind APB_M1 and APB_M8 and AXI_M0 and AXI_M1 and AXI_M2

| Base | Size | Region | Port | Kind | Note |
|---|---|---|---|---|---|
| `0x00000000` | 2 KiB | `rom` | AXI_M0 | memory | Boot code, read-only, executable |
| `0x20000000` | 4 KiB | `isram_dbg` | AXI_M1 | memory | The debug window: the first 4 KiB of ISRAM, not a block of its own |
| `0x20001000` | 60 KiB | `isram` | AXI_M1 | memory | The downloaded application |
| `0x30000000` | 32 KiB | `dsram` | AXI_M2 | memory | Stack, heap and variables |
| `0x80004000` | 16 KiB | `syscsr` | APB_M1 | peripheral |  |
| `0x80020000` | 16 KiB | `uart_0` | APB_M8 | peripheral | Carries the boot download |
<!-- /gen -->

The bootloader runs from the ROM, keeps its stack in `DSRAM`, writes `ISRAM` only
from `0x2000_1000`, or from `0x2000_0000` when the frame carries a debug program,
and accesses no peripheral other than `UART0` and one register of `SYSCSR`,
`DBG_BOOT`, which it only reads.

# 4. Sequence

![Reset to application](../figures/img/fig_boot_top.png){width=6.4in}

: Boot stages

| Stage | Done by | Specified in | Ends when |
|---|---|---|---|
| 1. Chip reset | `SCRC` `RRC` | `QNSC_SCRC_MAS` 7.3 | chip reset releases |
| 2. Power-up | `SCRC` `MCPU` | `QNSC_SCRC_MAS` 7.5 | CPU released; `UART0` clocked and reachable |
| 3. ROM start | Ibex, `crt0.S` | `QNSC_ROM_MAS` 6, section 8 | `boot_main` called |
| 4. Download | bootloader | section 7 | every CRC passes, `ACKP` sent |
| 5. Debug wait | bootloader, host | 7.5 | `DBG_BOOT.dbg_en` reads 0 |
| 6. Jump | bootloader | 7.5 | first instruction at `0x2000_1080` |

Both modes run the same stages. The `DBG_EN` pin does not change where the CPU
starts and does not hold it in reset: the CPU always starts in the ROM, and the
pin only makes the ROM wait at stage 5. `SYSCSR` passes the pin through two
flip-flops into `DBG_BOOT.dbg_en`, which the ROM reads; the host clears it by
writing `DBG_BOOT.dbg_en_mask` = 1 over JTAG (`QNSC_SYSCSR_MAS` 7.5). The debug
program, if the frame carries one, is in `ISRAM` from `0x2000_0000` before the
wait starts, so the host can halt the CPU into it at any time: Ibex enters it at
`DmHaltAddr`, `0x2000_0800`.

: Steps of Figure 4-1

| Step of Figure 4-1 | What happens | Specified in |
|---|---|---|
| Power on | The power-on reset. A WDT bite or SW_RST resets the chip too and enters at the next step. | `QNSC_SCRC_MAS` 7.3 |
| SCRC: hold the whole chip in reset, clock the IPs | The `RRC` holds the chip in reset: 16 cycles after a WDT bite or SW_RST; after POR it releases one cycle later. Then `MCPU` runs the CRM program, which first starts the clocks of the peripherals that `CLK_EN` asks for: after reset, every peripheral except TIMER1. | `QNSC_SCRC_MAS` 7.3, 7.5 |
| SCRC: release the reset of every IP except the CPU | At least 3 cycles later `MCPU` releases the reset of every domain except the CPU. At least 16 cycles after that it opens the APB guards of the peripherals whose clock runs, the TIMER1 guard staying closed, so `UART0` is reachable before the CPU runs. Register values: `QNSC_SCRC_MAS` 7.5. | `QNSC_SCRC_MAS` 7.5 |
| SCRC releases the CPU reset | Last, `MCPU` releases the CPU reset, in both modes. | `QNSC_SCRC_MAS` 7.5 |
| Ibex fetches 0x0000_0080 (ROM) | Ibex starts at its boot address + 0x80: `0x0000_0080` in the ROM. The start-up code points the stack at the top of DSRAM, `0x3000_8000`, and calls the bootloader, `boot_main`. | `QNSC_ROM_MAS` 6, section 8 |
| init UART0 | Sets 19 200 baud, 8 data bits, no parity and 1 stop bit, turns the FIFOs on and the interrupts off (section 5). The ROM starts listening for MAGIC at once. | 5 |
| receive the frame from the PC over UART0: DEBUG_PAYLOAD to 0x2000_0000 (only when DEBUG_PROG = 0x55), PAYLOAD to 0x2000_1000 | Receive and check the frame, Figure 7-1 and Table 7-1. The step ends when the header CRC, `LENGTH`, the debug program CRC if there is one, and the payload CRC all pass. On any failure the ROM sends a failure token, empties the line and sends `QRDY`, and the PC resends the whole frame. | 7 |
| SYSCSR.DBG_EN = 1? | The ROM reads `SYSCSR` `DBG_BOOT`. Bit 0, `dbg_en`, is the `DBG_EN` pin through two flip-flops, forced to 0 once the host has written `dbg_en_mask` = 1. | 7.5, `QNSC_SYSCSR_MAS` 7.5 |
| CPU polling: read SYSCSR.DBG_EN again (1: debug boot) | The ROM reads `DBG_BOOT` in a loop. The CPU is not held in reset: it runs this loop, so the host can halt it into the debug program at any time: Ibex enters it at `DmHaltAddr`, `0x2000_0800`, and `dret` brings it back into this loop. The host ends the wait by writing `DBG_BOOT.dbg_en_mask` = 1 through the `SYSDBG` bus master. With `DEBUG_PROG` other than `0x55` the ROM waits all the same and sends no token. | 7.5 |
| jump to 0x2000_1080 (ISRAM) (0: normal boot) | The ROM clears the instruction prefetch and jumps to `0x2000_1080`. | 7.5 |
| application runs from ISRAM | Section 9. If the frame carried a debug program, the host can halt the CPU into it while the application runs. | 9 |

# 5. UART0 configuration

`UART0` is `pulp-platform/apb_uart` around `obi_uart`: 16550 registers at byte
offset 4 x *n*, 16-byte RX FIFO.

: `UART0` registers used, base `0x8002_0000`

| Offset | Register | Use |
|---|---|---|
| `0x00` | `RBR` / `THR` / `DLL` | receive, transmit; `DLL` = 65 while `DLAB` = 1 |
| `0x04` | `IER` / `DLM` | `IER` = 0; `DLM` = 0 while `DLAB` = 1 |
| `0x08` | `FCR` | `0x07`: FIFOs on, both cleared |
| `0x0C` | `LCR` | `0x80` (`DLAB`) while writing the divisor, then `0x03`: 8 bits, no parity, 1 stop |
| `0x14` | `LSR` | bit 0 data ready; bit 5 `THRE`; bit 6 `TEMT`. Bits 1--3, the line errors, are not read |

Divisor 65: 20 MHz / (16 x 65) = 19 231 baud, 0.16 % above 19 200, a standard rate
on the PC. One byte takes 520 µs, 10 400 cycles. The low rate keeps a wide margin
against framing errors on the link.

The ROM polls `UART0` and uses no interrupt. To receive, it reads `LSR` in a loop:
bit 0 set means a byte waits in `RBR`, which it then reads; otherwise it reads `LSR`
again. While it hunts `MAGIC` the loop has no limit; after `MAGIC` it counts the
polls against `RX_TIMEOUT` (7.3). To send, it waits for `LSR.THRE` = 1 and writes
`THR`.

The ROM ignores the line error bits. With 8N1 there is no parity error. A byte
received with a framing error is kept as it is and fails a CRC (`FHCR`, `FDCR` or
`FPCR`). A byte lost to an overrun leaves the frame one byte short, so the ROM
waits for a byte that never comes and sends `FTMO`. Either way the PC resends the
frame.

# 6. Frame format

![Boot frame; every field little-endian](../figures/img/fig_boot_frame.png){width=6.4in}

: Frame fields

| Offset | Field | ROM check |
|---|---|---|
| `0x00` | `MAGIC` | the bytes 'Q', 'S', 'O', 'C' in that order |
| `0x04` | `LENGTH` | multiple of 4, 132 to 61 440 |
| `0x08` | `DEBUG_PROG` | not checked: `0x0000_0055`, a debug program follows the header; any other value, none |
| `0x0C` | `HDR_CRC` | CRC32 of bytes `0x00`--`0x0B` |
| `0x10` | `DEBUG_PAYLOAD` | only with `DEBUG_PROG` = `0x55`: 4 096 bytes, the debug program zero-padded by the PC; written to `ISRAM` from `0x2000_0000` |
| `0x1010` | `DBG_CRC` | only with `DEBUG_PROG` = `0x55`: CRC32 of `DEBUG_PAYLOAD` |
| *D* | `PAYLOAD` | `LENGTH` bytes of the application binary, zero-padded by the PC; written to `ISRAM` from `0x2000_1000`. *D* = `0x10`, or `0x1014` after a debug program |
| *D* + `LENGTH` | `PAY_CRC` | CRC32 of `PAYLOAD` |

The frame carries no address. The debug program always goes to `0x2000_0000`, the
payload always to `0x2000_1000`, and the ROM always jumps to `0x2000_1080`, after
the application's 128-byte vector table. `LENGTH` is at least 132 so that the image
reaches the first instruction at `0x2000_1080`, and at most 61 440 so that it ends
inside `ISRAM`, at `0x2001_0000`. The debug program has no length field: it is
always sent in full, so it can neither overlap the payload nor stop short.

`DEBUG_PROG` is a whole word so that every field stays on a 4-byte boundary. The
ROM compares the whole word with `0x0000_0055` and checks nothing else: any other
value means no debug program, and the PC loader sends `0x0000_00AA` for that.
`HDR_CRC` already shows that the value is the one the PC sent, and the PC sends the
debug program on the same test, so the two sides cannot disagree.

CRC32 is the zlib variant: reflected polynomial `0xEDB88320`, initial value and
final XOR `0xFFFF_FFFF`. The ROM computes it bitwise.

# 7. Bootloader behaviour

![Bootloader flow](../figures/img/fig_boot_flow.png){width=4.1in}

Table 7-1 describes each step of Figure 7-1 and how each failure is found. Every
check is done by the bootloader in software.

: Steps of Figure 7-1

| Step of Figure 7-1 | What the ROM does | Failure detected, token |
|---|---|---|
| init UART0 | Section 5. | -- |
| waiting for each MAGIC byte from PC; last 4 bytes = 'Q' 'S' 'O' 'C'? | Poll `LSR` with no time limit and shift each byte through a 4-byte window until it holds `MAGIC`. Nothing is sent. | none |
| waiting for the next header byte: LENGTH, DEBUG_PROG, HDR_CRC | Poll `LSR` for the 12 bytes of `LENGTH`, `DEBUG_PROG` and `HDR_CRC`. A CRC32 runs over `MAGIC`, `LENGTH` and `DEBUG_PROG` as they arrive. | -- |
| new byte within RX_TIMEOUT polls? | The poll count restarts at every byte (7.3). | no: `FTMO` |
| 12 header bytes received? | No: wait for the next header byte. | -- |
| CRC32 = HDR_CRC? | Checked before the fields: with a wrong CRC their values mean nothing. | no: `FHCR` |
| LENGTH valid? | The CRC only shows that the bytes arrived as the PC sent them, not that the value makes sense. `LENGTH` must be a multiple of 4 and 132 to 61 440 (Table 6-1), so the payload reaches `0x2000_1080` and stays inside `ISRAM`. `DEBUG_PROG` is not checked. | no: `FHDR` |
| send ACKH | `ISRAM` is written only after this token. | -- |
| DEBUG_PROG = 0x55? | The whole word is compared. No, any other value: go to the payload. | -- |
| waiting for the next debug program or DBG_CRC byte; write it to 0x2000_0000 (ISRAM) | Every 4 bytes are written as one word to `ISRAM`, the first at `0x2000_0000`, and fed to a CRC32. The 4 bytes of `DBG_CRC` are neither written nor fed. | -- |
| new byte within RX_TIMEOUT polls? | As for the header. | no: `FTMO` |
| 4 096 bytes and DBG_CRC received? | The loop bound only. No: wait for the next byte. | -- |
| CRC32 = DBG_CRC? | `DBG_CRC` is the CRC32 the PC computed over the debug program. | no: `FDCR` |
| send ACKD | The PC may send the payload. | -- |
| waiting for the next payload or PAY_CRC byte; write the payload to 0x2000_1000 (ISRAM) | As for the debug program, from `0x2000_1000`, with a CRC32 of its own. | -- |
| new byte within RX_TIMEOUT polls? | As for the header. | no: `FTMO` |
| all payload and PAY_CRC bytes received? | The loop bound only: `LENGTH` payload bytes, then 4 bytes of `PAY_CRC`. No: wait for the next byte. | -- |
| CRC32 = PAY_CRC? | `PAY_CRC` is the CRC32 the PC computed over the payload; the ROM compares it with its own. | no: `FPCR`, no jump |
| send ACKP | 7.5. | -- |
| read SYSCSR.DBG_EN = 1?; CPU polling | 7.5. Yes: read it again. | -- |
| jump to 0x2000_1080 (ISRAM) | 7.5. | -- |
| send failure token, clear RX FIFO, discard bytes until quiet for DRAIN_IDLE polls, send QRDY | The token is sent in full first. Then the RX FIFO is cleared, bytes are discarded until the line has been quiet for `DRAIN_IDLE`, `QRDY` is sent, and the ROM waits for `MAGIC` again (7.2). | -- |

## 7.1 Handshake

![PC loader and boot ROM](../figures/img/fig_boot_seq.png){width=5.6in}

: Tokens, 4 ASCII bytes, sent by the ROM

| Token | Sent when |
|---|---|
| `QRDY` | after every failure, once the line is drained; not after reset |
| `ACKH` | header received, `HDR_CRC` correct, `LENGTH` in range |
| `ACKD` | `DBG_CRC` correct; only with `DEBUG_PROG` = `0x55` |
| `ACKP` | `PAY_CRC` correct |
| `FHCR` | `HDR_CRC` wrong |
| `FHDR` | `LENGTH` out of range |
| `FDCR` | `DBG_CRC` wrong |
| `FPCR` | `PAY_CRC` wrong |
| `FTMO` | more than `RX_TIMEOUT` between two bytes after `MAGIC` |

- FAIL in Figure 7-2 is any failure token; Figure 7-1 shows which step sends which.
- Bytes before `MAGIC` get no reply, so line noise is harmless. No token is sent after reset: the PC sends its frame without waiting.
  If the frame starts before `UART0` is configured, `MAGIC` is missed, no `ACKH`
  comes back, and the PC resends after its 2 s wait.
- Nothing is written to `ISRAM` before `ACKH`.
- No token reports a UART error: a CRC failure or `FTMO` reports it (5).
- `ACKP` does not say that the application runs: with the `DBG_EN` pin at 1 the ROM
  waits for the host first (7.5).

## 7.2 Failure and retry

After a failure token the ROM clears its RX FIFO, discards bytes until the line
has been quiet for `DRAIN_IDLE`, sends `QRDY` and waits for a new frame; the PC
resends the whole frame, debug program included. Words already in `ISRAM` are
overwritten by the next one. The watchdog is off after reset (`aon_timer`
`WDOG_CTRL` resets to 0), so a download that never completes waits for the PC or a
reset. The PC waits for `QRDY` before it resends, so no byte of the new frame is
lost in the drain. The PC stops sending as soon as it reads a failure token: it
sends the debug program and the payload in chunks and checks for a token between
them, so the ROM does not drain the rest of a bad frame.

## 7.3 Timeouts

The bootloader uses no timer: a timeout is a count of `LSR` polls. A poll is at
least one APB read, and an APB transfer takes at least 2 cycles, so Table 7-3 gives
minimum times only. The exact time per poll depends on the bus path and is not
specified.

: Timeouts

| Constant | Polls | Minimum, at 2 cycles per poll | Meaning |
|---|---:|---|---|
| `RX_TIMEOUT` | 1 000 000 | 100 ms, 192 byte times | between two bytes of a frame, after `MAGIC` |
| `DRAIN_IDLE` | 500 000 | 50 ms, 96 byte times | quiet line that ends a drain |
| `MAGIC` hunt | -- | -- | no limit |
| Debug wait | -- | -- | no limit: until the host writes `DBG_BOOT.dbg_en_mask` = 1 |

A slower poll only lengthens a timeout. The PC waits 2 s for each token, plus the
transfer time for `ACKD` and `ACKP`, so the counts need no tuning. The margins
cover gaps in the PC stream from the operating system and the USB-serial adapter.
`RX_TIMEOUT` must stay below the PC's 2 s wait, so a poll must take fewer than 40
cycles; the time per poll is measured in simulation (10).

## 7.4 Writing ISRAM

The debug program and the payload are written one 32-bit word per four received
bytes, by the same loop.

## 7.5 Debug wait and jump

After `ACKP` the ROM waits for `LSR.TEMT` = 1, so the token has left `UART0`. Then
it reads `SYSCSR` `DBG_BOOT` (`0x8000_400C`) until bit 0, `dbg_en`, is 0:

- **Normal boot**, `DBG_EN` pin at 0: the first read returns 0.
- **Debug boot**, `DBG_EN` pin at 1: the ROM reads in a loop. The CPU runs and is
  not held in reset, so the host can raise the Ibex debug request at any time.
  The host ends the wait by writing `DBG_BOOT.dbg_en_mask` = 1 through the
  `SYSDBG` bus master (`AXI_S0`, `S_BUS`, `P_BUS`); the host can only clear
  `dbg_en`, never set it. The bus master needs no help from the CPU, so the mask
  can be written while the CPU is halted.
- **A debug request during the wait** suspends the loop, it does not end it. Ibex
  saves the PC of the interrupted loop instruction in `dpc` and enters the debug
  program at its dispatch loop, `DmHaltAddr` = `0x2000_0800` (9). When the host
  resumes it, `dret` returns to `dpc`, back into the wait loop, which reads
  `DBG_BOOT` again. Only `dbg_en` = 0 ends the wait. To stop on the first
  instruction of the application, the host halts the CPU, plants a breakpoint at
  `0x2000_1080`, writes `dbg_en_mask` = 1 and resumes.
- `DEBUG_PROG` other than `0x55` with the pin at 1 is an operator mistake: there is no debug
  program, so `0x2000_0800` holds no dispatch loop and the host must not raise the
  debug request. The ROM waits all the same and sends no token; the host releases
  it with `dbg_en_mask` = 1.

Then the ROM executes `fence.i` and jumps to `0x2000_1080`. It does not return.

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
- V3.4 image: 734 bytes, 606 bytes of code after the vector table.

: Source, `design/rom/boot/`

| File | Content |
|---|---|
| `boot.h` | Frame, tokens, timeouts, the `SYSCSR` `DBG_BOOT` address; addresses from the generated `qnsc_map.h` |
| `crt0.S`, `boot.c` | Vectors and `_start`; the bootloader |
| `link.ld` | Layout and the limits above |
| `Makefile` | `make`, `make size`, `make test`, `make test-serial`; output `rom_image.hex` |
| `tools/qsoc_image.py` | Packs an application binary, and with `--debug` a debug program, into a frame: pads the payload to a multiple of 4 and the debug program to 4 096 bytes, sets `LENGTH` and `DEBUG_PROG` |
| `tools/qsoc_loader.py` | Sends a frame over a serial port at 19 200 baud and follows the handshake: the debug program and the payload in chunks, stopped at a failure token, then a retry |
| `tools/rom_model.py`, `tools/test_protocol.py` | Python model of `boot.c`, `DBG_EN` pin and `dbg_en_mask` included, and the loader run against it for every token (`make test`) |
| `tools/test_serial_link.py` | The loader command line through `pyserial` (`socket://`) against the model (`make test-serial`) |

# 9. Application contract

- Link at `0x2000_1000`, 132 bytes to 60 KiB.
- Put a 128-byte vector table at `0x2000_1000` and set `mtvec` to it; put `_start`
  at `0x2000_1080`.
- Set up its own stack and data in `DSRAM`.
- Find `UART0` configured (19 231 baud 8N1, FIFOs on, interrupts off, transmitter
  empty), every peripheral clock running except `TIMER1`, and the watchdog off.
- Read and clear `SYSCSR` `RESET_CAUSE` (`QNSC_SYSCSR_MAS` 7.6).
- A debug program is linked at `0x2000_0000`, at most 4 KiB, and follows the
  debug window layout of `QNSC_SYSDBG_DECISIONS` 4.11 (Table 9-1), because the
  Ibex debug addresses are fixed when the CPU is built.

: Debug program layout, fixed by the Ibex debug parameters

| Address | Contents |
|---|---|
| `0x2000_0000`--`0x2000_07FF` | Instruction sequence area, written by the host |
| `0x2000_0800` | Dispatch loop, `DmHaltAddr`: Ibex enters here on every halt |
| `0x2000_0810` | Exception handler, `DmExceptionAddr`: a fault in debug mode |
| `0x2000_0F00` | Result words |
| `0x2000_0F08` | Command word |
| `0x2000_0F0C` | Resume flag: the dispatch loop clears it and executes `dret` |

Without a valid dispatch loop at `0x2000_0800` the first halt runs whatever is
there. Before V3.3 `SYSDBG` wrote the dispatch loop over JTAG; now it comes in the
frame. What the loop and the sequences do is specified with the debug flow, not
here.

Download time at 19 231 baud: 60 KiB in about 32 s, 22 KiB in about 11.7 s; a debug
program adds about 2.1 s.

# 10. Requirements on others, and open items

: Requirements on other owners

| Item | Owner | What it blocks |
|---|---|---|
| `qnsc_map.h` generated from the contract, as `qnsc_pkg.sv` is | lead | `boot.h` without typed addresses |
| `SYSCSR` `DBG_BOOT` at `0x0C`: `dbg_en` RO, `dbg_en_mask` RW, the `DBG_EN` pin through two flip-flops | `SYSCSR` (same owner) | 7.5 |
| The `DBG_EN` pad wired to `SYSCSR` `i_dbg_en` | top (lead) | 7.5 |
| `QNSC_SYSDBG_MAS` follows this flow: no CPU hold, no boot address mux, no debug window initialiser; the bus master reaches `SYSCSR` | `SYSDBG` (lead) | debug boot as in 4 and 7.5 |
| Ibex `DmHaltAddr` = `0x2000_0800`, `DmExceptionAddr` = `0x2000_0810`, as in `QNSC_SYSDBG_DECISIONS` 4.11 | `SYSDBG`, CPU | the debug request of 7.5, the layout of 9 |

Open items: `design/rom/boot/` is in PR #51 (`feat/rom-wrapper`), not yet merged. ROM
owner. Time per `LSR` poll, measured in simulation, to replace the minimums of
Table 7-3. ROM owner.

`dbg_en_mask` is reset by power-on only (`QNSC_SYSCSR_MAS` 7.5): after a WDT bite or
SW_RST in a debug session the mask keeps the value the host wrote, so the ROM waits
again only after a power-on.

# 11. Verification

1. `BOOT_001` After each reset source the ROM sends no token and accepts a correct
   frame: `ACKH`, `ACKP`, then execution at `0x2000_1080`.
2. `BOOT_002` Bytes before `MAGIC` get no reply.
3. `BOOT_003` A wrong `HDR_CRC` gives `FHCR`; a `LENGTH` out of range gives `FHDR`;
   neither writes `ISRAM`. A `DEBUG_PROG` other than `0x0000_0055` (`0x0`, `0x33`,
   `0x155`) is taken as no debug program: `ACKH`, `ACKP`, nothing written below
   `0x2000_1000`.
4. `BOOT_004` A wrong `PAY_CRC` gives `FPCR` and no jump.
5. `BOOT_005` A gap longer than `RX_TIMEOUT` after `MAGIC` gives `FTMO`; a byte
   changed on the line gives `FHCR`, `FDCR` or `FPCR`, a byte lost gives `FTMO`.
6. `BOOT_006` After every failure the ROM sends `QRDY` and accepts a resent frame.
7. `BOOT_007` After `ACKP`, `ISRAM` from `0x2000_1000` equals the payload word for word.
8. `BOOT_008` The build fails when a limit of Table 8-1 is broken.
9. `BOOT_009` `make test` passes against `rom_model.py` for every token.
10. `BOOT_010` With `DEBUG_PROG` = `0x55` the ROM answers `ACKH`, `ACKD`, `ACKP`, and
    `ISRAM` from `0x2000_0000` equals the debug program padded to 4 096 bytes; a
    wrong `DBG_CRC` gives `FDCR` and a retry.
11. `BOOT_011` With the `DBG_EN` pin at 1 the ROM sends `ACKP` and does not jump
    until `DBG_BOOT.dbg_en_mask` is written 1; then it jumps to `0x2000_1080`.
12. `BOOT_012` With the `DBG_EN` pin at 1 and no debug program the ROM waits as
    in `BOOT_011` and sends no failure token.

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
| Why `LOAD_ADDR` and `ENTRY` are separate | Quan (mentor) | DECISIONS; both removed in V3.2 |
| First fetch is ROM base + `0x80` | Sinh | `QNSC_ROM_MAS` 6 |
| `UART0` at `0x8002_4000`, "APB slave 9" | lead, V3.0 | `0x8002_0000`, `APB_M8`, map generated in 3 |
| Byte time 86.8 µs, 1736 cycles | lead, V3.0 | 88.0 µs, 1760 cycles at the real baud rate |
| Word writes justified by "no byte-strobe path" | lead, V3.0 | `ISRAM` has byte strobes (`QNSC_RAM_MAS` 7.3); reason removed |
| Figure 4-1: show the CPU release | Quan (mentor), 29/09 | Figure 4-1, Table 4-2 |
| Leave out of the MAS any parameter or step that is not known | Quan (mentor), 29/09 | 7.3: timeouts as minimums |
| Polling for the PC data not defined; `QRDY` after reset not needed | Quan (mentor), 29/09 | 5: polling; 7.1: no `QRDY` after reset, kept after a failure |
| "ACKP sent?" should test the CRC | Quan (mentor), 29/09 | Figure 7-1: CRC32 = PAY_CRC? before ACKP; V3.2 Figure 4-1 no longer repeats it |
| How does the CPU run the image loaded over JTAG if it starts in the ROM? | Quan (mentor), 29/09 | V3.1: hardware boot address mux. V3.3: no longer asked, the ROM loads every image |
| Baud rate down to about 10 000--20 000 | Quan (mentor), 29/09 | 5: 19 200 |
| Figure 7-1: how each failure is detected and reported | Quan (mentor), 29/09 | Table 7-1 |
| Describe every step of Figures 4-1 and 7-1 | Quan (mentor), 29/09 | Tables 4-2, 7-1 |
| Drop `ENTRY` from the header, to match debug boot | Quan (mentor), V3.1 review | 6: no `ENTRY`, no `LOAD_ADDR`; the ROM jumps to `0x2000_1080` |
| The ROM loads the programs, not JTAG | Quan (mentor), 12/10 drawing | 4, 7: both programs over `UART0` |
| Header field `DEBUG_PROG`: `0x55` debug program and user program, `0xAA` user program only | Quan (mentor), 12/10 drawing | 6: a 4-byte word; 4 096-byte debug program with `DBG_CRC` |
| ROM reads `SYSCSR.DEBUG_EN`: 1, CPU polls; 0, jump to the user program | Quan (mentor), 12/10 drawing | 7.5; named `DBG_BOOT.dbg_en` by the Naming Rule |
| JTAG clears it by writing `DEBUG_EN_MASK` = 1 through a mux; the pin feeds the status through two flip-flops | Quan (mentor), 12/10 drawing | 7.5, `QNSC_SYSCSR_MAS` 7.5: `dbg_en_mask` |
| JTAG can put the CPU in debug mode at any time with `cpu_dbg_en` | Quan (mentor), 12/10 drawing | 4, 7.5: the CPU is never held, so the request works during the wait and while the application runs |
| Tokens `ACKD` and `FDCR` for the debug program | Quan (mentor), 12/10, confirmed | 7.1 |
| Entry `0x2000_1080`, after the application's vector table, not the load address `0x2000_1000` | Quan (mentor), 12/10, confirmed | 6, 7.5 |
| `dbg_en_mask` reset by power-on only | Quan (mentor), 12/10, confirmed | 10, `QNSC_SYSCSR_MAS` 7.5 |
| `DEBUG_PROG` = `0x55`: load the debug program; any other value: skip it, no `0xAA` check | Quan (mentor), 14/10 | V3.4: 6, 7.1; `FHDR` for `LENGTH` only |
