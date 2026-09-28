#!/usr/bin/env python3
"""Post-process m_qnsc_wrap_cpu.sv after Emacs AUTOINST/AUTOWIRE regeneration.

verilog-mode's AUTOINST cannot parse a few constructs in ibex_top's port list
correctly. Run this every time the Makefile's `cpu` target regenerates the
file from m_qnsc_wrap_cpu.src.sv -- these are real, repeatable tool
limitations, not one-off hand edits, and re-running `make cpu` without this
step reproduces every one of them:

  1. RVFI ports are excluded from AUTOINPUT/AUTOOUTPUT by the .src.sv's own
     ignore-regexp (RVFI is not compiled into this build), but AUTOWIRE still
     declares dangling internal wires for them since they are unlisted
     instantiation outputs. Stripped entirely.
  2. AUTOINST emits two bogus lines that mis-parse the icache-cfg ports'
     packed-array-of-struct type (prim_ram_1p_pkg::ram_1p_cfg_{req,rsp}_t
     [ibex_pkg::IC_NUM_WAYS-1:0]) as if the type name were itself a port
     connection -- removed. (The ports themselves need no fix: every
     ibex_top port here is covered by the AUTO_TEMPLATE, so AUTOINPUT/
     AUTOOUTPUT never has to auto-declare -- and mis-infer -- a new port for
     any of them, unlike the three-module version of this file this one
     replaced.)
  3. AUTOINST also restates BaseIsa/PMPRstCfg/PMPRstMsecCfg/RV32M/RV32B/
     RV32ZC/RegFile/RndCnstLfsrSeed/RndCnstLfsrPerm as if they were port
     connections, duplicating what the legitimate `#()` parameter override
     block above already sets -- removed.
"""
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
