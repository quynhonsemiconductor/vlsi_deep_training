#!/usr/bin/env python3
"""
contract_tag.py -- a fixed value that must equal the contract is checked against it.

IP does not use qnsc_pkg (design/README.md), so a value an IP shares with the
chip -- the APB address width, a RAM depth -- is written as a number. The tag
says which contract entry the number copies:

    .APB_ADDR_WIDTH (12),              // contract: meta.apb_paddr_width
    input logic [11:0] i_bus_apb_paddr, // contract: meta.apb_paddr_width

The line passes when it holds a literal equal to the value, or a range [N:0]
with N = value - 1 (a width). If util/qsoc_contract.yml changes, every tagged
line that no longer matches fails, so the copy cannot drift.

The key is a path into util/qsoc_contract.yml. A list is entered by the `name`
of one of its items:

    meta.apb_paddr_width          -> 12
    memory_map.isram.size         -> the size of the region named isram

SCOPE   design/**/rtl/**/*.sv, *.v   (vendor/ excluded)
OUTPUT  GitHub Actions annotations in CI

Usage:
    python3 flow/lint/contract_tag.py                 # whole design/ tree
    python3 flow/lint/contract_tag.py design/pwm      # one block
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
DESIGN = REPO / "design"
CONTRACT = REPO / "util" / "qsoc_contract.yml"
CI = bool(os.environ.get("GITHUB_ACTIONS"))

TAG = re.compile(r"//\s*contract:\s*(?P<key>[A-Za-z0-9_.]+)")
SIZED = re.compile(r"\d*\s*'\s*[sS]?(?P<base>[bodhBODH])(?P<digits>[0-9a-fA-F_]+)")
BARE = re.compile(r"(?<![\w'])(?P<value>\d[\d_]*)(?![\w'])")
RANGE = re.compile(r"\[\s*(?P<msb>\d+)\s*:\s*0\s*\]")
RADIX = {"b": 2, "o": 8, "d": 10, "h": 16}


def resolve(contract: object, key: str) -> object:
    node = contract
    for part in key.split("."):
        if isinstance(node, dict):
            if part not in node:
                raise KeyError(part)
            node = node[part]
        elif isinstance(node, list):
            match = [i for i in node if isinstance(i, dict) and i.get("name") == part]
            if not match:
                raise KeyError(part)
            node = match[0]
        else:
            raise KeyError(part)
    return node


def literals(code: str) -> set[int]:
    values: set[int] = set()
    for m in SIZED.finditer(code):
        try:
            values.add(int(m.group("digits").replace("_", ""), RADIX[m.group("base").lower()]))
        except ValueError:
            pass
    stripped = SIZED.sub(" ", code)
    for m in BARE.finditer(stripped):
        values.add(int(m.group("value").replace("_", "")))
    return values


def emit(path: Path, line: int, msg: str) -> None:
    rel = path.relative_to(REPO) if path.is_relative_to(REPO) else path
    if CI:
        print(f"::error file={rel},line={line},title=contract tag::{msg}")
    else:
        print(f"  {rel}:{line}  [contract tag]  {msg}")


def collect(paths: list[Path]) -> list[Path]:
    files: list[Path] = []
    for p in paths:
        if p.is_file() and p.suffix in (".sv", ".v"):
            files.append(p)
        elif p.is_dir():
            files += [f for f in sorted(p.rglob("*"))
                      if f.suffix in (".sv", ".v") and "vendor" not in f.parts]
    return files


def main(argv: list[str]) -> int:
    contract = yaml.safe_load(CONTRACT.read_text())
    files = collect([Path(a).resolve() for a in argv[1:]] or [DESIGN])
    tags = errors = 0
    for path in files:
        for n, line in enumerate(path.read_text(errors="ignore").splitlines(), 1):
            m = TAG.search(line)
            if not m:
                continue
            tags += 1
            key = m.group("key")
            code = line[:m.start()]
            try:
                value = resolve(contract, key)
            except KeyError as e:
                emit(path, n, f"'{key}' is not in util/qsoc_contract.yml (no '{e.args[0]}')")
                errors += 1
                continue
            if not isinstance(value, int) or isinstance(value, bool):
                emit(path, n, f"'{key}' is {value!r} in the contract, not a number")
                errors += 1
                continue
            widths = {int(r.group("msb")) + 1 for r in RANGE.finditer(code)}
            if value in literals(code) or value in widths:
                continue
            emit(path, n, f"the contract says {key} = {value}, and this line holds "
                          f"neither {value} nor [{value - 1}:0]. Update the line, "
                          f"or the contract if the chip changed")
            errors += 1

    print(f"contract-tag: {tags} tag(s) in {len(files)} file(s)")
    if errors:
        print(f"contract-tag: {errors} tag(s) do not match util/qsoc_contract.yml")
        return 1
    print("contract-tag: clean")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
