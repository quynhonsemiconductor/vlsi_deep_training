`timescale 1ns/1ps

// =============================================================================
// m_qnsc_scrc_apb_guard -- APB guard of one gateable slave (QNSC_SCRC_MAS V3.4,
// 7.7, Figure 7-8/7-9). Designed with SCRC, instantiated 11 times in design/top
// between P_BUS and the wrappers of timer_0, timer_1, uart_0, uart_1, gpio_0,
// gpio_1, gpio_2, spi, i2c, pwm and the DMA configuration port. WDT has none.
//
//   - Samples APB_BLK[n] in the SETUP phase (PSEL & !PENABLE); a change during
//     a transfer does not affect that transfer (SCRC_BUS_002).
//   - Blocked: completes in the ACCESS phase with PREADY = 1, PSLVERR = 1,
//     PRDATA = 0, and never asserts PSEL at the IP (SCRC_BUS_001).
//   - Not blocked: pass-through; busy = PSEL at the IP, so 1 from SETUP until
//     the IP completes the transfer (SCRC_BUS_003).
// Runs on o_clk_pbus, reset o_rst_n_pbus (MAS 7.7): blocked out of reset.
// s_0 is the P_BUS side, m_0 the IP side. PADDR, PWRITE, PWDATA, PSTRB, PPROT
// go straight from P_BUS to the IP.
// =============================================================================
module m_qnsc_scrc_apb_guard (
  input  logic        i_clk_pbus,
  input  logic        i_rst_n_pbus,
  input  logic        i_guard_blk,             // APB_BLK[n] (SCRC o_guard_blk[n])
  output logic        o_guard_busy,            // to SCRC i_guard_busy[n]
  // P_BUS side
  input  logic        i_bus_apb_s_0_psel,
  input  logic        i_bus_apb_s_0_penable,
  output logic        o_bus_apb_s_0_pready,
  output logic        o_bus_apb_s_0_pslverr,
  output logic [31:0] o_bus_apb_s_0_prdata,
  // IP side
  output logic        o_bus_apb_m_0_psel,
  output logic        o_bus_apb_m_0_penable,
  input  logic        i_bus_apb_m_0_pready,
  input  logic        i_bus_apb_m_0_pslverr,
  input  logic [31:0] i_bus_apb_m_0_prdata
);

  logic w_setup, w_blk, r_blk;

  assign w_setup = i_bus_apb_s_0_psel & ~i_bus_apb_s_0_penable;

  always_ff @(posedge i_clk_pbus or negedge i_rst_n_pbus) begin
    if (!i_rst_n_pbus) r_blk <= 1'b1;          // blocked out of reset
    else if (w_setup)  r_blk <= i_guard_blk;
  end

  assign w_blk = w_setup ? i_guard_blk : r_blk;

  assign o_bus_apb_m_0_psel    = i_bus_apb_s_0_psel    & ~w_blk;
  assign o_bus_apb_m_0_penable = i_bus_apb_s_0_penable & ~w_blk;
  assign o_bus_apb_s_0_pready  = w_blk ? 1'b1  : i_bus_apb_m_0_pready;
  assign o_bus_apb_s_0_pslverr = w_blk ? 1'b1  : i_bus_apb_m_0_pslverr;
  assign o_bus_apb_s_0_prdata  = w_blk ? 32'd0 : i_bus_apb_m_0_prdata;
  assign o_guard_busy          = o_bus_apb_m_0_psel;

endmodule
