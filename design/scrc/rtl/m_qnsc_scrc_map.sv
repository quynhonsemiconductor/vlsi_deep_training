`timescale 1ns/1ps

// =============================================================================
// m_qnsc_scrc_map -- the bit map between the SCRC CSR fields and the guard
// vectors (QNSC_SCRC_MAS V3.4, Table 6-3). The only logic of the SCRC top level,
// kept here because the top is generated with emacs verilog-mode and holds
// instances only.
//
//   o_guard_blk[n]  = APB_BLK field of gateable domain n; the other bits 0
//   o_busy_<d>      = i_guard_busy[n] of gateable domain n
//
// design/top ties i_guard_busy bits 0, 1, 2, 11, 12, 13, 14 to 0 (MAS 11); they
// are not read here.
// =============================================================================
module m_qnsc_scrc_map (
  // APB_BLK fields of the 11 gateable domains, from the SCRC CSR
  input  logic        i_blk_timer_0,
  input  logic        i_blk_timer_1,
  input  logic        i_blk_uart_0,
  input  logic        i_blk_uart_1,
  input  logic        i_blk_spi,
  input  logic        i_blk_i2c,
  input  logic        i_blk_gpio_0,
  input  logic        i_blk_dma,
  input  logic        i_blk_pwm,
  input  logic        i_blk_gpio_1,
  input  logic        i_blk_gpio_2,
  output logic [17:0] o_guard_blk,       // to the guards in design/top
  // busy of the 11 guards, to the SCRC CSR APB_BUSY fields
  input  logic [17:0] i_guard_busy,      // from the guards in design/top
  output logic        o_busy_timer_0,
  output logic        o_busy_timer_1,
  output logic        o_busy_uart_0,
  output logic        o_busy_uart_1,
  output logic        o_busy_spi,
  output logic        o_busy_i2c,
  output logic        o_busy_gpio_0,
  output logic        o_busy_dma,
  output logic        o_busy_pwm,
  output logic        o_busy_gpio_1,
  output logic        o_busy_gpio_2
);

  // bit:              17            16            15         14..11   10         9             8          7
  assign o_guard_blk = {i_blk_gpio_2, i_blk_gpio_1, i_blk_pwm, 4'b0000, i_blk_dma, i_blk_gpio_0, i_blk_i2c, i_blk_spi,
  //                    6             5             4              3              2..0
                        i_blk_uart_1, i_blk_uart_0, i_blk_timer_1, i_blk_timer_0, 3'b000};

  assign o_busy_timer_0 = i_guard_busy[3];
  assign o_busy_timer_1 = i_guard_busy[4];
  assign o_busy_uart_0  = i_guard_busy[5];
  assign o_busy_uart_1  = i_guard_busy[6];
  assign o_busy_spi     = i_guard_busy[7];
  assign o_busy_i2c     = i_guard_busy[8];
  assign o_busy_gpio_0  = i_guard_busy[9];
  assign o_busy_dma     = i_guard_busy[10];
  assign o_busy_pwm     = i_guard_busy[15];
  assign o_busy_gpio_1  = i_guard_busy[16];
  assign o_busy_gpio_2  = i_guard_busy[17];

endmodule
