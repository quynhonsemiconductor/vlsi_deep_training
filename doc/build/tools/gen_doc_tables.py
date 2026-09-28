#!/usr/bin/env python3
"""Generate specification tables from the inter-block contract.

A table that restates the contract -- the interrupt line assignment, the memory
map, the core's tied-off interrupt inputs -- is a copy, and a copy drifts. The
five specifications and util/qsoc_contract.yml disagreeing is exactly the failure
this repository is organised to prevent, so those tables are generated into the
markdown instead of typed.

A generated region is delimited in the markdown by:

    <!-- gen:interrupt_lines -->
    ... table, rewritten by this tool ...
    <!-- /gen -->

A marker may carry options, key=value separated by spaces, which are passed
to the generator. Only memory_map takes one today:

    <!-- gen:memory_map ports=AXI_M1,AXI_M2 -->

Text outside the markers is never touched, so a section can introduce or qualify
its table in prose and keep only the rows generated.

    python3 doc/build/tools/gen_doc_tables.py            rewrite every region
    python3 doc/build/tools/gen_doc_tables.py --check     fail if any is stale (CI)

--check is the half that matters: it makes a specification that has drifted from
the contract a failing pull request rather than something found in review.
"""

import argparse
import inspect
import pathlib
import re
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[3]
CONTRACT = ROOT / "util" / "qsoc_contract.yml"
SRC = ROOT / "doc" / "specs"

MARKER = re.compile(
    r"(?P<open><!--\s*gen:(?P<name>[a-z_]+)(?P<args>(?:\s+[a-z_]+=[^\s>]+)*)\s*-->\n)"
    r"(?P<body>.*?)"
    r"(?P<close><!--\s*/gen\s*-->)",
    re.S,
)


def table(header, rows=None, align="", caption=None):
    """Render a markdown table. Columns are not padded: the width would change
    with the content and make every regeneration a diff.

    align is one character per column -- 'r' right, anything else left. Numeric
    columns read better right-aligned, and the alignment has to be generated
    along with the rows or regenerating would silently drop it."""
    align = (align + "l" * len(header))[:len(header)]
    # The caption is generated with the table, not left in the prose: pandoc only
    # attaches ": caption" to a table it directly abuts, and the <!-- gen --> line
    # would sit between the two.
    out = [": " + caption, ""] if caption else []
    out += ["| " + " | ".join(header) + " |",
           "|" + "|".join("---:" if a == "r" else "---" for a in align) + "|"]
    out += ["| " + " | ".join(str(c) for c in r) + " |" for r in rows]
    return "\n".join(out) + "\n"


# --------------------------------------------------------------------------
# generators -- one per marker name
# --------------------------------------------------------------------------

def source_ports(entry):
    """The vendor port(s) behind one INTMAP input, compact enough for a cell.

    Several ports sharing a prefix and suffix (spi_device's eight intr_*_o)
    collapse to the pattern and a count; one port name with more than one
    source is one port per instance (GPIO0-2)."""
    ports, n = entry["ports"], entry["sources"]
    if len(ports) > 4:
        pre = ports[0]
        while not all(p.startswith(pre) for p in ports):
            pre = pre[:-1]
        suf = ports[0]
        while not all(p.endswith(suf) for p in ports):
            suf = suf[1:]
        return "`%s*%s` ×%d" % (pre, suf, len(ports))
    if len(ports) == 1 and n > 1 and "[" not in ports[0]:
        return "`%s` ×%d" % (ports[0], n)
    return ", ".join("`%s`" % p for p in ports)


def interrupt_lines(c):
    """Fast-line assignment, including the spare lines and the NMI.

    One row per core input: the CPU port, the cause and vector it raises, the
    INTMAP input that drives it, and the vendor port(s) behind that input. The
    vector is derived, because mtvec + 4 * mcause is fixed by Ibex's vectored
    mode. The INTMAP input is i_int_<peripheral> by the naming rule."""
    i = c["interrupts"]
    rows = []
    for l in i["lines"]:
        n = l["line"]
        rows.append([n, "`irq_fast_i[%d]`" % n, 16 + n,
                     "`mtvec + 0x%02X`" % (4 * (16 + n)),
                     "`i_int_%s`" % l["peripheral"], source_ports(l),
                     l["sources"], l["shape"]])
    used, avail = len(i["lines"]), i["fast_lines_available"]
    if used < avail:
        rows.append(["%d-%d" % (used, avail - 1),
                     "`irq_fast_i[%d:%d]`" % (avail - 1, used),
                     "%d-%d" % (16 + used, 16 + avail - 1),
                     "--", "tied 0 in `design/top`", "--", 0, "--"])
    n = i["nmi"]
    rows.append(["--", "`%s`" % n["port"], "**%d**" % n["mcause"],
                 "`mtvec + 0x%02X`" % (4 * n["mcause"]),
                 "**`i_int_%s`**" % n["peripheral"], source_ports(n),
                 n["sources"], n["shape"]])
    return table(["Line", "CPU port", "mcause", "Vector", "INTMAP input",
                  "Source port", "Width", "Shape"], rows, align="rlrlllrl",
                 caption="Interrupt line assignment")


def interrupt_totals(c):
    """The counts a reviewer checks first, as a table so the arithmetic is
    visible rather than asserted. The block names are the ones on the chip
    block diagram: the peripheral name up to its first underscore."""
    i = c["interrupts"]
    agg = sum(l["sources"] for l in i["lines"])
    nmi = i["nmi"]["sources"]
    every = i["lines"] + [i["nmi"]]
    blocks = []
    for l in every:
        b = l["peripheral"].split("_")[0].upper()
        if b not in blocks:
            blocks.append(b)
    pulses = sum(l["sources"] for l in every if l["shape"].startswith("pulse"))
    return table(["", "Count"], align="lr",
                 caption="Interrupt source totals", rows=[
        ["Sources onto fast lines", agg],
        ["Sources on the non-maskable input", nmi],
        ["**Total interrupt sources**", "**%d**" % (agg + nmi)],
        ["Source blocks (%s)" % ", ".join(blocks), len(blocks)],
        ["Sources that pulse", pulses],
        ["Fast lines driven", len(i["lines"])],
        ["Fast lines Ibex provides", i["fast_lines_available"]],
        ["Fast lines spare", i["fast_lines_available"] - len(i["lines"])],
    ])


def core_tie_offs(c):
    """Every interrupt input the core has, driven or tied. The mcause of a tied
    input is the standard RISC-V cause it would raise; tied, it never does."""
    i = c["interrupts"]
    used, avail = len(i["lines"]), i["fast_lines_available"]
    rows = [
        ["`irq_fast_i[%d:0]`" % (used - 1), used, "**`o_int_fast`, this block**",
         "%d source groups, one per line, `mcause` 16-%d" % (used, 15 + used)],
        ["`irq_fast_i[%d:%d]`" % (avail - 1, used), avail - used,
         "tied `%d'b0` in `design/top`" % (avail - used),
         "spare; `mcause` %d-%d never raised" % (16 + used, 15 + avail)],
        ["`%s`" % i["nmi"]["port"], 1, "**`o_int_nm`, this block**",
         "%s wire, `mcause` %d, outside `mie` and `mstatus.MIE`"
         % (i["nmi"]["peripheral"], i["nmi"]["mcause"])],
    ]
    note = {
        "irq_external_i": "no PLIC; `mcause` 11 never raised",
        "irq_timer_i": "no CLINT `mtime`/`mtimecmp`; `mip.MTIP` stays 0",
        "irq_software_i": "no CLINT `msip`; `mip.MSIP` stays 0",
    }
    rows += [["`%s`" % p, 1, "tied `0` in `design/top`", note.get(p, "not used")]
             for p in i["tied_low"]]
    return table(["Core input", "Width", "Driven by", "Note"], rows, align="lrll",
                 caption="Every interrupt input on the core")


def memory_map(c, ports=None):
    """Every region, in address order -- or, with ports=AXI_M1,AXI_M2, only the
    regions behind those ports, so a block's specification can show its own
    rows without restating the whole chip.

    Bases are stored as integers in the contract so they can be sorted and
    compared, and are formatted here: a memory map written in decimal is
    unreadable. The first sentence of the note is used rather than the whole of
    it, because several notes carry a paragraph of reasoning that belongs in a
    _DECISIONS file, not in a table cell."""
    rows = []
    keep = set(ports.split(",")) if ports else None
    for r in sorted(c["memory_map"], key=lambda x: int(x["base"])):
        if keep is not None and r.get("port") not in keep:
            continue
        size = int(r["size"])
        human = ("%d KiB" % (size // 1024) if size >= 1024 else "%d B" % size)
        note = (r.get("note") or "").strip().split(". ")[0].rstrip(".")
        rows.append(["`0x%08X`" % int(r["base"]), human, "`%s`" % r["name"],
                     r.get("port", "--"), r.get("kind", ""), note])
    caption = ("QSOC memory map" if keep is None else
               "Memory map, regions behind %s" % " and ".join(sorted(keep)))
    return table(["Base", "Size", "Region", "Port", "Kind", "Note"], rows,
                 align="llllll", caption=caption)


GENERATORS = {
    "interrupt_lines": interrupt_lines,
    "interrupt_totals": interrupt_totals,
    "core_tie_offs": core_tie_offs,
    "memory_map": memory_map,
}


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true",
                    help="do not write; exit 1 if any region is stale")
    args = ap.parse_args()

    contract = yaml.safe_load(CONTRACT.read_text())
    stale, wrote, seen = [], [], 0

    for path in sorted(SRC.glob("*.md")):
        text = path.read_text()
        if "<!-- gen:" not in text:
            continue

        def repl(m):
            nonlocal seen
            name = m.group("name")
            if name not in GENERATORS:
                print("%s: unknown generator '%s' -- known: %s"
                      % (path.name, name, ", ".join(sorted(GENERATORS))),
                      file=sys.stderr)
                sys.exit(2)
            seen += 1
            opts = dict(a.split("=", 1) for a in m.group("args").split())
            known = set(inspect.signature(GENERATORS[name]).parameters) - {"c"}
            if set(opts) - known:
                print("%s: generator '%s' does not take option(s) %s"
                      % (path.name, name, ", ".join(sorted(set(opts) - known))),
                      file=sys.stderr)
                sys.exit(2)
            fresh = GENERATORS[name](contract, **opts)
            if m.group("body") != fresh:
                stale.append("%s: %s" % (path.name, name))
            return m.group("open") + fresh + m.group("close")

        new = MARKER.sub(repl, text)
        if new != text and not args.check:
            path.write_text(new)
            wrote.append(path.name)

    if not seen:
        print("no generated region found -- nothing to check", file=sys.stderr)
        return 0

    if args.check:
        if stale:
            print("stale generated table(s), regenerate with "
                  "doc/build/tools/gen_doc_tables.py:", file=sys.stderr)
            for s in stale:
                print("  " + s, file=sys.stderr)
            return 1
        print("%d generated region(s) match the contract" % seen)
        return 0

    print("%d region(s) in %d file(s)%s"
          % (seen, len({s.split(":")[0] for s in stale}) if stale else 0,
             ": " + ", ".join(sorted(set(wrote))) if wrote else " already current"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
