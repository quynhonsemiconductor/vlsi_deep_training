`timescale 1ns/1ps

// Power-on reset glitch filter, SMIC 28HKMG implementation: ARM sc9mc_base_svt_c31 r1p0 (suffix _A9TS_C31).
// Same module and ports as generic/qnsc_rst_filter.sv; the library cell is kept by instance
// name (set_size_only */u_size_only_*). The cell's behaviour is in the PDK's own
// Verilog model, read on the training server only (README "smic28").
// Three DLY4 taps; NAND4 of the pad and the taps = SN (set, active low); OR4 and
// INV = R (clear, active high); DFFSRPQ with CK = 0, D = 0 holds the result. Set
// wins over reset in DFFSRPQ; the two are never active together.

module qnsc_rst_filter (
  input  logic i_rst_n_raw,
  output logic o_rst_n_filt
);

  logic w_tap_1, w_tap_2, w_tap_3, w_set_n, w_any, w_clr;

  DLY4_X1M_A9TS_C31 u_size_only_dly_1 (.A (i_rst_n_raw), .Y (w_tap_1));  // naming-check: ignore -- library cell
  DLY4_X1M_A9TS_C31 u_size_only_dly_2 (.A (w_tap_1),     .Y (w_tap_2));  // naming-check: ignore -- library cell
  DLY4_X1M_A9TS_C31 u_size_only_dly_3 (.A (w_tap_2),     .Y (w_tap_3));  // naming-check: ignore -- library cell

  NAND4_X1M_A9TS_C31 u_size_only_nand_set (  // naming-check: ignore -- library cell
    .A (i_rst_n_raw), .B (w_tap_1), .C (w_tap_2), .D (w_tap_3), .Y (w_set_n)
  );
  OR4_X1M_A9TS_C31 u_size_only_or_clr (  // naming-check: ignore -- library cell
    .A (i_rst_n_raw), .B (w_tap_1), .C (w_tap_2), .D (w_tap_3), .Y (w_any)
  );
  INV_X1M_A9TS_C31 u_size_only_inv_clr (.A (w_any), .Y (w_clr));  // naming-check: ignore -- library cell

  DFFSRPQ_X1M_A9TS_C31 u_size_only_ff (  // naming-check: ignore -- library cell
    .CK (1'b0), .D (1'b0), .R (w_clr), .SN (w_set_n), .Q (o_rst_n_filt)
  );

endmodule
