# `rom/boot` — serial bootloader burned into the boot ROM

**Owner:** Nam Nguyen Hao · **Spec:** `QNSC_BOOT_SPEC` V3.4 on the team SharePoint

Software, not RTL: its only output consumed by the hardware is `rom_image.hex`,
which `make rtl` copies to `util/gen/rom/` and turns into the constant module
`m_qnsc_rom_image` with `util/gen_rom.py` (QNSC_ROM_MAS 7.2).

## What it does

After every reset, in normal and debug boot alike, Ibex fetches
`ROM_BASE + 0x80`. The ROM configures UART0 at 0x8002_0000 (divisor 65:
19 231 baud 8N1, polling) and, sending nothing, listens for the magic. It
receives one frame from the PC: when `DEBUG_PROG` = 0x55, a 4 096-byte debug
program written from `0x2000_0000`; then the payload, written from
`0x2000_1000`; each part with its own CRC. After `ACKP` it reads SYSCSR
`DBG_BOOT` (0x8000_400C) and waits while bit 0, `dbg_en`, is 1: the `DBG_EN`
pin is 1 and the host has not yet written `dbg_en_mask` = 1 over JTAG. A halt
during the wait enters the debug program at `0x2000_0800` (`DmHaltAddr`) and
`dret` returns to the wait. Then it jumps to `0x2000_1080`. Every step after the magic answers with a 4-byte
token; on failure the ROM sends the token, drains the line, sends `QRDY`, and
the PC resends the whole frame.

## Frame (all fields little-endian)

| Offset | Size | Field | Checked by the ROM |
|---|---|---|---|
| 0x00 | 4 | MAGIC | `'Q','S','O','C'` in that order (LE word `0x434F5351`) |
| 0x04 | 4 | LENGTH | payload bytes, `%4 == 0`, 132 .. 61440 (the image reaches `0x2000_1080` and fits in ISRAM) |
| 0x08 | 4 | DEBUG_PROG | not checked: exactly `0x0000_0055`, a debug program follows; any other value, none (the loader sends `0xAA`) |
| 0x0C | 4 | HDR_CRC | CRC32 of bytes 0x00..0x0B |
| 0x10 | 4096 | DEBUG_PAYLOAD | only with 0x55: the debug program, zero-padded, linked at `0x2000_0000` |
| 0x1010 | 4 | DBG_CRC | only with 0x55: CRC32 of DEBUG_PAYLOAD |
| D | N | PAYLOAD | raw bytes of the app `.bin`, linked at `0x2000_1000`; D = 0x10 or 0x1014 |
| D+N | 4 | PAY_CRC | CRC32 of PAYLOAD |

CRC32 is zlib/IEEE (reflected `0xEDB88320`, init and final XOR `0xFFFFFFFF`):
`zlib.crc32()` on the PC, bitwise in the ROM.

## Handshake

```
               PC: header (16 B)              (nothing is sent after reset)
ROM: ACKH | FHCR | FHDR | FTMO
               PC: DEBUG_PAYLOAD + DBG_CRC, in 256-byte chunks  (only with 0x55)
ROM: ACKD | FDCR | FTMO
               PC: PAYLOAD + PAY_CRC, in 256-byte chunks
ROM: ACKP | FPCR | FTMO             (then waits while DBG_BOOT.dbg_en = 1,
                                     then jumps to 0x2000_1080)
after any F***:  ROM drains the line, then QRDY;  PC resends the whole frame
```
`FTMO` = more than `RX_TIMEOUT` polls (at least 100 ms) between two bytes
after the magic. The ROM does not read the UART error bits: a byte with a
framing error fails a CRC (`FHCR`/`FDCR`/`FPCR`), a byte lost to an overrun leaves
the frame short and ends in `FTMO`. Bytes before the magic are skipped
silently. The
loader checks for a failure token between payload chunks and stops sending
at once: UART0 has no hardware flow control.

## Files

| File | What |
|---|---|
| `boot.h` | memory map, UART registers, SYSCSR `DBG_BOOT`, timeouts, frame and token constants |
| `crt0.S` | 128-byte trap table + `_start` at 0x80 (SP = top of DSRAM) |
| `boot.c` | the bootloader |
| `link.ld` | 2 KiB ROM layout; asserts no `.data`/`.bss` and the 2 KiB limit |
| `Makefile` | build, size check against the 1 KiB code budget, `make test` |
| `tools/bin2hex.py` | `boot.bin` → `rom_image.hex` (512 × 32-bit words, LE) |
| `tools/qsoc_image.py` | app `.bin` (and `--debug dbg.bin`) → frame (pads, sets LENGTH and DEBUG_PROG) |
| `tools/qsoc_loader.py` | PC loader over USB-UART (needs `pyserial`) |
| `tools/rom_model.py` | Python model of `boot.c`, step for step, with the `DBG_EN` pin and `dbg_en_mask` |
| `tools/test_serial_link.py` | the loader command line through pyserial (`socket://`) against the model: good frame, FPCR and FTMO (lost byte) retries, `--debug` |
| `tools/test_protocol.py` | loader vs model: good frame, noise, changed and lost bytes, bad CRCs, LENGTH checks, DEBUG_PROG other than 0x55, debug program, debug wait and release, timeout, early stop after a stall |

## Build and test

```sh
make CROSS=riscv-none-elf-          # xPack (Windows: add PYTHON=py); or riscv64-unknown-elf-
make CROSS=riscv-none-elf- rtl      # also regenerate util/gen/rom/m_qnsc_rom_image.sv
make test                           # protocol test, needs only Python 3
make test-serial                    # loader CLI over pyserial, needs pip install pyserial
python3 tools/qsoc_loader.py COM5 app.bin   # opens the port at 19200 8N1
python3 tools/qsoc_loader.py COM5 app.bin --debug dbg.bin   # with a debug program
```

## Status (14/10/2026, QNSC_BOOT_SPEC V3.4)

- V3.4 from the mentor's feedback of 14/10: the ROM loads the debug program
  when `DEBUG_PROG` is exactly `0x0000_0055` and skips it otherwise; `0xAA`
  is no longer checked and `FHDR` is now for `LENGTH` only. `HDR_CRC` already
  vouches for the value, so nothing is lost.
- `make test`: 46 checks pass; `make test-serial`: 10 checks pass.
- Built with xPack `riscv-none-elf-gcc` 15.2.0 and `-Werror`:
  **734 B image, 606 B of code after the 128 B vector table** (budget 1024 B,
  418 B left). `make CROSS=riscv-none-elf- rtl` put the image into `util/gen/rom/`.

### V3.3 (12/10/2026)

- V3.3 changes from the mentor's debug boot flow of 12/10: the header gains
  `DEBUG_PROG` (16 B); with 0x55 a 4 096-byte debug program and `DBG_CRC`
  follow it and go to `0x2000_0000`, answered by `ACKD` / `FDCR`; after `ACKP`
  the ROM waits while SYSCSR `DBG_BOOT.dbg_en` = 1. Debug boot runs this code
  too: no CPU hold, no boot address mux, no load over JTAG.
- `make test`: all protocol cases pass against the model (45 checks).
  `make test-serial`: the loader CLI through pyserial passes (9 checks).
- Built with xPack `riscv-none-elf-gcc` 15.2.0 and `-Werror`:
  **748 B image, 620 B of code after the 128 B vector table** (budget 1024 B,
  404 B left). `make CROSS=riscv-none-elf- rtl` put the image into `util/gen/rom/`.

### V3.2 (09/10/2026)

- V3.2 changes from the mentor review of 08/10: the header drops `LOAD_ADDR`
  and `ENTRY` (12 B instead of 20 B); the payload always goes to `0x2000_1000`
  and the ROM jumps to `0x2000_1080`, as in debug boot; `LENGTH` 132 to 61 440;
  `FUAR` removed and the UART error bits no longer read.
- `make test`: all protocol cases pass against the model (27 checks).
  `make test-serial`: the loader CLI through pyserial passes (7 checks).
- Built with xPack `riscv-none-elf-gcc` 15.2.0 and `-Werror`:
  **672 B image, 544 B of code after the 128 B vector table** (budget 1024 B,
  480 B left). `make CROSS=riscv-none-elf- rtl` put the image into `util/gen/rom/`.

### V3.1 (01/10/2026)

- `make test`: all protocol cases pass against the model (24 checks).
  `make test-serial`: the loader CLI through pyserial 3.5 passes (7 checks).
  Not yet run on a real USB-UART port: no adapter on the test machine.
- V3.1 changes from the mentor review of 29/09: no `QRDY` after reset, `QRDY`
  only after a failure; 19 200 baud (divisor 65); UART errors before the magic
  ignored; the failure token leaves UART0 in full before the drain, which
  clears the RX FIFO only; `RX_TIMEOUT` 1 000 000 and `DRAIN_IDLE` 500 000
  polls; the loader sends the payload in chunks and stops on a failure token.
- Built with xPack `riscv-none-elf-gcc` 15.2.0 and `-Werror`:
  **730 B image, 602 B of code after the 128 B vector table** (budget 1024 B,
  422 B left). `make CROSS=riscv-none-elf- rtl` put the image into `util/gen/rom/`.
- Open: the time per `LSR` poll, to be measured in simulation (QNSC_BOOT_SPEC 10).
- Addresses will come from `qnsc_map.h` once the lead generates it from the
  contract (QNSC_BOOT_SPEC Table 10-1).
- V3.1/V3.2 only: debug boot (DBG_EN = 1) did not run this code. Since V3.3 it does.
