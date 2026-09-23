// =============================================================================
// GENERATED FILE -- DO NOT EDIT.
//
// Source:    util/qsoc_contract.yml
// Generator: util/gen_qnsc_pkg.py
//
// Every constant here is shared by more than one block. Import this package
// rather than retyping a number, so that two blocks cannot disagree about one
// fact -- which is how ROM 8 KiB against 2 KiB, APB_M11 against APB_S11 and
// eleven interrupt sources against twelve all happened.
//
// To change a number: edit the contract, run the generator, commit both. CI
// regenerates and compares, so this file cannot drift from the contract.
// =============================================================================

package qnsc_pkg;

  // ---- geometry ------------------------------------------------------------
  localparam int unsigned C_DATA_WIDTH = 32;
  localparam int unsigned C_ADDR_WIDTH = 32;
  localparam int unsigned C_CLK_MHZ    = 20;

  // ---- memory map ----------------------------------------------------------
  // Source: QSOC_HAS Table 7-1. Every address in the 32-bit space belongs to
  // exactly one region; anything else must answer DECERR.
  localparam logic [C_ADDR_WIDTH-1:0] C_ROM_BASE = 32'h00000000;
  localparam int unsigned             C_ROM_SIZE = 2048;  // 2 KiB
  localparam logic [C_ADDR_WIDTH-1:0] C_ISRAM_DBG_BASE = 32'h20000000;
  localparam int unsigned             C_ISRAM_DBG_SIZE = 4096;  // 4 KiB
  localparam logic [C_ADDR_WIDTH-1:0] C_ISRAM_BASE = 32'h20001000;
  localparam int unsigned             C_ISRAM_SIZE = 61440;  // 60 KiB
  localparam logic [C_ADDR_WIDTH-1:0] C_DSRAM_BASE = 32'h30000000;
  localparam int unsigned             C_DSRAM_SIZE = 32768;  // 32 KiB
  localparam logic [C_ADDR_WIDTH-1:0] C_SCRC_BASE = 32'h80000000;
  localparam int unsigned             C_SCRC_SIZE = 16384;  // 16 KiB
  localparam logic [C_ADDR_WIDTH-1:0] C_SYSCSR_BASE = 32'h80004000;
  localparam int unsigned             C_SYSCSR_SIZE = 16384;  // 16 KiB
  localparam logic [C_ADDR_WIDTH-1:0] C_WDT_BASE = 32'h80008000;
  localparam int unsigned             C_WDT_SIZE = 16384;  // 16 KiB
  localparam logic [C_ADDR_WIDTH-1:0] C_GPIO_0_BASE = 32'h8000C000;
  localparam int unsigned             C_GPIO_0_SIZE = 16384;  // 16 KiB
  localparam logic [C_ADDR_WIDTH-1:0] C_GPIO_1_BASE = 32'h80010000;
  localparam int unsigned             C_GPIO_1_SIZE = 16384;  // 16 KiB
  localparam logic [C_ADDR_WIDTH-1:0] C_GPIO_2_BASE = 32'h80014000;
  localparam int unsigned             C_GPIO_2_SIZE = 16384;  // 16 KiB
  localparam logic [C_ADDR_WIDTH-1:0] C_GPIO_3_BASE = 32'h80018000;
  localparam int unsigned             C_GPIO_3_SIZE = 16384;  // 16 KiB
  localparam logic [C_ADDR_WIDTH-1:0] C_TIMER_0_BASE = 32'h8001C000;
  localparam int unsigned             C_TIMER_0_SIZE = 16384;  // 16 KiB
  localparam logic [C_ADDR_WIDTH-1:0] C_TIMER_1_BASE = 32'h80020000;
  localparam int unsigned             C_TIMER_1_SIZE = 16384;  // 16 KiB
  localparam logic [C_ADDR_WIDTH-1:0] C_UART_0_BASE = 32'h80024000;
  localparam int unsigned             C_UART_0_SIZE = 16384;  // 16 KiB
  localparam logic [C_ADDR_WIDTH-1:0] C_UART_1_BASE = 32'h80028000;
  localparam int unsigned             C_UART_1_SIZE = 16384;  // 16 KiB
  localparam logic [C_ADDR_WIDTH-1:0] C_SPI_BASE = 32'h8002C000;
  localparam int unsigned             C_SPI_SIZE = 16384;  // 16 KiB
  localparam logic [C_ADDR_WIDTH-1:0] C_I2C_BASE = 32'h80030000;
  localparam int unsigned             C_I2C_SIZE = 16384;  // 16 KiB
  localparam logic [C_ADDR_WIDTH-1:0] C_PWM_BASE = 32'h80034000;
  localparam int unsigned             C_PWM_SIZE = 16384;  // 16 KiB
  localparam logic [C_ADDR_WIDTH-1:0] C_DMA_CFG_BASE = 32'h80038000;
  localparam int unsigned             C_DMA_CFG_SIZE = 16384;  // 16 KiB

  // ---- interrupt lines -----------------------------------------------------
  // Source: QSOC_HAS Table 8-1. The line index IS the priority: Ibex resolves
  // the lowest index first, so this order is the default priority order and
  // changing it means re-synthesising. Order follows the rule
  // "data loss first, human time last".
  //
  // mcause = 16 + line, and the vector is mtvec + 4 * mcause. Causes 16 and
  // above are platform-use space in the privileged specification.
  localparam int unsigned C_INT_FAST_LINES_AVAILABLE = 15;
  localparam int unsigned C_INT_FAST_LINES_USED      = 11;
  localparam int unsigned C_INT_SOURCES_AGGREGATED   = 26;  // through INTMAP
  localparam int unsigned C_INT_SOURCES_TOTAL        = 27;  // including the NMI

  localparam int unsigned C_INT_LINE_DMA          = 0;   // mcause 16, 1 source(s), level
  localparam int unsigned C_INT_LINE_SPI_DEVICE   = 1;   // mcause 17, 8 source(s), level
  localparam int unsigned C_INT_LINE_SPI_HOST     = 2;   // mcause 18, 2 source(s), level
  localparam int unsigned C_INT_LINE_I2C          = 3;   // mcause 19, 1 source(s), level
  localparam int unsigned C_INT_LINE_UART_0       = 4;   // mcause 20, 1 source(s), level
  localparam int unsigned C_INT_LINE_UART_1       = 5;   // mcause 21, 1 source(s), level
  localparam int unsigned C_INT_LINE_TIMER_1      = 6;   // mcause 22, 2 source(s), pulse; level in one-shot with prescaler or ref clock
  localparam int unsigned C_INT_LINE_PWM          = 7;   // mcause 23, 4 source(s), pulse
  localparam int unsigned C_INT_LINE_WDT_WAKEUP   = 8;   // mcause 24, 1 source(s), level
  localparam int unsigned C_INT_LINE_GPIO         = 9;   // mcause 25, 4 source(s), pulse
  localparam int unsigned C_INT_LINE_TIMER_0      = 10;   // mcause 26, 1 source(s), pulse; level in one-shot with prescaler or ref clock

  localparam int unsigned C_INT_MCAUSE_BASE = 16;
  localparam int unsigned C_INT_MCAUSE_NMI  = 31;   // wdt_bark, on irq_nm_i, a wire through INTMAP, never ORed

  // ---- clock and reset clusters ---------------------------------------------
  // Source: QSOC_HAS v4 section 'Clock and Reset'. One frequency for the whole
  // chip -- no PLL, the PDK has no analogue IP -- so a domain is a gate plus a
  // reset synchroniser, not a separate frequency.
  //
  // The cluster name is what goes into the port name the naming rule requires:
  //   i_clk_<domain> / i_rst_n_<domain>
  //   i_clk_cpu   hardwired on, not writable
  //     cpu, bus, sysdbg
  //   i_clk_mem   hardwired on, not writable
  //     rom, isram, dsram
  //   i_clk_peri  gateable via CLK_EN in SCRC
  //     wdt, timer_0, timer_1, uart_0, uart_1, spi, i2c, gpio, dma, pwm
  localparam int unsigned C_CLK_CLUSTERS = 3;

  localparam int unsigned C_RST_SOURCES = 3;   // power_on, watchdog, software

  // The CLK_EN and SOFT_RST_CTRL bit positions per peripheral belong to the
  // SCRC register map and are not duplicated here -- see tbd: in the contract.

endpackage : qnsc_pkg
