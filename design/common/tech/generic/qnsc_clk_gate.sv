`timescale 1ns/1ps

// Integrated clock gate, generic implementation (simulation, FPGA, open synthesis).
//
// o_clk_gated follows i_clk_src while the enable, latched while the clock is low,
// is high. i_dft_scan_en forces the clock on during scan shift. Every clock gate of
// QSOC is this module, so one library cell serves the whole chip: an ASIC library
// in design/common/tech/<tech>/ implements the same module and ports on its ICG cell.
// Naming Rule 2.8.

module qnsc_clk_gate (
  input  logic i_clk_src,
  input  logic i_en,
  input  logic i_dft_scan_en,
  output logic o_clk_gated
);

  logic r_en;

  // transparent while the clock is low, so the enable cannot change mid-pulse
  always_latch begin
    if (!i_clk_src) r_en = i_en | i_dft_scan_en;
  end

  assign o_clk_gated = i_clk_src & r_en;

endmodule
