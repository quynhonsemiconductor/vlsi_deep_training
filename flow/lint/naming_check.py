#!/usr/bin/env python3
"""
naming_check.py -- enforce QNSC_RTL_Design_Naming_Rule V1.2 on RTL written here.

The rule is mandatory and mechanical, so it is checked by a deterministic script
rather than by review or by a language model: the same input must always give the
same verdict, because this runs as a required status check and a gate that
sometimes passes and sometimes fails on identical input is worse than no gate.

SCOPE -- this checks only code written in this project:

    design/**/rtl/**/*.sv, *.v          checked
    vendor/**                           NOT checked, and must never be edited

Vendored IP follows its upstream's conventions (OpenTitan's `data_i`/`data_o`,
pulp's `clk_i`) and is not ours to rename. Section 4.3 of the rule applies to
"RTL before it is committed" -- that is our RTL.

WHAT IS CHECKED (section 4.3, Enforcement Checklist)

    module name       m_qnsc_<function> | m_qnsc_wrap_<block> | qnsc_<function>
    chip top          m_qnsc_top, m_qnsc_chip, in design/top/rtl/ only
    package           qnsc_<function>_pkg
    file              one module/package/interface per file, named after it
    port direction    i_ | o_ | io_ prefix, matching the declared direction
    clock, reset      i_clk_<domain>, i_rst_n_<domain>
    bus               <i|o>_bus_apb[_<port>]_<sig>, <i|o>_bus_axi[_<port>]_<ch>_<sig>
    type              <function>_t; enum members S_<STATE> or C_<FUNCTION>
    parameter         P_<UPPER>          constant C_<UPPER>   FSM state S_<UPPER>
    instance          u_<function>[_<index>]
    internal signal   r_<function> registered, w_<function> combinational
    memory array      mem_<function>
    identifier case   lowercase and underscore only, no CamelCase
    numeric index     timer_0, never timer0
    active low        _n after the meaning, never rstn/resetn/reset_b/rst_bar
    vocabulary        int not irq, clk not clock, rst not reset, cfg not config

Output is GitHub Actions annotations when running in CI, so a violation appears
inline on the pull request diff at the offending line. Locally it prints the same
information as plain text.

A line may be exempted with a trailing comment stating why:

    logic clk_i;  // naming-check: ignore -- port of a vendored module

Usage:
    python3 flow/lint/naming_check.py                  # whole design/ tree
    python3 flow/lint/naming_check.py <file|dir> ...   # specific paths
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
RULES_FILE = Path(__file__).resolve().parent / "naming_rules.yml"
CI = bool(os.environ.get("GITHUB_ACTIONS"))

# --- rules, loaded from naming_rules.yml -----------------------------------
# The patterns live in that file rather than here so that a new revision of
# QNSC_RTL_Design_Naming_Rule is an edit to data, not a patch to a regex only
# its author can read -- and so a reviewer can compare the file line by line
# with section 4.3 of the rule document.
RULES = yaml.safe_load(RULES_FILE.read_text())

DEFAULT_SCOPE = REPO / RULES["scope"]["include"][0]
EXTENSIONS = tuple(RULES["scope"]["extensions"])
EXCLUDE_PARTS = set(RULES["scope"]["exclude_path_parts"])
IGNORE = re.compile(r"//\s*" + re.escape(RULES["scope"]["ignore_comment"]))

_ID = RULES["identifiers"]
MODULE_OK = re.compile(_ID["module"]["pattern"])
PORT_OK = re.compile(_ID["port"]["pattern"])
PARAM_OK = re.compile(_ID["parameter"]["pattern"])
INST_OK = re.compile(_ID["instance"]["pattern"])
SIGNAL_OK = re.compile(_ID["signal"]["pattern"])
DIR_PREFIX = _ID["port_direction"]["prefix"]
CLOCK = (re.compile(_ID["clock"]["applies_to"]), re.compile(_ID["clock"]["pattern"]))
RESET = (re.compile(_ID["reset"]["applies_to"]), re.compile(_ID["reset"]["pattern"]))
BUS = (re.compile(_ID["bus"]["applies_to"]), re.compile(_ID["bus"]["pattern"]))
TYPE_OK = re.compile(_ID["type"]["pattern"])
ENUM_OK = re.compile(_ID["enum_member"]["pattern"])
PACKAGE_OK = re.compile(_ID["package"]["pattern"])
CHIP_TOP = RULES["chip_top"]

_LX = RULES["lexical"]
CAMEL = re.compile(_LX["mixed_case"]["forbid_pattern"])
BAD_ACTIVE_LOW = re.compile(_LX["active_low"]["forbid_pattern"])
BAD_INDEX = re.compile(_LX["numeric_index"]["forbid_pattern"])
VOCAB = RULES["vocabulary"]["replace"]


def _msg(section: str, key: str) -> str:
    """The message text for a rule, from the config."""
    d = RULES[section][key] if section != "identifiers" else RULES[section][key]
    return " ".join(str(d["message"]).split())


def _rule(section: str, key: str) -> str:
    return RULES[section][key]["rule"]

# --- SystemVerilog keywords that are not identifiers we own ---------------
KEYWORDS = {
    "module", "endmodule", "input", "output", "inout", "wire", "reg", "logic",
    "parameter", "localparam", "assign", "always", "always_ff", "always_comb",
    "always_latch", "begin", "end", "if", "else", "case", "endcase", "for",
    "while", "generate", "endgenerate", "genvar", "typedef", "enum", "struct",
    "union", "packed", "signed", "unsigned", "function", "endfunction", "task",
    "endtask", "return", "package", "endpackage", "import", "export", "initial",
    "final", "assert", "assume", "cover", "property", "endproperty", "sequence",
    "posedge", "negedge", "default", "casez", "casex", "unique", "priority",
    "integer", "int", "bit", "byte", "shortint", "longint", "real", "time",
    "string", "const", "static", "automatic", "interface", "endinterface",
    "modport", "clocking", "endclocking", "class", "endclass", "extends",
    "virtual", "pure", "extern", "forever", "repeat", "do", "break", "continue",
    "disable", "fork", "join", "wait", "sv", "tri", "supply0", "supply1",
}


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
            print(f"::error file={rel},line={self.line},title=naming {self.rule}::{self.msg}")
        else:
            print(f"  {rel}:{self.line}  [{self.rule}]  {self.msg}")


def strip_comments(text: str) -> str:
    """Blank out comments but keep line count and column positions."""
    text = re.sub(r"/\*.*?\*/", lambda m: re.sub(r"[^\n]", " ", m.group(0)),
                  text, flags=re.S)
    return re.sub(r"//[^\n]*", lambda m: " " * len(m.group(0)), text)


def strip_literals(text: str) -> str:
    """Blank out sized literals so 2'd0 does not read as an identifier 'd0'.

    Without this, every 32'hDEAD and 1'b0 in the design would be reported as a
    mixed-case or bad-index identifier.
    """
    text = re.sub(r"\d*'[sS]?[bodhBODH][0-9a-fA-FxXzZ?_]+",
                  lambda m: " " * len(m.group(0)), text)
    # and strings: the text of a $display is not an identifier
    return re.sub(r'"(?:[^"\\\n]|\\.)*"', lambda m: " " * len(m.group(0)), text)


def blank(text: str, start: int, end: int) -> str:
    """text with [start, end) replaced by spaces, newlines kept."""
    return text[:start] + re.sub(r"[^\n]", " ", text[start:end]) + text[end:]


def match_close(text: str, pos: int) -> int:
    """Index of the bracket closing the one at text[pos]."""
    pairs = {"(": ")", "[": "]", "{": "}"}
    stack = []
    for i in range(pos, len(text)):
        c = text[i]
        if c in pairs:
            stack.append(pairs[c])
        elif stack and c == stack[-1]:
            stack.pop()
            if not stack:
                return i
    return len(text) - 1


def split_top(text: str, base: int) -> list[tuple[str, int]]:
    """Split text at commas outside brackets; each piece with its offset."""
    out, depth, start = [], 0, 0
    for i, c in enumerate(text):
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif c == "," and depth == 0:
            out.append((text[start:i], base + start))
            start = i + 1
    out.append((text[start:], base + start))
    return out


DIRECTIONS = ("input", "output", "inout")
# a declarator: the name, then unpacked dimensions or an initialiser
DECL_NAME = re.compile(r"([A-Za-z_]\w*)\s*(?:\[[^\]]*\]\s*)*(?:=.*)?$", re.S)


def declared_names(piece: str, base: int) -> list[tuple[str, int]]:
    """The name a declaration piece declares: `logic [3:0] r_a = '0` -> r_a."""
    m = DECL_NAME.search(piece.strip()) if piece.strip() else None
    if not m:
        return []
    off = piece.find(piece.strip()) + m.start(1)
    return [(m.group(1), base + off)]


def ansi_ports(src: str):
    """(direction, name, offset) of every port in the ANSI header of each module.

    A port without a direction keyword takes the previous one, as SystemVerilog
    does (`input logic i_a, i_b`).
    """
    for m in re.finditer(r"^\s*module\s+\w+\s*(?:import[^;]*;\s*)*", src, re.M):
        i = m.end()
        if src[i:i + 1] == "#":
            j = src.find("(", i)
            i = match_close(src, j) + 1
        j = src.find("(", i)
        if j < 0 or src[i:j].strip():
            continue
        k = match_close(src, j)
        direction = None
        for piece, off in split_top(src[j + 1:k], j + 1):
            w = re.match(r"\s*(input|output|inout)\b", piece)
            if w:
                direction = w.group(1)
            for name, pos in declared_names(piece, off):
                if name not in KEYWORDS and direction:
                    yield direction, name, pos


def rel_dir(path: Path) -> str:
    try:
        return path.parent.relative_to(REPO).as_posix()
    except ValueError:
        return path.parent.as_posix()


def check_file(path: Path) -> list[Finding]:
    raw = path.read_text(errors="ignore")
    raw_lines = raw.splitlines()
    src = strip_literals(strip_comments(raw))
    out: list[Finding] = []

    def exempt(lineno: int) -> bool:
        return lineno <= len(raw_lines) and bool(IGNORE.search(raw_lines[lineno - 1]))

    def add(lineno: int, rule: str, msg: str) -> None:
        if not exempt(lineno):
            out.append(Finding(path, lineno, rule, msg))

    def lineno_of(pos: int) -> int:
        return src.count("\n", 0, pos) + 1

    # ---- 2.1 module and package name, chip top; 2.7 file ------------------
    units = []
    for m in re.finditer(r"^\s*(module|package|interface)\s+([A-Za-z_]\w*)", src, re.M):
        kind, name, ln = m.group(1), m.group(2), lineno_of(m.start(2))
        units.append((kind, name, ln))
        if kind == "package":
            if not PACKAGE_OK.match(name):
                add(ln, _rule("identifiers", "package"),
                    f"package '{name}' {_msg('identifiers', 'package')}")
        elif not MODULE_OK.match(name):
            add(ln, _rule("identifiers", "module"),
                f"{kind} '{name}' {_msg('identifiers', 'module')}")
        in_top = rel_dir(path) == CHIP_TOP["directory"]
        if kind == "module" and (name in CHIP_TOP["modules"]) != in_top:
            add(ln, CHIP_TOP["rule"], f"module '{name}': {CHIP_TOP['message']}")
    stem = path.name.split(".")[0]
    if len(units) > 1:
        add(units[1][2], RULES["files"]["rule"],
            f"{len(units)} design units in one file: {RULES['files']['message']}")
    if units and units[0][1] != stem:
        add(units[0][2], RULES["files"]["rule"],
            f"{units[0][0]} '{units[0][1]}' in {path.name}: {RULES['files']['message']}")

    # ---- 1.2 / 3.1 / 3.2 / 3.3 / 3.4 ports --------------------------------
    # ANSI header ports, and non-ANSI or task/function declarations
    # (`input logic a, b;`), every name of a list
    ports = list(ansi_ports(src))
    for m in re.finditer(r"^[ \t]*(input|output|inout)\b([^;()]*);", src, re.M):
        for piece, off in split_top(m.group(2), m.start(2)):
            for name, pos in declared_names(piece, off):
                if name not in KEYWORDS:
                    ports.append((m.group(1), name, pos))
    port_names = set()
    for direction, name, pos in ports:
        port_names.add(name)
        ln = lineno_of(pos)
        if not PORT_OK.match(name):
            add(ln, _rule("identifiers", "port"),
                f"port '{name}' {_msg('identifiers', 'port')}")
            continue
        if not name.startswith(DIR_PREFIX[direction]):
            add(ln, _rule("identifiers", "port_direction"),
                f"{direction} '{name}': {_msg('identifiers', 'port_direction')} "
                f"({DIR_PREFIX[direction]})")
        for key, (applies, ok) in (("clock", CLOCK), ("reset", RESET), ("bus", BUS)):
            if applies.search(name) and not ok.match(name):
                add(ln, _rule("identifiers", key), f"port '{name}' {_msg('identifiers', key)}")

    # ---- 2.4 parameter / constant / state --------------------------------
    for m in re.finditer(r"^\s*(?:localparam|parameter)\b[^=;]*?\b([A-Za-z_]\w*)\s*=",
                         src, re.M):
        name, ln = m.group(1), lineno_of(m.start(1))
        if name in KEYWORDS:
            continue
        if not PARAM_OK.match(name):
            add(ln, _rule("identifiers", "parameter"),
                f"'{name}' {_msg('identifiers', 'parameter')}")

    # ---- 2.2 instance name ----------------------------------------------
    # <ModuleName> [#(...)] <inst> ( ... )   at statement level
    # At least one blank must separate the module name (or its #(...) block)
    # from the instance name. Without it, backtracking split `if (` into a
    # module `i` and an instance `f`.
    for m in re.finditer(
        r"^[ \t]*([A-Za-z_]\w*)(?:[ \t]*#\s*\([^;]*?\))?[ \t]+([A-Za-z_]\w*)[ \t]*\(",
        src, re.M
    ):
        mod, inst = m.group(1), m.group(2)
        if mod in KEYWORDS or inst in KEYWORDS:
            continue
        ln = lineno_of(m.start(2))
        if not INST_OK.match(inst):
            add(ln, _rule("identifiers", "instance"),
                f"instance '{inst}' of '{mod}' {_msg('identifiers', 'instance')}")

    # ---- 2.6 types and enum members ---------------------------------------
    body = src                       # src with struct/union/enum bodies blanked
    for m in re.finditer(r"\b(struct|union|enum)\b[^{;]*\{", src):
        o = m.end() - 1
        c = match_close(src, o)
        if m.group(1) == "enum":
            for piece, off in split_top(src[o + 1:c], o + 1):
                for name, pos in declared_names(piece, off):
                    if not ENUM_OK.match(name):
                        add(lineno_of(pos), _rule("identifiers", "enum_member"),
                            f"'{name}' -- {_msg('identifiers', 'enum_member')}")
        body = blank(body, o, c + 1)  # a member of a struct is a field, not a signal
    # a variable local to a function or task is not a signal of the module (2.3)
    for m in re.finditer(r"\b(function|task)\b.*?\bend\1\b", body, re.S):
        body = blank(body, m.start(), m.end())
    for m in re.finditer(r"\btypedef\b[^;]*?([A-Za-z_]\w*)\s*(?:\[[^\]]*\]\s*)*;", body):
        name = m.group(1)
        if not TYPE_OK.match(name):
            add(lineno_of(m.start(1)), _rule("identifiers", "type"),
                f"type '{name}' {_msg('identifiers', 'type')}")

    # ---- 2.3 / 2.5 internal signal ---------------------------------------
    # every name of a declaration list, of a built-in type or of a type _t
    for m in re.finditer(
        r"^[ \t]*(?:(?:reg|wire|logic|bit)\b(?:\s+(?:signed|unsigned))?"
        r"|(?:\w+::)?[a-z]\w*_t\b)((?:\s*\[[^\]]*\])*)([^;]*);",
        body, re.M
    ):
        if re.match(r"\s*\(", m.group(2)):          # a cast or a call, not a declaration
            continue
        for piece, off in split_top(m.group(2), m.start(2)):
            for name, pos in declared_names(piece, off):
                if name in KEYWORDS or name in port_names:
                    continue
                if not SIGNAL_OK.match(name):
                    add(lineno_of(pos), _rule("identifiers", "signal"),
                        f"'{name}' {_msg('identifiers', 'signal')}")

    # ---- 1.1 / 1.3 / 1.4 / 1.5 lexical rules over all identifiers --------
    seen: set[tuple[int, str]] = set()
    for m in re.finditer(r"[A-Za-z_]\w*", src):
        name, ln = m.group(0), lineno_of(m.start())
        if name in KEYWORDS or (ln, name) in seen:
            continue

        # An identifier written after a dot is not ours to name: in
        #     ibex_top u_cpu_0 ( .irq_fast_i (o_int_fast) );
        # the left-hand `irq_fast_i` is the vendored module's port. Renaming it
        # would mean editing vendor/, which vendor_guard.sh forbids -- so
        # checking it here would put two CI checks in direct contradiction.
        # The same applies to struct and package member access.
        if m.start() > 0 and src[m.start() - 1] == ".":
            continue
        # Not ours either: a system function ($clog2), a macro (`APB_TYPEDEF_ALL)
        # and a package member (obi_pkg::ObiMinimalOptionalConfig) are named by
        # the language or by the vendored package that declares them.
        if m.start() > 0 and src[m.start() - 1] in "$`":
            continue
        if m.start() > 1 and src[m.start() - 2:m.start()] == "::":
            continue

        seen.add((ln, name))

        if CAMEL.search(name) and not PARAM_OK.match(name):
            add(ln, _rule("lexical", "mixed_case"),
                f"'{name}' {_msg('lexical', 'mixed_case')}")
        if BAD_ACTIVE_LOW.search(name):
            add(ln, _rule("lexical", "active_low"),
                f"'{name}' -- {_msg('lexical', 'active_low')}")
        if BAD_INDEX.search(name) and not PARAM_OK.match(name):
            add(ln, _rule("lexical", "numeric_index"),
                f"'{name}' -- {_msg('lexical', 'numeric_index')}")
        low = name.lower()
        for bad, good in VOCAB.items():
            if re.search(rf"(?:^|_){bad}(?:_|$)", low):
                add(ln, RULES["vocabulary"]["rule"],
                    f"'{name}' uses '{bad}'; "
                    f"{RULES['vocabulary']['message']} '{good}'")
                break
    return out


def collect(paths: list[Path]) -> list[Path]:
    files: list[Path] = []
    for p in paths:
        if p.is_file() and p.suffix in EXTENSIONS:
            files.append(p)
        elif p.is_dir():
            for f in sorted(p.rglob("*")):
                if f.suffix in EXTENSIONS and not (EXCLUDE_PARTS & set(f.parts)):
                    files.append(f)
    return files


def main(argv: list[str]) -> int:
    targets = [Path(a).resolve() for a in argv[1:]] or [DEFAULT_SCOPE]
    files = collect(targets)
    if not files:
        print("naming-check: no RTL under design/ yet -- nothing to check")
        return 0

    findings: list[Finding] = []
    for f in files:
        findings.extend(check_file(f))

    print(f"naming-check: {len(files)} file(s) checked against "
          f"{RULES['document']} V{RULES['version']}")
    if not findings:
        print("naming-check: clean")
        return 0

    for f in findings:
        f.emit()
    by_rule: dict[str, int] = {}
    for f in findings:
        by_rule[f.rule] = by_rule.get(f.rule, 0) + 1
    print(f"\nnaming-check: {len(findings)} violation(s)")
    for rule, n in sorted(by_rule.items()):
        print(f"  {n:4}  {rule}")
    print("\nRule: doc/rules/QNSC_RTL_Design_Naming_Rule.pdf, "
          "section 4.3 Enforcement Checklist.")
    print("A deliberate exception needs a trailing '// naming-check: ignore -- <reason>'.")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
