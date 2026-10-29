`timescale 1ns/1ps
//--------------------------------------
//Project: APB BUS Generator
//Module: m_qnsc_p_bus_dec
//Function: APB Decoder
//Author: apb-bus-generator
//Script Author: Trthinh (Ethan), Thang Luong (superzeldalink)
//Page: VLSI Technology
//--------------------------------------

module m_qnsc_p_bus_dec (
  // ============================================================================
  // Interface of Master AXI2APB
  // ============================================================================
  input  logic [17:0]   i_paddr,
  input  logic          i_protect_en,
  input  logic          i_slverr_en,
  input  logic [2:0]    i_pprot,
  input  logic [31:0]   i_pwdata,
  input  logic          i_pwrite,
  input  logic          i_penable,
  input  logic          i_psel,
  input  logic [3:0]    i_pstrb,
  output logic          o_pslverr,
  output logic          o_pready,
  output logic [31:0]   o_prdata,
  // ============================================================================
  // Interface of Slave SCRC
  // ============================================================================
  output logic [13:0]   o_paddr_scrc,  // to SCRC
  output logic          o_protect_en_scrc,
  output logic          o_slverr_en_scrc,
  output logic [2:0]    o_pprot_scrc,
  output logic [31:0]   o_pwdata_scrc,
  output logic          o_pwrite_scrc,
  output logic          o_penable_scrc,
  output logic          o_psel_scrc,
  output logic [3:0]    o_pstrb_scrc,
  input  logic          i_pslverr_scrc,
  input  logic          i_pready_scrc,
  input  logic [31:0]   i_prdata_scrc,
  // ============================================================================
  // Interface of Slave SYSCSR
  // ============================================================================
  output logic [13:0]   o_paddr_syscsr,  // to SYSCSR
  output logic          o_protect_en_syscsr,
  output logic          o_slverr_en_syscsr,
  output logic [2:0]    o_pprot_syscsr,
  output logic [31:0]   o_pwdata_syscsr,
  output logic          o_pwrite_syscsr,
  output logic          o_penable_syscsr,
  output logic          o_psel_syscsr,
  output logic [3:0]    o_pstrb_syscsr,
  input  logic          i_pslverr_syscsr,
  input  logic          i_pready_syscsr,
  input  logic [31:0]   i_prdata_syscsr,
  // ============================================================================
  // Interface of Slave WDT
  // ============================================================================
  output logic [13:0]   o_paddr_wdt,  // to WDT
  output logic          o_protect_en_wdt,
  output logic          o_slverr_en_wdt,
  output logic [2:0]    o_pprot_wdt,
  output logic [31:0]   o_pwdata_wdt,
  output logic          o_pwrite_wdt,
  output logic          o_penable_wdt,
  output logic          o_psel_wdt,
  output logic [3:0]    o_pstrb_wdt,
  input  logic          i_pslverr_wdt,
  input  logic          i_pready_wdt,
  input  logic [31:0]   i_prdata_wdt,
  // ============================================================================
  // Interface of Slave GPIO_0
  // ============================================================================
  output logic [13:0]   o_paddr_gpio_0,  // to GPIO_0
  output logic          o_protect_en_gpio_0,
  output logic          o_slverr_en_gpio_0,
  output logic [2:0]    o_pprot_gpio_0,
  output logic [31:0]   o_pwdata_gpio_0,
  output logic          o_pwrite_gpio_0,
  output logic          o_penable_gpio_0,
  output logic          o_psel_gpio_0,
  output logic [3:0]    o_pstrb_gpio_0,
  input  logic          i_pslverr_gpio_0,
  input  logic          i_pready_gpio_0,
  input  logic [31:0]   i_prdata_gpio_0,
  // ============================================================================
  // Interface of Slave GPIO_1
  // ============================================================================
  output logic [13:0]   o_paddr_gpio_1,  // to GPIO_1
  output logic          o_protect_en_gpio_1,
  output logic          o_slverr_en_gpio_1,
  output logic [2:0]    o_pprot_gpio_1,
  output logic [31:0]   o_pwdata_gpio_1,
  output logic          o_pwrite_gpio_1,
  output logic          o_penable_gpio_1,
  output logic          o_psel_gpio_1,
  output logic [3:0]    o_pstrb_gpio_1,
  input  logic          i_pslverr_gpio_1,
  input  logic          i_pready_gpio_1,
  input  logic [31:0]   i_prdata_gpio_1,
  // ============================================================================
  // Interface of Slave GPIO_2
  // ============================================================================
  output logic [13:0]   o_paddr_gpio_2,  // to GPIO_2
  output logic          o_protect_en_gpio_2,
  output logic          o_slverr_en_gpio_2,
  output logic [2:0]    o_pprot_gpio_2,
  output logic [31:0]   o_pwdata_gpio_2,
  output logic          o_pwrite_gpio_2,
  output logic          o_penable_gpio_2,
  output logic          o_psel_gpio_2,
  output logic [3:0]    o_pstrb_gpio_2,
  input  logic          i_pslverr_gpio_2,
  input  logic          i_pready_gpio_2,
  input  logic [31:0]   i_prdata_gpio_2,
  // ============================================================================
  // Interface of Slave TIMER_0
  // ============================================================================
  output logic [13:0]   o_paddr_timer_0,  // to TIMER_0
  output logic          o_protect_en_timer_0,
  output logic          o_slverr_en_timer_0,
  output logic [2:0]    o_pprot_timer_0,
  output logic [31:0]   o_pwdata_timer_0,
  output logic          o_pwrite_timer_0,
  output logic          o_penable_timer_0,
  output logic          o_psel_timer_0,
  output logic [3:0]    o_pstrb_timer_0,
  input  logic          i_pslverr_timer_0,
  input  logic          i_pready_timer_0,
  input  logic [31:0]   i_prdata_timer_0,
  // ============================================================================
  // Interface of Slave TIMER_1
  // ============================================================================
  output logic [13:0]   o_paddr_timer_1,  // to TIMER_1
  output logic          o_protect_en_timer_1,
  output logic          o_slverr_en_timer_1,
  output logic [2:0]    o_pprot_timer_1,
  output logic [31:0]   o_pwdata_timer_1,
  output logic          o_pwrite_timer_1,
  output logic          o_penable_timer_1,
  output logic          o_psel_timer_1,
  output logic [3:0]    o_pstrb_timer_1,
  input  logic          i_pslverr_timer_1,
  input  logic          i_pready_timer_1,
  input  logic [31:0]   i_prdata_timer_1,
  // ============================================================================
  // Interface of Slave UART_0
  // ============================================================================
  output logic [13:0]   o_paddr_uart_0,  // to UART_0
  output logic          o_protect_en_uart_0,
  output logic          o_slverr_en_uart_0,
  output logic [2:0]    o_pprot_uart_0,
  output logic [31:0]   o_pwdata_uart_0,
  output logic          o_pwrite_uart_0,
  output logic          o_penable_uart_0,
  output logic          o_psel_uart_0,
  output logic [3:0]    o_pstrb_uart_0,
  input  logic          i_pslverr_uart_0,
  input  logic          i_pready_uart_0,
  input  logic [31:0]   i_prdata_uart_0,
  // ============================================================================
  // Interface of Slave UART_1
  // ============================================================================
  output logic [13:0]   o_paddr_uart_1,  // to UART_1
  output logic          o_protect_en_uart_1,
  output logic          o_slverr_en_uart_1,
  output logic [2:0]    o_pprot_uart_1,
  output logic [31:0]   o_pwdata_uart_1,
  output logic          o_pwrite_uart_1,
  output logic          o_penable_uart_1,
  output logic          o_psel_uart_1,
  output logic [3:0]    o_pstrb_uart_1,
  input  logic          i_pslverr_uart_1,
  input  logic          i_pready_uart_1,
  input  logic [31:0]   i_prdata_uart_1,
  // ============================================================================
  // Interface of Slave SPI
  // ============================================================================
  output logic [13:0]   o_paddr_spi,  // to SPI
  output logic          o_protect_en_spi,
  output logic          o_slverr_en_spi,
  output logic [2:0]    o_pprot_spi,
  output logic [31:0]   o_pwdata_spi,
  output logic          o_pwrite_spi,
  output logic          o_penable_spi,
  output logic          o_psel_spi,
  output logic [3:0]    o_pstrb_spi,
  input  logic          i_pslverr_spi,
  input  logic          i_pready_spi,
  input  logic [31:0]   i_prdata_spi,
  // ============================================================================
  // Interface of Slave I2C
  // ============================================================================
  output logic [13:0]   o_paddr_i2c,  // to I2C
  output logic          o_protect_en_i2c,
  output logic          o_slverr_en_i2c,
  output logic [2:0]    o_pprot_i2c,
  output logic [31:0]   o_pwdata_i2c,
  output logic          o_pwrite_i2c,
  output logic          o_penable_i2c,
  output logic          o_psel_i2c,
  output logic [3:0]    o_pstrb_i2c,
  input  logic          i_pslverr_i2c,
  input  logic          i_pready_i2c,
  input  logic [31:0]   i_prdata_i2c,
  // ============================================================================
  // Interface of Slave PWM
  // ============================================================================
  output logic [13:0]   o_paddr_pwm,  // to PWM
  output logic          o_protect_en_pwm,
  output logic          o_slverr_en_pwm,
  output logic [2:0]    o_pprot_pwm,
  output logic [31:0]   o_pwdata_pwm,
  output logic          o_pwrite_pwm,
  output logic          o_penable_pwm,
  output logic          o_psel_pwm,
  output logic [3:0]    o_pstrb_pwm,
  input  logic          i_pslverr_pwm,
  input  logic          i_pready_pwm,
  input  logic [31:0]   i_prdata_pwm,
  // ============================================================================
  // Interface of Slave DMA_CFG
  // ============================================================================
  output logic [13:0]   o_paddr_dma_cfg,  // to DMA_CFG
  output logic          o_protect_en_dma_cfg,
  output logic          o_slverr_en_dma_cfg,
  output logic [2:0]    o_pprot_dma_cfg,
  output logic [31:0]   o_pwdata_dma_cfg,
  output logic          o_pwrite_dma_cfg,
  output logic          o_penable_dma_cfg,
  output logic          o_psel_dma_cfg,
  output logic [3:0]    o_pstrb_dma_cfg,
  input  logic          i_pslverr_dma_cfg,
  input  logic          i_pready_dma_cfg,
  input  logic [31:0]   i_prdata_dma_cfg
);
  logic [13:0] w_sel;

  // ============================================================================
  // Address Decode Logic
  // ============================================================================
  assign w_sel[0] = (i_paddr <= 18'h03FFF);  // SCRC
  assign w_sel[1] = (i_paddr >= 18'h04000) & (i_paddr <= 18'h07FFF);  // SYSCSR
  assign w_sel[2] = (i_paddr >= 18'h08000) & (i_paddr <= 18'h0BFFF);  // WDT
  assign w_sel[3] = (i_paddr >= 18'h0C000) & (i_paddr <= 18'h0FFFF);  // GPIO_0
  assign w_sel[4] = (i_paddr >= 18'h10000) & (i_paddr <= 18'h13FFF);  // GPIO_1
  assign w_sel[5] = (i_paddr >= 18'h14000) & (i_paddr <= 18'h17FFF);  // GPIO_2
  assign w_sel[6] = (i_paddr >= 18'h18000) & (i_paddr <= 18'h1BFFF);  // TIMER_0
  assign w_sel[7] = (i_paddr >= 18'h1C000) & (i_paddr <= 18'h1FFFF);  // TIMER_1
  assign w_sel[8] = (i_paddr >= 18'h20000) & (i_paddr <= 18'h23FFF);  // UART_0
  assign w_sel[9] = (i_paddr >= 18'h24000) & (i_paddr <= 18'h27FFF);  // UART_1
  assign w_sel[10] = (i_paddr >= 18'h28000) & (i_paddr <= 18'h2BFFF);  // SPI
  assign w_sel[11] = (i_paddr >= 18'h2C000) & (i_paddr <= 18'h2FFFF);  // I2C
  assign w_sel[12] = (i_paddr >= 18'h30000) & (i_paddr <= 18'h33FFF);  // PWM
  assign w_sel[13] = (i_paddr >= 18'h34000) & (i_paddr <= 18'h37FFF);  // DMA_CFG

  // ============================================================================
  // PREADY, PSLVERR, PRDATA Logic
  // ============================================================================
  always_comb begin
    casez (w_sel)
      14'b00000000000001: begin  // SCRC
        o_pready  = i_pready_scrc;
        o_pslverr = i_pslverr_scrc;
        o_prdata  = i_prdata_scrc;
      end
      14'b00000000000010: begin  // SYSCSR
        o_pready  = i_pready_syscsr;
        o_pslverr = i_pslverr_syscsr;
        o_prdata  = i_prdata_syscsr;
      end
      14'b00000000000100: begin  // WDT
        o_pready  = i_pready_wdt;
        o_pslverr = i_pslverr_wdt;
        o_prdata  = i_prdata_wdt;
      end
      14'b00000000001000: begin  // GPIO_0
        o_pready  = i_pready_gpio_0;
        o_pslverr = i_pslverr_gpio_0;
        o_prdata  = i_prdata_gpio_0;
      end
      14'b00000000010000: begin  // GPIO_1
        o_pready  = i_pready_gpio_1;
        o_pslverr = i_pslverr_gpio_1;
        o_prdata  = i_prdata_gpio_1;
      end
      14'b00000000100000: begin  // GPIO_2
        o_pready  = i_pready_gpio_2;
        o_pslverr = i_pslverr_gpio_2;
        o_prdata  = i_prdata_gpio_2;
      end
      14'b00000001000000: begin  // TIMER_0
        o_pready  = i_pready_timer_0;
        o_pslverr = i_pslverr_timer_0;
        o_prdata  = i_prdata_timer_0;
      end
      14'b00000010000000: begin  // TIMER_1
        o_pready  = i_pready_timer_1;
        o_pslverr = i_pslverr_timer_1;
        o_prdata  = i_prdata_timer_1;
      end
      14'b00000100000000: begin  // UART_0
        o_pready  = i_pready_uart_0;
        o_pslverr = i_pslverr_uart_0;
        o_prdata  = i_prdata_uart_0;
      end
      14'b00001000000000: begin  // UART_1
        o_pready  = i_pready_uart_1;
        o_pslverr = i_pslverr_uart_1;
        o_prdata  = i_prdata_uart_1;
      end
      14'b00010000000000: begin  // SPI
        o_pready  = i_pready_spi;
        o_pslverr = i_pslverr_spi;
        o_prdata  = i_prdata_spi;
      end
      14'b00100000000000: begin  // I2C
        o_pready  = i_pready_i2c;
        o_pslverr = i_pslverr_i2c;
        o_prdata  = i_prdata_i2c;
      end
      14'b01000000000000: begin  // PWM
        o_pready  = i_pready_pwm;
        o_pslverr = i_pslverr_pwm;
        o_prdata  = i_prdata_pwm;
      end
      14'b10000000000000: begin  // DMA_CFG
        o_pready  = i_pready_dma_cfg;
        o_pslverr = i_pslverr_dma_cfg;
        o_prdata  = i_prdata_dma_cfg;
      end
      default: begin  // Unmapped access
        o_pready  = 1'b1;
        o_pslverr = 1'b1;
        o_prdata  = 32'd0;
      end
    endcase
  end

  // ============================================================================
  // Slave Select and Signal Routing
  // ============================================================================
  // SCRC
  assign o_psel_scrc       = w_sel[0] & i_psel;
  assign o_penable_scrc    = i_penable;
  assign o_pwrite_scrc     = i_pwrite;
  assign o_paddr_scrc      = 14'(i_paddr);
  assign o_pwdata_scrc     = i_pwdata;
  assign o_pstrb_scrc      = i_pstrb;
  assign o_protect_en_scrc    = i_protect_en;
  assign o_slverr_en_scrc     = i_slverr_en;
  assign o_pprot_scrc         = i_pprot;

  // SYSCSR
  assign o_psel_syscsr     = w_sel[1] & i_psel;
  assign o_penable_syscsr  = i_penable;
  assign o_pwrite_syscsr   = i_pwrite;
  assign o_paddr_syscsr    = 14'(i_paddr - 18'h04000);
  assign o_pwdata_syscsr   = i_pwdata;
  assign o_pstrb_syscsr    = i_pstrb;
  assign o_protect_en_syscsr  = i_protect_en;
  assign o_slverr_en_syscsr   = i_slverr_en;
  assign o_pprot_syscsr       = i_pprot;

  // WDT
  assign o_psel_wdt        = w_sel[2] & i_psel;
  assign o_penable_wdt     = i_penable;
  assign o_pwrite_wdt      = i_pwrite;
  assign o_paddr_wdt       = 14'(i_paddr - 18'h08000);
  assign o_pwdata_wdt      = i_pwdata;
  assign o_pstrb_wdt       = i_pstrb;
  assign o_protect_en_wdt     = i_protect_en;
  assign o_slverr_en_wdt      = i_slverr_en;
  assign o_pprot_wdt          = i_pprot;

  // GPIO_0
  assign o_psel_gpio_0     = w_sel[3] & i_psel;
  assign o_penable_gpio_0  = i_penable;
  assign o_pwrite_gpio_0   = i_pwrite;
  assign o_paddr_gpio_0    = 14'(i_paddr - 18'h0C000);
  assign o_pwdata_gpio_0   = i_pwdata;
  assign o_pstrb_gpio_0    = i_pstrb;
  assign o_protect_en_gpio_0  = i_protect_en;
  assign o_slverr_en_gpio_0   = i_slverr_en;
  assign o_pprot_gpio_0       = i_pprot;

  // GPIO_1
  assign o_psel_gpio_1     = w_sel[4] & i_psel;
  assign o_penable_gpio_1  = i_penable;
  assign o_pwrite_gpio_1   = i_pwrite;
  assign o_paddr_gpio_1    = 14'(i_paddr - 18'h10000);
  assign o_pwdata_gpio_1   = i_pwdata;
  assign o_pstrb_gpio_1    = i_pstrb;
  assign o_protect_en_gpio_1  = i_protect_en;
  assign o_slverr_en_gpio_1   = i_slverr_en;
  assign o_pprot_gpio_1       = i_pprot;

  // GPIO_2
  assign o_psel_gpio_2     = w_sel[5] & i_psel;
  assign o_penable_gpio_2  = i_penable;
  assign o_pwrite_gpio_2   = i_pwrite;
  assign o_paddr_gpio_2    = 14'(i_paddr - 18'h14000);
  assign o_pwdata_gpio_2   = i_pwdata;
  assign o_pstrb_gpio_2    = i_pstrb;
  assign o_protect_en_gpio_2  = i_protect_en;
  assign o_slverr_en_gpio_2   = i_slverr_en;
  assign o_pprot_gpio_2       = i_pprot;

  // TIMER_0
  assign o_psel_timer_0    = w_sel[6] & i_psel;
  assign o_penable_timer_0 = i_penable;
  assign o_pwrite_timer_0  = i_pwrite;
  assign o_paddr_timer_0   = 14'(i_paddr - 18'h18000);
  assign o_pwdata_timer_0  = i_pwdata;
  assign o_pstrb_timer_0   = i_pstrb;
  assign o_protect_en_timer_0 = i_protect_en;
  assign o_slverr_en_timer_0  = i_slverr_en;
  assign o_pprot_timer_0      = i_pprot;

  // TIMER_1
  assign o_psel_timer_1    = w_sel[7] & i_psel;
  assign o_penable_timer_1 = i_penable;
  assign o_pwrite_timer_1  = i_pwrite;
  assign o_paddr_timer_1   = 14'(i_paddr - 18'h1C000);
  assign o_pwdata_timer_1  = i_pwdata;
  assign o_pstrb_timer_1   = i_pstrb;
  assign o_protect_en_timer_1 = i_protect_en;
  assign o_slverr_en_timer_1  = i_slverr_en;
  assign o_pprot_timer_1      = i_pprot;

  // UART_0
  assign o_psel_uart_0     = w_sel[8] & i_psel;
  assign o_penable_uart_0  = i_penable;
  assign o_pwrite_uart_0   = i_pwrite;
  assign o_paddr_uart_0    = 14'(i_paddr - 18'h20000);
  assign o_pwdata_uart_0   = i_pwdata;
  assign o_pstrb_uart_0    = i_pstrb;
  assign o_protect_en_uart_0  = i_protect_en;
  assign o_slverr_en_uart_0   = i_slverr_en;
  assign o_pprot_uart_0       = i_pprot;

  // UART_1
  assign o_psel_uart_1     = w_sel[9] & i_psel;
  assign o_penable_uart_1  = i_penable;
  assign o_pwrite_uart_1   = i_pwrite;
  assign o_paddr_uart_1    = 14'(i_paddr - 18'h24000);
  assign o_pwdata_uart_1   = i_pwdata;
  assign o_pstrb_uart_1    = i_pstrb;
  assign o_protect_en_uart_1  = i_protect_en;
  assign o_slverr_en_uart_1   = i_slverr_en;
  assign o_pprot_uart_1       = i_pprot;

  // SPI
  assign o_psel_spi        = w_sel[10] & i_psel;
  assign o_penable_spi     = i_penable;
  assign o_pwrite_spi      = i_pwrite;
  assign o_paddr_spi       = 14'(i_paddr - 18'h28000);
  assign o_pwdata_spi      = i_pwdata;
  assign o_pstrb_spi       = i_pstrb;
  assign o_protect_en_spi     = i_protect_en;
  assign o_slverr_en_spi      = i_slverr_en;
  assign o_pprot_spi          = i_pprot;

  // I2C
  assign o_psel_i2c        = w_sel[11] & i_psel;
  assign o_penable_i2c     = i_penable;
  assign o_pwrite_i2c      = i_pwrite;
  assign o_paddr_i2c       = 14'(i_paddr - 18'h2C000);
  assign o_pwdata_i2c      = i_pwdata;
  assign o_pstrb_i2c       = i_pstrb;
  assign o_protect_en_i2c     = i_protect_en;
  assign o_slverr_en_i2c      = i_slverr_en;
  assign o_pprot_i2c          = i_pprot;

  // PWM
  assign o_psel_pwm        = w_sel[12] & i_psel;
  assign o_penable_pwm     = i_penable;
  assign o_pwrite_pwm      = i_pwrite;
  assign o_paddr_pwm       = 14'(i_paddr - 18'h30000);
  assign o_pwdata_pwm      = i_pwdata;
  assign o_pstrb_pwm       = i_pstrb;
  assign o_protect_en_pwm     = i_protect_en;
  assign o_slverr_en_pwm      = i_slverr_en;
  assign o_pprot_pwm          = i_pprot;

  // DMA_CFG
  assign o_psel_dma_cfg    = w_sel[13] & i_psel;
  assign o_penable_dma_cfg = i_penable;
  assign o_pwrite_dma_cfg  = i_pwrite;
  assign o_paddr_dma_cfg   = 14'(i_paddr - 18'h34000);
  assign o_pwdata_dma_cfg  = i_pwdata;
  assign o_pstrb_dma_cfg   = i_pstrb;
  assign o_protect_en_dma_cfg = i_protect_en;
  assign o_slverr_en_dma_cfg  = i_slverr_en;
  assign o_pprot_dma_cfg      = i_pprot;


endmodule
