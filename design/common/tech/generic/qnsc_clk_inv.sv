`timescale 1ns/1ps

// Clock inverter, generic implementation; an ASIC library maps it to its clock
// inverter. Naming Rule 2.8.

module qnsc_clk_inv (
  input  logic i_clk_src,
  output logic o_clk_inv
);

  assign o_clk_inv = ~i_clk_src;

endmodule
