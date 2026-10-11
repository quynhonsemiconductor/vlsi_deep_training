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
                contains an AUTO comment), has no import statement. verilog-mode's
                parser does not resolve package declarations; an integration module
                generated with emacs names a constant as qnsc_pkg::C_X at the
                connection.
  5. NO-OWN-PKG A wrapper does not use a package written here (any package declared
                under design/), for a value, a width or a type. The configuration
                is a literal in the wrapper; a type the IP needs is declared in the
                wrapper (pulp: `AXI_TYPEDEF_ALL). A constant of the vendored IP's own
                package (ibex_pkg::RV32MFast) is the IP's own fixed value and is
                accepted. qnsc_pkg is covered by rule 1 and, in an integration
                block, allowed.
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
PKG_DECL = re.compile(r"^\s*package\s+(\w+)\s*;", re.M)
PKG_REF = re.compile(r"\b(\w+)\s*::")
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


def own_packages() -> set[str]:
    """Every package declared under design/ (written here, not vendored)."""
    names: set[str] = set()
    for f in DESIGN.rglob("*.sv"):
        names.update(PKG_DECL.findall(strip_comments(f.read_text(errors="ignore"))))
    return names


def check_file(path: Path, integration: set[str], own_pkgs: set[str]) -> list[Finding]:
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
                "verilog-mode's parser does not resolve packages. Write the IP's "
                "configuration as a literal (design/README.md)")

    if is_wrapper:
        seen: set[str] = set()
        for m in PKG_REF.finditer(src):
            pkg = m.group(1)
            if pkg == "qnsc_pkg" or pkg not in own_pkgs:
                continue
            ln = lineno(m.start())
            if (pkg, ln) in seen:
                continue
            seen.add((pkg, ln))
            add(m.start(), "NO-OWN-PKG",
                f"a wrapper takes nothing from {pkg}, a package written here: the "
                "IP owner writes the configuration as a literal in the wrapper, and "
                "declares the types the IP needs there (design/README.md)")
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

    own_pkgs = own_packages()
    findings: list[Finding] = []
    for f in files:
        findings.extend(check_file(f, integration, own_pkgs))

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
