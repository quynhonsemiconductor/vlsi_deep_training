`timescale 1ns/1ps

// Two-input AND on a clock path, generic implementation; an ASIC library maps it
// to its clock AND cell, balanced for both edges. Naming Rule 2.8.

module qnsc_clk_and (
  input  logic i_clk_src,
  input  logic i_en,
  output logic o_clk_and
);

  assign o_clk_and = i_clk_src & i_en;

endmodule
