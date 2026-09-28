#!/usr/bin/env python3
"""
fix_pkg_ports.py -- remove the connections verilog-mode invents for items whose
type comes from a package.

verilog-mode's parser does not understand two SystemVerilog constructs that IP
such as Ibex uses in its module header:

  1. A package-typed packed-array PORT:
         input prim_ram_1p_pkg::ram_1p_cfg_req_t [ibex_pkg::IC_NUM_WAYS-1:0] ram_cfg_icache_tag_i,
     AUTOINST emits a phantom connection named after the type, which is not
     SystemVerilog:
         .prim_ram_1p_pkg::ram_1p_cfg_req_t(PRIM_RAM_1P_PKG::RAM_1P_CFG_REQ_T),
  2. A package-typed PARAMETER:
         parameter ibex_pkg::rv32m_e RV32M = ibex_pkg::RV32MFast,
     AUTOINST lists it under "// Interfaces" as if it were a port:
         .RV32M (RV32M),
     and every simulator rejects connecting a parameter as a port.

Both were reproduced on the CPU demo of MCU_guide_ws with verilog-mode
2026-01-18 (Emacs 31.1). Setting verilog-typedef-regexp, or connecting the real
port by hand, removes neither. This script deletes those lines after every
expansion (flow/emacs/wrap.mk), and moves the closing ');' to the line before
when the deleted line was the last connection. A parameter the wrapper really
sets goes in the instance's #( ... ), which verilog-mode leaves alone.

It changes nothing in a wrapper whose IP has no package-typed item.

Usage: fix_pkg_ports.py <generated .sv> [<filelist the IP is read from>]
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

PHANTOM = re.compile(r"^\s*\.\w+::\w+\s*\(")
CONNECTION = re.compile(r"^\s*\.(?P<name>\w+)\s*\(")
PARAMETER = re.compile(
    r"\bparameter\s+(?:[A-Za-z_][\w:]*\s+)?(?:\[[^\]]*\]\s*)*(?P<name>[A-Za-z_]\w*)"
    r"\s*(?:\[[^\]]*\]\s*)*=")


def filelist_sources(filelist: Path, seen: set[Path] | None = None) -> list[Path]:
    """Every source file a -f / -F filelist names, nested filelists included."""
    seen = seen if seen is not None else set()
    filelist = filelist.resolve()
    if filelist in seen or not filelist.is_file():
        return []
    seen.add(filelist)
    out: list[Path] = []
    for raw in filelist.read_text(errors="ignore").splitlines():
        line = raw.split("//")[0].strip()
        if not line or line.startswith("+"):
            continue
        parts = line.split()
        if parts[0] in ("-f", "-F") and len(parts) > 1:
            target = Path(parts[1])
            for base in (filelist.parent, Path.cwd()):
                cand = target if target.is_absolute() else base / target
                if cand.is_file():
                    out += filelist_sources(cand, seen)
                    break
            continue
        if parts[0].startswith("-"):
            continue
        cand = Path(parts[0])
        cand = cand if cand.is_absolute() else filelist.parent / cand
        if cand.suffix in (".sv", ".v", ".svh", ".vh") and cand.is_file():
            out.append(cand)
    return out


def ip_parameters(filelist: Path | None) -> set[str]:
    if filelist is None:
        return set()
    names: set[str] = set()
    for src in filelist_sources(filelist):
        text = re.sub(r"//[^\n]*", "", src.read_text(errors="ignore"))
        names.update(m.group("name") for m in PARAMETER.finditer(text))
    return names


def fix(text: str, params: set[str]) -> str:
    out: list[str] = []
    in_autoinst = False
    for line in text.split("\n"):
        if "/*AUTOINST*/" in line:
            in_autoinst = True
        drop = bool(PHANTOM.match(line))
        if not drop and in_autoinst:
            m = CONNECTION.match(line)
            drop = bool(m and m.group("name") in params)
        if not drop:
            out.append(line)
            if in_autoinst and ");" in line.split("//")[0]:
                in_autoinst = False
            continue
        if ");" in line.split("//")[0]:
            in_autoinst = False
            # The dropped line was the last connection: move its ');' to the
            # line before, in place of that line's ','.
            for j in range(len(out) - 1, -1, -1):
                code, sep, comment = out[j].partition("//")
                if code.strip():
                    if code.rstrip().endswith(","):
                        out[j] = code.rstrip()[:-1] + ");" + (" " + sep + comment if sep else "")
                    break
    return "\n".join(out)


def main(argv: list[str]) -> int:
    if len(argv) not in (2, 3):
        print(__doc__)
        return 2
    path = Path(argv[1])
    params = ip_parameters(Path(argv[2]) if len(argv) == 3 else None)
    text = path.read_text()
    fixed = fix(text, params)
    if fixed != text:
        path.write_text(fixed)
        print(f"fix_pkg_ports: removed connections to package-typed items in {path.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
