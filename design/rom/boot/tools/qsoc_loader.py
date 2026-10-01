#!/usr/bin/env python3
"""PC-side loader for the QSOC boot ROM (USB-UART -> UART0, 8N1).

The PC opens the port at 19200; the ROM runs at 20 MHz / (16 x 65) = 19 231
baud, 0.16 % faster, well inside the 8N1 tolerance (QNSC_BOOT_SPEC V3.1, 5).

  qsoc_loader.py COM5 app.bin                   build the frame and send it
  qsoc_loader.py /dev/ttyUSB0 --frame app.qsoc  send a prebuilt frame
  qsoc_loader.py socket://127.0.0.1:5555 app.bin  any pyserial URL works too

Protocol (ROM tokens are 4 ASCII bytes; the ROM sends nothing after reset):
  PC: header (20 B)  ->  ROM: ACKH | FHCR | FHDR | FTMO | FUAR
  PC: payload + PAY_CRC, in chunks  ->  ROM: ACKP | FPCR | FTMO | FUAR
  The loader checks for a failure token between chunks and stops sending at
  once (there is no hardware flow control). On any F*** token the ROM drains
  the line and sends QRDY; the loader waits for it and resends the whole
  frame, up to --retries times.
Needs pyserial (pip install pyserial) only for a real port.
"""
import argparse
import struct
import sys
import time

from qsoc_image import FAIL_TOKENS, HEADER_LEN, TOKENS, make_frame

BAUD = 19200
CHUNK = 256            # payload bytes per write; a failure token is checked between chunks


class SerialLink:
    """Thin wrapper so the protocol code also runs against rom_model.py."""

    def __init__(self, port: str, baud: int = BAUD):
        import serial  # imported here: the model test does not need it
        # serial_for_url opens a plain port name (COM5, /dev/ttyUSB0) like
        # serial.Serial, and also a URL such as socket://host:port, which
        # tools/test_serial_link.py uses to reach the ROM model over pyserial.
        self.s = serial.serial_for_url(port, baudrate=baud, bytesize=8, parity="N",
                                       stopbits=1, timeout=0.05)

    def write(self, data: bytes) -> None:
        self.s.write(data)
        self.s.flush()

    def read(self, n: int, timeout: float) -> bytes:
        self.s.timeout = timeout
        return self.s.read(n)

    def read_available(self) -> bytes:
        n = self.s.in_waiting
        return self.s.read(n) if n else b""

    def reset_input(self) -> None:
        self.s.reset_input_buffer()


def wait_token(link, wanted: set, timeout: float, window: bytes = b"") -> bytes:
    """Slide a 4-byte window over incoming bytes until a known token shows up.
    Returns the token, or b'' on timeout. Bytes that are not tokens (e.g. line
    noise) are ignored."""
    deadline = time.monotonic() + timeout
    while True:
        left = deadline - time.monotonic()
        if left <= 0:
            return b""
        c = link.read(1, min(left, 0.05))
        if not c:
            continue
        window = (window + c)[-4:]
        if window in wanted:
            return window


def payload_seconds(n_bytes: int, baud: int = BAUD) -> float:
    return n_bytes * 10 / baud          # 8N1 = 10 bits per byte


def find_token(data: bytes, wanted: set) -> bytes:
    for k in range(len(data) - 3):
        if data[k:k + 4] in wanted:
            return data[k:k + 4]
    return b""


def send_payload(link, body: bytes):
    """Send the payload in chunks; stop at once if a failure token arrives.

    Returns (bytes_seen_from_rom, token_or_b''). ACKP is looked for too: it
    can arrive while the last chunk is still being written. The check
    between chunks does not block, so it puts no gap in the stream.
    """
    seen = b""
    for i in range(0, len(body), CHUNK):
        link.write(body[i:i + CHUNK])
        seen += link.read_available()
        tok = find_token(seen, FAIL_TOKENS | {b"ACKP"})
        if tok:
            return seen, tok
    return seen, b""


def download(link, header: bytes, body: bytes, retries: int = 5,
             ready_timeout: float = 3.0, log=print) -> bool:
    length, load, entry = struct.unpack_from("<III", header, 4)
    log(f"frame: LENGTH={length} LOAD=0x{load:08x} ENTRY=0x{entry:08x}, "
        f"~{payload_seconds(len(header) + len(body)):.1f} s at {BAUD} baud")
    failed = False        # the ROM sends QRDY only after a failure token
    for attempt in range(1, retries + 1):
        if failed:
            tok = wait_token(link, {b"QRDY"}, ready_timeout)
            if not tok:
                log(f"[{attempt}] no QRDY within {ready_timeout:.0f} s - sending anyway")
        failed = False
        link.write(header)
        tok = wait_token(link, {b"ACKH"} | FAIL_TOKENS, 2.0)
        if tok != b"ACKH":
            # no answer at all: the ROM missed the magic and is still hunting
            failed = tok in FAIL_TOKENS
            log(f"[{attempt}] header: {tok.decode() if tok else 'no answer'}"
                f" - {TOKENS.get(tok, 'timeout')}")
            continue
        seen, tok = send_payload(link, body)
        if not tok:
            tok = wait_token(link, {b"ACKP"} | FAIL_TOKENS, 2.0, seen[-3:])
        if tok == b"ACKP":
            log(f"[{attempt}] ACKP - application started at 0x{entry:08x}")
            return True
        failed = tok in FAIL_TOKENS
        log(f"[{attempt}] payload: {tok.decode() if tok else 'no answer'}"
            f" - {TOKENS.get(tok, 'timeout')}")
    log(f"failed after {retries} attempts")
    return False


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("port")
    ap.add_argument("bin", nargs="?", help="application .bin (objcopy -O binary)")
    ap.add_argument("--frame", help="prebuilt frame from qsoc_image.py")
    ap.add_argument("--load", type=lambda s: int(s, 0), default=0x2000_1000)
    ap.add_argument("--entry", type=lambda s: int(s, 0), default=None)
    ap.add_argument("--retries", type=int, default=5)
    a = ap.parse_args()

    if a.frame:
        raw = open(a.frame, "rb").read()
        header, body = raw[:HEADER_LEN], raw[HEADER_LEN:]
    elif a.bin:
        header, body = make_frame(open(a.bin, "rb").read(), a.load, a.entry)
    else:
        ap.error("give an application .bin or --frame")
    link = SerialLink(a.port)
    link.reset_input()
    return 0 if download(link, header, body, a.retries) else 1


if __name__ == "__main__":
    sys.exit(main())
