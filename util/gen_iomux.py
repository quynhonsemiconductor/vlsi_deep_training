#!/usr/bin/env python3
"""Generate the IO MUX datapath, its CSR workbook and its test table.

    python3 util/gen_iomux.py <iomux_pads.yml> <out_dir> <workbook.xlsx>

Reads the pin map (util/gen/iomux/iomux_pads.yml) and writes into <out_dir>:

    m_qnsc_iomux_mux.sv   one `case` per pad on its 2-bit select
    iomux_expect.svh      per pad and code: what A, OE and Y must be, and the
                          idle value of every IP input that no pad selects

and the APB-CSR-Generator workbook to <workbook.xlsx> (two PADSEL registers),
which util/gen/iomux/gen.sh feeds to the vendored generator.

Before writing anything the table is checked; any failure stops with a message
and writes nothing:
  - every function on a pad is in the catalog, and every port it names exists
    with the right direction (a / oe read i_ ports, y drives an o_ port);
  - every IP input (o_ port bit) is reached by at most one pad and code, so no
    priority is needed, and by at least one, so no port exists for nothing;
  - every IP output (i_ port bit) is used by at least one pad and code;
  - the dbg_force functions all sit on b00.
Output is byte-identical for the same input (no date, sorted, LF).
"""
import re
import sys
from pathlib import Path

import openpyxl
import yaml

CODES = ["b00", "b01", "b10", "b11"]
REF = re.compile(r"(i_[a-z0-9_]+|o_[a-z0-9_]+)(?:\[(\d+)\])?")


def die(msg):
    sys.exit(f"gen_iomux: {msg}")


def fmt(template, groups):
    """Fill {1}, {2}, {lower1} from the regex groups of a function match."""
    out = template
    for i, g in enumerate(groups, start=1):
        out = out.replace(f"{{lower{i}}}", g.lower()).replace(f"{{{i}}}", g)
    return out


def load(path):
    data = yaml.safe_load(Path(path).read_text(encoding="utf-8"))
    ports = {p["name"]: p for p in data["ports"]}
    for p in data["ports"]:
        want = "i_" if p["dir"] == "in" else "o_"
        if not p["name"].startswith(want):
            die(f"port {p['name']}: dir {p['dir']} needs prefix {want}")
    return data, ports


def resolve(name, functions):
    for f in functions:
        m = re.fullmatch(f["match"], name)
        if m:
            r = {k: fmt(str(v), m.groups()) for k, v in f.items()
                 if k in ("a", "oe", "y", "idle")}
            r["kind"] = f["kind"]
            r["name"] = name
            return r
    die(f"function {name!r} is not in the catalog")


def refs(expr):
    """(port, bit or None) for each port named in an expression."""
    return [(m.group(1), None if m.group(2) is None else int(m.group(2)))
            for m in REF.finditer(expr)]


def check_ref(port, bit, ports, want_dir, where):
    if port not in ports:
        die(f"{where}: no port {port}")
    p = ports[port]
    if p["dir"] != want_dir:
        die(f"{where}: {port} is dir {p['dir']}, used as {want_dir}")
    if bit is None and p["width"] != 1:
        die(f"{where}: {port} is {p['width']} bits wide, give a bit")
    if bit is not None and not 0 <= bit < p["width"]:
        die(f"{where}: {port}[{bit}] out of range")


def build(data, ports):
    functions = data["functions"]
    pads = []
    y_users = {}                       # (port, bit) -> [(pad, code, name)]
    i_used = set()                     # (port, bit)
    for idx, row in enumerate(data["pads"]):
        pad = {"idx": idx, "pin": row["pin"], "codes": {}}
        for c, code in enumerate(CODES):
            name = row.get(code, "-")
            if name in (None, "-", ""):
                continue
            f = resolve(name, functions)
            where = f"PIN{row['pin']} {code} {name}"
            if f["kind"] in ("out", "inout"):
                for key in ("a", "oe"):
                    for port, bit in refs(f[key]):
                        check_ref(port, bit, ports, "in", where)
                        i_used.add((port, bit))
            if f["kind"] in ("in", "inout"):
                (port, bit), = refs(f["y"])
                check_ref(port, bit, ports, "out", where)
                y_users.setdefault((port, bit), []).append((idx, c, name))
                if "idle" not in f:
                    die(f"{where}: no idle value")
            pad["codes"][c] = f
        pads.append(pad)

    for (port, bit), users in sorted(y_users.items(), key=str):
        if len(users) > 1:
            die(f"{port}[{bit}] is reached from {len(users)} pads {users}: "
                "a priority would be needed")
    for p in ports.values():
        bits = [None] if p["width"] == 1 else range(p["width"])
        for b in bits:
            if p["dir"] == "out" and (p["name"], b) not in y_users:
                die(f"{p['name']}[{b}] is reached from no pad: drop the port")
            if p["dir"] == "in" and (p["name"], b) not in i_used:
                die(f"{p['name']}[{b}] reaches no pad: drop the port")

    force = []
    for name in data["dbg_force"]:
        hits = [pd for pd in pads if pd["codes"].get(0, {}).get("name") == name]
        if len(hits) != 1:
            die(f"dbg_force {name}: must be on b00 of exactly one pad")
        force.append(hits[0]["idx"])
    if sorted(force) != list(range(5)):
        die(f"dbg_force pads {sorted(force)}: design/iomux/rtl/m_qnsc_iomux.sv "
            "forces w_padsel[9:0] (pads 0-4); change it with the table")

    muxed = {pd["pin"] for pd in pads}
    for d in data.get("dedicated", []):
        if d["pin"] in muxed:
            die(f"PIN{d['pin']} is dedicated ({d['function']}) and muxed")
    return pads, y_users, sorted(force)


def idle_of(y_users, pads, port, bit):
    idx, c, _ = y_users[(port, bit)][0]
    return pads[idx]["codes"][c]["idle"]


def lit(value, width):
    bit = value.split("'b")[-1]
    return f"1'b{bit}" if width == 1 else f"{{{width}{{1'b{bit}}}}}"


HEADER = """\
// -----------------------------------------------------------------------------
// GENERATED by util/gen_iomux.py from util/gen/iomux/iomux_pads.yml.
// Do not edit: change the table and run `make gen IP=iomux`.
// -----------------------------------------------------------------------------
"""


def emit_mux(pads, y_users, ports):
    n = len(pads)
    L = ["`timescale 1ns/1ps", HEADER,
         "// IO MUX datapath. Combinational: no clock, no state.",
         "//   i_padsel[2k+1:2k] selects the function of pad k (b00 after reset).",
         "//   Pad k drives o_pad_out[k] / o_pad_oe[k] (OE active high) and",
         "//   returns i_pad_in[k]. An unassigned code leaves OE = 0 (Hi-Z).",
         "//   An IP input that no pad selects holds its idle value.",
         "//",
         "// Pad k -> package pin:"]
    for pd in pads:
        names = ", ".join(f"{CODES[c]} {f['name']}" for c, f in sorted(pd["codes"].items()))
        L.append(f"//   [{pd['idx']:2d}] PIN{pd['pin']:<3d} {names}")
    L += ["module m_qnsc_iomux_mux (",
          f"  input  logic [{2 * n - 1}:0] i_padsel,"]
    for p in ports.values():
        rng = f"[{p['width'] - 1}:0] " if p["width"] > 1 else ""
        d = "input " if p["dir"] == "in" else "output"
        L.append(f"  {d} logic {rng}{p['name']},")
    L += [f"  output logic [{n - 1}:0] o_pad_out,",
          f"  output logic [{n - 1}:0] o_pad_oe,",
          f"  input  logic [{n - 1}:0] i_pad_in",
          ");",
          "",
          "always_comb begin",
          "  // nothing drives a pad until its function does",
          "  o_pad_out = '0;",
          "  o_pad_oe  = '0;",
          "  // idle values of the IP inputs"]
    for p in ports.values():
        if p["dir"] != "out":
            continue
        if p["width"] == 1:
            L.append(f"  {p['name']} = {idle_of(y_users, pads, p['name'], None)};")
            continue
        vals = [idle_of(y_users, pads, p["name"], b) for b in range(p["width"])]
        if len(set(vals)) == 1:
            L.append(f"  {p['name']} = {lit(vals[0], p['width'])};")
        else:
            for b, v in enumerate(vals):
                L.append(f"  {p['name']}[{b}] = {v};")
    for pd in pads:
        k = pd["idx"]
        L += ["", f"  // [{k}] PIN{pd['pin']}",
              f"  case (i_padsel[{2 * k + 1}:{2 * k}])"]
        for c, f in sorted(pd["codes"].items()):
            body = []
            if f["kind"] in ("out", "inout"):
                body.append(f"o_pad_out[{k}] = {f['a']};")
                body.append(f"o_pad_oe[{k}]  = {f['oe']};")
            if f["kind"] in ("in", "inout"):
                body.append(f"{f['y']} = i_pad_in[{k}];")
            L.append(f"    2'b{CODES[c][1:]}: begin  // {f['name']}")
            L += [f"      {s}" for s in body]
            L.append("    end")
        if len(pd["codes"]) < 4:
            L.append("    default: ;  // unassigned: Hi-Z")
        L.append("  endcase")
    L += ["end", "", "endmodule", ""]
    return "\n".join(L)


def emit_expect(pads, y_users, force):
    n = len(pads)
    L = [HEADER,
         "// Included by dv/iomux/tb_iomux.sv. Expects in the testbench:",
         "//   r_sel_eff[k]   the select pad k should be using (after the debug force)",
         "//   t_chk(ok, msg) fails the test when ok is 0",
         "// and every DUT port as a testbench signal of the same name.",
         "",
         f"localparam int C_N_PAD = {n};",
         "localparam int C_PIN [C_N_PAD] = '{" + ", ".join(str(p["pin"]) for p in pads) + "};",
         "",
         "function automatic bit f_forced(input int k);",
         "  return k inside {" + ", ".join(str(k) for k in force) + "};",
         "endfunction",
         "",
         "// A, OE and Y of pad k under code c",
         "task automatic t_expect_pad(input int k, input logic [1:0] c);",
         "  case (k)"]
    for pd in pads:
        k = pd["idx"]
        L += [f"    {k}: case (c)  // PIN{pd['pin']}"]
        for c in range(4):
            f = pd["codes"].get(c)
            tag = f"PIN{pd['pin']} {CODES[c]}"
            if f is None:
                L.append(f"      2'b{CODES[c][1:]}: t_chk(o_pad_oe[{k}] === 1'b0, \"{tag} unassigned: OE = 0\");")
                continue
            chks = []
            if f["kind"] in ("out", "inout"):
                chks.append(f"t_chk(o_pad_out[{k}] === ({f['a']}), \"{tag} {f['name']}: A\");")
                chks.append(f"t_chk(o_pad_oe[{k}] === ({f['oe']}), \"{tag} {f['name']}: OE\");")
            else:
                chks.append(f"t_chk(o_pad_oe[{k}] === 1'b0, \"{tag} {f['name']}: OE = 0\");")
            if f["kind"] in ("in", "inout"):
                chks.append(f"t_chk({f['y']} === i_pad_in[{k}], \"{tag} {f['name']}: Y\");")
            L.append(f"      2'b{CODES[c][1:]}: begin")
            L += [f"        {s}" for s in chks]
            L.append("      end")
        L.append("      default: t_chk(1'b0, \"t_expect_pad: code is X\");")
        L.append("    endcase")
    L += ["    default: t_chk(1'b0, \"t_expect_pad: no such pad\");",
          "  endcase",
          "endtask",
          "",
          "// every IP input that no pad selects holds its idle value",
          "task automatic t_expect_idle();"]
    for (port, bit), users in sorted(y_users.items(), key=lambda kv: (kv[0][0], kv[0][1] if kv[0][1] is not None else -1)):
        idx, c, name = users[0]
        sig = port if bit is None else f"{port}[{bit}]"
        idle = pads[idx]["codes"][c]["idle"]
        L.append(f"  if (r_sel_eff[{idx}] != 2'b{CODES[c][1:]}) "
                 f"t_chk({sig} === {idle}, \"{name} not selected: idle {idle}\");")
    L += ["endtask", ""]
    return "\n".join(L)


def emit_workbook(path, n):
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "IOMUXCSR"
    rows = [
        ["Table - Configuration"],
        ["Config", "Value", "Description"],
        ["Module Name", "m_qnsc_iomux_csr"],
        ["Protocol", "APB"],
        ["Data Width", 32],
        ["Address Width", 16],
        ["Write Strobe", 4],
        ["Asynchronous", 0],
        ["Table - Register Definition"],
        ["REGISTER", "OFFSET", "BIT NAME", "FIELD WIDTH", "BIT TYPE", "RESET VALUE", "DESCRIPTION"],
    ]
    left = n
    for r in range((2 * n + 31) // 32):
        pads_here = min(16, left)
        left -= pads_here
        lo = 16 * r
        rows.append([f"padsel_{r}", f"0x{4 * r:04X}", None, None, None, "0x0",
                     f"Pad {lo}..{lo + pads_here - 1}: bits [2k+1:2k] select pad {lo}+k"])
        if pads_here < 16:
            rows.append([None, None, "reserved", f"[31:{2 * pads_here}]", "ro", "0x0",
                         "Reserved. Read-as-zero, write ignore."])
        rows.append([None, None, "sel", f"[{2 * pads_here - 1}:0]", "rw", "0x0",
                     "Function select, 2 bits per pad, b00 after reset"])
    for row in rows:
        ws.append(row)
    wb.save(path)


def main():
    if len(sys.argv) != 4:
        die("usage: gen_iomux.py <iomux_pads.yml> <out_dir> <workbook.xlsx>")
    data, ports = load(sys.argv[1])
    pads, y_users, force = build(data, ports)
    out = Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    (out / "m_qnsc_iomux_mux.sv").write_bytes(emit_mux(pads, y_users, ports).encode())
    (out / "iomux_expect.svh").write_bytes(emit_expect(pads, y_users, force).encode())
    emit_workbook(sys.argv[3], len(pads))
    print(f"gen_iomux: {len(pads)} pads, {sum(len(p['codes']) for p in pads)} "
          f"functions placed, force on pads {force}")


if __name__ == "__main__":
    main()
