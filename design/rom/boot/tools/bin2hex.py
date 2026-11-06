#!/usr/bin/env python3
"""boot.bin -> rom_image.hex: one 32-bit word per line, little-endian (byte 0
of the ROM is bits [7:0] of word 0), padded with zeros to the full 512 words.
It is the input of util/gen_rom.py, which turns it into the constant module
m_qnsc_rom_image (QNSC_ROM_MAS 7.2); the RTL never reads the hex itself.

  bin2hex.py boot.bin rom_image.hex --words 512
  bin2hex.py boot.bin - --words 512 --budget 1024 --report   (size check only)
"""
import argparse
import sys

TRAP_TABLE = 0x80


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("bin")
    ap.add_argument("hex", help="output file, or - for none")
    ap.add_argument("--words", type=int, default=512)
    ap.add_argument("--budget", type=int, default=0,
                    help="max code bytes after the trap table (0 = no check)")
    ap.add_argument("--report", action="store_true")
    a = ap.parse_args()

    data = open(a.bin, "rb").read()
    rom_bytes = a.words * 4
    if len(data) > rom_bytes:
        print(f"error: image {len(data)} B > ROM {rom_bytes} B", file=sys.stderr)
        return 1

    code = max(0, len(data) - TRAP_TABLE)
    if a.report:
        print(f"ROM image : {len(data)} B of {rom_bytes} B")
        print(f"boot code : {code} B after the 128 B trap table"
              + (f" (budget {a.budget} B, {a.budget - code:+d} B left)" if a.budget else ""))
    if a.budget and code > a.budget:
        print(f"error: boot code {code} B exceeds budget {a.budget} B", file=sys.stderr)
        return 1

    if a.hex != "-":
        data = data + bytes(rom_bytes - len(data))
        with open(a.hex, "w", newline="\n") as f:
            for i in range(0, rom_bytes, 4):
                f.write(f"{int.from_bytes(data[i:i + 4], 'little'):08x}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
