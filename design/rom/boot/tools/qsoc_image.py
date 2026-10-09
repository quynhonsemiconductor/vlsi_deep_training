#!/usr/bin/env python3
"""Build a QSOC boot frame from an application binary.

Frame (all fields little-endian, see ../boot.h):
    MAGIC 'QSOC' | LENGTH | HDR_CRC | PAYLOAD | PAY_CRC
    HDR_CRC = crc32(bytes 0x00..0x07), PAY_CRC = crc32(PAYLOAD), zlib CRC32.

The ROM always writes the payload from 0x2000_1000 and jumps to 0x2000_1080,
as in debug boot, so the application must be linked at 0x2000_1000.

  qsoc_image.py app.bin app.qsoc
"""
import argparse
import struct
import sys
import zlib

# ---- must match ../boot.h ------------------------------------------------
ISRAM_APP_BASE = 0x2000_1000
ISRAM_END = 0x2001_0000
APP_ENTRY = ISRAM_APP_BASE + 0x80
APP_MIN_LEN = APP_ENTRY + 4 - ISRAM_APP_BASE   # 132: the payload reaches ENTRY
APP_MAX_LEN = ISRAM_END - ISRAM_APP_BASE
MAGIC = b"QSOC"

TOKENS = {
    b"QRDY": "ROM ready, waiting for a frame",
    b"ACKH": "header accepted",
    b"ACKP": "payload CRC ok, ROM jumps to 0x2000_1080",
    b"FHCR": "header CRC mismatch",
    b"FHDR": "LENGTH out of range",
    b"FPCR": "payload CRC mismatch",
    b"FTMO": "timeout between two bytes",
}
FAIL_TOKENS = {t for t in TOKENS if t.startswith(b"F")}

HEADER_LEN = 12


def check_header(length: int) -> str:
    """Same check as boot.c. Returns '' if valid."""
    if length % 4 or length < APP_MIN_LEN or length > APP_MAX_LEN:
        return f"LENGTH {length} must be a multiple of 4, {APP_MIN_LEN} to {APP_MAX_LEN}"
    return ""


def make_header(length: int) -> bytes:
    body = MAGIC + struct.pack("<I", length)
    return body + struct.pack("<I", zlib.crc32(body))


def make_frame(payload: bytes, force: bool = False) -> tuple:
    """Returns (header, payload_and_crc). Pads payload to a multiple of 4."""
    payload = payload + bytes(-len(payload) % 4)
    err = check_header(len(payload))
    if err and not force:
        raise ValueError(err)
    header = make_header(len(payload))
    return header, payload + struct.pack("<I", zlib.crc32(payload))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("bin", help="raw application binary (objcopy -O binary)")
    ap.add_argument("out", help="frame file to send with qsoc_loader.py --frame")
    a = ap.parse_args()

    payload = open(a.bin, "rb").read()
    try:
        header, rest = make_frame(payload)
    except ValueError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    open(a.out, "wb").write(header + rest)
    length, = struct.unpack_from("<I", header, 4)
    print(f"{a.out}: LENGTH={length} "
          f"HDR_CRC=0x{struct.unpack_from('<I', header, 8)[0]:08x} "
          f"PAY_CRC=0x{struct.unpack_from('<I', rest, len(rest) - 4)[0]:08x}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
