//==============================================================================
// Module      : m_qnsc_intmap
// Description : Combinational interrupt map: 26 sources onto 11 Ibex fast lines
//               (5 OR gates, 6 wires) and one wire onto the non-maskable input
// Spec ref    : QNSC_Interrupt_Map_MAS.md V2.2 §5, §7.1-§7.3, §8, §11 item 2
// REQ-IDs     : REQ-001..REQ-016, REQ-018..REQ-021
//               (REQ-017 is an integration note for design/top, not implemented here)
//==============================================================================
module m_qnsc_intmap
  import qnsc_pkg::*;
(
  // No clock, no reset, no bus port: the block holds no state        // REQ-016 REQ-018
  // ---- interrupt sources ----                                      // REQ-016
  input  logic                             i_int_dma,         // DMA dma_irq_o
  input  logic [7:0]                       i_int_spi_device,  // SPI device intr_*_o, port declaration order
  input  logic [1:0]                       i_int_spi_host,    // bit 0 intr_error_o, bit 1 intr_spi_event_o
  input  logic                             i_int_i2c,         // I2C interrupt_o
  input  logic                             i_int_uart_0,      // UART0 INT
  input  logic                             i_int_uart_1,      // UART1 INT
  input  logic [1:0]                       i_int_timer_1,     // bit 0 irq_lo_o, bit 1 irq_hi_o
  input  logic [3:0]                       i_int_pwm,         // bit n = events_o[n]
  input  logic                             i_int_wdt_wakeup,  // WDT intr_wkup_timer_expired_o
  input  logic [2:0]                       i_int_gpio,        // bit n = GPIOn interrupt
  input  logic                             i_int_timer_0,     // TIMER0 irq_lo_o, 64-bit mode
  input  logic                             i_int_wdt_bark,    // WDT nmi_wdog_timer_bark_o
  // ---- to the Ibex core ----                                       // REQ-016
  output logic [C_INT_FAST_LINES_USED-1:0] o_int_fast,        // to irq_fast_i[10:0]
  output logic                             o_int_nm           // to irq_nm_i
);

  // One source group per line, line index from qnsc_pkg (= priority, mcause 16+n)
  // REQ-013 REQ-015 REQ-020
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

  // The watchdog bark is a wire to the non-maskable input, never ORed  // REQ-012
  assign o_int_nm = i_int_wdt_bark;

`ifndef SYNTHESIS
  // Simulation only: name the source that carries an X             // REQ-021
  // (IbexIrqX in ibex_top checks only the bundle). Concurrent SVA for
  // REQ-001..REQ-015 is added by /sva_generator.
  always_comb begin
    a_int_dma_known         : assert final (!$isunknown(i_int_dma));
    a_int_spi_device_known  : assert final (!$isunknown(i_int_spi_device));
    a_int_spi_host_known    : assert final (!$isunknown(i_int_spi_host));
    a_int_i2c_known         : assert final (!$isunknown(i_int_i2c));
    a_int_uart_0_known      : assert final (!$isunknown(i_int_uart_0));
    a_int_uart_1_known      : assert final (!$isunknown(i_int_uart_1));
    a_int_timer_1_known     : assert final (!$isunknown(i_int_timer_1));
    a_int_pwm_known         : assert final (!$isunknown(i_int_pwm));
    a_int_wdt_wakeup_known  : assert final (!$isunknown(i_int_wdt_wakeup));
    a_int_gpio_known        : assert final (!$isunknown(i_int_gpio));
    a_int_timer_0_known     : assert final (!$isunknown(i_int_timer_0));
    a_int_wdt_bark_known    : assert final (!$isunknown(i_int_wdt_bark));
  end
`endif

endmodule : m_qnsc_intmap
