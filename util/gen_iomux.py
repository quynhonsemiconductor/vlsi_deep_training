#!/usr/bin/env python3
"""Generate the IO MUX datapath and its test table.

    python3 util/gen_iomux.py <iomux_pads.yml> <out_dir>

Reads the pin map (util/gen/iomux/iomux_pads.yml) and writes into <out_dir>:

    m_qnsc_iomux_mux.sv   per muxed pad: b00..b11 on its 2-bit field of i_sel;
                          per fixed pad: its one function (b00)
    iomux_expect.svh      per pad and select: what A, OE, IE and Y must be, and
                          the idle value of every IP input no pad selects

Before writing anything the table is checked; any failure stops with a message
and writes nothing:
  - every function on a pad is in the catalog, and every port it names exists
    with the right direction (a / oe read i_ ports, y drives an o_ port);
  - every IP input (o_ port bit) is reached by at most one pad and select, so no
    priority is needed, and by at least one, so no port exists for nothing;
  - every IP output (i_ port bit) is used by at least one pad;
  - the select fields are 0..N-1, each on one muxed pad; a fixed pad has none
    (field k is i_sel[2k+1:2k]);
  - no pad uses a dedicated pin.
Output is byte-identical for the same input (no date, sorted, LF).
"""
import re
import sys
from pathlib import Path

import yaml

CODES = ["b00", "b01", "b10", "b11"]   # value of a muxed pad's 2-bit select field
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
            r["ie"] = "1'b1" if f["kind"] in ("in", "inout") else "1'b0"
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
    sels = {}                          # select bit -> pad index
    for idx, row in enumerate(data["pads"]):
        sel = row.get("sel")
        pad = {"idx": idx, "pin": row["pin"], "sel": sel, "codes": {}}
        for key in row:
            if key not in ("pin", "sel") + tuple(CODES):
                die(f"PIN{row['pin']}: unknown key {key!r}")
        if sel is None and any(row.get(c) not in (None, "-", "") for c in CODES[1:]):
            die(f"PIN{row['pin']}: b01..b11 without a select field")
        if sel is not None:
            if sel in sels:
                die(f"select bit {sel} on PIN{row['pin']} and pad {sels[sel]}")
            sels[sel] = idx
        for c, code in enumerate(CODES if sel is not None else CODES[:1]):
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

    if sorted(sels) != list(range(len(sels))):
        die(f"select fields {sorted(sels)} must be 0..{len(sels) - 1}")
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

    used = {pd["pin"] for pd in pads}
    for d in data.get("dedicated", []):
        if d["pin"] in used:
            die(f"PIN{d['pin']} is dedicated ({d['function']}) and in the pad table")
    return pads, y_users, len(sels)


def idle_of(y_users, pads, port, bit):
    idx, c, _ = y_users[(port, bit)][0]
    return pads[idx]["codes"][c]["idle"]


def lit(value, width):
    bit = value.split("'b")[-1]
    return f"1'b{bit}" if width == 1 else f"{{{width}{{1'b{bit}}}}}"


def body(f, k):
    """Assignments of pad k when function f is selected."""
    out = []
    if f["kind"] in ("out", "inout"):
        out.append(f"o_pad_out[{k}] = {f['a']};")
        out.append(f"o_pad_oe[{k}]  = {f['oe']};")
    out.append(f"o_pad_ie[{k}]  = {f['ie']};")
    if f["kind"] in ("in", "inout"):
        out.append(f"{f['y']} = i_pad_in[{k}];")
    return out


HEADER = """\
// -----------------------------------------------------------------------------
// GENERATED by util/gen_iomux.py from util/gen/iomux/iomux_pads.yml.
// Do not edit: change the table and run `make gen IP=iomux`.
// -----------------------------------------------------------------------------
"""


def emit_mux(pads, y_users, ports, n_sel):
    n = len(pads)
    L = ["`timescale 1ns/1ps", HEADER,
         "// IO MUX datapath. Combinational: no clock, no state.",
         "//   A muxed pad uses the function its 2-bit field of i_sel names",
         "//   (b00 after reset).",
         "//   A fixed pad has one function. Pad k drives o_pad_out[k] / o_pad_oe[k]",
         "//   (OE active high) / o_pad_ie[k] and returns i_pad_in[k]. An unassigned",
         "//   function leaves OE = 0 and IE = 0. An IP input that no pad selects",
         "//   holds its idle value.",
         "//",
         "// Pad k -> package pin:"]
    for pd in pads:
        names = ", ".join(f"{CODES[c]} {f['name']}" for c, f in sorted(pd["codes"].items()))
        names = names or "unassigned (reserved)"
        sel = (f"sel[{2 * pd['sel'] + 1}:{2 * pd['sel']}]" if pd["sel"] is not None
               else "fixed")
        L.append(f"//   [{pd['idx']:2d}] PIN{pd['pin']:<3d} {sel:<11} {names}")
    L += ["module m_qnsc_iomux_mux (",
          f"  input  logic [{2 * n_sel - 1}:0] i_sel,"]
    for p in ports.values():
        rng = f"[{p['width'] - 1}:0] " if p["width"] > 1 else ""
        d = "input " if p["dir"] == "in" else "output"
        L.append(f"  {d} logic {rng}{p['name']},")
    L += [f"  output logic [{n - 1}:0] o_pad_out,",
          f"  output logic [{n - 1}:0] o_pad_oe,",
          f"  output logic [{n - 1}:0] o_pad_ie,",
          f"  input  logic [{n - 1}:0] i_pad_in",
          ");",
          "",
          "always_comb begin",
          "  // nothing drives or receives on a pad until its function does",
          "  o_pad_out = '0;",
          "  o_pad_oe  = '0;",
          "  o_pad_ie  = '0;",
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
        if pd["sel"] is None:
            f = pd["codes"].get(0)
            if f is None:               # reserved pin: OE = 0, IE = 0 (defaults above)
                L += ["", f"  // [{k}] PIN{pd['pin']}: unassigned (reserved), Hi-Z"]
                continue
            L += ["", f"  // [{k}] PIN{pd['pin']}: {f['name']}"]
            L += [f"  {s}" for s in body(f, k)]
            continue
        L += ["", f"  // [{k}] PIN{pd['pin']}",
              f"  case (i_sel[{2 * pd['sel'] + 1}:{2 * pd['sel']}])"]
        free = []
        for c in range(len(CODES)):
            f = pd["codes"].get(c)
            if f is None:
                free.append(CODES[c])
                continue
            L.append(f"    2'{CODES[c]}: begin  // {f['name']}")
            L += [f"      {s}" for s in body(f, k)]
            L.append("    end")
        if free:
            L.append(f"    default: ;  // {', '.join(free)} unassigned: Hi-Z")
        L.append("  endcase")
    L += ["end", "", "endmodule", ""]
    return "\n".join(L)


def emit_expect(pads, y_users):
    n = len(pads)
    L = [HEADER,
         "// Included by dv/iomux/tb_iomux.sv. Expects in the testbench:",
         "//   r_sel_eff[k]   the 2-bit code of the function pad k should be using",
         "//                  (always 2'b00 on a fixed pad)",
         "//   t_chk(ok, msg) fails the test when ok is 0",
         "// and every DUT port as a testbench signal of the same name.",
         "",
         f"localparam int C_N_PAD = {n};",
         "localparam int C_PIN [C_N_PAD] = '{" + ", ".join(str(p["pin"]) for p in pads) + "};",
         "// select field of pad k (i_sel[2f+1:2f]), -1 on a fixed pad",
         "localparam int C_SEL [C_N_PAD] = '{" + ", ".join(
             str(p["sel"]) if p["sel"] is not None else "-1" for p in pads) + "};",
         "",
         "// A, OE, IE and Y of pad k using function c",
         "task automatic t_expect_pad(input int k, input logic [1:0] c);",
         "  case (k)"]
    for pd in pads:
        k = pd["idx"]
        L += [f"    {k}: case (c)  // PIN{pd['pin']}"]
        for c in range(len(CODES) if pd["sel"] is not None else 1):
            f = pd["codes"].get(c)
            tag = f"PIN{pd['pin']} {CODES[c]}"
            if f is None:
                L.append(f"      2'{CODES[c]}: t_chk(o_pad_oe[{k}] === 1'b0 && o_pad_ie[{k}] === 1'b0, "
                         f"\"{tag} unassigned: OE = 0, IE = 0\");")
                continue
            chks = []
            if f["kind"] in ("out", "inout"):
                chks.append(f"t_chk(o_pad_out[{k}] === ({f['a']}), \"{tag} {f['name']}: A\");")
                chks.append(f"t_chk(o_pad_oe[{k}] === ({f['oe']}), \"{tag} {f['name']}: OE\");")
            else:
                chks.append(f"t_chk(o_pad_oe[{k}] === 1'b0, \"{tag} {f['name']}: OE = 0\");")
            chks.append(f"t_chk(o_pad_ie[{k}] === {f['ie']}, \"{tag} {f['name']}: IE\");")
            if f["kind"] in ("in", "inout"):
                chks.append(f"t_chk({f['y']} === i_pad_in[{k}], \"{tag} {f['name']}: Y\");")
            L.append(f"      2'{CODES[c]}: begin")
            L += [f"        {s}" for s in chks]
            L.append("      end")
        L.append("      default: t_chk(1'b0, \"t_expect_pad: function is X or none\");")
        L.append("    endcase")
    L += ["    default: t_chk(1'b0, \"t_expect_pad: no such pad\");",
          "  endcase",
          "endtask",
          "",
          "// every IP input that no pad selects holds its idle value",
          "task automatic t_expect_idle();"]
    for (port, bit), users in sorted(y_users.items(), key=lambda kv: (kv[0][0], kv[0][1] if kv[0][1] is not None else -1)):
        idx, c, name = users[0]
        if pads[idx]["sel"] is None:
            continue                    # on a fixed pad: always selected
        sig = port if bit is None else f"{port}[{bit}]"
        idle = pads[idx]["codes"][c]["idle"]
        L.append(f"  if (r_sel_eff[{idx}] != 2'{CODES[c]}) "
                 f"t_chk({sig} === {idle}, \"{name} not selected: idle {idle}\");")
    L += ["endtask", ""]
    return "\n".join(L)


def main():
    if len(sys.argv) != 3:
        die("usage: gen_iomux.py <iomux_pads.yml> <out_dir>")
    data, ports = load(sys.argv[1])
    pads, y_users, n_sel = build(data, ports)
    out = Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    (out / "m_qnsc_iomux_mux.sv").write_bytes(emit_mux(pads, y_users, ports, n_sel).encode())
    (out / "iomux_expect.svh").write_bytes(emit_expect(pads, y_users).encode())
    print(f"gen_iomux: {len(pads)} pads, {n_sel} select fields ({2 * n_sel} bits), "
          f"{sum(len(p['codes']) for p in pads)} functions placed")


if __name__ == "__main__":
    main()
