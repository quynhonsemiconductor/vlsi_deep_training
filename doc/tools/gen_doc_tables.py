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

Text outside the markers is never touched, so a section can introduce or qualify
its table in prose and keep only the rows generated.

    python3 doc/tools/gen_doc_tables.py            rewrite every region
    python3 doc/tools/gen_doc_tables.py --check     fail if any is stale (CI)

--check is the half that matters: it makes a specification that has drifted from
the contract a failing pull request rather than something found in review.
"""

import argparse
import pathlib
import re
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "util" / "qsoc_contract.yml"
SRC = ROOT / "doc" / "src"

MARKER = re.compile(
    r"(?P<open><!--\s*gen:(?P<name>[a-z_]+)\s*-->\n)"
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

def interrupt_lines(c):
    """Fast-line assignment, including the spare lines and the NMI.

    The vector address is derived here rather than written down, because
    mtvec + 4 * mcause is a property of Ibex being in vectored mode, not a
    choice this project gets to make."""
    i = c["interrupts"]
    rows = []
    for l in i["lines"]:
        n = l["line"]
        rows.append([n, 16 + n, "`mtvec + 0x%02X`" % (4 * (16 + n)),
                     l["peripheral"], l["sources"], l["shape"]])
    used, avail = len(i["lines"]), i["fast_lines_available"]
    if used < avail:
        rows.append(["%d-%d" % (used, avail - 1),
                     "%d-%d" % (16 + used, 16 + avail - 1),
                     "--", "spare, tied to 0", 0, "--"])
    n = i["nmi"]
    rows.append(["--", "**%d**" % n["mcause"],
                 "`mtvec + 0x%02X`" % (4 * n["mcause"]),
                 "**%s**, on `irq_nm_i`" % n["peripheral"],
                 n["sources"], n["shape"]])
    return table(["Line", "mcause", "Vector", "Peripheral", "Sources", "Shape"],
                 rows, align="rrllrl",
                 caption="Fast interrupt line assignment")


def interrupt_totals(c):
    """The sentence every reviewer checks first, as a table so the arithmetic is
    visible rather than asserted."""
    i = c["interrupts"]
    agg = sum(l["sources"] for l in i["lines"])
    nmi = i["nmi"]["sources"]
    return table(["", "Count"], align="lr",
                 caption="Interrupt source totals", rows=[
        ["Sources aggregated onto fast lines", agg],
        ["Sources on the non-maskable input", nmi],
        ["**Total interrupt sources**", "**%d**" % (agg + nmi)],
        ["Fast lines driven", len(i["lines"])],
        ["Fast lines Ibex provides", i["fast_lines_available"]],
        ["Fast lines spare", i["fast_lines_available"] - len(i["lines"])],
    ])


def core_tie_offs(c):
    """The core interrupt inputs QSOC does not drive, and why."""
    i = c["interrupts"]
    why = {
        "irq_external_i": "nothing aggregates onto it; there is no external "
                          "interrupt controller",
        "irq_timer_i": "no CLINT, so `mip.MTIP` is never set -- TIMER0 is an "
                       "ordinary fast line",
        "irq_software_i": "permitted on a single-hart system",
    }
    rows = [["`irq_fast_i[%d:%d]`" % (i["fast_lines_available"] - 1,
                                      len(i["lines"])),
             "`%d'b0`" % (i["fast_lines_available"] - len(i["lines"])),
             "QSOC drives %d of the %d lines"
             % (len(i["lines"]), i["fast_lines_available"])]]
    rows += [["`%s`" % p, "`0`", why.get(p, "not used")] for p in i["tied_low"]]
    return table(["Port", "Tied to", "Why"], rows,
                 caption="Core interrupt inputs tied off")


def memory_map(c):
    """Every region, in address order."""
    rows = []
    for r in sorted(c["memory_map"], key=lambda x: int(str(x["base"]), 16)):
        size = int(str(r["size"]), 0)
        human = ("%d KiB" % (size // 1024) if size >= 1024 else "%d B" % size)
        rows.append(["`%s`" % r["base"], human, r["name"],
                     r.get("bus", "--"), r.get("description", "")])
    return table(["Base", "Size", "Region", "Bus", "Description"], rows,
                 caption="QSOC memory map")


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
            fresh = GENERATORS[name](contract)
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
                  "doc/tools/gen_doc_tables.py:", file=sys.stderr)
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
