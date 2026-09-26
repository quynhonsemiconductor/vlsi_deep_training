//==============================================================================
// Module      : m_qnsc_intmap
// Description : Interrupt map. 25 maskable sources, grouped per peripheral, onto
//               11 Ibex fast lines, and the watchdog bark onto the NMI. Purely
//               combinational: no clock, no reset, no state, no bus port.
// Spec ref    : QNSC_Interrupt_Map_MAS.md §5, §7.1-7.3
// REQ-IDs     : REQ-001 .. REQ-020
//==============================================================================
module m_qnsc_intmap
  import qnsc_pkg::*;
(
  // ---- Interrupt sources, from the peripherals ---- // REQ-016
  input  logic                             i_int_dma,
  input  logic [7:0]                       i_int_spi_device,
  input  logic [1:0]                       i_int_spi_host,
  input  logic                             i_int_i2c,
  input  logic                             i_int_uart_0,
  input  logic                             i_int_uart_1,
  input  logic [1:0]                       i_int_timer_1,
  input  logic [3:0]                       i_int_pwm,
  input  logic                             i_int_wdt_wakeup,
  input  logic [2:0]                       i_int_gpio,
  input  logic                             i_int_timer_0,
  input  logic                             i_int_wdt_bark,

  // ---- To Ibex: irq_fast_i[10:0] and irq_nm_i ---- // REQ-016, REQ-019
  output logic [C_INT_FAST_LINES_USED-1:0] o_int_fast,
  output logic                             o_int_nm
);

  // One source group per line; the line index is the priority (MAS §7.2).
  // Wires for single sources, OR reductions for groups. REQ-001 .. REQ-011, REQ-013, REQ-015
  assign o_int_fast[C_INT_LINE_DMA]        =  i_int_dma;          // REQ-001
  assign o_int_fast[C_INT_LINE_SPI_DEVICE] = |i_int_spi_device;   // REQ-002
  assign o_int_fast[C_INT_LINE_SPI_HOST]   = |i_int_spi_host;     // REQ-003
  assign o_int_fast[C_INT_LINE_I2C]        =  i_int_i2c;          // REQ-004
  assign o_int_fast[C_INT_LINE_UART_0]     =  i_int_uart_0;       // REQ-005
  assign o_int_fast[C_INT_LINE_UART_1]     =  i_int_uart_1;       // REQ-006
  assign o_int_fast[C_INT_LINE_TIMER_1]    = |i_int_timer_1;      // REQ-007
  assign o_int_fast[C_INT_LINE_PWM]        = |i_int_pwm;          // REQ-008
  assign o_int_fast[C_INT_LINE_WDT_WAKEUP] =  i_int_wdt_wakeup;   // REQ-009
  assign o_int_fast[C_INT_LINE_GPIO]       = |i_int_gpio;         // REQ-010
  assign o_int_fast[C_INT_LINE_TIMER_0]    =  i_int_timer_0;      // REQ-011

  // The watchdog bark is a wire to the NMI, never ORed with a fast line (MAS §7.3). REQ-012
  assign o_int_nm = i_int_wdt_bark;

`ifndef SYNTHESIS
  // Every interrupt input is 0 or 1. An X passes an OR gate silently and Ibex checks
  // only the whole bundle, so an unreset source is reported here (MAS §11). REQ-020
  always_comb begin
    assert final (!$isunknown({i_int_dma, i_int_spi_device, i_int_spi_host, i_int_i2c,
                               i_int_uart_0, i_int_uart_1, i_int_timer_1, i_int_pwm,
                               i_int_wdt_wakeup, i_int_gpio, i_int_timer_0,
                               i_int_wdt_bark}))
      else $error("m_qnsc_intmap: X on an i_int_* input");
  end
`endif

endmodule
