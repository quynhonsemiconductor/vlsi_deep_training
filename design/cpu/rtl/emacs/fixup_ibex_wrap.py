#!/usr/bin/env python3
"""Post-process m_qnsc_wrap_ibex.sv after Emacs AUTOINST/AUTOWIRE regeneration.

verilog-mode's AUTOINST cannot parse a few constructs in ibex_top's port list
correctly. Run this every time the Makefile's `ibex` target regenerates the
file from m_qnsc_wrap_ibex.src.sv -- these are real, repeatable tool
limitations, not one-off hand edits, and re-running `make ibex` without this
step reproduces every one of them:

  1. RVFI ports are excluded from AUTOINPUT/AUTOOUTPUT by the .src.sv's own
     ignore-regexp (RVFI is not compiled into this build), but AUTOWIRE still
     declares dangling internal wires for them since they are unlisted
     instantiation outputs. Stripped entirely.
  2. The icache-cfg ports (ram_cfg_icache_{data,tag}_{i,o}) use a packed-array-
     of-struct type (prim_ram_1p_pkg::ram_1p_cfg_{req,rsp}_t
     [ibex_pkg::IC_NUM_WAYS-1:0]) that AUTOINPUT/AUTOOUTPUT mis-parses as a
     bare, untyped port -- fixed with the correct explicit declaration.
  3. AUTOINST also emits two bogus lines that mis-parse the same struct type
     as if it were itself a port connection -- removed.
  4. scramble_key_i/scramble_nonce_i use SCRAMBLE_KEY_W/SCRAMBLE_NONCE_W,
     parameters local to ibex_top and not visible to this wrapper -- replaced
     with the literal widths (128/64 bits).
  5. cheriot_enable_i/fetch_enable_i/mcounteren_writable_i/crash_dump_o/
     lockstep_cmp_en_o are typed with ibex_mubi_t/crash_dump_t, which
     AUTOINPUT/AUTOOUTPUT's generic "Others" catch-all does not infer --
     their port declarations are added explicitly.
  6. AUTOINST also restates BaseIsa/PMPRstCfg/PMPRstMsecCfg/RV32M/RV32B/
     RV32ZC/RegFile/RndCnstLfsrSeed/RndCnstLfsrPerm as if they were port
     connections, duplicating what the legitimate `#()` parameter override
     block above already sets -- removed.
"""
import re
import sys

PATH = sys.argv[1] if len(sys.argv) > 1 else "m_qnsc_wrap_ibex.sv"

lines = open(PATH, encoding="utf-8").readlines()
lines = [l for l in lines if "rvfi_" not in l]

out = []
in_instantiation = False
for l in lines:
    if "u_ibex_top(/*AUTOINST*/" in l:
        in_instantiation = True
    if re.match(r'^input\s+i_mem_icache_data_cfg,', l):
        out.append("input  prim_ram_1p_pkg::ram_1p_cfg_req_t [ibex_pkg::IC_NUM_WAYS-1:0] i_mem_icache_data_cfg, // To u_ibex_top of ibex_top.v\n")
        continue
    if re.match(r'^input\s+i_mem_icache_tag_cfg,', l):
        out.append("input  prim_ram_1p_pkg::ram_1p_cfg_req_t [ibex_pkg::IC_NUM_WAYS-1:0] i_mem_icache_tag_cfg,  // To u_ibex_top of ibex_top.v\n")
        continue
    if re.match(r'^output\s+o_mem_icache_data_cfg,', l):
        out.append("output prim_ram_1p_pkg::ram_1p_cfg_rsp_t [ibex_pkg::IC_NUM_WAYS-1:0] o_mem_icache_data_cfg, // From u_ibex_top of ibex_top.v\n")
        continue
    if re.match(r'^output\s+o_mem_icache_tag_cfg,', l):
        out.append("output prim_ram_1p_pkg::ram_1p_cfg_rsp_t [ibex_pkg::IC_NUM_WAYS-1:0] o_mem_icache_tag_cfg,  // From u_ibex_top of ibex_top.v\n")
        continue
    if "prim_ram_1p_pkg::ram_1p_cfg_rsp_t(prim_ram_1p_pkg" in l:
        continue
    if "prim_ram_1p_pkg::ram_1p_cfg_req_t(prim_ram_1p_pkg" in l:
        continue
    l = l.replace("[SCRAMBLE_KEY_W-1:0]", "[127:0]")
    l = l.replace("[SCRAMBLE_NONCE_W-1:0]", "[63:0]")
    stripped = l.strip()
    if in_instantiation and any(stripped.startswith(f".{name}") for name in (
        "BaseIsa", "PMPRstCfg", "PMPRstMsecCfg", "RV32M", "RV32B", "RV32ZC",
        "RegFile", "RndCnstLfsrSeed", "RndCnstLfsrPerm",
    )):
        continue
    out.append(l)

text = "".join(out)

text = text.replace(
    "input logic [31:0]\ti_hart_id,\t\t// To u_ibex_top of ibex_top.v\n",
    "input logic [31:0]\ti_hart_id,\t\t// To u_ibex_top of ibex_top.v\n"
    "input  ibex_mubi_t\ti_cheriot_enable,\t// To u_ibex_top of ibex_top.v\n"
    "input  ibex_mubi_t\ti_fetch_enable,\t\t// To u_ibex_top of ibex_top.v\n"
    "input  ibex_mubi_t\ti_mcounteren_writable,\t// To u_ibex_top of ibex_top.v\n"
)
text = text.replace(
    "output logic\t\to_trvk_revbm_req\t// From u_ibex_top of ibex_top.v\n",
    "output logic\t\to_trvk_revbm_req,\t// From u_ibex_top of ibex_top.v\n"
    "output crash_dump_t\to_crash_dump,\t\t// From u_ibex_top of ibex_top.v\n"
    "output ibex_mubi_t\to_lockstep_cmp_en\t// From u_ibex_top of ibex_top.v\n"
)

if not text.startswith("`default_nettype none"):
    text = "`default_nettype none\n" + text
if "`default_nettype wire\n" not in text:
    text = text.replace("endmodule\n", "endmodule\n`default_nettype wire\n", 1)

open(PATH, "w", encoding="utf-8", newline="\n").write(text)
print(f"fixup_ibex_wrap: patched {PATH}")
