`timescale 1ns/1ps

// Glitch filter of the power-on reset pad, generic implementation
// (QNSC_SCRC_MAS 7.2). Clockless: at power-on the clock may not run yet.
//
//   i_rst_n_raw -> three delay taps
//   all four 1  -> set:   o_rst_n_filt = 1 (reset released)
//   all four 0  -> clear: o_rst_n_filt = 0 (reset asserted)
//   otherwise   -> hold
//
// So a pulse shorter than the three delays changes nothing. An ASIC library builds
// it from three delay cells, a NAND4 (set), an OR4 and an inverter (clear) and a
// flip-flop with asynchronous set and reset. The delays here are simulation models
// only, 1 ns per tap; the file stands alone because the lint of a technology cell
// compiles it on its own. Naming Rule 2.8.

module qnsc_rst_filter (
  input  logic i_rst_n_raw,
  output logic o_rst_n_filt
);

  logic w_tap_1, w_tap_2, w_tap_3, w_set_n, w_clr, r_rst_n;

  // One delay cell per tap, 1 ns each, where the tool times it (as in qnsc_dly):
  // every simulator, and Verilator with --timing. Verilator lint sees wires.
`ifdef VERILATOR
`ifdef VERILATOR_TIMING
  assign #1 w_tap_1 = i_rst_n_raw;
  assign #1 w_tap_2 = w_tap_1;
  assign #1 w_tap_3 = w_tap_2;
`else
  assign w_tap_1 = i_rst_n_raw;
  assign w_tap_2 = w_tap_1;
  assign w_tap_3 = w_tap_2;
`endif
`else
  assign #1 w_tap_1 = i_rst_n_raw;
  assign #1 w_tap_2 = w_tap_1;
  assign #1 w_tap_3 = w_tap_2;
`endif

  assign w_set_n = ~(i_rst_n_raw & w_tap_1 & w_tap_2 & w_tap_3);
  assign w_clr   = ~(i_rst_n_raw | w_tap_1 | w_tap_2 | w_tap_3);

  // set and clear are never active together; set wins, as in the library flip-flop
  always_latch begin
    if (!w_set_n)   r_rst_n = 1'b1;
    else if (w_clr) r_rst_n = 1'b0;
  end

  assign o_rst_n_filt = r_rst_n;

endmodule
