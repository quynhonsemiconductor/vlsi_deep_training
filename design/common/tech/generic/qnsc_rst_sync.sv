`timescale 1ns/1ps

// Reset synchroniser, generic implementation. o_rst_n_dst falls as soon as
// i_rst_n_src falls, with or without a clock, and rises on the second rising edge
// of i_clk_dst after i_rst_n_src rises (two flip-flops, for metastability).
// i_dft_scan_en = 1 bypasses the flip-flops so scan controls the reset directly;
// QSOC ties it 0 (no scan in v1). An ASIC library maps it to its two-stage
// synchroniser flip-flop plus a bypass mux. Naming Rule 2.8.

module qnsc_rst_sync (
  input  logic i_clk_dst,
  input  logic i_rst_n_src,
  input  logic i_dft_scan_en,
  output logic o_rst_n_dst
);

  logic [1:0] r_sync;

  always_ff @(posedge i_clk_dst or negedge i_rst_n_src) begin
    if (!i_rst_n_src) r_sync <= 2'b00;
    else              r_sync <= {r_sync[0], 1'b1};
  end

  assign o_rst_n_dst = i_dft_scan_en ? i_rst_n_src : r_sync[1];

endmodule
