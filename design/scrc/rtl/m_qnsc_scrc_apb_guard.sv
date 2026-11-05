`timescale 1ns/1ps

// =============================================================================
// m_qnsc_scrc_apb_guard -- APB guard of one gateable slave (QNSC_SCRC_MAS V3.5,
// 7.7, Figure 7-8/7-9). Designed with SCRC, instantiated 11 times in design/top
// between P_BUS and the wrappers of timer_0, timer_1, uart_0, uart_1, spi, i2c,
// gpio_0, gpio_1, gpio_2, the DMA configuration port and pwm (SCRC domain bits
// 2-12). The always-on slaves (SCRC, SYSCSR, WDT) have none.
//
// Why it exists: MCPU must not stop a clock under an APB transfer, and the CPU
// cannot be trusted to have finished. The guard is the hardware that knows: it
// sees PSEL/PENABLE/PREADY of every transfer to its slave. MCPU closes it first
// (i_csr_blk = APB_BLK[n] = 1), then reads APB_BUSY[n] (o_csr_busy) until
// 0, then stops the clock. Software on Ibex is not involved.
//
//   - Samples APB_BLK[n] in the SETUP phase (PSEL & !PENABLE); a change during
//     a transfer does not affect that transfer (SCRC_BUS_002).
//   - Blocked: completes in the ACCESS phase with PREADY = 1, PSLVERR = 1,
//     PRDATA = 0, and never asserts PSEL at the IP (SCRC_BUS_001).
//   - Not blocked: pass-through; busy = PSEL at the IP, so 1 from SETUP until
//     the IP completes the transfer (SCRC_BUS_003).
// Runs on o_clk_sys, reset o_rst_n_sys (MAS 7.7): blocked out of reset.
// s_0 is the P_BUS side, m_0 the IP side. PADDR, PWRITE, PWDATA, PSTRB, PPROT
// go straight from P_BUS to the IP.
// =============================================================================
module m_qnsc_scrc_apb_guard (
  input  logic        i_clk_sys,
  input  logic        i_rst_n_sys,
  input  logic        i_csr_blk,               // APB_BLK[n] (SCRC o_csr_blk[n])
  output logic        o_csr_busy,              // APB_BUSY[n] (SCRC i_csr_busy[n])
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

  always_ff @(posedge i_clk_sys or negedge i_rst_n_sys) begin
    if (!i_rst_n_sys) r_blk <= 1'b1;           // blocked out of reset
    else if (w_setup) r_blk <= i_csr_blk;
  end

  assign w_blk = w_setup ? i_csr_blk : r_blk;

  assign o_bus_apb_m_0_psel    = i_bus_apb_s_0_psel    & ~w_blk;
  assign o_bus_apb_m_0_penable = i_bus_apb_s_0_penable & ~w_blk;
  assign o_bus_apb_s_0_pready  = w_blk ? 1'b1  : i_bus_apb_m_0_pready;
  assign o_bus_apb_s_0_pslverr = w_blk ? 1'b1  : i_bus_apb_m_0_pslverr;
  assign o_bus_apb_s_0_prdata  = w_blk ? 32'd0 : i_bus_apb_m_0_prdata;
  assign o_csr_busy            = o_bus_apb_m_0_psel;

endmodule
