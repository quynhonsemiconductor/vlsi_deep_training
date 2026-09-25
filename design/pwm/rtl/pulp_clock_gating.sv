`timescale 1ns/1ps

// Clock gate for apb_adv_timer, which instantiates pulp_clock_gating once per
// timer module (enable CH_EN[i], test enable dft_cg_enable_i) but does not ship
// it. Mapped onto OpenTitan prim_clock_gating, the cell Ibex already uses, which
// has the same ports. Spec: doc/src/QNSC_PWM_MAS.md, section 4.
//
// The module and port names are fixed by the vendored instantiation, so they keep
// the upstream convention instead of the QNSC naming rule.

module pulp_clock_gating (  // naming-check: ignore -- name fixed by apb_adv_timer
  input  logic clk_i,       // naming-check: ignore -- port of a vendored cell
  input  logic en_i,        // naming-check: ignore -- port of a vendored cell
  input  logic test_en_i,   // naming-check: ignore -- port of a vendored cell
  output logic clk_o        // naming-check: ignore -- port of a vendored cell
);

  prim_clock_gating u_clk_gate (  // naming-check: ignore -- vendored OpenTitan cell
    .clk_i     (clk_i),
    .en_i      (en_i),
    .test_en_i (test_en_i),
    .clk_o     (clk_o)
  );

endmodule
