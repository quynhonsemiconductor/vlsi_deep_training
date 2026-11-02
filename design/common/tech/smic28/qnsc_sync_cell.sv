`timescale 1ns/1ps

// Two flip-flop synchroniser, SMIC 28HKMG implementation: ARM sc9mc_base_svt_c31 r1p0 (suffix _A9TS_C31).
// Same module and ports as generic/qnsc_sync_cell.sv; the library cell is kept by instance
// name (set_size_only */u_size_only_*). The cell's behaviour is in the PDK's own
// Verilog model, read on the training server only (README "smic28").
// SDFFYRPQ2D: two flip-flops in series for MTBF, active-high reset R.

module qnsc_sync_cell (
  input  logic i_clk_dst,
  input  logic i_rst_n_dst,
  input  logic i_d,
  output logic o_q
);

  logic w_rst;

  INV_X1M_A9TS_C31 u_size_only_inv (.A (i_rst_n_dst), .Y (w_rst));  // naming-check: ignore -- library cell

  SDFFYRPQ2D_X1M_A9TS_C31 u_size_only_sync (  // naming-check: ignore -- library cell
    .CK (i_clk_dst), .D (i_d), .R (w_rst), .SE (1'b0), .SI (1'b0), .Q (o_q)
  );

endmodule
