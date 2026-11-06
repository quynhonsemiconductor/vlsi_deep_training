`timescale 1ns/1ps

// Integrated clock gate, SMIC 28HKMG implementation: ARM sc9mc_base_svt_c31 r1p0 (suffix _A9TS_C31).
// Same module and ports as generic/qnsc_clk_gate.sv; the library cell is kept by instance
// name (set_size_only */u_size_only_*). The cell's behaviour is in the PDK's own
// Verilog model, read on the training server only (README "smic28").
// PREICG: latch transparent while CK is low, for rising-edge flip-flops.

module qnsc_clk_gate (
  input  logic i_clk_src,
  input  logic i_en,
  input  logic i_dft_scan_en,
  output logic o_clk_gated
);

  PREICG_X1B_A9TS_C31 u_size_only_icg (  // naming-check: ignore -- library cell
    .CK (i_clk_src), .E (i_en), .SE (i_dft_scan_en), .ECK (o_clk_gated)
  );

endmodule
