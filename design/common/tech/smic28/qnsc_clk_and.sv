`timescale 1ns/1ps

// Clock AND, SMIC 28HKMG implementation: ARM sc9mc_base_svt_c31 r1p0 (suffix _A9TS_C31).
// Same module and ports as generic/qnsc_clk_and.sv; the library cell is kept by instance
// name (set_size_only */u_size_only_*). The cell's behaviour is in the PDK's own
// Verilog model, read on the training server only (README "smic28").


module qnsc_clk_and (
  input  logic i_clk_src,
  input  logic i_en,
  output logic o_clk_and
);

  AND2_X1M_A9TS_C31 u_size_only_and (.A (i_clk_src), .B (i_en), .Y (o_clk_and));  // naming-check: ignore -- library cell

endmodule
