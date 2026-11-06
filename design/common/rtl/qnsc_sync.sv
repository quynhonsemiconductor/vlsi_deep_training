`timescale 1ns/1ps

// Flip-flop synchroniser for level signals entering the i_clk_dst domain.
//
// Each bit is synchronised on its own, so use it for independent levels (a pad,
// a request flag), never for a multi-bit value that must arrive together -- that
// needs a handshake. Every such crossing in QSOC goes through this cell, so a
// crossing is found with `grep qnsc_sync` (CONTRIBUTING.md, CDC stage).
//
// With P_STAGES = 2 (the default) every bit is one qnsc_sync_cell, the technology
// synchroniser of design/common/tech/<tech>/ (on smic28 the library's two-flop
// synchroniser cell). A bit that resets to 1 runs inverted through the cell, whose
// reset value is 0. Any other P_STAGES is plain flip-flops, with no library cell.
//
// Users: PWM (TIM_EXT pads), SYSDBG (requests, DBG_EN).

module qnsc_sync #(
  parameter int unsigned        P_WIDTH       = 1,
  parameter int unsigned        P_STAGES      = 2,
  parameter logic [P_WIDTH-1:0] P_RST_VALUE = '0
) (
  input  logic               i_clk_dst,
  input  logic               i_rst_n_dst,
  input  logic [P_WIDTH-1:0] i_d,
  output logic [P_WIDTH-1:0] o_q
);

  if (P_STAGES == 2) begin : g_cell
    for (genvar i = 0; i < P_WIDTH; i++) begin : g_bit
      if (P_RST_VALUE[i]) begin : g_rst_high
        logic w_q_n;
        qnsc_sync_cell u_sync_cell (
          .i_clk_dst   (i_clk_dst),
          .i_rst_n_dst (i_rst_n_dst),
          .i_d         (~i_d[i]),
          .o_q         (w_q_n)
        );
        assign o_q[i] = ~w_q_n;
      end else begin : g_rst_low
        qnsc_sync_cell u_sync_cell (
          .i_clk_dst   (i_clk_dst),
          .i_rst_n_dst (i_rst_n_dst),
          .i_d         (i_d[i]),
          .o_q         (o_q[i])
        );
      end
    end
  end else begin : g_flops
    logic [P_STAGES*P_WIDTH-1:0] r_sync;

    always_ff @(posedge i_clk_dst or negedge i_rst_n_dst) begin
      if (!i_rst_n_dst) begin
        r_sync <= {P_STAGES{P_RST_VALUE}};
      end else begin
        r_sync <= {r_sync[(P_STAGES-1)*P_WIDTH-1:0], i_d};
      end
    end

    assign o_q = r_sync[P_STAGES*P_WIDTH-1 -: P_WIDTH];
  end

endmodule
