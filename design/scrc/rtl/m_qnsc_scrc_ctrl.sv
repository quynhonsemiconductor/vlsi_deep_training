`timescale 1ns/1ps

// =============================================================================
// m_qnsc_scrc_ctrl -- one domain controller: clock gate + reset synchroniser
// (QNSC_SCRC_MAS V3.4, 7.1, Figure 7-1). 18 instances in m_qnsc_scrc; the seven
// always-on domains get i_icg_en = 1 there.
//
// Both are technology cells (design/common/tech): the mentor's rule is that a
// clock gate and a synchroniser are library cells, never inferred (MAS 7.1, 11).
// The synchroniser runs on the gated clock: a domain whose clock is stopped stays
// in reset even when its input is 1, and releases 2 edges after the clock runs
// again (SCRC_RST_002, SCRC_RST_008). Scan enable tied 0: no scan in QSOC v1.
// =============================================================================
module m_qnsc_scrc_ctrl (
  input  logic i_clk_root,     // w_clk_root
  input  logic i_icg_en,       // ICG_EN[n]; 1 for an always-on domain
  input  logic i_rst_n_in,     // RST_REL[n]; sysdbg: o_rst_n_por
  output logic o_clk_gated,    // o_clk_<d>
  output logic o_rst_n_sync    // o_rst_n_<d>
);

  qnsc_clk_gate u_icg (
    .i_clk_src     (i_clk_root),
    .i_en          (i_icg_en),
    .i_dft_scan_en (1'b0),
    .o_clk_gated   (o_clk_gated)
  );

  qnsc_rst_sync u_rst_sync (
    .i_clk_dst     (o_clk_gated),
    .i_rst_n_src   (i_rst_n_in),
    .i_dft_scan_en (1'b0),
    .o_rst_n_dst   (o_rst_n_sync)
  );

endmodule
