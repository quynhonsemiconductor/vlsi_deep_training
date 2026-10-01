#!/usr/bin/env python3
"""Behavioural model of boot.c, for testing the PC loader without hardware.

Mirrors boot_once()/boot_main() step for step; keep the two in sync. Timeouts
are wall-clock seconds here, loop counts in the C code.

A test can put UART_ERR into the PC -> ROM stream to stand for a byte that
UART0 received with an overrun, parity or framing error (LSR bit 1-3).
"""
import queue
import struct
import threading
import time
import zlib

from qsoc_image import APP_MAX_LEN, ISRAM_APP_BASE, ISRAM_END

RX_TIMEOUT_S = 0.1     # boot.h RX_TIMEOUT   (>= 100 ms, QNSC_BOOT_SPEC 7.3)
DRAIN_IDLE_S = 0.05    # boot.h DRAIN_IDLE   (>= 50 ms)

UART_ERR = object()    # a received byte flagged with a UART error


class _Timeout(Exception):
    pass


class _UartError(Exception):
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
    chunks); it may return a list mixing byte values and UART_ERR.
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
        if b is UART_ERR:
            raise _UartError
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
            if b is None or b is UART_ERR:   # a byte with a UART error is dropped
                continue
            window = (window + bytes([b]))[-4:]
        try:
            length, load, entry, hcrc = (self.get32() for _ in range(4))
            if zlib.crc32(b"QSOC" + struct.pack("<III", length, load, entry)) != hcrc:
                return b"FHCR"
            if length == 0 or length % 4 or length > APP_MAX_LEN:
                return b"FHDR"
            if load % 4 or load < ISRAM_APP_BASE or load > ISRAM_END:
                return b"FHDR"
            if length > ISRAM_END - load:
                return b"FHDR"
            if entry % 2 or entry < load or entry - load >= length:
                return b"FHDR"
            self.put_tok(b"ACKH")
            crc = 0
            for a in range(load, load + length, 4):
                w = self.get32()
                self.ram[a] = w
                crc = zlib.crc32(struct.pack("<I", w), crc)
            if crc != self.get32():
                return b"FPCR"
        except _Timeout:
            return b"FTMO"
        except _UartError:
            return b"FUAR"
        self.put_tok(b"ACKP")
        self.entry = entry
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
