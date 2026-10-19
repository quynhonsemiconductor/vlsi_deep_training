#!/usr/bin/env python3
"""
gen_qnsc_pkg.py -- generate design/top/rtl/qnsc_pkg.sv from util/qsoc_contract.yml.

The package holds every number shared between blocks: base addresses, region
sizes, interrupt line indices and their mcause values, and the clock clusters. A wrapper imports it instead of retyping the number, so two
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


def check_paddr(c: dict) -> list[str]:
    """The two APB address widths must describe the memory map, not just sit next to it."""
    meta = c["meta"]
    slave, master = 1 << meta["apb_paddr_width"], 1 << meta["pbus_paddr_width"]
    apb = [r for r in c["memory_map"] if str(r.get("port", "")).startswith("APB_M")]
    bad = []
    for r in apb:
        if r["size"] != slave:
            bad.append(f"{r['name']}: size {r['size']:#x}, but 2**apb_paddr_width = {slave:#x}")
    lo = min(r["base"] for r in apb)
    hi = max(r["base"] + r["size"] for r in apb)
    if lo % master or hi - lo > master:
        bad.append(f"APB regions {lo:#x}..{hi:#x} do not fit one window of "
                   f"2**pbus_paddr_width = {master:#x} aligned to itself")
    return bad


def check_debug_window(c: dict) -> list[str]:
    """The debug window is the isram_dbg region, and its entry points and mailbox sit where
    the layout says. Ibex and the debug program take the numbers from here; a mismatch with
    the memory map would put the halt address outside the RAM that holds the program."""
    w = c["debug_window"]
    reg = next(r for r in c["memory_map"] if r["name"] == "isram_dbg")
    bad = []
    if w["base"] != reg["base"]:
        bad.append(f"debug_window.base {w['base']:#x} is not isram_dbg.base {reg['base']:#x}")
    if w["mask"] != reg["size"] - 1:
        bad.append(f"debug_window.mask {w['mask']:#x} is not isram_dbg.size - 1 = {reg['size'] - 1:#x}")
    if w["base"] & w["mask"]:
        bad.append("debug_window.base is not aligned to the window size (Ibex PMP rule)")
    if w["halt_addr"] != w["base"] + w["sequence_size"]:
        bad.append("debug_window.halt_addr is not base + sequence_size")
    if w["exception_addr"] != w["halt_addr"] + 0x10:
        bad.append("debug_window.exception_addr is not halt_addr + 0x10")
    seen = set()
    for m in w["mailbox"]:
        o = m["offset"]
        if o % 4 or o in seen:
            bad.append(f"mailbox {m['name']}: offset {o:#x} is unaligned or used twice")
        seen.add(o)
        if not (w["exception_addr"] - w["base"] + 0x10 <= o <= w["mask"] - 3):
            bad.append(f"mailbox {m['name']}: offset {o:#x} is not in the data area after the code")
    return bad


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
    a(f"  localparam int unsigned C_APB_PADDR_WIDTH  = {meta['apb_paddr_width']};  // P_BUS -> every APB slave: offset in its window")
    a(f"  localparam int unsigned C_PBUS_PADDR_WIDTH = {meta['pbus_paddr_width']};  // AXI2APB -> P_BUS: offset in the AXI2APB window")
    a(f"  localparam logic [31:0]  C_CHIP_ID = {hexlit(meta['chip_id'])};  // SYSCSR CHIP_ID_REV, ASCII 'QSOC'")
    a(f"  localparam logic [C_ADDR_WIDTH-1:0] C_AXI2APB_BASE = {hexlit(meta['apb_window_base'])};")
    a(f"  localparam int unsigned C_AXI2APB_SIZE = {meta['apb_window_size']};"
      f"  // {meta['apb_window_size'] // 1024} KiB, the whole P_BUS window (AXI_M3)")
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

    # ---- debug window ----------------------------------------------------
    w = c["debug_window"]
    a("  // ---- debug window --------------------------------------------------------")
    a("  // The first 4 KiB of ISRAM. Ibex DmBaseAddr/DmAddrMask/DmHaltAddr/DmExceptionAddr,")
    a("  // and the addresses the debug program and SYSDBG use. QNSC_BOOT_SPEC Table 9-1.")
    a(f"  localparam logic [C_ADDR_WIDTH-1:0] C_DM_BASE           = {hexlit(w['base'])};")
    a(f"  localparam logic [C_ADDR_WIDTH-1:0] C_DM_MASK           = {hexlit(w['mask'])};")
    a(f"  localparam logic [C_ADDR_WIDTH-1:0] C_DM_HALT_ADDR      = {hexlit(w['halt_addr'])};")
    a(f"  localparam logic [C_ADDR_WIDTH-1:0] C_DM_EXCEPTION_ADDR = {hexlit(w['exception_addr'])};")
    for m in w["mailbox"]:
        n = f"C_DM_MBX_{m['name'].upper()}_ADDR"
        a(f"  localparam logic [C_ADDR_WIDTH-1:0] {n:<19} = {hexlit(w['base'] + m['offset'])};")
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
      f"   // {ints['nmi']['peripheral']}, on irq_nm_i, a wire through INTMAP, never ORed")
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
    a("  // The CLK_EN bit positions per peripheral belong to the")
    a("  // SCRC register map and are not duplicated here -- see QNSC_SCRC_MAS Table 6-2.")
    a("")
    a("endpackage : qnsc_pkg")
    return "\n".join(L) + "\n"


def main(argv: list[str]) -> int:
    contract = yaml.safe_load(CONTRACT.read_text())
    problems = check_paddr(contract) + check_debug_window(contract)
    if problems:
        print("FAIL: the contract disagrees with itself:")
        for p in problems:
            print("  " + p)
        return 1
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
