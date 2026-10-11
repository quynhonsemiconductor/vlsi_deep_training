#!/usr/bin/env python3
"""
test_module_rules.py -- every rule of module_rules.py fires on its case and on nothing else.

Each case is a small file written into a temporary design/ tree; `make module-rules`
runs this first, so a change to a pattern that stops a rule firing fails before it
reaches a pull request.
"""
from __future__ import annotations

import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import module_rules as mr  # noqa: E402

INTEGRATION = {"top", "bus", "intmap", "iomux", "scrc"}
OWN = {"qnsc_cpu2axi_pkg"}

# (name, block, source, expected rules)
CASES = [
    ("header parameter", "pwm",
     "module m_qnsc_wrap_pwm #(parameter int W = 4) (input logic a); endmodule", ["NO-PARAM"]),
    ("empty #() accepted", "pwm",
     "module m_qnsc_wrap_pwm #() (input logic a); endmodule", []),
    ("body parameter", "pwm",
     "module m_qnsc_wrap_pwm (input logic a);\n  parameter int W = 4;\nendmodule", ["NO-PARAM"]),
    ("localparam accepted", "pwm",
     "module m_qnsc_wrap_pwm (input logic a);\n  localparam int W = 4;\nendmodule", []),
    ("import in a hand-written wrapper", "pwm",
     "module m_qnsc_wrap_pwm\n  import foo_pkg::*;\n(input logic a); endmodule", ["NO-IMPORT"]),
    ("import in an emacs file", "top",
     "module m_qnsc_top (input logic a);\n  import qnsc_pkg::*;\n  /*AUTOWIRE*/\nendmodule", ["NO-IMPORT"]),
    ("qnsc_pkg in IP", "pwm",
     "module m_qnsc_wrap_pwm (input logic a);\n  ip #(.W(qnsc_pkg::C_W)) u_ip ();\nendmodule", ["NO-PKG"]),
    ("own package in a wrapper", "cpu",
     "module m_qnsc_wrap_cpu (output logic [qnsc_cpu2axi_pkg::P_ID_W-1:0] o_id); endmodule",
     ["NO-OWN-PKG"]),
    ("vendored IP's own constant accepted", "cpu",
     "module m_qnsc_wrap_cpu (input logic a);\n  ibex_top #(.RV32M(ibex_pkg::RV32MFast)) u_ibex ();\nendmodule", []),
    ("literal accepted", "pwm",
     "module m_qnsc_wrap_pwm (input logic a);\n  ip #(.W(4)) u_ip ();  // contract: meta.x\nendmodule", []),
    ("in-house module may have parameters", "cpu",
     "module m_qnsc_cpu2axi #(parameter int P_N = 2) (input logic a); endmodule", []),
    ("qnsc_pkg in integration accepted", "top",
     "module m_qnsc_top (input logic a);\n  m_qnsc_wrap_pwm u_pwm (.i_cfg(qnsc_pkg::C_X));\nendmodule", []),
    ("top overrides a wrapper", "top",
     "module m_qnsc_top (input logic a);\n  m_qnsc_wrap_pwm #(.W(8)) u_pwm ();\nendmodule", ["NO-OVERRIDE"]),
    ("defparam", "top",
     "module m_qnsc_top (input logic a);\n  defparam u_pwm.u_ip.W = 8;\nendmodule", ["NO-OVERRIDE"]),
    ("wrapper named after the IP", "pwm",
     "module m_qnsc_wrap_apb_adv_timer (input logic a); endmodule", ["WRAP-NAME"]),
    ("waived with a reason", "pwm",
     "module m_qnsc_wrap_pwm (input logic a);\n  parameter int W = 4;  // module-rules: ignore -- test\nendmodule", []),
]


def main() -> int:
    failed = 0
    with tempfile.TemporaryDirectory() as tmp:
        mr.DESIGN = Path(tmp)
        for name, block, src, want in CASES:
            f = Path(tmp) / block / "rtl" / "t.sv"
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_text(src + "\n")
            got = sorted(x.rule for x in mr.check_file(f, INTEGRATION, OWN))
            if got != sorted(want):
                failed += 1
                print(f"FAIL  {name}: expected {want}, got {got}")
            f.unlink()
    print(f"module-rules self-test: {len(CASES) - failed}/{len(CASES)} cases pass")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
