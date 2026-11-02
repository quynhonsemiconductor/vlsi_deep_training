`timescale 1ns/1ps

// =============================================================================
// m_qnsc_scrc_rrc -- Reset Request Controller (QNSC_SCRC_MAS V3.4, 7.3,
// Figure 7-3/7-4)
//
// Merges the watchdog bite and SW_RST into w_rst_n_sys. Both requests are
// cleared by the reset they cause (the aon_timer request by o_rst_n_wdt,
// SW_RST by the reset of SCRC CSR), so they are latched here and the reset is
// driven from a flip-flop for exactly 16 cycles.
//
//   - Every flip-flop, CNT included, is reset to 0 by w_rst_n_por only.
//   - A request while CNT = 0 (and idle) loads CNT = 15 and asserts w_rst_n_sys.
//     w_rst_n_sys stays 0 while CNT != 0 or a request is held.
//   - CAUSE captures the synchronised WDT request and SW_RST in the load cycle.
//     o_cause_we_* are those flip-flops, held while w_rst_n_sys = 0: a level,
//     not a one-cycle pulse, because the SYSCSR W1C field lets an APB write win
//     over a hardware set in the same cycle (QNSC_SYSCSR_MAS 7.2).
//   - Power-on: no stretch. w_rst_n_sys releases one cycle after w_rst_n_por;
//     every domain is still held by RST_REL = 0.
//
// Checks: SCRC_RST_001, SCRC_RST_005, SCRC_RRC_001, SCRC_IMP_001.
// =============================================================================
module m_qnsc_scrc_rrc (
  input  logic i_clk_root,       // w_clk_root
  input  logic i_rst_n_por,      // w_rst_n_por: the ONLY reset of this block
  input  logic i_wdt_rst_req,    // aon_timer_rst_req_o, sticky, WDT domain
  input  logic i_sw_rst,         // SCRC CSR SW_RST
  output logic o_rst_n_sys,      // w_rst_n_sys
  output logic o_cause_we_wdt,
  output logic o_cause_we_sw
);
  logic       w_wdt_req, w_req, w_load, w_rst_n_sys_nxt;
  logic [3:0] r_cnt;
  logic       r_rst_n_sys, r_cause_wdt, r_cause_sw;

  qnsc_sync_cell u_sync_wdt (
    .i_clk_dst   (i_clk_root),
    .i_rst_n_dst (i_rst_n_por),
    .i_d         (i_wdt_rst_req),
    .o_q         (w_wdt_req)
  );

  assign w_req           = w_wdt_req | i_sw_rst;
  assign w_load          = w_req & (r_cnt == 4'd0) & r_rst_n_sys;
  assign w_rst_n_sys_nxt = ~(w_load | (r_cnt != 4'd0) | w_req);

  always_ff @(posedge i_clk_root or negedge i_rst_n_por) begin
    if (!i_rst_n_por) begin
      r_cnt       <= 4'd0;
      r_rst_n_sys <= 1'b0;
      r_cause_wdt <= 1'b0;
      r_cause_sw  <= 1'b0;
    end else begin
      if (w_load)              r_cnt <= 4'd15;
      else if (r_cnt != 4'd0)  r_cnt <= r_cnt - 4'd1;

      r_rst_n_sys <= w_rst_n_sys_nxt;

      if (w_load) begin
        r_cause_wdt <= w_wdt_req;
        r_cause_sw  <= i_sw_rst;
      end else if (w_rst_n_sys_nxt) begin
        r_cause_wdt <= 1'b0;
        r_cause_sw  <= 1'b0;
      end
    end
  end

  assign o_rst_n_sys    = r_rst_n_sys;
  assign o_cause_we_wdt = r_cause_wdt;
  assign o_cause_we_sw  = r_cause_sw;
endmodule
