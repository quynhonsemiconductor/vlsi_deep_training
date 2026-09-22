#!/usr/bin/env python3
"""
gen_qnsc_pkg.py -- generate design/top/rtl/qnsc_pkg.sv from util/qsoc_contract.yml.

The package holds every number shared between blocks: base addresses, region
sizes, interrupt line indices and their mcause values, and the clock-domain
soft-reset bits. A wrapper imports it instead of retyping the number, so two
blocks cannot disagree about one fact.

The four defects that motivated this were all one fact written twice:
ROM 8 KiB against 2 KiB, APB_M11 against APB_S11, eleven interrupt sources
against twelve, apb_adv_timer against apb_timer_unit.

Constants follow QNSC_RTL_Design_Naming_Rule V1.0 section 2.4: a local constant
is C_<FUNCTION>, uppercase. The generated file is therefore checked by
flow/lint/naming_check.py like any other RTL under design/.

Usage:
    python3 util/gen_qnsc_pkg.py            # write the package
    python3 util/gen_qnsc_pkg.py --check    # fail if the committed file differs
"""
from __future__ import annotations

import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")

REPO = Path(__file__).resolve().parent.parent
CONTRACT = REPO / "util" / "qsoc_contract.yml"
OUT = REPO / "design" / "top" / "rtl" / "qnsc_pkg.sv"


def hexlit(value: int, width: int = 32) -> str:
    return f"{width}'h{value:08X}"


def emit(c: dict) -> str:
    meta = c["meta"]
    L: list[str] = []
    a = L.append

    a("// =============================================================================")
    a("// GENERATED FILE -- DO NOT EDIT.")
    a("//")
    a("// Source:    util/qsoc_contract.yml")
    a("// Generator: util/gen_qnsc_pkg.py")
    a("//")
    a("// Every constant here is shared by more than one block. Import this package")
    a("// rather than retyping a number, so that two blocks cannot disagree about one")
    a("// fact -- which is how ROM 8 KiB against 2 KiB, APB_M11 against APB_S11 and")
    a("// eleven interrupt sources against twelve all happened.")
    a("//")
    a("// To change a number: edit the contract, run the generator, commit both. CI")
    a("// regenerates and compares, so this file cannot drift from the contract.")
    a("// =============================================================================")
    a("")
    a("package qnsc_pkg;")
    a("")
    a("  // ---- geometry ------------------------------------------------------------")
    a(f"  localparam int unsigned C_DATA_WIDTH = {meta['data_width']};")
    a(f"  localparam int unsigned C_ADDR_WIDTH = {meta['addr_width']};")
    a(f"  localparam int unsigned C_CLK_MHZ    = {meta['clock_mhz']};")
    a("")

    # ---- memory map ------------------------------------------------------
    a("  // ---- memory map ----------------------------------------------------------")
    a("  // Source: QSOC_HAS Table 7-1. Every address in the 32-bit space belongs to")
    a("  // exactly one region; anything else must answer DECERR.")
    width = max(len(r["name"]) for r in c["memory_map"])
    for r in c["memory_map"]:
        n = r["name"].upper()
        a(f"  localparam logic [C_ADDR_WIDTH-1:0] C_{n}_BASE = {hexlit(r['base'])};")
        a(f"  localparam int unsigned             C_{n}_SIZE = {r['size']};"
          f"  // {r['size'] // 1024} KiB" if r["size"] >= 1024 else
          f"  localparam int unsigned             C_{n}_SIZE = {r['size']};"
          f"  // {r['size']} B")
    a("")

    # ---- interrupts ------------------------------------------------------
    ints = c["interrupts"]
    a("  // ---- interrupt lines -----------------------------------------------------")
    a("  // Source: QSOC_HAS Table 8-1. The line index IS the priority: Ibex resolves")
    a("  // the lowest index first, so this order is the default priority order and")
    a("  // changing it means re-synthesising. Order follows the rule")
    a("  // \"data loss first, human time last\".")
    a("  //")
    a("  // mcause = 16 + line, and the vector is mtvec + 4 * mcause. Causes 16 and")
    a("  // above are platform-use space in the privileged specification.")
    a(f"  localparam int unsigned C_INT_FAST_LINES_AVAILABLE = {ints['fast_lines_available']};")
    a(f"  localparam int unsigned C_INT_FAST_LINES_USED      = {len(ints['lines'])};")
    total = sum(l["sources"] for l in ints["lines"])
    a(f"  localparam int unsigned C_INT_SOURCES_AGGREGATED   = {total};"
      f"  // through INTMAP")
    a(f"  localparam int unsigned C_INT_SOURCES_TOTAL        = {total + ints['nmi']['sources']};"
      f"  // including the NMI")
    a("")
    for l in ints["lines"]:
        n = l["peripheral"].upper()
        a(f"  localparam int unsigned C_INT_LINE_{n:<12} = {l['line']};"
          f"   // mcause {16 + l['line']}, {l['sources']} source(s), {l['shape']}")
    a("")
    a(f"  localparam int unsigned C_INT_MCAUSE_BASE = 16;")
    a(f"  localparam int unsigned C_INT_MCAUSE_NMI  = {ints['nmi']['mcause']};"
      f"   // {ints['nmi']['peripheral']}, on irq_nm_i, never through INTMAP")
    a("")

    # ---- clock domains ---------------------------------------------------
    a("  // ---- clock and reset clusters ---------------------------------------------")
    a("  // Source: QSOC_HAS v4 section 'Clock and Reset'. One frequency for the whole")
    a("  // chip -- no PLL, the PDK has no analogue IP -- so a domain is a gate plus a")
    a("  // reset synchroniser, not a separate frequency.")
    a("  //")
    a("  // The cluster name is what goes into the port name the naming rule requires:")
    a("  //   i_clk_<domain> / i_rst_n_<domain>")
    cl = c["clock_domains"]["clusters"]
    for cluster in cl:
        blocks = ", ".join(cluster["blocks"])
        gate = "gateable via CLK_EN in SCRC" if cluster["gateable"] else "hardwired on, not writable"
        a(f"  //   i_clk_{cluster['port_suffix']:<5} {gate}")
        a(f"  //     {blocks}")
    a(f"  localparam int unsigned C_CLK_CLUSTERS = {len(cl)};")
    a("")
    a(f"  localparam int unsigned C_RST_SOURCES = {len(c['reset_sources'])};"
      f"   // {', '.join(c['reset_sources'])}")
    a("")
    a("  // The CLK_EN and SOFT_RST_CTRL bit positions per peripheral belong to the")
    a("  // SCRC register map and are not duplicated here -- see tbd: in the contract.")
    a("")
    a("endpackage : qnsc_pkg")
    return "\n".join(L) + "\n"


def main(argv: list[str]) -> int:
    contract = yaml.safe_load(CONTRACT.read_text())
    text = emit(contract)

    if "--check" in argv:
        if not OUT.exists():
            print(f"FAIL: {OUT.relative_to(REPO)} does not exist. "
                  f"Run: python3 util/gen_qnsc_pkg.py")
            return 1
        current = OUT.read_text()
        if current != text:
            print(f"FAIL: {OUT.relative_to(REPO)} has drifted from "
                  f"{CONTRACT.relative_to(REPO)}.")
            print("The committed package no longer matches the contract it is")
            print("generated from, which is the drift this check exists to stop.")
            print("\nFix: python3 util/gen_qnsc_pkg.py  -- then commit both files.")
            import difflib
            diff = difflib.unified_diff(
                current.splitlines(keepends=True), text.splitlines(keepends=True),
                fromfile="committed", tofile="regenerated", n=2)
            sys.stdout.writelines(list(diff)[:60])
            return 1
        print(f"contract check: {OUT.relative_to(REPO)} matches "
              f"{CONTRACT.relative_to(REPO)}")
        return 0

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text)
    print(f"wrote {OUT.relative_to(REPO)} "
          f"({len(text.splitlines())} lines) from {CONTRACT.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
