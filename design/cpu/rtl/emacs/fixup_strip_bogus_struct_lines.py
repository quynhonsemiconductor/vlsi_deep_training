#!/usr/bin/env python3
"""Strip the two bogus AUTOINST lines verilog-mode emits whenever it AUTOINSTs
an instance with a packed-array-of-struct port (prim_ram_1p_pkg::ram_1p_cfg_*),
which it mis-parses as if the struct type name were itself a port connection.
Used by both m_qnsc_wrap_ibex.sv (direct ibex_top instantiation) and
m_qnsc_wrap_cpu.sv (which AUTOINSTs m_qnsc_wrap_ibex and inherits the same
inferred port).
"""
import sys

PATH = sys.argv[1]
lines = open(PATH, encoding="utf-8").readlines()
out = [l for l in lines if "prim_ram_1p_pkg::ram_1p_cfg_rsp_t(prim_ram_1p_pkg" not in l
                        and "prim_ram_1p_pkg::ram_1p_cfg_req_t(prim_ram_1p_pkg" not in l]
open(PATH, "w", encoding="utf-8", newline="\n").writelines(out)
print(f"fixup_strip_bogus_struct_lines: removed {len(lines)-len(out)} line(s) from {PATH}")
