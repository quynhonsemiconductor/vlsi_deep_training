`timescale 1ns/1ps

// Clock buffer, SMIC 28HKMG implementation: ARM sc9mc_base_svt_c31 r1p0 (suffix _A9TS_C31).
// Same module and ports as generic/qnsc_clk_buf.sv; the library cell is kept by instance
// name (set_size_only */u_size_only_*). The cell's behaviour is in the PDK's own
// Verilog model, read on the training server only (README "smic28").
// BUFH: high-drive buffer. Size X4M is a placeholder; physical design resizes it.

module qnsc_clk_buf (
  input  logic i_clk_src,
  output logic o_clk_buf
);

  BUFH_X4M_A9TS_C31 u_size_only_buf (.A (i_clk_src), .Y (o_clk_buf));  // naming-check: ignore -- library cell

endmodule
