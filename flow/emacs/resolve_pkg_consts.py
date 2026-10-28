#!/usr/bin/env python3
"""
resolve_pkg_consts.py -- replace `<pkg>::<NAME>` constants with their numeric value.

A wrapper names an IP's enum constant with its package, `ibex_pkg::RV32MFast`
(no import is allowed). A reviewer may want the number the elaborator sees. This
script reads the package from the IP's own source and rewrites each such constant
in the generated wrapper, so no value is copied by hand:

    .RV32M (ibex_pkg::RV32MFast)   ->   .RV32M (ibex_pkg::rv32m_e'(2))

An enum member keeps its type as a cast, because a bare number assigned to an
enum parameter draws VCS Warning-[ENUMASSIGN]; any other constant becomes the
plain number. It resolves three forms, all found in the package file named by the filelist:
  - an enum member:       typedef enum integer { A = 0, B, C = 5 } t;
  - a literal parameter:  parameter ibex_mubi_t IbexMuBiOn = 4'b0101;
  - an integer expression of the package's own parameters:
                          localparam int P_MST_ID_W = P_LEAF_ID_W + 1;  ->  5
Only the name is replaced: `[P_MST_ID_W-1:0]` becomes `[5-1:0]`, which the tools
evaluate. A type is left alone: a typedef, or any name ending _t or _e (a macro
such as AXI_TYPEDEF_ALL declares types the script cannot see). A name that is
none of these (a function call such as $clog2, an unknown name) is an error,
never a guess, and the script exits 1.

The .src.sv keeps the names; only the generated wrapper carries numbers. Run by
the block's Makefile after the expansion (see design/cpu/rtl/emacs/Makefile).

Usage: resolve_pkg_consts.py <generated .sv> <filelist.f> [<filelist.f> ...] <pkg> [<pkg> ...]
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fix_pkg_ports import filelist_sources  # noqa: E402

LITERAL = re.compile(r"^(?:\d+|\d*'[sS]?[bBoOdDhH][0-9a-fA-FxXzZ_]+)$")


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def package_text(pkg: str, filelists: list[Path]) -> str:
    for filelist in filelists:
        for src in filelist_sources(filelist):
            text = strip_comments(src.read_text(errors="ignore"))
            if re.search(rf"\bpackage\s+{pkg}\s*;", text):
                return text
    raise SystemExit(f"resolve_pkg_consts: package {pkg} not found via {', '.join(map(str, filelists))}")


def enum_members(text: str) -> tuple[dict[str, str], dict[str, str]]:
    out: dict[str, str] = {}
    types: dict[str, str] = {}
    for body, tname in re.findall(r"\benum\b[^{]*\{(.*?)\}\s*(\w+)\s*;", text, flags=re.S):
        value = -1
        for item in (i.strip() for i in body.split(",")):
            if not item:
                continue
            m = re.fullmatch(r"(\w+)\s*(?:=\s*(.+))?", item, flags=re.S)
            if not m:
                continue
            name, expr = m.group(1), m.group(2)
            types[name] = tname
            if expr is None:
                value += 1
            elif re.fullmatch(r"\d+", expr.strip()):
                value = int(expr)
            else:
                out[name] = None  # a member whose value is not a plain integer
                continue
            out[name] = str(value)
    return out, types


def literal_parameters(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for name, expr in re.findall(
            r"\b(?:local)?param(?:eter)?\s+(?:[\w:]+\s+)*(?:\[[^\]]*\]\s*)?(\w+)\s*=\s*([^;,]+)[;,]", text):
        out[name] = expr.strip()
    return out


def evaluate(name: str, params: dict[str, str], stack: tuple[str, ...] = ()) -> str | None:
    expr = params.get(name)
    if expr is None or name in stack:
        return None
    if LITERAL.match(expr):
        return expr

    def sub(m: re.Match) -> str:
        value = evaluate(m.group(0), params, stack + (name,))
        if value is None or not re.fullmatch(r"\d+", value):
            raise ValueError(m.group(0))
        return value

    try:
        folded = re.sub(r"[A-Za-z_]\w*", sub, expr)
    except ValueError:
        return None
    if not re.fullmatch(r"[0-9+\-*/() ]+", folded):
        return None
    return str(eval(folded.replace("/", "//"), {"__builtins__": {}}))


def typedef_names(text: str) -> set[str]:
    return set(re.findall(r"\}\s*(\w+)\s*;", text)) | \
        set(re.findall(r"\btypedef\b[^;{}]*?\b(\w+)\s*;", text))


def main(argv: list[str]) -> int:
    if len(argv) < 4:
        print(__doc__)
        return 2
    path = Path(argv[1])
    filelists = [Path(a) for a in argv[2:] if a.endswith(".f")]
    pkgs = [a for a in argv[2:] if not a.endswith(".f")]
    if not filelists or not pkgs:
        print(__doc__)
        return 2
    text = path.read_text()
    errors: list[str] = []
    replaced: dict[str, str] = {}
    for pkg in pkgs:
        ptext = package_text(pkg, filelists)
        params = literal_parameters(ptext)
        members, member_type = enum_members(ptext)
        consts = {**{n: evaluate(n, params) for n in params}, **members}
        types = typedef_names(ptext)
        for name in sorted(set(re.findall(rf"\b{pkg}::(\w+)", text))):
            if name in types or name.endswith(("_t", "_e")):
                continue
            value = consts.get(name)
            if value is None:
                errors.append(f"{pkg}::{name} is not a type, an enum member or a literal parameter")
                continue
            if name in member_type:
                value = f"{pkg}::{member_type[name]}'({value})"
            text = re.sub(rf"\b{pkg}::{name}\b", lambda _m, v=value: v, text)
            replaced[f"{pkg}::{name}"] = value
    if errors:
        print("resolve_pkg_consts: " + "; ".join(errors), file=sys.stderr)
        return 1
    path.write_text(text)
    for name, value in replaced.items():
        print(f"resolve_pkg_consts: {name} -> {value}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
