#!/usr/bin/env python3
"""Self-test of naming_check.py: every rule passes a correct case and catches a wrong one.

    python3 flow/lint/test_naming_check.py      (make naming runs it first)

Each case is a file written to a temporary design/ tree, checked, and compared with
the rules it must report (a set of rule ids; empty = clean). A change to a pattern
in naming_rules.yml that stops catching a case, or starts flagging a correct one,
fails here before it reaches a pull request.
"""
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import naming_check as nc  # noqa: E402

GOOD_WRAP = """\
module m_qnsc_wrap_x (
  input  logic        i_clk_peri,
  input  logic        i_rst_n_peri,
  input  logic [11:0] i_bus_apb_paddr,
  input  logic        i_bus_apb_psel, i_bus_apb_penable,
  output logic [31:0] o_bus_apb_prdata,
  output logic        o_int_x
);
  typedef enum logic [1:0] {S_IDLE = 2'd0, S_BUSY = 2'd1} state_t;
  typedef struct packed { logic [3:0] addr; logic valid; } req_t;
  state_t r_state;
  req_t   w_req;
  logic   r_a, w_b;
  logic [3:0] mem_q [4];
  assign o_bus_apb_prdata = '0;
  assign o_int_x = 1'b0;
  initial $display("rstn irq Clock");
endmodule
"""

CASES = [
    # (path under design/, text, rules expected)
    ("x/rtl/m_qnsc_wrap_x.sv", GOOD_WRAP, set()),
    ("x/rtl/m_qnsc_x.sv", "module m_qnsc_x (\n  input logic o_a,\n  output logic i_b\n);\nendmodule\n",
     {"1.2 port prefix"}),
    ("x/rtl/m_qnsc_x.sv", "module m_qnsc_x (\n  input logic i_clk,\n  input logic i_rstn\n);\nendmodule\n",
     {"3.1 clock", "3.2 reset", "1.3 active low"}),
    ("x/rtl/m_qnsc_x.sv", "module m_qnsc_x (\n  input logic i_rst_sys\n);\nendmodule\n",
     {"3.2 reset"}),
    ("x/rtl/m_qnsc_x.sv", "module m_qnsc_x (\n  input logic [11:0] i_paddr_apb,\n"
     "  input logic [4:0] i_axi_s_0_aw_id\n);\nendmodule\n", {"3.3/3.4 bus"}),
    ("x/rtl/m_qnsc_x.sv", "module m_qnsc_x (\n  input logic [4:0] i_bus_axi_s_0_aw_id,\n"
     "  output logic o_bus_apb_m_8_psel,\n  input logic [7:0] i_bus_axi_req\n);\n"
     "  assign o_bus_apb_m_8_psel = 1'b0;\nendmodule\n", set()),
    ("x/rtl/m_qnsc_x.sv", "module m_qnsc_x;\n  logic r_a, w_b, bad_c;\nendmodule\n",
     {"2.3 signal"}),
    ("x/rtl/m_qnsc_x.sv", "module m_qnsc_x;\n  axi_pkg::resp_t bad_resp;\nendmodule\n",
     {"2.3 signal"}),
    ("x/rtl/m_qnsc_x.sv", "module m_qnsc_x;\n  typedef enum logic {IDLE, BUSY} state_t;\nendmodule\n",
     {"2.6 type"}),
    ("x/rtl/m_qnsc_x.sv", "module m_qnsc_x;\n  typedef logic [3:0] nibble;\nendmodule\n",
     {"2.6 type"}),
    ("x/rtl/m_qnsc_x.sv", "package s_bus_pkg;\nendpackage\n", {"2.1 module", "2.7 file"}),
    ("x/rtl/qnsc_x_pkg.sv", "package qnsc_x_pkg;\n  typedef logic [31:0] addr_t;\nendpackage\n", set()),
    ("x/rtl/m_qnsc_wrong.sv", "module m_qnsc_x;\nendmodule\n", {"2.7 file"}),
    ("x/rtl/m_qnsc_x.sv", "module m_qnsc_x;\nendmodule\nmodule m_qnsc_y;\nendmodule\n", {"2.7 file"}),
    ("x/rtl/emacs/m_qnsc_wrap_x.src.sv", "module m_qnsc_wrap_x;\nendmodule\n", set()),
    ("x/rtl/m_qnsc_top.sv", "module m_qnsc_top;\nendmodule\n", {"2.1 module"}),
    ("top/rtl/m_qnsc_top.sv", "module m_qnsc_top;\nendmodule\n", set()),
    ("top/rtl/m_qnsc_soc.sv", "module m_qnsc_soc;\nendmodule\n", {"2.1 module"}),
    ("x/rtl/m_qnsc_x.sv", "module m_qnsc_x (\n  input logic i_a  // naming-check: ignore -- test\n);\n"
     "  logic clk_i;  // naming-check: ignore -- port of a vendored cell\nendmodule\n", set()),
    ("x/rtl/m_qnsc_x.sv", "module m_qnsc_x (\n  output logic o_irq_x\n);\nendmodule\n",
     {"1.5 vocabulary"}),
    # a header with two imports is still parsed
    ("x/rtl/m_qnsc_x.sv", "module m_qnsc_x\n  import a_pkg::*;\n  import b_pkg::*;\n#(\n)\n(\n"
     "  input logic [4:0] i_axi_s_0_aw_id\n);\nendmodule\n", {"3.3/3.4 bus"}),
    # a function's local variable is not a signal
    ("x/rtl/qnsc_x_pkg.sv", "package qnsc_x_pkg;\n  function automatic cfg_t f();\n    cfg_t c;\n"
     "    return c;\n  endfunction\nendpackage\n", set()),
]


def main() -> int:
    failed = 0
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        nc.REPO = root                               # chip-top directory is relative to it
        for i, (rel, text, want) in enumerate(CASES):
            path = root / "design" / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
            got = {f.rule for f in nc.check_file(path)}
            path.unlink()
            if got != want:
                failed += 1
                print(f"  case {i} {rel}: expected {sorted(want) or 'clean'}, got {sorted(got) or 'clean'}")
    print(f"naming-check self-test: {len(CASES) - failed}/{len(CASES)} cases pass")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
