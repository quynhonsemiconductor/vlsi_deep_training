`timescale 1ns/1ps

// Clock buffer, generic implementation. A clock path that must start at a known
// cell (a root, a balancing point) instantiates this; an ASIC library maps it to
// its clock buffer. Naming Rule 2.8.

module qnsc_clk_buf (
  input  logic i_clk_src,
  output logic o_clk_buf
);

  assign o_clk_buf = i_clk_src;

endmodule
