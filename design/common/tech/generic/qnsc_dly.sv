`timescale 1ns/1ps

// Delay cell, generic implementation. A delay that must exist in silicon (the
// PORSTN glitch filter of SCRC, QNSC_SCRC_MAS 7.2) cannot be written as RTL: an
// ASIC library maps this module to its delay cell, and synthesis keeps it by
// instance name (u_size_only_*). Here the delay is a simulation model only, 1 ns,
// so a testbench can show the filter working; lint and synthesis ignore it.
// Naming Rule 2.8.

module qnsc_dly (
  input  logic i_sig,
  output logic o_sig_dly
);

  // The delay is kept where the tool times it: every simulator, and Verilator with
  // --timing (make sim). Verilator lint runs without --timing and rejects a delay,
  // so it sees a wire.
`ifdef VERILATOR
`ifdef VERILATOR_TIMING
  assign #1 o_sig_dly = i_sig;
`else
  assign o_sig_dly = i_sig;
`endif
`else
  assign #1 o_sig_dly = i_sig;
`endif

endmodule
