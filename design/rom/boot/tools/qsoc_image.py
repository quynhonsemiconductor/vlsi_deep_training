#!/usr/bin/env python3
"""Build a QSOC boot frame from an application binary, and optionally a debug
program.

Frame (all fields little-endian, see ../boot.h):
    MAGIC 'QSOC' | LENGTH | DEBUG_PROG | HDR_CRC
    [ DEBUG_PAYLOAD (4096 B) | DBG_CRC ]      only when DEBUG_PROG = 0x55
    PAYLOAD | PAY_CRC
    HDR_CRC = crc32(bytes 0x00..0x0B), DBG_CRC = crc32(DEBUG_PAYLOAD),
    PAY_CRC = crc32(PAYLOAD), zlib CRC32.

The ROM always writes the payload from 0x2000_1000 and jumps to 0x2000_1080,
so the application must be linked at 0x2000_1000. The debug program is padded
to 4096 bytes and written from 0x2000_0000.

  qsoc_image.py app.bin app.qsoc
  qsoc_image.py app.bin app.qsoc --debug dbg.bin
"""
import argparse
import struct
import sys
import zlib

# ---- must match ../boot.h ------------------------------------------------
ISRAM_DBG_BASE = 0x2000_0000
ISRAM_APP_BASE = 0x2000_1000
ISRAM_END = 0x2001_0000
APP_ENTRY = ISRAM_APP_BASE + 0x80
APP_MIN_LEN = APP_ENTRY + 4 - ISRAM_APP_BASE   # 132: the payload reaches ENTRY
APP_MAX_LEN = ISRAM_END - ISRAM_APP_BASE
DBG_LEN = ISRAM_APP_BASE - ISRAM_DBG_BASE      # 4096, always sent in full
MAGIC = b"QSOC"
DEBUG_PROG_ON = 0x55       # the debug program precedes the payload
DEBUG_PROG_OFF = 0xAA      # the payload only

TOKENS = {
    b"QRDY": "ROM ready, waiting for a frame",
    b"ACKH": "header accepted",
    b"ACKD": "debug program CRC ok",
    b"ACKP": "payload CRC ok; the ROM jumps to 0x2000_1080, after the host "
             "releases it if the DBG_EN pin is 1",
    b"FHCR": "header CRC mismatch",
    b"FHDR": "LENGTH out of range or DEBUG_PROG not 0x55/0xAA",
    b"FDCR": "debug program CRC mismatch",
    b"FPCR": "payload CRC mismatch",
    b"FTMO": "timeout between two bytes",
}
FAIL_TOKENS = {t for t in TOKENS if t.startswith(b"F")}

HEADER_LEN = 16
DEBUG_PART_LEN = DBG_LEN + 4               # DEBUG_PAYLOAD + DBG_CRC


def check_header(length: int, debug_prog: int = DEBUG_PROG_OFF) -> str:
    """Same check as boot.c. Returns '' if valid."""
    if length % 4 or length < APP_MIN_LEN or length > APP_MAX_LEN:
        return f"LENGTH {length} must be a multiple of 4, {APP_MIN_LEN} to {APP_MAX_LEN}"
    if debug_prog not in (DEBUG_PROG_ON, DEBUG_PROG_OFF):
        return f"DEBUG_PROG 0x{debug_prog:x} must be 0x55 or 0xAA"
    return ""


def make_header(length: int, debug_prog: int = DEBUG_PROG_OFF) -> bytes:
    body = MAGIC + struct.pack("<II", length, debug_prog)
    return body + struct.pack("<I", zlib.crc32(body))


def with_crc(data: bytes) -> bytes:
    return data + struct.pack("<I", zlib.crc32(data))


def make_frame(payload: bytes, debug: bytes = None, force: bool = False) -> tuple:
    """Returns (header, debug_part, payload_and_crc). Pads the payload to a
    multiple of 4 and the debug program to 4096 bytes. debug_part is b''
    when there is no debug program."""
    payload = payload + bytes(-len(payload) % 4)
    debug_prog = DEBUG_PROG_OFF if debug is None else DEBUG_PROG_ON
    err = check_header(len(payload), debug_prog)
    if debug is not None and len(debug) > DBG_LEN:
        err = err or f"debug program {len(debug)} B, at most {DBG_LEN}"
    if err and not force:
        raise ValueError(err)
    header = make_header(len(payload), debug_prog)
    dpart = b"" if debug is None else with_crc(debug + bytes(DBG_LEN - len(debug)))
    return header, dpart, with_crc(payload)


def split_frame(raw: bytes) -> tuple:
    """The inverse of make_frame for a frame file: (header, debug_part, rest)."""
    header = raw[:HEADER_LEN]
    debug_prog, = struct.unpack_from("<I", header, 8)
    n = DEBUG_PART_LEN if debug_prog == DEBUG_PROG_ON else 0
    return header, raw[HEADER_LEN:HEADER_LEN + n], raw[HEADER_LEN + n:]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("bin", help="raw application binary (objcopy -O binary)")
    ap.add_argument("out", help="frame file to send with qsoc_loader.py --frame")
    ap.add_argument("--debug", help="debug program .bin, at most 4096 B, linked at 0x2000_0000")
    a = ap.parse_args()

    payload = open(a.bin, "rb").read()
    debug = open(a.debug, "rb").read() if a.debug else None
    try:
        header, dpart, rest = make_frame(payload, debug)
    except ValueError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    open(a.out, "wb").write(header + dpart + rest)
    length, debug_prog, hcrc = struct.unpack_from("<III", header, 4)
    dcrc = f"DBG_CRC=0x{struct.unpack_from('<I', dpart, DBG_LEN)[0]:08x} " if dpart else ""
    print(f"{a.out}: LENGTH={length} DEBUG_PROG=0x{debug_prog:02x} HDR_CRC=0x{hcrc:08x} "
          f"{dcrc}PAY_CRC=0x{struct.unpack_from('<I', rest, len(rest) - 4)[0]:08x}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
