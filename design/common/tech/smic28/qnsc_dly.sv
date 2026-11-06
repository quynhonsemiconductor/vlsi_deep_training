`timescale 1ns/1ps

// Delay cell, SMIC 28HKMG implementation: ARM sc9mc_base_svt_c31 r1p0 (suffix _A9TS_C31).
// Same module and ports as generic/qnsc_dly.sv; the library cell is kept by instance
// name (set_size_only */u_size_only_*). The cell's behaviour is in the PDK's own
// Verilog model, read on the training server only (README "smic28").
// DLY4_X1M: cell_rise 0.063 ns at tt 0.90 V 25 C, 0.038 ns at ff (QNSC_SCRC_MAS 7.2).

module qnsc_dly (
  input  logic i_sig,
  output logic o_sig_dly
);

  DLY4_X1M_A9TS_C31 u_size_only_dly (.A (i_sig), .Y (o_sig_dly));  // naming-check: ignore -- library cell

endmodule
