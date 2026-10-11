#!/usr/bin/env python3
"""
module_rules.py -- what an IP module, a wrapper and an emacs-generated file may contain.

The rules, from design/README.md ("Shared numbers: who may use qnsc_pkg" and
"Writing a wrapper with emacs verilog-mode"). The reasons are Tam's: verilog-mode's
parser has trouble with import, so a wrapper takes no configuration from a package;
and the IP owner controls the IP's configuration, written as fixed values in the
wrapper, while design/top only connects -- clearer, and it holds at any depth of
hierarchy.

  1. NO-PKG     An IP module does not use qnsc_pkg -- no import, no qnsc_pkg::.
                IP is every block not listed as integration in module_rules.yml,
                plus design/common. An IP that knows the chip cannot be reused in
                another chip, and a chip value inside it is a second copy of the
                contract.
  2. NO-PARAM   A wrapper (m_qnsc_wrap_*) declares no parameter, in its #( ) header
                or as a `parameter` in its body. The IP owner fixes the IP's
                configuration inside the wrapper; design/top only connects. An empty
                #() is accepted, as in the I2C demo; a localparam is a fixed value
                and is accepted.
  3. WRAP-NAME  The wrapper of design/<block>, its boundary, is m_qnsc_wrap_<block>:
                named after the block (its name in the contract), not the IP module,
                so the name stays when the IP is replaced. A block built from several
                IPs may nest one wrapper per IP inside it, named
                m_qnsc_wrap_<block>_<part> (design/cpu: m_qnsc_wrap_cpu around
                m_qnsc_wrap_cpu_ibex and m_qnsc_wrap_cpu_cpu2axi). Two configurations
                of one IP are two blocks (design/isram, design/dsram).
  4. NO-IMPORT  A wrapper file, and any file expanded by emacs verilog-mode (it
                contains an AUTO comment), has no import statement. verilog-mode does
                not read packages, so an item is named pkg::item where it is used,
                visible to the reader and to every tool; an integration module
                generated with emacs names a constant as qnsc_pkg::C_X at the
                connection.
  5. FLAT-PORT  The boundary of a block -- its wrapper m_qnsc_wrap_<block>[_<part>],
                or the top m_qnsc_<block> of a block designed here -- has flat
                ports: type `logic` (or wire/reg/bit), width a number. No struct or
                other package type, no width named by a parameter or an imported
                constant. An integration block may write a width as qnsc_pkg::C_X.
                verilog-mode copies these ports into design/top: a package type
                is dropped or mis-connected there, a name is copied unresolved.
                Inside the wrapper the IP's own package may be used as pkg::item
                (ibex_pkg::RV32MFast, an internal wire of the IP's struct type).
  6. NO-OVERRIDE  Nobody sets a wrapper's configuration from outside: no
                `defparam`, and no #( ) on an m_qnsc_wrap_* instance. design/top
                only connects.

SCOPE   design/**/rtl/**/*.sv, *.v   (vendor/ and the generated qnsc_pkg.sv excluded)
OUTPUT  GitHub Actions annotations in CI, so a violation lands inline on the diff

A deliberate exception needs a reason on the line:

    import foo_pkg::*;  // module-rules: ignore -- <reason>

Usage:
    python3 flow/lint/module_rules.py                  # whole design/ tree
    python3 flow/lint/module_rules.py design/pwm       # one block
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")

REPO = Path(__file__).resolve().parent.parent.parent
DESIGN = REPO / "design"
RULES = Path(__file__).resolve().parent / "module_rules.yml"
GENERATED_PKG = DESIGN / "top" / "rtl" / "qnsc_pkg.sv"
CI = bool(os.environ.get("GITHUB_ACTIONS"))
IGNORE = re.compile(r"//\s*module-rules:\s*ignore")

AUTO = re.compile(r"/\*\s*AUTO[A-Z_]*")
IMPORT = re.compile(r"\bimport\s+\w+\s*::")
QNSC_PKG = re.compile(r"\bqnsc_pkg\b")
WRAP_NAME = re.compile(r"\bmodule\s+(?P<name>m_qnsc_wrap_\w+)")
BODY_PARAM = re.compile(r"(?<![\w`])parameter\b")
MODULE = re.compile(r"\bmodule\s+(?P<name>m_qnsc_\w+)")
PORT_KEYWORDS = {"input", "output", "inout", "logic", "wire", "reg", "bit",
                 "signed", "unsigned", "var", "tri"}
QNSC_CONST = re.compile(r"\bqnsc_pkg\s*::\s*C_\w+")
DEFPARAM = re.compile(r"\bdefparam\b")
WRAP_INST_PARAM = re.compile(r"\b(m_qnsc_wrap_\w+)\s*#\s*\(")
# module <name> [import ...;] #( ... ) (
WRAP_HEADER = re.compile(
    r"\bmodule\s+(?P<name>m_qnsc_wrap_\w+)\s*(?:import[^;]*;\s*)*#\s*\(",
    re.S)


def strip_comments(text: str) -> str:
    """Blank out comments, keeping every newline so line numbers stay right."""
    text = re.sub(r"/\*.*?\*/", lambda m: re.sub(r"[^\n]", " ", m.group(0)),
                  text, flags=re.S)
    return re.sub(r"//[^\n]*", lambda m: " " * len(m.group(0)), text)


def paren_body(src: str, open_pos: int) -> str:
    """Text between the '(' at open_pos and its matching ')'."""
    depth = 0
    for i in range(open_pos, len(src)):
        if src[i] == "(":
            depth += 1
        elif src[i] == ")":
            depth -= 1
            if depth == 0:
                return src[open_pos + 1:i]
    return src[open_pos + 1:]


class Finding:
    __slots__ = ("path", "line", "rule", "msg")

    def __init__(self, path: Path, line: int, rule: str, msg: str):
        self.path, self.line, self.rule, self.msg = path, line, rule, msg

    def emit(self) -> None:
        try:
            rel = self.path.relative_to(REPO)
        except ValueError:
            rel = self.path
        if CI:
            print(f"::error file={rel},line={self.line},title={self.rule}::{self.msg}")
        else:
            print(f"  {rel}:{self.line}  [{self.rule}]  {self.msg}")


def block_of(path: Path) -> str:
    rel = path.resolve().relative_to(DESIGN.resolve())
    return rel.parts[0]


def port_list(src: str, name_end: int) -> tuple[int, str] | None:
    """(offset, text) of the ANSI port list of the module whose name ends at name_end."""
    pos = name_end
    while True:
        m = re.compile(r"\s*import\s[^;]*;").match(src, pos)
        if not m:
            break
        pos = m.end()
    m = re.compile(r"\s*#\s*\(").match(src, pos)
    if m:
        pos = m.end() - 1 + len(paren_body(src, m.end() - 1)) + 2
    m = re.compile(r"\s*\(").match(src, pos)
    if not m:
        return None
    return m.end(), paren_body(src, m.end() - 1)


def split_top(text: str) -> list[tuple[int, str]]:
    """Split on commas outside brackets; (offset, item) pairs."""
    out, depth, start = [], 0, 0
    for i, c in enumerate(text):
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif c == "," and depth == 0:
            out.append((start, text[start:i]))
            start = i + 1
    out.append((start, text[start:]))
    return out


def port_problem(item: str, integration_block: bool) -> str | None:
    """Why a port declaration is not flat, or None."""
    text = QNSC_CONST.sub("0", item) if integration_block else item
    if "::" in text:
        return "a package type or constant"
    if "." in re.sub(r"\d+\.\d+", "", text):
        return "an interface port"
    ranges = re.findall(r"\[([^\]]*)\]", text)
    for r in ranges:
        r = re.sub(r"\$\w+", "", r)                      # $clog2(16)
        r = re.sub(r"\d*'[sS]?[bBoOdDhH][0-9a-fA-F_xXzZ]+", "0", r)
        if re.search(r"[A-Za-z_]\w*", r):
            return f"the width [{r.strip()}] is a name, not a number"
    words = [w for w in re.findall(r"[A-Za-z_]\w*", re.sub(r"\[[^\]]*\]", " ", text))
             if w not in PORT_KEYWORDS]
    if len(words) > 1:
        return f"the type {words[0]}"
    return None


def check_file(path: Path, integration: set[str]) -> list[Finding]:
    raw = path.read_text(errors="ignore")
    raw_lines = raw.splitlines()
    src = strip_comments(raw)
    block = block_of(path)
    is_ip = block not in integration
    is_emacs = bool(AUTO.search(raw))
    is_wrapper = bool(WRAP_NAME.search(src))
    out: list[Finding] = []

    def lineno(pos: int) -> int:
        return src.count("\n", 0, pos) + 1

    def add(pos: int, rule: str, msg: str) -> None:
        ln = lineno(pos)
        if ln <= len(raw_lines) and IGNORE.search(raw_lines[ln - 1]):
            return
        out.append(Finding(path, ln, rule, msg))

    if is_ip:
        for m in QNSC_PKG.finditer(src):
            add(m.start(), "NO-PKG",
                f"'{block}' is IP, and IP does not use qnsc_pkg. Write the IP's own "
                "configuration as a fixed value; take a chip value on an i_cfg_* "
                "port that design/top ties; tag a structural value with "
                "'// contract: <key>' (design/README.md)")

    if is_emacs or is_wrapper:
        for m in IMPORT.finditer(src):
            add(m.start(), "NO-IMPORT",
                "a wrapper, or a file expanded by emacs verilog-mode, has no import: "
                "verilog-mode does not read packages. Name the item as pkg::item "
                "where it is used, or write a number (design/README.md)")

    if is_wrapper:
        headers = []  # (start, end) of each wrapper #( ) header
        for h in WRAP_HEADER.finditer(src):
            start = h.end() - 1
            headers.append((start, start + len(paren_body(src, start)) + 1))
        for m in BODY_PARAM.finditer(src):
            if any(a <= m.start() <= b for a, b in headers):
                continue  # inside the #( ) header: reported once by the header check
            add(m.start(), "NO-PARAM",
                "a wrapper declares no parameter: write a fixed value, or a "
                "localparam (design/README.md)")

    for m in MODULE.finditer(src):
        name = m.group("name")
        boundary = (name == f"m_qnsc_{block}" or name == f"m_qnsc_wrap_{block}"
                    or name.startswith(f"m_qnsc_wrap_{block}_"))
        if not boundary:
            continue
        pl = port_list(src, m.end())
        if not pl:
            continue
        base, body = pl
        for off, item in split_top(body):
            if not item.strip():
                continue
            why = port_problem(item, not is_ip)
            if why:
                lead = len(item) - len(item.lstrip())
                add(base + off + lead, "FLAT-PORT",
                    f"port '{' '.join(item.split())}' of {name}: {why}. A block's "
                    "boundary has flat ports, `logic [N-1:0]` with N a number "
                    "(tag it // contract: <key> when the contract fixes it); "
                    "design/top's verilog-mode copies them (design/README.md)")

    for m in DEFPARAM.finditer(src):
        add(m.start(), "NO-OVERRIDE",
            "no defparam: the IP owner fixes the configuration inside the wrapper, "
            "design/top only connects (design/README.md)")
    for m in WRAP_INST_PARAM.finditer(src):
        if src[:m.start()].rstrip().endswith("module"):
            continue  # the wrapper's own header, not an instance
        add(m.start(), "NO-OVERRIDE",
            f"{m.group(1)} is instantiated with #( ): a wrapper has no parameter "
            "to set, design/top only connects (design/README.md)")

    for m in WRAP_NAME.finditer(src):
        name = m.group("name")
        if name != f"m_qnsc_wrap_{block}" and not name.startswith(f"m_qnsc_wrap_{block}_"):
            add(m.start(), "WRAP-NAME",
                f"a wrapper in design/{block} is m_qnsc_wrap_{block}, or "
                f"m_qnsc_wrap_{block}_<part> for a wrapper nested inside it (named after "
                f"the block, not the IP module), not {name} (design/README.md, Naming)")

    for m in WRAP_HEADER.finditer(src):
        body = paren_body(src, m.end() - 1)
        if body.strip():
            add(m.start(), "NO-PARAM",
                f"wrapper {m.group('name')} declares a parameter. The IP owner fixes "
                "the configuration inside the wrapper; design/top only connects "
                "(design/README.md)")

    return out


def collect(paths: list[Path]) -> list[Path]:
    files: list[Path] = []
    for p in paths:
        if p.is_file() and p.suffix in (".sv", ".v"):
            files.append(p)
        elif p.is_dir():
            for f in sorted(p.rglob("*")):
                if (f.suffix in (".sv", ".v")
                        and "rtl" in f.parts
                        and "vendor" not in f.parts
                        and f.resolve() != GENERATED_PKG.resolve()):
                    files.append(f)
    return files


def main(argv: list[str]) -> int:
    integration = set(yaml.safe_load(RULES.read_text())["integration"])
    targets = [Path(a).resolve() for a in argv[1:]] or [DESIGN]
    files = collect(targets)
    if not files:
        print("module-rules: no RTL under design/ yet -- nothing to check")
        return 0

    findings: list[Finding] = []
    for f in files:
        findings.extend(check_file(f, integration))

    print(f"module-rules: {len(files)} file(s) checked; integration blocks: "
          f"{', '.join(sorted(integration))}")
    if not findings:
        print("module-rules: clean")
        return 0
    for f in findings:
        f.emit()
    print(f"\nmodule-rules: {len(findings)} violation(s). See design/README.md,")
    print("'Shared numbers: who may use qnsc_pkg'.")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
