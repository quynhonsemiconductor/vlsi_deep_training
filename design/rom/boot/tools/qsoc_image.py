#!/usr/bin/env python3
"""Build a QSOC boot frame from an application binary.

Frame (all fields little-endian, see ../boot.h):
    MAGIC 'QSOC' | LENGTH | LOAD_ADDR | ENTRY | HDR_CRC | PAYLOAD | PAY_CRC
    HDR_CRC = crc32(bytes 0x00..0x0F), PAY_CRC = crc32(PAYLOAD), zlib CRC32.

  qsoc_image.py app.bin app.qsoc                       (load 0x2000_1000, entry +0x80)
  qsoc_image.py app.bin app.qsoc --load 0x20001000 --entry 0x20001080
"""
import argparse
import struct
import sys
import zlib

# ---- must match ../boot.h ------------------------------------------------
ISRAM_APP_BASE = 0x2000_1000
ISRAM_END = 0x2001_0000
APP_MAX_LEN = ISRAM_END - ISRAM_APP_BASE
MAGIC = b"QSOC"

TOKENS = {
    b"QRDY": "ROM ready, waiting for a frame",
    b"ACKH": "header accepted",
    b"ACKP": "payload CRC ok, ROM jumps to ENTRY",
    b"FHCR": "header CRC mismatch",
    b"FHDR": "header field out of range",
    b"FPCR": "payload CRC mismatch",
    b"FTMO": "timeout between two bytes",
    b"FUAR": "UART overrun / parity / framing error",
}
FAIL_TOKENS = {t for t in TOKENS if t.startswith(b"F")}

HEADER_LEN = 20


def check_header(length: int, load: int, entry: int) -> str:
    """Same checks as boot.c, in the same order. Returns '' if valid."""
    if length == 0 or length % 4 or length > APP_MAX_LEN:
        return f"LENGTH {length} must be a non-zero multiple of 4, <= {APP_MAX_LEN}"
    if load % 4 or load < ISRAM_APP_BASE or load > ISRAM_END:
        return f"LOAD_ADDR 0x{load:08x} must be word-aligned, >= 0x{ISRAM_APP_BASE:08x}"
    if length > ISRAM_END - load:
        return f"image ends at 0x{load + length:08x}, past ISRAM end 0x{ISRAM_END:08x}"
    if entry % 2 or entry < load or entry - load >= length:
        return f"ENTRY 0x{entry:08x} must be even and inside the payload"
    return ""


def make_header(length: int, load: int, entry: int) -> bytes:
    body = MAGIC + struct.pack("<III", length, load, entry)
    return body + struct.pack("<I", zlib.crc32(body))


def make_frame(payload: bytes, load: int = ISRAM_APP_BASE, entry: int = None,
               force: bool = False) -> tuple:
    """Returns (header, payload_and_crc). Pads payload to a multiple of 4."""
    if entry is None:
        entry = load + 0x80
    payload = payload + bytes(-len(payload) % 4)
    err = check_header(len(payload), load, entry)
    if err and not force:
        raise ValueError(err)
    header = make_header(len(payload), load, entry)
    return header, payload + struct.pack("<I", zlib.crc32(payload))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("bin", help="raw application binary (objcopy -O binary)")
    ap.add_argument("out", help="frame file to send with qsoc_loader.py --frame")
    ap.add_argument("--load", type=lambda s: int(s, 0), default=ISRAM_APP_BASE)
    ap.add_argument("--entry", type=lambda s: int(s, 0), default=None,
                    help="default: LOAD_ADDR + 0x80 (vector table first, like the ROM)")
    a = ap.parse_args()

    payload = open(a.bin, "rb").read()
    try:
        header, rest = make_frame(payload, a.load, a.entry)
    except ValueError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    open(a.out, "wb").write(header + rest)
    length, load, entry = struct.unpack_from("<III", header, 4)
    print(f"{a.out}: LENGTH={length} LOAD=0x{load:08x} ENTRY=0x{entry:08x} "
          f"HDR_CRC=0x{struct.unpack_from('<I', header, 16)[0]:08x} "
          f"PAY_CRC=0x{struct.unpack_from('<I', rest, len(rest) - 4)[0]:08x}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
