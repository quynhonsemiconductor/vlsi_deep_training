`timescale 1ns/1ps
// Clock gate apb_adv_timer instantiates but does not ship, mapped onto OpenTitan
// prim_clock_gating. Names are fixed by the vendored instantiation.
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
