`timescale 1ns/1ps

// Two flip-flop synchroniser for one level, generic implementation, for a path
// that must be built from library cells (SCRC: the WDT reset request, QNSC_SCRC_MAS
// 7.3). o_q follows i_d two rising edges of i_clk_dst later; i_rst_n_dst clears
// both flip-flops asynchronously. An ASIC library maps it to its two-stage
// synchroniser flip-flop. Data crossings that need no library cell use the
// behavioural qnsc_sync of design/common/rtl. Naming Rule 2.8.

module qnsc_sync_cell (
  input  logic i_clk_dst,
  input  logic i_rst_n_dst,
  input  logic i_d,
  output logic o_q
);

  logic [1:0] r_sync;

  always_ff @(posedge i_clk_dst or negedge i_rst_n_dst) begin
    if (!i_rst_n_dst) r_sync <= 2'b00;
    else              r_sync <= {r_sync[0], i_d};
  end

  assign o_q = r_sync[1];

endmodule
