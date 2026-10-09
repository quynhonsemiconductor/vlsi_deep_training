# `rom/boot` — serial bootloader burned into the boot ROM

**Owner:** Nam Nguyen Hao · **Spec:** [`QNSC_BOOT_SPEC.md`](../../../doc/specs/QNSC_BOOT_SPEC.md) V3.2

Software, not RTL: its only output consumed by the hardware is `rom_image.hex`,
which `make rtl` copies to `util/gen/rom/` and turns into the constant module
`m_qnsc_rom_image` with `util/gen_rom.py` (QNSC_ROM_MAS 7.2).

## What it does

After reset Ibex fetches `ROM_BASE + 0x80`. The ROM configures UART0 at
0x8002_0000 (divisor 65: 19 231 baud 8N1, polling) and, sending nothing,
listens for the magic. It receives one frame from the PC, writes the payload
into ISRAM word by word from `0x2000_1000`, checks both CRCs and jumps to
`0x2000_1080`: the same addresses as debug boot, so the frame carries none. Every step
after the magic answers with a 4-byte token; on failure the ROM sends the
token, drains the line, sends `QRDY`, and the PC resends the whole frame.

## Frame (all fields little-endian)

| Offset | Size | Field | Checked by the ROM |
|---|---|---|---|
| 0x00 | 4 | MAGIC | `'Q','S','O','C'` in that order (LE word `0x434F5351`) |
| 0x04 | 4 | LENGTH | payload bytes, `%4 == 0`, 132 .. 61440 (the image reaches `0x2000_1080` and fits in ISRAM) |
| 0x08 | 4 | HDR_CRC | CRC32 of bytes 0x00..0x07 |
| 0x0C | N | PAYLOAD | raw bytes of the app `.bin`, linked at `0x2000_1000` |
| 0x0C+N | 4 | PAY_CRC | CRC32 of PAYLOAD |

CRC32 is zlib/IEEE (reflected `0xEDB88320`, init and final XOR `0xFFFFFFFF`):
`zlib.crc32()` on the PC, bitwise in the ROM.

## Handshake

```
               PC: header (12 B)              (nothing is sent after reset)
ROM: ACKH | FHCR | FHDR | FTMO
               PC: PAYLOAD + PAY_CRC, in 256-byte chunks
ROM: ACKP | FPCR | FTMO             (ACKP = jumping to 0x2000_1080)
after any F***:  ROM drains the line, then QRDY;  PC resends the whole frame
```
`FTMO` = more than `RX_TIMEOUT` polls (at least 100 ms) between two bytes
after the magic. The ROM does not read the UART error bits: a byte with a
framing error fails a CRC (`FHCR`/`FPCR`), a byte lost to an overrun leaves
the frame short and ends in `FTMO`. Bytes before the magic are skipped
silently. The
loader checks for a failure token between payload chunks and stops sending
at once: UART0 has no hardware flow control.

## Files

| File | What |
|---|---|
| `boot.h` | memory map, UART registers, timeouts, frame and token constants |
| `crt0.S` | 128-byte trap table + `_start` at 0x80 (SP = top of DSRAM) |
| `boot.c` | the bootloader |
| `link.ld` | 2 KiB ROM layout; asserts no `.data`/`.bss` and the 2 KiB limit |
| `Makefile` | build, size check against the 1 KiB code budget, `make test` |
| `tools/bin2hex.py` | `boot.bin` → `rom_image.hex` (512 × 32-bit words, LE) |
| `tools/qsoc_image.py` | app `.bin` → frame (pads to a multiple of 4, sets LENGTH) |
| `tools/qsoc_loader.py` | PC loader over USB-UART (needs `pyserial`) |
| `tools/rom_model.py` | Python model of `boot.c`, step for step |
| `tools/test_serial_link.py` | the loader command line through pyserial (`socket://`) against the model: good frame, FPCR and FTMO (lost byte) retries |
| `tools/test_protocol.py` | loader vs model: good frame, noise, changed and lost bytes, bad CRCs, LENGTH limits, timeout, early stop after a stall |

## Build and test

```sh
make CROSS=riscv-none-elf-          # xPack (Windows: add PYTHON=py); or riscv64-unknown-elf-
make CROSS=riscv-none-elf- rtl      # also regenerate util/gen/rom/m_qnsc_rom_image.sv
make test                           # protocol test, needs only Python 3
make test-serial                    # loader CLI over pyserial, needs pip install pyserial
python3 tools/qsoc_loader.py COM5 app.bin   # opens the port at 19200 8N1
```

## Status (09/10/2026, QNSC_BOOT_SPEC V3.2)

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
- Debug boot (DBG_EN = 1) does not run this code (QNSC_SYSDBG_MAS 7.2).
