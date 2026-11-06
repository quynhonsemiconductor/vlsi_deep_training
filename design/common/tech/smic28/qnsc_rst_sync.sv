`timescale 1ns/1ps

// Reset synchroniser, SMIC 28HKMG implementation: ARM sc9mc_base_svt_c31 r1p0 (suffix _A9TS_C31).
// Same module and ports as generic/qnsc_rst_sync.sv; the library cell is kept by instance
// name (set_size_only */u_size_only_*). The cell's behaviour is in the PDK's own
// Verilog model, read on the training server only (README "smic28").
// SDFFYRPQ2D: two flip-flops in series for MTBF, active-high reset R, so an
// inverter makes it from i_rst_n_src. MX2 (Y = S0 ? B : A) is the scan bypass.

module qnsc_rst_sync (
  input  logic i_clk_dst,
  input  logic i_rst_n_src,
  input  logic i_dft_scan_en,
  output logic o_rst_n_dst
);

  logic w_rst, w_sync;

  INV_X1M_A9TS_C31 u_size_only_inv (.A (i_rst_n_src), .Y (w_rst));  // naming-check: ignore -- library cell

  SDFFYRPQ2D_X1M_A9TS_C31 u_size_only_sync (  // naming-check: ignore -- library cell
    .CK (i_clk_dst), .D (1'b1), .R (w_rst), .SE (1'b0), .SI (1'b0), .Q (w_sync)
  );

  MX2_X1B_A9TS_C31 u_size_only_mux (  // naming-check: ignore -- library cell
    .A (w_sync), .B (i_rst_n_src), .S0 (i_dft_scan_en), .Y (o_rst_n_dst)
  );

endmodule
