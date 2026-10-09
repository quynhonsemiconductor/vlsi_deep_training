#!/usr/bin/env python3
"""Behavioural model of boot.c, for testing the PC loader without hardware.

Mirrors boot_once()/boot_main() step for step; keep the two in sync. Timeouts
are wall-clock seconds here, loop counts in the C code.

Like boot.c, the model has no notion of a UART error: a test stands for a
framing error by changing a byte, and for an overrun by dropping one.
"""
import queue
import struct
import threading
import time
import zlib

from qsoc_image import APP_ENTRY, APP_MAX_LEN, APP_MIN_LEN, ISRAM_APP_BASE

RX_TIMEOUT_S = 0.1     # boot.h RX_TIMEOUT   (>= 100 ms, QNSC_BOOT_SPEC 7.3)
DRAIN_IDLE_S = 0.05    # boot.h DRAIN_IDLE   (>= 50 ms)


class _Timeout(Exception):
    pass


class Pipe:
    """One direction of a byte stream."""

    def __init__(self):
        self.q = queue.Queue()

    def put(self, data) -> None:
        for b in data:
            self.q.put(b)

    def get(self, timeout):
        try:
            return self.q.get(timeout=timeout)
        except queue.Empty:
            return None


class PcSide:
    """Link object handed to qsoc_loader.download().

    tamper(n, data) may change the n-th write (1 = header, 2.. = payload
    chunks).
    byte_time > 0 makes each write take as long as the bytes would on the
    wire, so the ROM answers while the PC is still sending.
    """

    def __init__(self, to_rom: Pipe, from_rom: Pipe, tamper=None, byte_time=0.0):
        self.to_rom, self.from_rom, self.tamper = to_rom, from_rom, tamper
        self.byte_time = byte_time
        self.writes = 0
        self.bytes_sent = 0

    def write(self, data: bytes) -> None:
        self.writes += 1
        if self.tamper:
            data = self.tamper(self.writes, data)
        self.bytes_sent += len(data)
        self.to_rom.put(data)
        if self.byte_time:
            time.sleep(len(data) * self.byte_time)

    def read(self, n: int, timeout: float) -> bytes:
        out = b""
        while len(out) < n:
            b = self.from_rom.get(timeout)
            if b is None:
                break
            out += bytes([b])
        return out

    def read_available(self) -> bytes:
        out = b""
        while True:
            b = self.from_rom.get(0)
            if b is None:
                return out
            out += bytes([b])

    def reset_input(self) -> None:
        while self.from_rom.get(0) is not None:
            pass


class RomModel(threading.Thread):
    def __init__(self, rx: Pipe, tx: Pipe):
        super().__init__(daemon=True)
        self.rx, self.tx = rx, tx
        self.ram = {}                 # word address -> value
        self.entry = None             # set when the ROM "jumps"
        self.sent = []                # tokens, for the test to inspect
        self.stop = False

    # -- UART ----------------------------------------------------------------
    def put_tok(self, tok: bytes) -> None:
        self.sent.append(tok)
        self.tx.put(tok)

    def getc(self, limit):
        b = self.rx.get(limit)
        if b is None:
            raise _Timeout
        return b

    def get32(self) -> int:
        w = 0
        for _ in range(4):
            w = (w >> 8) | (self.getc(RX_TIMEOUT_S) << 24)
        return w

    def drain(self) -> None:          # RX FIFO cleared, then until quiet
        while self.rx.get(DRAIN_IDLE_S) is not None:
            pass

    # -- boot_once() -----------------------------------------------------------
    def boot_once(self) -> bytes:
        window = b""
        while window != b"QSOC":      # sliding window, waits forever
            b = self.rx.get(0.05)
            if self.stop:
                return b""
            if b is None:
                continue
            window = (window + bytes([b]))[-4:]
        try:
            length, hcrc = (self.get32() for _ in range(2))
            if zlib.crc32(b"QSOC" + struct.pack("<I", length)) != hcrc:
                return b"FHCR"
            if length % 4 or length < APP_MIN_LEN or length > APP_MAX_LEN:
                return b"FHDR"
            self.put_tok(b"ACKH")
            crc = 0
            for a in range(ISRAM_APP_BASE, ISRAM_APP_BASE + length, 4):
                w = self.get32()
                self.ram[a] = w
                crc = zlib.crc32(struct.pack("<I", w), crc)
            if crc != self.get32():
                return b"FPCR"
        except _Timeout:
            return b"FTMO"
        self.put_tok(b"ACKP")
        self.entry = APP_ENTRY
        return b""

    def run(self) -> None:          # boot_main(): no token after reset
        while not self.stop:
            tok = self.boot_once()
            if not tok:
                return               # jumped (or stopped)
            self.put_tok(tok)        # failure token, sent in full
            self.drain()
            self.put_tok(b"QRDY")    # the PC may resend the frame


def connect(tamper=None, byte_time=0.0):
    """Returns (pc_link, rom) with the ROM thread already running."""
    to_rom, from_rom = Pipe(), Pipe()
    rom = RomModel(to_rom, from_rom)
    rom.start()
    time.sleep(0.01)
    return PcSide(to_rom, from_rom, tamper, byte_time), rom
