#!/usr/bin/env python3
"""
filelist_check.py -- every path in a filelist is relative to it, and exists.

A filelist is read on every machine: a laptop, the training server and CI.
An absolute path such as /home/<user>/vlsi_deep_training/... works only in
the one checkout it was written in, and a path to a file that is not there
fails only when someone else builds the block. Both are caught here, before
lint, with the line that is wrong.

Paths are resolved from the directory of the filelist, which is how every
tool in flow/ reads them (verilator -F, read_slang -F) and how emacs
verilog-mode reads a filelist_emacs.f.

SCOPE   every *.f under design/
OUTPUT  GitHub Actions annotations in CI, so a violation lands inline on the diff

Usage:
    python3 flow/lint/filelist_check.py
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
CI = bool(os.environ.get("GITHUB_ACTIONS"))

# Options that take no path, and options whose next token is a path.
NO_PATH_PREFIXES = ("+define+", "+libext+", "-Wno-", "-W", "--", "-D", "-I")
PATH_OPTIONS = ("-f", "-F", "-v", "-y")


def paths_in(line: str) -> list[str]:
    """The paths named on one filelist line."""
    tokens = line.split()
    out: list[str] = []
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if tok.startswith("+incdir+"):
            out += [p for p in tok[len("+incdir+"):].split("+") if p]
        elif tok in PATH_OPTIONS and i + 1 < len(tokens):
            out.append(tokens[i + 1])
            i += 1
        elif not tok.startswith(NO_PATH_PREFIXES) and not tok.startswith("+"):
            out.append(tok)
        i += 1
    return out


def check(flist: Path) -> list[tuple[int, str]]:
    errors: list[tuple[int, str]] = []
    for n, raw in enumerate(flist.read_text(errors="ignore").splitlines(), 1):
        line = raw.split("//")[0].strip()
        if not line or line.startswith("#"):
            continue
        for path in paths_in(line):
            if path.startswith(("/", "~")):
                errors.append((n, f"absolute path '{path}': write it relative to this "
                                  f"filelist, as ../../vendor/... or rtl/..."))
            elif "$" in path:
                errors.append((n, f"'{path}' depends on an environment variable: "
                                  f"write it relative to this filelist"))
            elif not (flist.parent / path).exists():
                errors.append((n, f"'{path}' not found (resolved from {flist.parent.relative_to(REPO)}/)"))
    return errors


def main() -> int:
    flists = sorted((REPO / "design").rglob("*.f"))
    total = 0
    for flist in flists:
        rel = flist.relative_to(REPO)
        for line, msg in check(flist):
            total += 1
            if CI:
                print(f"::error file={rel},line={line}::{msg}")
            print(f"  {rel}:{line}  {msg}")
    print(f"filelist-check: {len(flists)} filelist(s), "
          f"{'clean' if total == 0 else f'{total} problem(s)'}")
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
