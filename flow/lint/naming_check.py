#!/usr/bin/env python3
"""
naming_check.py -- enforce QNSC_RTL_Design_Naming_Rule V1.0 on RTL written here.

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

    module name       m_qnsc_<function> | m_qnsc_wrap_<ip> | qnsc_<function>
    port direction    i_ | o_ | io_ prefix
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

REPO = Path(__file__).resolve().parent.parent.parent
DEFAULT_SCOPE = REPO / "design"
CI = bool(os.environ.get("GITHUB_ACTIONS"))
IGNORE = re.compile(r"//\s*naming-check:\s*ignore")

# --- rule patterns ---------------------------------------------------------
MODULE_OK = re.compile(r"^(?:m_qnsc_wrap_[a-z0-9_]+|m_qnsc_[a-z0-9_]+|qnsc_[a-z0-9_]+)$")
PORT_OK = re.compile(r"^(?:i_|o_|io_)[a-z0-9_]+$")
PARAM_OK = re.compile(r"^(?:P_|C_|S_)[A-Z0-9_]+$")
INST_OK = re.compile(r"^u_[a-z0-9_]+$")
SIGNAL_OK = re.compile(r"^(?:r_|w_|mem_)[a-z0-9_]+$")

CAMEL = re.compile(r"[a-z][A-Z]|[A-Z]{2,}[a-z]")
BAD_INDEX = re.compile(r"[a-z]\d+(?:_|$)")          # timer0  ->  timer_0
BAD_ACTIVE_LOW = re.compile(r"\b(?:rstn|resetn|reset_b|rst_bar)\b")
VOCAB = {
    "irq": "int", "interrupt": "int", "clock": "clk", "reset": "rst",
    "config": "cfg", "debug": "dbg", "power": "pwr", "memory": "mem",
    "peripheral": "peri", "multiplexer": "mux", "analog": "ana",
}

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
    return re.sub(r"\d*'[sS]?[bodhBODH][0-9a-fA-FxXzZ?_]+",
                  lambda m: " " * len(m.group(0)), text)


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

    # ---- 2.1 module name -------------------------------------------------
    for m in re.finditer(r"^\s*module\s+([A-Za-z_]\w*)", src, re.M):
        name, ln = m.group(1), lineno_of(m.start(1))
        if not MODULE_OK.match(name):
            add(ln, "2.1 module",
                f"module '{name}' must be m_qnsc_<function>, m_qnsc_wrap_<ip_module> "
                f"or qnsc_<function>")

    # ---- 1.2 / 3.x port direction prefix ---------------------------------
    # ANSI port declarations: input/output/inout ... name
    for m in re.finditer(
        r"^\s*(input|output|inout)\b([^;,)\n]*?)\b([A-Za-z_]\w*)\s*(?:,|\)|;|$)",
        src, re.M
    ):
        name, ln = m.group(3), lineno_of(m.start(3))
        if name in KEYWORDS:
            continue
        if not PORT_OK.match(name):
            add(ln, "1.2 port prefix",
                f"port '{name}' must start with i_, o_ or io_")

    # ---- 2.4 parameter / constant / state --------------------------------
    for m in re.finditer(r"^\s*(?:localparam|parameter)\b[^=;]*?\b([A-Za-z_]\w*)\s*=",
                         src, re.M):
        name, ln = m.group(1), lineno_of(m.start(1))
        if name in KEYWORDS:
            continue
        if not PARAM_OK.match(name):
            add(ln, "2.4 parameter",
                f"'{name}' must be P_<FUNCTION> (parameter), C_<FUNCTION> (constant) "
                f"or S_<STATE> (FSM state), uppercase")

    # ---- 2.2 instance name ----------------------------------------------
    # <ModuleName> [#(...)] <inst> ( ... )   at statement level
    for m in re.finditer(
        r"^[ \t]*([A-Za-z_]\w*)[ \t]*(?:#\s*\([^;]*?\)[ \t]*)?([A-Za-z_]\w*)[ \t]*\(",
        src, re.M
    ):
        mod, inst = m.group(1), m.group(2)
        if mod in KEYWORDS or inst in KEYWORDS:
            continue
        ln = lineno_of(m.start(2))
        if not INST_OK.match(inst):
            add(ln, "2.2 instance",
                f"instance '{inst}' of '{mod}' must be u_<function>[_<index>]")

    # ---- 2.3 / 2.5 internal signal ---------------------------------------
    for m in re.finditer(
        r"^\s*(?:reg|wire|logic)\b(?:\s+(?:signed|unsigned))?"
        r"(?:\s*\[[^\]]*\])*\s*([A-Za-z_]\w*)",
        src, re.M
    ):
        name, ln = m.group(1), lineno_of(m.start(1))
        if name in KEYWORDS:
            continue
        # a declaration that is also a port was already checked above
        if PORT_OK.match(name):
            continue
        if not SIGNAL_OK.match(name):
            add(ln, "2.3 signal",
                f"'{name}' must be r_<function> if registered, w_<function> if "
                f"combinational, or mem_<function> if a memory array")

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

        seen.add((ln, name))

        if CAMEL.search(name) and not PARAM_OK.match(name):
            add(ln, "1.1 case",
                f"'{name}' uses mixed case; identifiers are lowercase with _ "
                f"(uppercase only for P_/C_/S_)")
        if BAD_ACTIVE_LOW.search(name):
            add(ln, "1.3 active low",
                f"'{name}' -- active low is _n after the meaning, as in i_rst_n_sys")
        if BAD_INDEX.search(name) and not PARAM_OK.match(name):
            add(ln, "1.4 index",
                f"'{name}' -- a numeric index takes an underscore, as in timer_0")
        low = name.lower()
        for bad, good in VOCAB.items():
            if re.search(rf"(?:^|_){bad}(?:_|$)", low):
                add(ln, "1.5 vocabulary",
                    f"'{name}' uses '{bad}'; the project term is '{good}'")
                break
    return out


def collect(paths: list[Path]) -> list[Path]:
    files: list[Path] = []
    for p in paths:
        if p.is_file() and p.suffix in (".sv", ".v"):
            files.append(p)
        elif p.is_dir():
            for f in sorted(p.rglob("*")):
                if f.suffix in (".sv", ".v") and "vendor" not in f.parts:
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
          f"QNSC_RTL_Design_Naming_Rule V1.0")
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
    print("\nRule: DM/RULES/FE/Release/QNSC_RTL_Design_Naming_Rule.pdf "
          "(MCU_guide_ws), section 4.3 Enforcement Checklist.")
    print("A deliberate exception needs a trailing '// naming-check: ignore -- <reason>'.")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
