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

    The CPU port column is what a reader traces the row to in the RTL, and was
    asked for in review: without it the table names a line number but never the
    wire it is.

    The vector address is derived here rather than written down, because
    mtvec + 4 * mcause is a property of Ibex being in vectored mode, not a
    choice this project gets to make."""
    i = c["interrupts"]
    rows = []
    for l in i["lines"]:
        n = l["line"]
        rows.append([n, "`irq_fast_i[%d]`" % n, 16 + n,
                     "`mtvec + 0x%02X`" % (4 * (16 + n)),
                     l["peripheral"], l["sources"], l["shape"]])
    used, avail = len(i["lines"]), i["fast_lines_available"]
    if used < avail:
        rows.append(["%d-%d" % (used, avail - 1),
                     "`irq_fast_i[%d:%d]`" % (avail - 1, used),
                     "%d-%d" % (16 + used, 16 + avail - 1),
                     "--", "spare, tied to 0", 0, "--"])
    n = i["nmi"]
    rows.append(["--", "`irq_nm_i`", "**%d**" % n["mcause"],
                 "`mtvec + 0x%02X`" % (4 * n["mcause"]),
                 "**%s**" % n["peripheral"],
                 n["sources"], n["shape"]])
    return table(["Line", "CPU port", "mcause", "Vector", "Peripheral",
                  "Sources", "Shape"], rows, align="rlrllrl",
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
    """Every interrupt input the core has, driven or tied.

    This listed only the tied-off inputs while the text below it claimed to account
    for every interrupt input on the core, which left out the eleven fast bits this
    block drives and the non-maskable input -- raised in review. Listing all five
    makes the claim true and puts the whole interrupt boundary of the core in one
    table.

    The reason a standard line is tied off is the same question as why only the fast
    lines are used, so it is answered here rather than in a section of its own."""
    i = c["interrupts"]
    used, avail = len(i["lines"]), i["fast_lines_available"]
    rows = [
        ["`irq_fast_i[%d:0]`" % (used - 1), used, "**`o_int_fast`, this block**",
         "%d peripherals, one line each, `mcause` 16-%d" % (used, 15 + used)],
        ["`irq_fast_i[%d:%d]`" % (avail - 1, used), avail - used,
         "tied `%d'b0`" % (avail - used),
         "spare: QSOC drives %d of the %d lines the core offers" % (used, avail)],
        ["`%s`" % i["nmi"]["port"], 1, "**`o_int_nm`, this block**",
         "%s, `mcause` %d, outside `mie` and `mstatus.MIE`"
         % (i["nmi"]["peripheral"], i["nmi"]["mcause"])],
    ]
    why = {
        "irq_external_i": "needs a **PLIC** -- a bus slave with priority, "
                          "per-source enable and claim/complete registers. QSOC "
                          "has none, and %d lines fit in the %d the core offers "
                          "without one" % (used, avail),
        "irq_timer_i": "needs a **CLINT** for `mtime` and `mtimecmp`. QSOC has "
                       "none, so `mip.MTIP` is never set and TIMER0 is an "
                       "ordinary fast line",
        "irq_software_i": "needs a second hart to send the inter-processor "
                          "interrupt. QSOC has one",
    }
    rows += [["`%s`" % p, 1, "tied `0`", why.get(p, "not used")]
             for p in i["tied_low"]]
    return table(["Core input", "Width", "Driven by", "Why"], rows, align="lrll",
                 caption="Every interrupt input on the core")


def memory_map(c):
    """Every region, in address order.

    Bases are stored as integers in the contract so they can be sorted and
    compared, and are formatted here: a memory map written in decimal is
    unreadable. The first sentence of the note is used rather than the whole of
    it, because several notes carry a paragraph of reasoning that belongs in a
    _DECISIONS file, not in a table cell."""
    rows = []
    for r in sorted(c["memory_map"], key=lambda x: int(x["base"])):
        size = int(r["size"])
        human = ("%d KiB" % (size // 1024) if size >= 1024 else "%d B" % size)
        note = (r.get("note") or "").strip().split(". ")[0].rstrip(".")
        rows.append(["`0x%08X`" % int(r["base"]), human, "`%s`" % r["name"],
                     r.get("port", "--"), r.get("kind", ""), note])
    return table(["Base", "Size", "Region", "Port", "Kind", "Note"], rows,
                 align="llllll", caption="QSOC memory map")


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
