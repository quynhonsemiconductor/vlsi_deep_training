#!/usr/bin/env python3
"""The real loader, through pyserial, against rom_model.RomModel over TCP.

test_protocol.py drives qsoc_loader.download() with an in-memory link. This
test runs the loader command line in its own process and lets it open
socket://127.0.0.1:<port> with pyserial, so SerialLink (write + flush,
in_waiting, read with a timeout, reset_input_buffer) and main() are exercised
too. Only the OS serial driver is not: for that, use a USB-UART adapter or a
virtual COM pair (com0com) and run qsoc_loader.py on the port by hand.

Run:  python3 tools/test_serial_link.py      (needs pyserial; skips without it)
"""
import os
import random
import socket
import struct
import subprocess
import sys
import tempfile
import threading

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rom_model                   # noqa: E402

FAILS = []


def check(name, cond, detail=""):
    print(f"  {'PASS' if cond else 'FAIL'}  {name}{'  ' + detail if detail and not cond else ''}")
    if not cond:
        FAILS.append(name)


class RomOverTcp:
    """Accepts one connection and wires it to a RomModel thread.

    tamper(i, b) sees every byte the PC sends (i counts from 0 across the
    whole connection) and returns a byte value or rom_model.UART_ERR.
    """

    def __init__(self, tamper=None):
        self.tamper = tamper
        self.srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.srv.bind(("127.0.0.1", 0))
        self.srv.listen(1)
        self.port = self.srv.getsockname()[1]
        self.rx, self.tx = rom_model.Pipe(), rom_model.Pipe()
        self.rom = rom_model.RomModel(self.rx, self.tx)
        self.received = 0
        threading.Thread(target=self._serve, daemon=True).start()

    def _serve(self):
        conn, _ = self.srv.accept()
        self.rom.start()
        threading.Thread(target=self._to_pc, args=(conn,), daemon=True).start()
        while True:
            data = conn.recv(4096)
            if not data:
                return
            items = []
            for b in data:
                items.append(self.tamper(self.received, b) if self.tamper else b)
                self.received += 1
            self.rx.put(items)

    def _to_pc(self, conn):
        while True:
            b = self.tx.get(0.05)
            if b is not None:
                try:
                    conn.sendall(bytes([b]))
                except OSError:
                    return


def run(name, app_path, tamper=None):
    print(name)
    rom = RomOverTcp(tamper)
    cmd = [sys.executable, os.path.join(HERE, "qsoc_loader.py"),
           f"socket://127.0.0.1:{rom.port}", app_path, "--retries", "3"]
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    rom.rom.stop = True
    return p, rom.rom


def main():
    try:
        import serial                   # noqa: F401
    except ImportError:
        print("SKIP: pyserial not installed (pip install pyserial)")
        return 0

    app = bytes(random.Random(11).randrange(256) for _ in range(4096))
    fd, path = tempfile.mkstemp(suffix=".bin")
    with os.fdopen(fd, "wb") as f:
        f.write(app)
    words = lambda rom: b"".join(struct.pack("<I", rom.ram.get(a, 0))
                                 for a in range(0x2000_1000, 0x2000_1000 + len(app), 4))
    try:
        p, rom = run("good frame, loader CLI over pyserial socket://", path)
        check("exit code 0", p.returncode == 0, p.stdout + p.stderr)
        check("tokens ACKH ACKP, no token after reset", rom.sent == [b"ACKH", b"ACKP"], str(rom.sent))
        check("RAM == payload, jumped to 0x2000_1080", words(rom) == app and rom.entry == 0x2000_1080)
        check("loader logged ACKP", "ACKP - application started" in p.stdout, p.stdout)

        first = [True]
        def flip(i, b):                 # one payload byte flipped, first frame only
            if i == 20 + 100 and first[0]:
                first[0] = False
                return b ^ 0x01
            return b
        p, rom = run("payload byte flipped once", path, flip)
        check("FPCR, QRDY, then retry ok", p.returncode == 0 and rom.sent == [b"ACKH", b"FPCR", b"QRDY", b"ACKH", b"ACKP"],
              str(rom.sent) + " " + p.stdout)

        hit = [True]
        def uart_err(i, b):             # a framing error in the first frame's payload
            if i == 20 + 300 and hit[0]:
                hit[0] = False
                return rom_model.UART_ERR
            return b
        p, rom = run("UART error in the payload", path, uart_err)
        check("FUAR, QRDY, then retry ok", p.returncode == 0 and rom.sent == [b"ACKH", b"FUAR", b"QRDY", b"ACKH", b"ACKP"],
              str(rom.sent) + " " + p.stdout)
        check("RAM == payload after the retry", words(rom) == app)
    finally:
        os.remove(path)

    print()
    print("ALL PASS" if not FAILS else f"{len(FAILS)} FAILED: {FAILS}")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
