# `rom/boot` — serial bootloader burned into the boot ROM

**Owner:** Nam Nguyen Hao · **Spec:** [`QNSC_BOOT_SPEC.md`](../../../doc/specs/QNSC_BOOT_SPEC.md) V3.0

Software, not RTL: its only output consumed by the hardware is `rom_image.hex`,
which `make rtl` copies to `util/gen/rom/` and turns into the constant module
`m_qnsc_rom_image` with `util/gen_rom.py` (QNSC_ROM_MAS 7.2).

## What it does

After reset Ibex fetches `ROM_BASE + 0x80`. The ROM configures UART0 at
0x8002_0000 (divisor 11: 113 636 baud 8N1, polling), sends `QRDY`, receives one frame from the PC, writes the
payload into ISRAM word by word, checks both CRCs and jumps to `ENTRY`. Every
step answers with a 4-byte token; on failure it drains the line, sends `QRDY`
again and the PC resends the whole frame.

## Frame (all fields little-endian)

| Offset | Size | Field | Checked by the ROM |
|---|---|---|---|
| 0x00 | 4 | MAGIC | `'Q','S','O','C'` in that order (LE word `0x434F5351`) |
| 0x04 | 4 | LENGTH | payload bytes, `%4 == 0`, 4 .. 61440 |
| 0x08 | 4 | LOAD_ADDR | `%4 == 0`, `>= 0x2000_1000`, `LOAD+LENGTH <= 0x2001_0000` |
| 0x0C | 4 | ENTRY | even, `LOAD <= ENTRY < LOAD+LENGTH` |
| 0x10 | 4 | HDR_CRC | CRC32 of bytes 0x00..0x0F |
| 0x14 | N | PAYLOAD | raw bytes of the app `.bin` |
| 0x14+N | 4 | PAY_CRC | CRC32 of PAYLOAD |

CRC32 is zlib/IEEE (reflected `0xEDB88320`, init and final XOR `0xFFFFFFFF`):
`zlib.crc32()` on the PC, bitwise in the ROM.

## Handshake

```
ROM: QRDY      PC: header (20 B)
ROM: ACKH | FHCR | FHDR | FTMO | FUAR
               PC: PAYLOAD + PAY_CRC
ROM: ACKP | FPCR | FTMO | FUAR      (ACKP = jumping to ENTRY)
```
`FTMO` = more than ~100 ms between two bytes after the magic. `FUAR` = UART
overrun/parity/framing error. Bytes before the magic are skipped silently.

## Files

| File | What |
|---|---|
| `boot.h` | memory map, UART registers, timeouts, frame and token constants |
| `crt0.S` | 128-byte trap table + `_start` at 0x80 (SP = top of DSRAM) |
| `boot.c` | the bootloader |
| `link.ld` | 2 KiB ROM layout; asserts no `.data`/`.bss` and the 2 KiB limit |
| `Makefile` | build, size check against the 1 KiB code budget, `make test` |
| `tools/bin2hex.py` | `boot.bin` → `rom_image.hex` (512 × 32-bit words, LE) |
| `tools/qsoc_image.py` | app `.bin` → frame (`--load`, `--entry`, default LOAD+0x80) |
| `tools/qsoc_loader.py` | PC loader over USB-UART (needs `pyserial`) |
| `tools/rom_model.py` | Python model of `boot.c`, step for step |
| `tools/test_protocol.py` | loader vs model: good frame, noise, bad CRCs, bad fields, timeout |

## Build and test

```sh
make CROSS=riscv-none-elf-          # xPack (Windows: add PYTHON=py); or riscv64-unknown-elf-
make CROSS=riscv-none-elf- rtl      # also regenerate util/gen/rom/m_qnsc_rom_image.sv
make test                           # protocol test, needs only Python 3
python3 tools/qsoc_loader.py COM5 app.bin
```

## Status (29/09/2026)

- `make test`: all protocol cases pass against the model.
- `UART0_BASE` corrected to 0x8002_0000 (APB_M8); 0x8002_4000 is UART1.
- `fence.i` written as the mnemonic, built with `-march=rv32imc_zicsr_zifencei`.
- Built with xPack `riscv-none-elf-gcc` 15.2.0 and `-Werror`:
  **712 B image, 584 B of code after the 128 B vector table** (budget 1024 B,
  440 B left). `_start` at 0x80, 32 vectors to `rom_trap`, `fence.i` before
  the jump. `make CROSS=riscv-none-elf- rtl` put the image into `util/gen/rom/`.
- Addresses will come from `qnsc_map.h` once the lead generates it from the
  contract (QNSC_BOOT_SPEC Table 10-1).
- Debug boot (DBG_EN = 1) does not run this code (QNSC_SYSDBG_MAS 7.2).
