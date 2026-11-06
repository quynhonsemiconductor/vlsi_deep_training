#!/usr/bin/env python3
"""
gen_axi_ports.py -- write the flat AXI4 ports of m_qnsc_wrap_sbus.src.sv.

S_BUS has 3 AXI slave ports and 3 AXI master ports of 45 signals each. They are ports
one signal at a time, named i_bus_axi_<s|m>_<n>_<channel>_<signal> (naming rule V1.2,
3.4), so emacs at TOP maps them to the IPs' own i_bus_axi_* / o_bus_axi_* ports. Inside
the block the crossbar still speaks packed structs (qnsc_sbus_pkg), so this script also
writes the assign lines between the flat ports and those structs.

It rewrites the two regions of the .src.sv between these marker pairs and nothing else:
    // BEGIN gen_axi_ports.py ports   ...   // END gen_axi_ports.py ports
    // BEGIN gen_axi_ports.py assigns ...   // END gen_axi_ports.py assigns

Usage: python gen_axi_ports.py [<m_qnsc_wrap_sbus.src.sv>]      (default: the file beside this one)
The widths below are checked against qnsc_sbus_pkg by the $bits checks in the .src.sv.
"""
from __future__ import annotations

import sys
from pathlib import Path

ADDR_W, DATA_W, USER_W = 32, 32, 1
SLV_ID_W = 1   # slave ports: the masters' ID
MST_ID_W = 3   # master ports: 1 + clog2(3)

# (name, width key, struct member path), per channel. "from_master" = driven by the master side.
# Width keys: a number, "BIT" (a scalar flag), or "ID" / "ADDR" / "DATA" / "STRB" / "USER".
AW = [("id", "ID"), ("addr", "ADDR"), ("len", 8), ("size", 3), ("burst", 2), ("lock", "BIT"), ("cache", 4),
      ("prot", 3), ("qos", 4), ("region", 4), ("atop", 6), ("user", "USER")]
W = [("data", "DATA"), ("strb", "STRB"), ("last", "BIT"), ("user", "USER")]
B = [("id", "ID"), ("resp", 2), ("user", "USER")]
AR = [("id", "ID"), ("addr", "ADDR"), ("len", 8), ("size", 3), ("burst", 2), ("lock", "BIT"), ("cache", 4),
      ("prot", 3), ("qos", 4), ("region", 4), ("user", "USER")]
R = [("id", "ID"), ("data", "DATA"), ("resp", 2), ("last", "BIT"), ("user", "USER")]

# One entry per signal: (flat suffix, width key, struct path under req/resp, driven by the master side?)
# The struct member of a channel field is <struct>.<chan>.<field>; a handshake is <struct>.<chan>_valid etc.
SIGNALS: list[tuple[str, object, str, bool]] = []
for chan, fields in (("aw", AW), ("w", W), ("b", B), ("ar", AR), ("r", R)):
    from_master = chan in ("aw", "w", "ar")
    struct = "req" if from_master else "resp"
    for name, width in fields:
        SIGNALS.append((f"{chan}_{name}", width, f"{struct}.{chan}.{name}", from_master))
    SIGNALS.append((f"{chan}_valid", "BIT", f"{struct}.{chan}_valid", from_master))
    # ready flows the other way
    SIGNALS.append((f"{chan}_ready", "BIT", f"{'resp' if from_master else 'req'}.{chan}_ready", not from_master))


def width_text(width, id_w: int) -> str:
    if width == "BIT":
        return ""  # a flag is a scalar, as in the CPU and DMA wrappers
    n = {"ID": id_w, "ADDR": ADDR_W, "DATA": DATA_W, "STRB": DATA_W // 8, "USER": USER_W}.get(width, width)
    return f"[{n - 1}:0]"


def ports() -> list[str]:
    """Port declarations, last one without a comma."""
    lines: list[str] = []
    groups = [("s", i, "slave", SLV_ID_W) for i in range(3)] + [("m", i, "master", MST_ID_W) for i in range(3)]
    names = {("s", 0): "SYSDBG (AXI_S0)", ("s", 1): "CPU, the CPU2AXI bridge (AXI_S1)", ("s", 2): "DMA (AXI_S2)",
             ("m", 0): "ROM (AXI_M0)", ("m", 1): "ISRAM, debug window and application (AXI_M1)",
             ("m", 2): "DSRAM (AXI_M2)"}
    for kind, idx, role, id_w in groups:
        lines.append(f"// ---- {role} port {kind}_{idx}: {names[(kind, idx)]}, ID {id_w} bit ----")
        for suffix, width, _path, from_master in SIGNALS:
            # S_BUS slave port: master-driven signals come in. S_BUS master port: they go out.
            is_input = from_master if kind == "s" else not from_master
            w = width_text(width, id_w)
            lines.append(f"{'input ' if is_input else 'output'} logic {w:<8}"
                         f"{'i' if is_input else 'o'}_bus_axi_{kind}_{idx}_{suffix},")
    lines[-1] = lines[-1].rstrip(",")
    return lines


def assigns() -> list[str]:
    lines: list[str] = []
    for kind, idx in [("s", 0), ("s", 1), ("s", 2), ("m", 0), ("m", 1), ("m", 2)]:
        lines.append(f"// ---- port {kind}_{idx} ----")
        for suffix, _w, path, from_master in SIGNALS:
            is_input = from_master if kind == "s" else not from_master
            struct, rest = path.split(".", 1)
            internal = f"w_axi_{kind}_{idx}_{struct}.{rest}"
            if is_input:
                lines.append(f"assign {internal} = i_bus_axi_{kind}_{idx}_{suffix};")
            else:
                lines.append(f"assign o_bus_axi_{kind}_{idx}_{suffix} = {internal};")
    return lines


def patch(text: str, tag: str, body: list[str]) -> str:
    begin, end = f"// BEGIN gen_axi_ports.py {tag}", f"// END gen_axi_ports.py {tag}"
    if text.count(begin) != 1 or text.count(end) != 1:
        raise SystemExit(f"gen_axi_ports: marker pair '{tag}' not found exactly once")
    head, rest = text.split(begin, 1)
    _old, tail = rest.split(end, 1)
    return head + begin + "\n" + "\n".join(body) + "\n" + end + tail


def main(argv: list[str]) -> int:
    path = Path(argv[1]) if len(argv) > 1 else Path(__file__).resolve().parent / "m_qnsc_wrap_sbus.src.sv"
    raw = path.read_bytes().decode("utf-8")
    crlf = "\r\n" in raw
    text = raw.replace("\r\n", "\n")
    text = patch(text, "ports", ports())
    text = patch(text, "assigns", assigns())
    path.write_bytes((text.replace("\n", "\r\n") if crlf else text).encode("utf-8"))
    print(f"gen_axi_ports: {len(ports())} port lines, {len(assigns())} assign lines -> {path.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
