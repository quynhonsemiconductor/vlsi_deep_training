#!/usr/bin/env python3
"""Fix 3 real AUTOINST/AUTOWIRE quirks against ibex_top after `make cpu`:
1) dangling rvfi_ wires (RVFI not built), 2) bogus icache-cfg type lines,
3) bogus restatement of BaseIsa/PMPRstCfg/.../RegFile as port connections."""
import sys

PATH = sys.argv[1] if len(sys.argv) > 1 else "m_qnsc_wrap_cpu.sv"

lines = open(PATH, encoding="utf-8").readlines()
lines = [l for l in lines if "rvfi_" not in l]

out = []
in_instantiation = False
for l in lines:
    if "u_ibex_top(/*AUTOINST*/" in l:
        in_instantiation = True
    if "prim_ram_1p_pkg::ram_1p_cfg_rsp_t(prim_ram_1p_pkg" in l:
        continue
    if "prim_ram_1p_pkg::ram_1p_cfg_req_t(prim_ram_1p_pkg" in l:
        continue
    stripped = l.strip()
    if in_instantiation and any(stripped.startswith(f".{name}") for name in (
        "BaseIsa", "PMPRstCfg", "PMPRstMsecCfg", "RV32M", "RV32B", "RV32ZC",
        "RegFile", "RndCnstLfsrSeed", "RndCnstLfsrPerm",
    )):
        continue
    out.append(l)

open(PATH, "w", encoding="utf-8", newline="\n").writelines(out)
print(f"fixup_ibex_wrap: patched {PATH}")
