#!/usr/bin/env python3
"""
hardcode_check.py -- refuse a literal in RTL that the contract already names.

The rule this enforces is the one the whole anti-drift design rests on:

    a number shared between blocks is imported from qnsc_pkg, never typed.

Every cross-block defect this project has paid for was one fact written twice --
ROM 8 KiB against 2 KiB, APB_M11 against APB_S11, eleven interrupt sources against
twelve. A wrapper that types 32'h8002_4000 instead of C_UART_0_BASE has created
the next one, and nothing but this check will notice.

HOW IT DECIDES -- by comparison, not by guessing:

  1. EXACT MATCH. A literal whose value equals a constant in
     util/qsoc_contract.yml is wrong by construction, and the message names the
     constant to use instead. No judgement, no false positives.

  2. INSIDE A MAPPED REGION. A literal that is not in the contract but falls
     inside a region of the memory map is almost certainly an address: a CRC
     polynomial or a threshold does not land in 0x8000_0000-0x8003_FFFF by
     accident. Either it belongs in the contract, or it is deliberate and says so.

Deliberately NOT flagged, because these are not shared facts:
  - tie-offs and small values: 1'b0, 1'b1, '0, '1, 0, 1, bit widths, indices
  - all-zeros and all-ones of any width, the two commonest idioms
  - anything under vendor/ -- not ours to change
  - design/top/rtl/qnsc_pkg.sv -- it is where the numbers are defined

SCOPE   design/**/rtl/**/*.sv, *.v          (vendor/ excluded)
OUTPUT  GitHub Actions annotations in CI, so a violation lands inline on the diff

A deliberate literal needs a reason on the line:

    localparam C_CRC32_POLY = 32'h04C11DB7;  // hardcode-check: ignore -- CRC-32 polynomial

Usage:
    python3 flow/lint/hardcode_check.py                  # whole design/ tree
    python3 flow/lint/hardcode_check.py design/uart      # one block
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")

REPO = Path(__file__).resolve().parent.parent.parent
CONTRACT = REPO / "util" / "qsoc_contract.yml"
DEFAULT_SCOPE = REPO / "design"
GENERATED_PKG = REPO / "design" / "top" / "rtl" / "qnsc_pkg.sv"
CI = bool(os.environ.get("GITHUB_ACTIONS"))
IGNORE = re.compile(r"//\s*hardcode-check:\s*ignore")

# A sized literal: 32'h8002_4000, 16'd1024, 8'b0101, and the unsized 'h1234.
LITERAL = re.compile(
    r"(?P<width>\d+)?\s*'\s*[sS]?(?P<base>[bodhBODH])(?P<digits>[0-9a-fA-F_xXzZ?]+)"
)
# A bare decimal that is not part of an identifier, a range or a width.
BARE_DEC = re.compile(r"(?<![\w'\[:.])(?P<value>\d{4,})(?![\w'\]:])")

BASE_RADIX = {"b": 2, "o": 8, "d": 10, "h": 16}


def load_contract() -> tuple[dict[int, list[str]], list[tuple[int, int, str]]]:
    """Return (value -> the constants holding it) and the mapped regions.

    A value can belong to several constants -- every peripheral window is
    16 KiB -- so the message lists them rather than naming one at random.
    """
    c = yaml.safe_load(CONTRACT.read_text())
    named: dict[int, list[str]] = {}
    regions: list[tuple[int, int, str]] = []

    for r in c["memory_map"]:
        n = r["name"].upper()
        named.setdefault(r["base"], []).append(f"C_{n}_BASE")
        named.setdefault(r["size"], []).append(f"C_{n}_SIZE")
        regions.append((r["base"], r["base"] + r["size"] - 1, r["name"]))

    # Interrupt line indices are small, so they are recorded but only reported on
    # an exact match in a context the checker cannot see -- kept out of `named`
    # to avoid flagging every loop bound that happens to equal 4.
    return named, regions


class Finding:
    __slots__ = ("path", "line", "rule", "msg")

    def __init__(self, path: Path, line: int, rule: str, msg: str):
        self.path, self.line, self.rule, self.msg = path, line, rule, msg

    def emit(self) -> None:
        try:
            rel = self.path.relative_to(REPO)
        except ValueError:
            rel = self.path
        if CI:
            print(f"::error file={rel},line={self.line},"
                  f"title=hardcoded {self.rule}::{self.msg}")
        else:
            print(f"  {rel}:{self.line}  [{self.rule}]  {self.msg}")


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", lambda m: re.sub(r"[^\n]", " ", m.group(0)),
                  text, flags=re.S)
    return re.sub(r"//[^\n]*", lambda m: " " * len(m.group(0)), text)


def is_trivial(value: int, width: int | None, digits: str) -> bool:
    """All-zeros and all-ones of any width, and anything that fits in 12 bits.

    0x000 and 0xFFF... are the two commonest idioms in RTL and carry no shared
    meaning. 12 bits is below the smallest region in the map, so a literal that
    small cannot be an address.
    """
    if value == 0:
        return True
    if width and value == (1 << width) - 1:
        return True
    if value < 0x1000:
        return True
    return False


def check_file(path: Path, named: dict[int, list[str]],
               regions: list[tuple[int, int, str]]) -> list[Finding]:
    raw = path.read_text(errors="ignore")
    raw_lines = raw.splitlines()
    src = strip_comments(raw)
    out: list[Finding] = []

    def exempt(ln: int) -> bool:
        return ln <= len(raw_lines) and bool(IGNORE.search(raw_lines[ln - 1]))

    def lineno(pos: int) -> int:
        return src.count("\n", 0, pos) + 1

    def report(pos: int, value: int, shown: str) -> None:
        ln = lineno(pos)
        if exempt(ln):
            return
        if value in named:
            names = named[value]
            if len(names) == 1:
                which = names[0]
                advice = f"use {which}"
            else:
                shownames = ", ".join(names[:4])
                more = f" and {len(names) - 4} more" if len(names) > 4 else ""
                which = f"{len(names)} constants"
                advice = f"use the one for your block -- {shownames}{more}"
            out.append(Finding(
                path, ln, "contract value",
                f"{shown} is {which} in util/qsoc_contract.yml. "
                f"Import from qnsc_pkg and {advice}, rather than typing the number"))
            return
        for lo, hi, name in regions:
            if lo <= value <= hi:
                out.append(Finding(
                    path, ln, "address literal",
                    f"{shown} falls inside the {name} region "
                    f"({lo:#010x}-{hi:#010x}). If it is an address it belongs in "
                    f"util/qsoc_contract.yml; if it is deliberate, say why with "
                    f"'// hardcode-check: ignore -- <reason>'"))
                return

    for m in LITERAL.finditer(src):
        digits = m.group("digits").replace("_", "")
        if re.search(r"[xXzZ?]", digits):          # don't-care, not a value
            continue
        radix = BASE_RADIX[m.group("base").lower()]
        try:
            value = int(digits, radix)
        except ValueError:
            continue
        width = int(m.group("width")) if m.group("width") else None
        if is_trivial(value, width, digits):
            continue
        report(m.start(), value, m.group(0).strip())

    for m in BARE_DEC.finditer(src):
        value = int(m.group("value"))
        if value < 0x1000:
            continue
        report(m.start(), value, m.group("value"))

    return out


def collect(paths: list[Path]) -> list[Path]:
    files: list[Path] = []
    for p in paths:
        if p.is_file() and p.suffix in (".sv", ".v"):
            files.append(p)
        elif p.is_dir():
            for f in sorted(p.rglob("*")):
                if (f.suffix in (".sv", ".v")
                        and "vendor" not in f.parts
                        and f.resolve() != GENERATED_PKG.resolve()):
                    files.append(f)
    return files


def main(argv: list[str]) -> int:
    named, regions = load_contract()
    targets = [Path(a).resolve() for a in argv[1:]] or [DEFAULT_SCOPE]
    files = collect(targets)

    if not files:
        print("hardcode-check: no RTL under design/ yet -- nothing to check")
        return 0

    findings: list[Finding] = []
    for f in files:
        findings.extend(check_file(f, named, regions))

    print(f"hardcode-check: {len(files)} file(s) checked against "
          f"{sum(len(v) for v in named.values())} contract constants "
          f"and {len(regions)} mapped regions")
    if not findings:
        print("hardcode-check: clean")
        return 0

    for f in findings:
        f.emit()
    print(f"\nhardcode-check: {len(findings)} hardcoded value(s)")
    print("\nA number shared between blocks is imported from qnsc_pkg, never typed.")
    print("That is what stops two blocks disagreeing about one fact -- see")
    print("CONTRIBUTING.md, 'Do not'.")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
