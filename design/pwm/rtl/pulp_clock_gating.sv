`timescale 1ns/1ps

// Clock gate for apb_adv_timer, which instantiates pulp_clock_gating once per
// timer module (enable CH_EN[i], test enable dft_cg_enable_i) but does not ship
// it. Mapped onto qnsc_clk_gate, the one clock gate of QSOC (Naming Rule 2.8,
// design/common/tech/README.md), so TECH= selects the same cell here as in every
// other block. Spec: doc/specs/QNSC_PWM_MAS.md, section 4.
//
// The module and port names are fixed by the vendored instantiation, so they keep
// the upstream convention instead of the QNSC naming rule.

module pulp_clock_gating (  // naming-check: ignore -- name fixed by apb_adv_timer
  input  logic clk_i,       // naming-check: ignore -- port of a vendored cell
  input  logic en_i,        // naming-check: ignore -- port of a vendored cell
  input  logic test_en_i,   // naming-check: ignore -- port of a vendored cell
  output logic clk_o        // naming-check: ignore -- port of a vendored cell
);

  qnsc_clk_gate u_clk_gate (
    .i_clk_src     (clk_i),
    .i_en          (en_i),
    .i_dft_scan_en (test_en_i),
    .o_clk_gated   (clk_o)
  );

endmodule
