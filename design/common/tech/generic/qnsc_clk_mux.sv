`timescale 1ns/1ps

// Two-input clock multiplexer, generic implementation. It is a plain mux: the
// select must change only while both clocks are stopped, or through a glitch-free
// switch built around it. An ASIC library maps it to its clock mux. Naming Rule 2.8.

module qnsc_clk_mux (
  input  logic i_clk_src_0,
  input  logic i_clk_src_1,
  input  logic i_sel,
  output logic o_clk_mux
);

  assign o_clk_mux = i_sel ? i_clk_src_1 : i_clk_src_0;

endmodule
