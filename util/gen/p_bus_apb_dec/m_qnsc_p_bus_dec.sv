// =============================================================================
// GENERATED FILE -- DO NOT EDIT.
//
// Source:    util/gen/p_bus_apb_dec/PBUS_APB_DEC.xlsx
// Generator: vendor/nguyenquanicd/APB-DEC-Generator/apb_dec_rtl_generator.py
//
// Single-master, 14-slave APB4 address decoder for P_BUS: fans the AXI2APB
// bridge's one APB master port (m_qnsc_wrap_bus's own w_apb_req[0]/
// w_apb_resp[0]) out to one flat port per peripheral. No arbitration logic:
// P_BUS has exactly one master today (see doc/specs/QNSC_BUS_DECISIONS.md,
// "P_BUS router: decoder only, not APB-BUS-Generator").
//
// To change the peripheral map: edit the workbook, run the generator, commit
// both -- same convention as design/top/rtl/qnsc_pkg.sv.
// =============================================================================

`timescale 1ns/1ps

module m_qnsc_p_bus_dec (
  // APB Master Interface
  input  logic [31:0]   i_paddr,
  input  logic [31:0]   i_pwdata,
  input  logic [ 3:0]   i_pstrb,
  input  logic          i_pwrite,
  input  logic          i_psel,
  input  logic          i_penable,
  output logic          o_pready,
  output logic          o_pslverr,
  output logic [31:0]   o_prdata,

  // APB Slave Interfaces
  // Slave 1: scrc (System clock and reset control registers)
  output logic [11:0]   o_paddr_scrc,
  output logic [31:0]   o_pwdata_scrc,
  output logic [ 3:0]   o_pstrb_scrc,
  output logic          o_psel_scrc,
  output logic          o_penable_scrc,
  output logic          o_pwrite_scrc,
  input  logic          i_pready_scrc,
  input  logic          i_pslverr_scrc,
  input  logic [31:0]   i_prdata_scrc,
  // Slave 2: syscsr (System control/status registers)
  output logic [11:0]   o_paddr_syscsr,
  output logic [31:0]   o_pwdata_syscsr,
  output logic [ 3:0]   o_pstrb_syscsr,
  output logic          o_psel_syscsr,
  output logic          o_penable_syscsr,
  output logic          o_pwrite_syscsr,
  input  logic          i_pready_syscsr,
  input  logic          i_pslverr_syscsr,
  input  logic [31:0]   i_prdata_syscsr,
  // Slave 3: wdt (Watchdog timer)
  output logic [11:0]   o_paddr_wdt,
  output logic [31:0]   o_pwdata_wdt,
  output logic [ 3:0]   o_pstrb_wdt,
  output logic          o_psel_wdt,
  output logic          o_penable_wdt,
  output logic          o_pwrite_wdt,
  input  logic          i_pready_wdt,
  input  logic          i_pslverr_wdt,
  input  logic [31:0]   i_prdata_wdt,
  // Slave 4: gpio_0 (GPIO bank 0)
  output logic [11:0]   o_paddr_gpio_0,
  output logic [31:0]   o_pwdata_gpio_0,
  output logic [ 3:0]   o_pstrb_gpio_0,
  output logic          o_psel_gpio_0,
  output logic          o_penable_gpio_0,
  output logic          o_pwrite_gpio_0,
  input  logic          i_pready_gpio_0,
  input  logic          i_pslverr_gpio_0,
  input  logic [31:0]   i_prdata_gpio_0,
  // Slave 5: gpio_1 (GPIO bank 1)
  output logic [11:0]   o_paddr_gpio_1,
  output logic [31:0]   o_pwdata_gpio_1,
  output logic [ 3:0]   o_pstrb_gpio_1,
  output logic          o_psel_gpio_1,
  output logic          o_penable_gpio_1,
  output logic          o_pwrite_gpio_1,
  input  logic          i_pready_gpio_1,
  input  logic          i_pslverr_gpio_1,
  input  logic [31:0]   i_prdata_gpio_1,
  // Slave 6: gpio_2 (GPIO bank 2)
  output logic [11:0]   o_paddr_gpio_2,
  output logic [31:0]   o_pwdata_gpio_2,
  output logic [ 3:0]   o_pstrb_gpio_2,
  output logic          o_psel_gpio_2,
  output logic          o_penable_gpio_2,
  output logic          o_pwrite_gpio_2,
  input  logic          i_pready_gpio_2,
  input  logic          i_pslverr_gpio_2,
  input  logic [31:0]   i_prdata_gpio_2,
  // Slave 7: timer_0 (apb_timer_unit, 64-bit mode (QSOC timebase))
  output logic [11:0]   o_paddr_timer_0,
  output logic [31:0]   o_pwdata_timer_0,
  output logic [ 3:0]   o_pstrb_timer_0,
  output logic          o_psel_timer_0,
  output logic          o_penable_timer_0,
  output logic          o_pwrite_timer_0,
  input  logic          i_pready_timer_0,
  input  logic          i_pslverr_timer_0,
  input  logic [31:0]   i_prdata_timer_0,
  // Slave 8: timer_1 (apb_timer_unit, two independent 32-bit timers)
  output logic [11:0]   o_paddr_timer_1,
  output logic [31:0]   o_pwdata_timer_1,
  output logic [ 3:0]   o_pstrb_timer_1,
  output logic          o_psel_timer_1,
  output logic          o_penable_timer_1,
  output logic          o_pwrite_timer_1,
  input  logic          i_pready_timer_1,
  input  logic          i_pslverr_timer_1,
  input  logic [31:0]   i_prdata_timer_1,
  // Slave 9: uart_0 (UART 0 (carries the boot download))
  output logic [11:0]   o_paddr_uart_0,
  output logic [31:0]   o_pwdata_uart_0,
  output logic [ 3:0]   o_pstrb_uart_0,
  output logic          o_psel_uart_0,
  output logic          o_penable_uart_0,
  output logic          o_pwrite_uart_0,
  input  logic          i_pready_uart_0,
  input  logic          i_pslverr_uart_0,
  input  logic [31:0]   i_prdata_uart_0,
  // Slave 10: uart_1 (UART 1)
  output logic [11:0]   o_paddr_uart_1,
  output logic [31:0]   o_pwdata_uart_1,
  output logic [ 3:0]   o_pstrb_uart_1,
  output logic          o_psel_uart_1,
  output logic          o_penable_uart_1,
  output logic          o_pwrite_uart_1,
  input  logic          i_pready_uart_1,
  input  logic          i_pslverr_uart_1,
  input  logic [31:0]   i_prdata_uart_1,
  // Slave 11: spi (SPI host + device (one APB4 slave for both))
  output logic [11:0]   o_paddr_spi,
  output logic [31:0]   o_pwdata_spi,
  output logic [ 3:0]   o_pstrb_spi,
  output logic          o_psel_spi,
  output logic          o_penable_spi,
  output logic          o_pwrite_spi,
  input  logic          i_pready_spi,
  input  logic          i_pslverr_spi,
  input  logic [31:0]   i_prdata_spi,
  // Slave 12: i2c (I2C)
  output logic [11:0]   o_paddr_i2c,
  output logic [31:0]   o_pwdata_i2c,
  output logic [ 3:0]   o_pstrb_i2c,
  output logic          o_psel_i2c,
  output logic          o_penable_i2c,
  output logic          o_pwrite_i2c,
  input  logic          i_pready_i2c,
  input  logic          i_pslverr_i2c,
  input  logic [31:0]   i_prdata_i2c,
  // Slave 13: pwm (PWM (apb_adv_timer))
  output logic [11:0]   o_paddr_pwm,
  output logic [31:0]   o_pwdata_pwm,
  output logic [ 3:0]   o_pstrb_pwm,
  output logic          o_psel_pwm,
  output logic          o_penable_pwm,
  output logic          o_pwrite_pwm,
  input  logic          i_pready_pwm,
  input  logic          i_pslverr_pwm,
  input  logic [31:0]   i_prdata_pwm,
  // Slave 14: dma_cfg (DMA register interface (data path is AXI_S2, not here))
  output logic [11:0]   o_paddr_dma_cfg,
  output logic [31:0]   o_pwdata_dma_cfg,
  output logic [ 3:0]   o_pstrb_dma_cfg,
  output logic          o_psel_dma_cfg,
  output logic          o_penable_dma_cfg,
  output logic          o_pwrite_dma_cfg,
  input  logic          i_pready_dma_cfg,
  input  logic          i_pslverr_dma_cfg,
  input  logic [31:0]   i_prdata_dma_cfg
);

  // Internal signals
  logic w_slave_scrc_sel;
  logic w_slave_syscsr_sel;
  logic w_slave_wdt_sel;
  logic w_slave_gpio_0_sel;
  logic w_slave_gpio_1_sel;
  logic w_slave_gpio_2_sel;
  logic w_slave_timer_0_sel;
  logic w_slave_timer_1_sel;
  logic w_slave_uart_0_sel;
  logic w_slave_uart_1_sel;
  logic w_slave_spi_sel;
  logic w_slave_i2c_sel;
  logic w_slave_pwm_sel;
  logic w_slave_dma_cfg_sel;
  // ============================================================================
  // Address Decode Logic
  // ============================================================================
  assign w_slave_scrc_sel = (i_paddr >= 32'h80000000 & i_paddr <= 32'h80003FFF);
  assign w_slave_syscsr_sel = (i_paddr >= 32'h80004000 & i_paddr <= 32'h80007FFF);
  assign w_slave_wdt_sel = (i_paddr >= 32'h80008000 & i_paddr <= 32'h8000BFFF);
  assign w_slave_gpio_0_sel = (i_paddr >= 32'h8000C000 & i_paddr <= 32'h8000FFFF);
  assign w_slave_gpio_1_sel = (i_paddr >= 32'h80010000 & i_paddr <= 32'h80013FFF);
  assign w_slave_gpio_2_sel = (i_paddr >= 32'h80014000 & i_paddr <= 32'h80017FFF);
  assign w_slave_timer_0_sel = (i_paddr >= 32'h80018000 & i_paddr <= 32'h8001BFFF);
  assign w_slave_timer_1_sel = (i_paddr >= 32'h8001C000 & i_paddr <= 32'h8001FFFF);
  assign w_slave_uart_0_sel = (i_paddr >= 32'h80020000 & i_paddr <= 32'h80023FFF);
  assign w_slave_uart_1_sel = (i_paddr >= 32'h80024000 & i_paddr <= 32'h80027FFF);
  assign w_slave_spi_sel = (i_paddr >= 32'h80028000 & i_paddr <= 32'h8002BFFF);
  assign w_slave_i2c_sel = (i_paddr >= 32'h8002C000 & i_paddr <= 32'h8002FFFF);
  assign w_slave_pwm_sel = (i_paddr >= 32'h80030000 & i_paddr <= 32'h80033FFF);
  assign w_slave_dma_cfg_sel = (i_paddr >= 32'h80034000 & i_paddr <= 32'h80037FFF);

  // ============================================================================
  // PREADY, PSLVERR and PRDATA Generation
  // ============================================================================
  always_comb begin
    casez ({
      w_slave_dma_cfg_sel,
      w_slave_pwm_sel,
      w_slave_i2c_sel,
      w_slave_spi_sel,
      w_slave_uart_1_sel,
      w_slave_uart_0_sel,
      w_slave_timer_1_sel,
      w_slave_timer_0_sel,
      w_slave_gpio_2_sel,
      w_slave_gpio_1_sel,
      w_slave_gpio_0_sel,
      w_slave_wdt_sel,
      w_slave_syscsr_sel,
      w_slave_scrc_sel
    })
      14'b?????????????1: begin
        o_pready  = i_pready_scrc;
        o_pslverr = i_pslverr_scrc;
        o_prdata  = i_prdata_scrc;
      end
      14'b????????????10: begin
        o_pready  = i_pready_syscsr;
        o_pslverr = i_pslverr_syscsr;
        o_prdata  = i_prdata_syscsr;
      end
      14'b???????????100: begin
        o_pready  = i_pready_wdt;
        o_pslverr = i_pslverr_wdt;
        o_prdata  = i_prdata_wdt;
      end
      14'b??????????1000: begin
        o_pready  = i_pready_gpio_0;
        o_pslverr = i_pslverr_gpio_0;
        o_prdata  = i_prdata_gpio_0;
      end
      14'b?????????10000: begin
        o_pready  = i_pready_gpio_1;
        o_pslverr = i_pslverr_gpio_1;
        o_prdata  = i_prdata_gpio_1;
      end
      14'b????????100000: begin
        o_pready  = i_pready_gpio_2;
        o_pslverr = i_pslverr_gpio_2;
        o_prdata  = i_prdata_gpio_2;
      end
      14'b???????1000000: begin
        o_pready  = i_pready_timer_0;
        o_pslverr = i_pslverr_timer_0;
        o_prdata  = i_prdata_timer_0;
      end
      14'b??????10000000: begin
        o_pready  = i_pready_timer_1;
        o_pslverr = i_pslverr_timer_1;
        o_prdata  = i_prdata_timer_1;
      end
      14'b?????100000000: begin
        o_pready  = i_pready_uart_0;
        o_pslverr = i_pslverr_uart_0;
        o_prdata  = i_prdata_uart_0;
      end
      14'b????1000000000: begin
        o_pready  = i_pready_uart_1;
        o_pslverr = i_pslverr_uart_1;
        o_prdata  = i_prdata_uart_1;
      end
      14'b???10000000000: begin
        o_pready  = i_pready_spi;
        o_pslverr = i_pslverr_spi;
        o_prdata  = i_prdata_spi;
      end
      14'b??100000000000: begin
        o_pready  = i_pready_i2c;
        o_pslverr = i_pslverr_i2c;
        o_prdata  = i_prdata_i2c;
      end
      14'b?1000000000000: begin
        o_pready  = i_pready_pwm;
        o_pslverr = i_pslverr_pwm;
        o_prdata  = i_prdata_pwm;
      end
      14'b10000000000000: begin
        o_pready  = i_pready_dma_cfg;
        o_pslverr = i_pslverr_dma_cfg;
        o_prdata  = i_prdata_dma_cfg;
      end
      default: begin
        o_pready  = 1'b1;
        o_pslverr = 1'b1;
        o_prdata  = 32'd0;
      end
    endcase
  end

  // ============================================================================
  // Slave Select Generation
  // ============================================================================
  assign o_psel_scrc    = w_slave_scrc_sel & i_psel;
  assign o_penable_scrc = i_penable;
  assign o_pwrite_scrc  = i_pwrite;
  assign o_paddr_scrc   = i_paddr[11:0];
  assign o_pwdata_scrc  = i_pwdata;
  assign o_pstrb_scrc   = i_pstrb;

  assign o_psel_syscsr    = w_slave_syscsr_sel & i_psel;
  assign o_penable_syscsr = i_penable;
  assign o_pwrite_syscsr  = i_pwrite;
  assign o_paddr_syscsr   = i_paddr[11:0];
  assign o_pwdata_syscsr  = i_pwdata;
  assign o_pstrb_syscsr   = i_pstrb;

  assign o_psel_wdt    = w_slave_wdt_sel & i_psel;
  assign o_penable_wdt = i_penable;
  assign o_pwrite_wdt  = i_pwrite;
  assign o_paddr_wdt   = i_paddr[11:0];
  assign o_pwdata_wdt  = i_pwdata;
  assign o_pstrb_wdt   = i_pstrb;

  assign o_psel_gpio_0    = w_slave_gpio_0_sel & i_psel;
  assign o_penable_gpio_0 = i_penable;
  assign o_pwrite_gpio_0  = i_pwrite;
  assign o_paddr_gpio_0   = i_paddr[11:0];
  assign o_pwdata_gpio_0  = i_pwdata;
  assign o_pstrb_gpio_0   = i_pstrb;

  assign o_psel_gpio_1    = w_slave_gpio_1_sel & i_psel;
  assign o_penable_gpio_1 = i_penable;
  assign o_pwrite_gpio_1  = i_pwrite;
  assign o_paddr_gpio_1   = i_paddr[11:0];
  assign o_pwdata_gpio_1  = i_pwdata;
  assign o_pstrb_gpio_1   = i_pstrb;

  assign o_psel_gpio_2    = w_slave_gpio_2_sel & i_psel;
  assign o_penable_gpio_2 = i_penable;
  assign o_pwrite_gpio_2  = i_pwrite;
  assign o_paddr_gpio_2   = i_paddr[11:0];
  assign o_pwdata_gpio_2  = i_pwdata;
  assign o_pstrb_gpio_2   = i_pstrb;

  assign o_psel_timer_0    = w_slave_timer_0_sel & i_psel;
  assign o_penable_timer_0 = i_penable;
  assign o_pwrite_timer_0  = i_pwrite;
  assign o_paddr_timer_0   = i_paddr[11:0];
  assign o_pwdata_timer_0  = i_pwdata;
  assign o_pstrb_timer_0   = i_pstrb;

  assign o_psel_timer_1    = w_slave_timer_1_sel & i_psel;
  assign o_penable_timer_1 = i_penable;
  assign o_pwrite_timer_1  = i_pwrite;
  assign o_paddr_timer_1   = i_paddr[11:0];
  assign o_pwdata_timer_1  = i_pwdata;
  assign o_pstrb_timer_1   = i_pstrb;

  assign o_psel_uart_0    = w_slave_uart_0_sel & i_psel;
  assign o_penable_uart_0 = i_penable;
  assign o_pwrite_uart_0  = i_pwrite;
  assign o_paddr_uart_0   = i_paddr[11:0];
  assign o_pwdata_uart_0  = i_pwdata;
  assign o_pstrb_uart_0   = i_pstrb;

  assign o_psel_uart_1    = w_slave_uart_1_sel & i_psel;
  assign o_penable_uart_1 = i_penable;
  assign o_pwrite_uart_1  = i_pwrite;
  assign o_paddr_uart_1   = i_paddr[11:0];
  assign o_pwdata_uart_1  = i_pwdata;
  assign o_pstrb_uart_1   = i_pstrb;

  assign o_psel_spi    = w_slave_spi_sel & i_psel;
  assign o_penable_spi = i_penable;
  assign o_pwrite_spi  = i_pwrite;
  assign o_paddr_spi   = i_paddr[11:0];
  assign o_pwdata_spi  = i_pwdata;
  assign o_pstrb_spi   = i_pstrb;

  assign o_psel_i2c    = w_slave_i2c_sel & i_psel;
  assign o_penable_i2c = i_penable;
  assign o_pwrite_i2c  = i_pwrite;
  assign o_paddr_i2c   = i_paddr[11:0];
  assign o_pwdata_i2c  = i_pwdata;
  assign o_pstrb_i2c   = i_pstrb;

  assign o_psel_pwm    = w_slave_pwm_sel & i_psel;
  assign o_penable_pwm = i_penable;
  assign o_pwrite_pwm  = i_pwrite;
  assign o_paddr_pwm   = i_paddr[11:0];
  assign o_pwdata_pwm  = i_pwdata;
  assign o_pstrb_pwm   = i_pstrb;

  assign o_psel_dma_cfg    = w_slave_dma_cfg_sel & i_psel;
  assign o_penable_dma_cfg = i_penable;
  assign o_pwrite_dma_cfg  = i_pwrite;
  assign o_paddr_dma_cfg   = i_paddr[11:0];
  assign o_pwdata_dma_cfg  = i_pwdata;
  assign o_pstrb_dma_cfg   = i_pstrb;

endmodule
