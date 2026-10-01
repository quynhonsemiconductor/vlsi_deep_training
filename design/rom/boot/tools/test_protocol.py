#!/usr/bin/env python3
"""Protocol tests: qsoc_loader.download() against rom_model.RomModel.

Also checks that the Python constants match ../boot.h, so the C ROM and the
PC tools cannot silently disagree on the magic, tokens or address limits.
Run:  python3 tools/test_protocol.py
"""
import os
import random
import re
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(__file__))
import qsoc_image as img           # noqa: E402
import qsoc_loader as ldr          # noqa: E402
import rom_model                   # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
FAILS = []


def check(name, cond, detail=""):
    print(f"  {'PASS' if cond else 'FAIL'}  {name}{'  ' + detail if detail and not cond else ''}")
    if not cond:
        FAILS.append(name)


def quiet(*_a, **_k):
    pass


def ram_bytes(rom, load, n):
    return b"".join(struct.pack("<I", rom.ram.get(a, 0)) for a in range(load, load + n, 4))


def run(name, payload, tamper=None, retries=3, byte_time=0.0, **frame_kw):
    print(name)
    header, body = img.make_frame(payload, **frame_kw)
    link, rom = rom_model.connect(tamper, byte_time)
    ok = ldr.download(link, header, body, retries=retries, ready_timeout=0.5, log=quiet)
    rom.stop = True
    return ok, rom, link


def with_uart_error(data, at):
    """data with the byte at `at` received with a UART error (rom_model.UART_ERR)."""
    out = list(data)
    out[at] = rom_model.UART_ERR
    return out


def test_boot_h_matches():
    print("boot.h constants == Python constants")
    text = open(os.path.join(HERE, "..", "boot.h")).read()
    toks = {m[0]: "".join(m[1:]) for m in
            re.findall(r"#define\s+(\w+)\s+TOK\('(.)', '(.)', '(.)', '(.)'\)", text)}
    check("MAGIC is QSOC", toks.get("MAGIC_QSOC") == "QSOC")
    py_toks = {t.decode() for t in img.TOKENS}
    c_toks = {v for k, v in toks.items() if k.startswith("TOK_")}
    check("same token set", py_toks == c_toks, f"C={sorted(c_toks)} Py={sorted(py_toks)}")
    for sym, val in (("ISRAM_APP_BASE", img.ISRAM_APP_BASE), ("ISRAM_END", img.ISRAM_END)):
        m = re.search(rf"#define\s+{sym}\s+0x([0-9A-Fa-f]+)u", text)
        check(f"{sym} = 0x{val:08x}", m and int(m.group(1), 16) == val)
    check("MAGIC word LE = 0x434F5351", struct.unpack("<I", b"QSOC")[0] == 0x434F5351)
    m = re.search(r"#define\s+UART_DIVISOR\s+(\d+)u", text)
    baud = 20_000_000 / (16 * int(m.group(1))) if m else 0
    check(f"UART_DIVISOR gives {baud:.0f} baud, within 0.5 % of the loader's {ldr.BAUD}",
          m and abs(baud - ldr.BAUD) / ldr.BAUD < 0.005)


def test_crc_matches_bitwise():
    print("bitwise CRC (as in boot.c) == zlib.crc32")
    def crc32_word(crc, w):
        crc ^= w
        for _ in range(32):
            crc = (crc >> 1) ^ (0xEDB88320 & -(crc & 1) & 0xFFFFFFFF)
        return crc
    data = bytes(random.Random(1).randrange(256) for _ in range(64))
    crc = 0xFFFFFFFF
    for i in range(0, len(data), 4):
        crc = crc32_word(crc, struct.unpack_from("<I", data, i)[0])
    check("64 random bytes", crc ^ 0xFFFFFFFF == zlib.crc32(data))


def main():
    rnd = random.Random(7)
    app = bytes(rnd.randrange(256) for _ in range(1024))

    test_boot_h_matches()
    test_crc_matches_bitwise()

    ok, rom, _ = run("good frame", app)
    check("download ok", ok)
    check("RAM == payload", ram_bytes(rom, 0x2000_1000, len(app)) == app)
    check("jumped to LOAD+0x80", rom.entry == 0x2000_1080)
    check("no token after reset: ACKH ACKP only", rom.sent == [b"ACKH", b"ACKP"], str(rom.sent))

    ok, rom, _ = run("line noise before the frame",
                     app, tamper=lambda n, d: (b"\x00QS\xffQSO" + d) if n == 1 else d)
    check("noise skipped, download ok", ok and rom.entry == 0x2000_1080)

    ok, rom, _ = run("odd-length payload is padded", app[:1021])
    check("download ok", ok and ram_bytes(rom, 0x2000_1000, 1024)[:1021] == app[:1021])

    def bad_hcrc(n, d):
        return d[:16] + bytes([d[16] ^ 1]) + d[17:] if n == 1 else d
    ok, rom, _ = run("header CRC corrupted once", app, tamper=bad_hcrc)
    check("FHCR, QRDY, then retry ok", ok and rom.sent == [b"FHCR", b"QRDY", b"ACKH", b"ACKP"],
          str(rom.sent))

    ok, rom, _ = run("UART error before the magic",
                     app, tamper=lambda n, d: (with_uart_error(b"UU", 1) + list(d)) if n == 1 else d)
    check("dropped without a reply, download ok", ok and rom.sent == [b"ACKH", b"ACKP"], str(rom.sent))

    ok, rom, _ = run("UART error in the header", app,
                     tamper=lambda n, d: with_uart_error(d, 9) if n == 1 else d)
    check("FUAR, QRDY, then retry ok", ok and rom.sent[:2] == [b"FUAR", b"QRDY"] and rom.entry == 0x2000_1080,
          str(rom.sent))

    def bad_payload(n, d):
        return d[:100] + bytes([d[100] ^ 0x80]) + d[101:] if n == 2 else d
    ok, rom, _ = run("payload corrupted once", app, tamper=bad_payload)
    check("FPCR then retry ok", ok and b"FPCR" in rom.sent, str(rom.sent))

    ok, rom, _ = run("LOAD_ADDR in the debug window", app, retries=1,
                     load=0x2000_0000, entry=0x2000_0080, force=True)
    check("rejected with FHDR", not ok and b"FHDR" in rom.sent, str(rom.sent))

    ok, rom, _ = run("ENTRY outside payload", app, retries=1,
                     entry=0x2000_1000 + len(app), force=True)
    check("rejected with FHDR", not ok and b"FHDR" in rom.sent, str(rom.sent))

    ok, rom, _ = run("image past ISRAM end", bytes(8), retries=1,
                     load=0x2000_FFFC, entry=0x2000_FFFC, force=True)
    check("rejected with FHDR", not ok and b"FHDR" in rom.sent, str(rom.sent))

    ok, rom, _ = run("payload cut short", app, retries=1,
                     tamper=lambda n, d: d[:200] if n == 2 else (b"" if n > 2 else d))
    check("FTMO", not ok and b"FTMO" in rom.sent, str(rom.sent))

    big = bytes(rnd.randrange(256) for _ in range(16 * 1024))
    chunks = len(big) // ldr.CHUNK
    ok, rom, _ = run("good 16 KiB frame at wire speed (ACKP may come during the last chunk)",
                     big, byte_time=20e-6)
    check("download ok, RAM == payload", ok and ram_bytes(rom, 0x2000_1000, len(big)) == big)

    ok, rom, link = run("UART error early in a 16 KiB payload, at wire speed", big, byte_time=20e-6,
                        tamper=lambda n, d: with_uart_error(d, 100) if n == 2 else d)
    first_try = link.writes - (1 + chunks) - 1          # payload chunks of the first attempt
    check("PC stopped sending after FUAR, then retry ok",
          ok and rom.sent == [b"ACKH", b"FUAR", b"QRDY", b"ACKH", b"ACKP"] and first_try < chunks // 2,
          f"sent={rom.sent} first attempt sent {first_try} of {chunks} chunks")
    print(f"        (first attempt stopped after {first_try} of {chunks} chunks)")

    print()
    print("ALL PASS" if not FAILS else f"{len(FAILS)} FAILED: {FAILS}")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
