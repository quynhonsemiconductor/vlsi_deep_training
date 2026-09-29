#!/usr/bin/env python3
"""Connectivity of a block's top module, from Verilator's elaborated design.

    python3 flow/conn/connectivity.py <block> [--out DIR]
    make connectivity BLOCK=<block>

Elaborates design/<block>/<block>.f with `verilator --json-only` (the same filelist
lint, VCS and synthesis read) and reports, for the top module only:

  - every port of the top: direction, width, what it connects to
  - every instance: each pin, its direction and width, the expression tied to it
    (a signal, a slice, a constant, or "open")
  - the continuous assigns of the top
  - a Mermaid flowchart of the same (renders in GitHub markdown: PR comments,
    job summaries)

and fails when an instance **input** pin is left open (a floating input), or a top
output is driven by nothing. An open instance output, or a top input nothing reads,
is listed but allowed: waivers and the MAS tie-off table say why.

The top is m_qnsc_wrap_<block> when the filelist names that file, else the last
rtl/*.sv line, as flow/vcs/run_vcs picks it.

Verilator >= 5.022 is needed for --json-only. VERILATOR_IMAGE=<docker image> runs
it in that container instead of the local verilator (CI does, since the runner's
apt package is older). This is an open-source cross-check of the wrapper; the VCS
compile and the Verdi schematic on the training server remain the reference.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import tempfile

ROOT = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True,
                      text=True, check=True).stdout.strip()


# ---------------------------------------------------------------- elaboration
def pick_top(block, flist):
    text = open(flist).read()
    if re.search(rf"(^|/)m_qnsc_wrap_{block}\.sv\s*$", text, re.M):
        return f"m_qnsc_wrap_{block}"
    hits = re.findall(r"rtl/([A-Za-z0-9_]+)\.sv", text)
    return hits[-1] if hits else None


def verilator_cmd(args, cwd):
    image = os.environ.get("VERILATOR_IMAGE")
    if image:
        uid = f"{os.getuid()}:{os.getgid()}"
        return ["docker", "run", "--rm", "-u", uid, "-v", f"{ROOT}:{ROOT}",
                "-v", "/tmp:/tmp", "-w", cwd,
                "--entrypoint", "/usr/local/bin/verilator",   # not the image's wrapper,
                image] + args                                  # which expects a C++ build
    return ["verilator"] + args


def check_version():
    if os.environ.get("VERILATOR_IMAGE"):
        return
    r = subprocess.run(["verilator", "--version"], capture_output=True, text=True)
    m = re.search(r"Verilator (\d+)\.(\d+)", r.stdout)
    if not m or (int(m.group(1)), int(m.group(2))) < (5, 22):
        raise SystemExit("connectivity needs Verilator >= 5.022 (--json-only); found "
                         f"{m.group(0) if m else 'none'}. Install a newer one, or set "
                         "VERILATOR_IMAGE=verilator/verilator:v5.052 to run it in Docker")


def elaborate(block, top, out):
    check_version()
    cwd = os.path.join(ROOT, "design", block)
    args = ["--json-only", "-Wno-fatal", "-Wno-lint", "-Wno-style", "--top-module", top,
            "-F", f"{block}.f", "--Mdir", out]
    r = subprocess.run(verilator_cmd(args, cwd), cwd=cwd, capture_output=True, text=True)
    path = os.path.join(out, f"V{top}.tree.json")
    if r.returncode != 0 or not os.path.exists(path):
        sys.stderr.write(r.stdout + r.stderr)
        raise SystemExit(f"{block}: elaboration failed (make lint BLOCK={block} shows why)")
    return json.load(open(path))


# ---------------------------------------------------------------- tree helpers
def index(tree):
    idx = {}

    def walk(n):
        if isinstance(n, dict):
            if "addr" in n:
                idx[n["addr"]] = n
            for v in n.values():
                walk(v)
        elif isinstance(n, list):
            for x in n:
                walk(x)
    walk(tree)
    return idx


def width(idx, dtypep):
    d = idx.get(dtypep, {})
    rng = d.get("range")
    if not rng:
        return 1
    hi, lo = (int(x) for x in rng.split(":"))
    return abs(hi - lo) + 1


def const_int(name):
    m = re.match(r"(\d+)?'s?([hdbo])([0-9a-fA-F_xz]+)$", name)
    if not m:
        return int(name) if name.isdigit() else None
    base = {"h": 16, "d": 10, "b": 2, "o": 8}[m.group(2)]
    try:
        return int(m.group(3).replace("_", ""), base)
    except ValueError:
        return None


IDX = {}


def render(e):
    """Verilog text of an expression, and the signal names it references."""
    if not e:
        return "", set()
    t = e["type"]
    kid = lambda k: e.get(k, [None])[0] if e.get(k) else None
    if t == "VARREF":
        return e["name"], {e["name"]}
    if t == "CONST":
        return e["name"], set()
    if t == "SEL":
        base, refs = render(kid("fromp"))
        lsb = kid("lsbp")
        lo = const_int(lsb["name"]) if lsb and lsb["type"] == "CONST" else None
        w = e.get("widthConst", 1)
        if lo is None:
            return f"{base}[...]", refs
        return (f"{base}[{lo}]" if w == 1 else f"{base}[{lo + w - 1}:{lo}]"), refs
    if t == "CONCAT":
        a, ra = render(kid("lhsp"))
        b, rb = render(kid("rhsp"))
        return "{" + a.strip("{}") + ", " + b.strip("{}") + "}", ra | rb
    if t in ("EXTEND", "EXTENDS"):          # {N'b0, x}, as Verilator folds a zero concat
        inner = kid("lhsp")
        s_, r_ = render(inner)
        pad = width(IDX, e.get("dtypep")) - width(IDX, inner.get("dtypep")) if inner else 0
        return (f"{{{pad}'b0, {s_}}}" if pad > 0 and t == "EXTEND" else s_), r_
    unary = {"REDOR": "|", "REDAND": "&", "REDXOR": "^", "NOT": "~", "LOGNOT": "!"}
    binary = {"OR": "|", "AND": "&", "XOR": "^", "LOGOR": "||", "LOGAND": "&&", "EQ": "==",
              "NEQ": "!=", "ADD": "+", "SUB": "-"}
    if t in unary:
        a, ra = render(kid("lhsp"))
        return f"{unary[t]}{a}", ra
    if t in binary:
        a, ra = render(kid("lhsp"))
        b, rb = render(kid("rhsp"))
        return f"({a} {binary[t]} {b})", ra | rb
    if t == "COND":
        c, rc = render(kid("condp"))
        a, ra = render(kid("thenp"))
        b, rb = render(kid("elsep"))
        return f"({c} ? {a} : {b})", rc | ra | rb
    refs, parts = set(), []
    for k, v in e.items():
        if isinstance(v, list):
            for c in v:
                if isinstance(c, dict) and "type" in c:
                    s, r = render(c)
                    parts.append(s)
                    refs |= r
    return f"{t.lower()}({', '.join(parts)})", refs


# ---------------------------------------------------------------- model
def model(tree, top):
    idx = index(tree)
    IDX.update(idx)
    mods = {m["name"]: m for m in tree["modulesp"]}
    m = mods[top]
    stmts = m.get("stmtsp", [])
    ports = [(v["name"], v["direction"].lower(), width(idx, v["dtypep"]))
             for v in stmts if v["type"] == "VAR" and v.get("varType") == "PORT"]
    cells = []
    for c in (s for s in stmts if s["type"] == "CELL"):
        child = idx.get(c["modp"], {})
        cports = {v["name"]: (v["direction"].lower(), width(idx, v["dtypep"]))
                  for v in child.get("stmtsp", [])
                  if v["type"] == "VAR" and v.get("varType") == "PORT"}
        pins = []
        for p in c.get("pinsp", []):
            text, refs = render(p["exprp"][0] if p.get("exprp") else None)
            d, w = cports.get(p["name"], ("?", "?"))
            pins.append((p["name"], d, w, text, refs))
        cells.append((c["name"], child.get("origName") or c["modName"], pins))
    assigns = []

    def collect(n):
        if isinstance(n, dict):
            if n.get("type") == "ASSIGNW":
                lhs, lr = render(n["lhsp"][0])
                rhs, rr = render(n["rhsp"][0])
                assigns.append((lhs, rhs, lr, rr))
                return
            for v in n.values():
                collect(v)
        elif isinstance(n, list):
            for x in n:
                collect(x)
    collect([s for s in stmts if s["type"] == "ASSIGNW" or
             (s["type"] == "ALWAYS" and s.get("keyword") == "cont_assign")])
    # procedural logic of the top itself: always_ff / always_comb / always @
    reads, writes = set(), set()

    def refs(n):
        if isinstance(n, dict):
            if n.get("type") == "VARREF":
                (writes if n.get("access") == "WR" else reads).add(n["name"])
            for v in n.values():
                refs(v)
        elif isinstance(n, list):
            for x in n:
                refs(x)
    refs([s for s in stmts if s["type"] == "ALWAYS" and s.get("keyword") != "cont_assign"])
    # a block that writes nothing is a check (assertion, $display): not connectivity
    procs = (reads, writes) if writes else None
    return ports, cells, assigns, procs


# ---------------------------------------------------------------- report
def report(block, top, ports, cells, assigns, procs):
    loads, drivers = {}, {}
    for cn, _, pins in cells:
        for pn, d, _, text, refs in pins:
            for r in refs:
                (drivers if d == "output" else loads).setdefault(r, []).append(f"{cn}.{pn}")
    for i, (lhs, rhs, lr, rr) in enumerate(assigns):
        for r in lr:
            drivers.setdefault(r, []).append(f"assign {lhs}")
        for r in rr:
            loads.setdefault(r, []).append(f"assign {lhs}")

    if procs:
        for r in procs[0]:
            loads.setdefault(r, []).append("always blocks")
        for w in procs[1]:
            drivers.setdefault(w, []).append("always blocks")
    fails, notes, out = [], [], []
    out.append(f"#### `{block}`: top `{top}`\n")
    out.append("| Port | Dir | Width | Connects to |\n|---|---|---:|---|")
    for n, d, w in ports:
        to = (loads if d == "input" else drivers).get(n, [])
        if not to:
            (fails if d == "output" else notes).append(
                f"top {d} `{n}` " + ("is driven by nothing" if d == "output" else "is read by nothing"))
        out.append(f"| `{n}` | {d} | {w} | {', '.join(f'`{x}`' for x in to) or '**none**'} |")
    for cn, mod, pins in cells:
        out.append(f"\n`{cn}` : `{mod}`\n\n| Pin | Dir | Width | Tied to |\n|---|---|---:|---|")
        for pn, d, w, text, _ in pins:
            if not text:
                (fails if d == "input" else notes).append(
                    f"`{cn}.{pn}` ({d}) is open" + (": a floating input" if d == "input" else ""))
            out.append(f"| `{pn}` | {d} | {w} | {f'`{text}`' if text else '*open*'} |")
    if assigns:
        out.append("\nContinuous assigns\n")
        out += [f"- `{lhs} = {rhs}`" for lhs, rhs, _, _ in assigns]
    out.append("\n" + mermaid(top, ports, cells, assigns, loads, drivers, procs))
    if notes:
        out.append("\nAllowed, check against the MAS tie-off table:\n")
        out += [f"- {n}" for n in notes]
    if fails:
        out.append("\n**FAIL**\n")
        out += [f"- {f}" for f in fails]
    return "\n".join(out) + "\n", fails


def mermaid(top, ports, cells, assigns, loads, drivers, procs):
    """A schematic-like block diagram, the same for every block.

    Left to right: the top's inputs, its instances, assigns, constants and procedural
    logic, then its outputs; the top module is the title. Wires are orthogonal. No box
    is drawn around the top: Mermaid's layout routes every wire that crosses a box
    through one point of its border, which makes a large block unreadable. To keep a
    wide interface readable:
      - bus ports, named `<i|o>_bus_<protocol>[_<channel>]_<signal>` by the Naming
        Rule, are one node per direction and prefix (`i_bus_apb_*`, `o_bus_axi_aw_*`)
        that lists its members, when there are three or more;
      - assigns to slices of one signal (`o_int_fast[0]`..`[10]`) are one node, and
        so are assigns to the members of one bus group;
      - constants are one node per value (`0`, `1`, ...), as tie cells in a schematic.
    The tables above stay complete; the diagram groups, it never drops a connection.
    """
    nid = lambda s: "n_" + re.sub(r"[^A-Za-z0-9]", "_", s)
    abase = lambda lhs: re.sub(r"\[[^\]]*\]$", "", lhs)

    groups = {}
    for n, d, _ in ports:
        if re.match(r"[io]_bus_", n):
            groups.setdefault((n.rsplit("_", 1)[0], d), []).append(n)
    pnode, plabel, gname = {}, {}, {}
    for (prefix, d), members in groups.items():
        if len(members) >= 3:
            key = nid("g " + prefix + " " + d)
            for m in members:
                gname[m] = prefix + "_*"
            short = " ".join(m[len(prefix) + 1:] for m in members)
            plabel[key] = f"{prefix}_*<br/>{short}"
            for m in members:
                pnode[m] = key
    width_of = {n: w for n, _, w in ports}
    for n, d, w in ports:
        if n not in pnode:
            pnode[n] = nid("p " + n)
            plabel[pnode[n]] = n + (f" [{w - 1}:0]" if w > 1 else "")

    def endpoint(ep):
        if ep == "always blocks":
            return "n_logic"
        if ep.startswith("assign "):
            b = abase(ep[len("assign "):])
            return nid("a " + gname.get(b, b))
        return nid("c " + ep.split(".")[0])

    edges = {}

    def add(a, b, lab):
        if a != b:
            edges.setdefault((a, b), set()).add(lab)
    for n, d, _ in ports:
        if d == "input":
            for ld in loads.get(n, []):
                add(pnode[n], endpoint(ld), ld.split(".")[-1] if "." in ld else n)
        else:
            for dr in drivers.get(n, []):
                add(endpoint(dr), pnode[n], dr.split(".")[-1] if "." in dr else n)
    for net, drs in drivers.items():
        if net in width_of:
            continue
        for dr in drs:
            for ld in loads.get(net, []):
                if endpoint(dr) != endpoint(ld):
                    add(endpoint(dr), endpoint(ld), net)
    consts = {}
    for cn, _, pins in cells:
        for pn, d, _, text, refs in pins:
            if text and not refs and d == "input":
                v = const_int(text)
                label = str(v) if v is not None else text
                k = nid("k " + label)
                consts[k] = label
                add(k, nid("c " + cn), pn)

    ins = [k for k in dict.fromkeys(pnode[n] for n, d, _ in ports if d == "input")]
    outs = [k for k in dict.fromkeys(pnode[n] for n, d, _ in ports if d != "input")]
    L = ["```mermaid", "---", f"title: {top}", "---",
         '%%{init: {"flowchart": {"curve": "stepAfter"}}}%%', "flowchart LR"]
    L += [f'  {k}>"{plabel[k]}"]' for k in ins]
    L += [f'  {nid("c " + cn)}["<b>{cn}</b><br/>{mod}"]' for cn, mod, _ in cells]
    abases = {}
    for lhs, _, _, _ in assigns:
        b = abase(lhs)
        abases.setdefault(gname.get(b, b), []).append(lhs)
    for b, lhss in abases.items():
        tag = f"assign {b}" if (len(lhss) == 1 and lhss[0] == b) or b.endswith("_*") \
            else f"assign {b}[...] x{len(lhss)}"
        L.append(f'  {nid("a " + b)}{{{{"{tag}"}}}}')
    if procs:
        L.append('  n_logic{{"always blocks"}}')
    L += [f'  {k}(["{v}"])' for k, v in consts.items()]
    L += [f'  {k}>"{plabel[k]}"]' for k in outs]
    for (a, b), labels in sorted(edges.items()):
        labs = sorted(labels)
        lab = ", ".join(labs) if len(", ".join(labs)) <= 40 else f"{labs[0]} ... ({len(labs)})"
        L.append(f'  {a} -->|"{lab}"| {b}')
    L.append("```")
    L.append("*Flag: a port of the top; box: an instance; hexagon: an assign or procedural "
             "logic; circle: a constant. Labels are the instance pins; `...` shortens a list, "
             "which the tables give in full.*")
    return "\n".join(L)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("block")
    ap.add_argument("--out", help="write connectivity.md here")
    a = ap.parse_args()
    flist = os.path.join(ROOT, "design", a.block, f"{a.block}.f")
    if not os.path.exists(flist):
        raise SystemExit(f"no {flist}")
    top = pick_top(a.block, flist)
    if not top:
        print(f"{a.block}: filelist has no rtl/*.sv yet, skipped")
        return 0
    with tempfile.TemporaryDirectory(dir="/tmp") as tmp:
        tree = elaborate(a.block, top, tmp)
    text, fails = report(a.block, top, *model(tree, top))
    if a.out:
        os.makedirs(a.out, exist_ok=True)
        open(os.path.join(a.out, "connectivity.md"), "w").write(text)
    print(text)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
