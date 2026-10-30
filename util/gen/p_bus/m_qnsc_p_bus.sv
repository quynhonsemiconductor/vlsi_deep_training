`timescale 1ns/1ps
//--------------------------------------
//Project: APB BUS Generator
//Module: m_qnsc_p_bus
//Function: APB Router Top-Level
//Author: apb-bus-generator
//Script Author: Trthinh (Ethan), Thang Luong (superzeldalink)
//Page: VLSI Technology
//--------------------------------------

module m_qnsc_p_bus (
  // ============================================================================
  // Global Signals
  // ============================================================================
  input  logic          i_clk,
  input  logic          i_rstn,

  // ============================================================================
  // Master Interfaces
  // ============================================================================
  // Master: AXI2APB
  input  logic [17:0]   i_paddr_axi2apb,
  input  logic          i_protect_en_axi2apb,
  input  logic          i_slverr_en_axi2apb,
  input  logic [2:0]    i_pprot_axi2apb,
  input  logic [31:0]   i_pwdata_axi2apb,
  input  logic          i_pwrite_axi2apb,
  input  logic          i_penable_axi2apb,
  input  logic          i_psel_axi2apb,
  input  logic [3:0]    i_pstrb_axi2apb,
  output logic          o_pslverr_axi2apb,
  output logic          o_pready_axi2apb,
  output logic [31:0]   o_prdata_axi2apb,

  // ============================================================================
  // Slave Interfaces
  // ============================================================================
  // Slave: SCRC
  output logic [13:0]   o_paddr_scrc,
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

  // Slave: SYSCSR
  output logic [13:0]   o_paddr_syscsr,
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

  // Slave: WDT
  output logic [13:0]   o_paddr_wdt,
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

  // Slave: GPIO_0
  output logic [13:0]   o_paddr_gpio_0,
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

  // Slave: GPIO_1
  output logic [13:0]   o_paddr_gpio_1,
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

  // Slave: GPIO_2
  output logic [13:0]   o_paddr_gpio_2,
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

  // Slave: TIMER_0
  output logic [13:0]   o_paddr_timer_0,
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

  // Slave: TIMER_1
  output logic [13:0]   o_paddr_timer_1,
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

  // Slave: UART_0
  output logic [13:0]   o_paddr_uart_0,
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

  // Slave: UART_1
  output logic [13:0]   o_paddr_uart_1,
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

  // Slave: SPI
  output logic [13:0]   o_paddr_spi,
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

  // Slave: I2C
  output logic [13:0]   o_paddr_i2c,
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

  // Slave: PWM
  output logic [13:0]   o_paddr_pwm,
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

  // Slave: DMA_CFG
  output logic [13:0]   o_paddr_dma_cfg,
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

  // ============================================================================
  // Internal Interconnect Wires
  // ============================================================================
  // Decoder <-> Arbiter per master-slave connections
  logic [13:0]   w_dec_paddr_dma_cfg_axi2apb;
  logic          w_dec_protect_en_dma_cfg_axi2apb;
  logic          w_dec_slverr_en_dma_cfg_axi2apb;
  logic [2:0]    w_dec_pprot_dma_cfg_axi2apb;
  logic [31:0]   w_dec_pwdata_dma_cfg_axi2apb;
  logic          w_dec_pwrite_dma_cfg_axi2apb;
  logic          w_dec_penable_dma_cfg_axi2apb;
  logic          w_dec_psel_dma_cfg_axi2apb;
  logic [3:0]    w_dec_pstrb_dma_cfg_axi2apb;
  logic          w_arb_pslverr_dma_cfg_axi2apb;
  logic          w_arb_pready_dma_cfg_axi2apb;
  logic [31:0]   w_arb_prdata_dma_cfg_axi2apb;
  logic [13:0]   w_dec_paddr_gpio_0_axi2apb;
  logic          w_dec_protect_en_gpio_0_axi2apb;
  logic          w_dec_slverr_en_gpio_0_axi2apb;
  logic [2:0]    w_dec_pprot_gpio_0_axi2apb;
  logic [31:0]   w_dec_pwdata_gpio_0_axi2apb;
  logic          w_dec_pwrite_gpio_0_axi2apb;
  logic          w_dec_penable_gpio_0_axi2apb;
  logic          w_dec_psel_gpio_0_axi2apb;
  logic [3:0]    w_dec_pstrb_gpio_0_axi2apb;
  logic          w_arb_pslverr_gpio_0_axi2apb;
  logic          w_arb_pready_gpio_0_axi2apb;
  logic [31:0]   w_arb_prdata_gpio_0_axi2apb;
  logic [13:0]   w_dec_paddr_gpio_1_axi2apb;
  logic          w_dec_protect_en_gpio_1_axi2apb;
  logic          w_dec_slverr_en_gpio_1_axi2apb;
  logic [2:0]    w_dec_pprot_gpio_1_axi2apb;
  logic [31:0]   w_dec_pwdata_gpio_1_axi2apb;
  logic          w_dec_pwrite_gpio_1_axi2apb;
  logic          w_dec_penable_gpio_1_axi2apb;
  logic          w_dec_psel_gpio_1_axi2apb;
  logic [3:0]    w_dec_pstrb_gpio_1_axi2apb;
  logic          w_arb_pslverr_gpio_1_axi2apb;
  logic          w_arb_pready_gpio_1_axi2apb;
  logic [31:0]   w_arb_prdata_gpio_1_axi2apb;
  logic [13:0]   w_dec_paddr_gpio_2_axi2apb;
  logic          w_dec_protect_en_gpio_2_axi2apb;
  logic          w_dec_slverr_en_gpio_2_axi2apb;
  logic [2:0]    w_dec_pprot_gpio_2_axi2apb;
  logic [31:0]   w_dec_pwdata_gpio_2_axi2apb;
  logic          w_dec_pwrite_gpio_2_axi2apb;
  logic          w_dec_penable_gpio_2_axi2apb;
  logic          w_dec_psel_gpio_2_axi2apb;
  logic [3:0]    w_dec_pstrb_gpio_2_axi2apb;
  logic          w_arb_pslverr_gpio_2_axi2apb;
  logic          w_arb_pready_gpio_2_axi2apb;
  logic [31:0]   w_arb_prdata_gpio_2_axi2apb;
  logic [13:0]   w_dec_paddr_i2c_axi2apb;
  logic          w_dec_protect_en_i2c_axi2apb;
  logic          w_dec_slverr_en_i2c_axi2apb;
  logic [2:0]    w_dec_pprot_i2c_axi2apb;
  logic [31:0]   w_dec_pwdata_i2c_axi2apb;
  logic          w_dec_pwrite_i2c_axi2apb;
  logic          w_dec_penable_i2c_axi2apb;
  logic          w_dec_psel_i2c_axi2apb;
  logic [3:0]    w_dec_pstrb_i2c_axi2apb;
  logic          w_arb_pslverr_i2c_axi2apb;
  logic          w_arb_pready_i2c_axi2apb;
  logic [31:0]   w_arb_prdata_i2c_axi2apb;
  logic [13:0]   w_dec_paddr_pwm_axi2apb;
  logic          w_dec_protect_en_pwm_axi2apb;
  logic          w_dec_slverr_en_pwm_axi2apb;
  logic [2:0]    w_dec_pprot_pwm_axi2apb;
  logic [31:0]   w_dec_pwdata_pwm_axi2apb;
  logic          w_dec_pwrite_pwm_axi2apb;
  logic          w_dec_penable_pwm_axi2apb;
  logic          w_dec_psel_pwm_axi2apb;
  logic [3:0]    w_dec_pstrb_pwm_axi2apb;
  logic          w_arb_pslverr_pwm_axi2apb;
  logic          w_arb_pready_pwm_axi2apb;
  logic [31:0]   w_arb_prdata_pwm_axi2apb;
  logic [13:0]   w_dec_paddr_scrc_axi2apb;
  logic          w_dec_protect_en_scrc_axi2apb;
  logic          w_dec_slverr_en_scrc_axi2apb;
  logic [2:0]    w_dec_pprot_scrc_axi2apb;
  logic [31:0]   w_dec_pwdata_scrc_axi2apb;
  logic          w_dec_pwrite_scrc_axi2apb;
  logic          w_dec_penable_scrc_axi2apb;
  logic          w_dec_psel_scrc_axi2apb;
  logic [3:0]    w_dec_pstrb_scrc_axi2apb;
  logic          w_arb_pslverr_scrc_axi2apb;
  logic          w_arb_pready_scrc_axi2apb;
  logic [31:0]   w_arb_prdata_scrc_axi2apb;
  logic [13:0]   w_dec_paddr_spi_axi2apb;
  logic          w_dec_protect_en_spi_axi2apb;
  logic          w_dec_slverr_en_spi_axi2apb;
  logic [2:0]    w_dec_pprot_spi_axi2apb;
  logic [31:0]   w_dec_pwdata_spi_axi2apb;
  logic          w_dec_pwrite_spi_axi2apb;
  logic          w_dec_penable_spi_axi2apb;
  logic          w_dec_psel_spi_axi2apb;
  logic [3:0]    w_dec_pstrb_spi_axi2apb;
  logic          w_arb_pslverr_spi_axi2apb;
  logic          w_arb_pready_spi_axi2apb;
  logic [31:0]   w_arb_prdata_spi_axi2apb;
  logic [13:0]   w_dec_paddr_syscsr_axi2apb;
  logic          w_dec_protect_en_syscsr_axi2apb;
  logic          w_dec_slverr_en_syscsr_axi2apb;
  logic [2:0]    w_dec_pprot_syscsr_axi2apb;
  logic [31:0]   w_dec_pwdata_syscsr_axi2apb;
  logic          w_dec_pwrite_syscsr_axi2apb;
  logic          w_dec_penable_syscsr_axi2apb;
  logic          w_dec_psel_syscsr_axi2apb;
  logic [3:0]    w_dec_pstrb_syscsr_axi2apb;
  logic          w_arb_pslverr_syscsr_axi2apb;
  logic          w_arb_pready_syscsr_axi2apb;
  logic [31:0]   w_arb_prdata_syscsr_axi2apb;
  logic [13:0]   w_dec_paddr_timer_0_axi2apb;
  logic          w_dec_protect_en_timer_0_axi2apb;
  logic          w_dec_slverr_en_timer_0_axi2apb;
  logic [2:0]    w_dec_pprot_timer_0_axi2apb;
  logic [31:0]   w_dec_pwdata_timer_0_axi2apb;
  logic          w_dec_pwrite_timer_0_axi2apb;
  logic          w_dec_penable_timer_0_axi2apb;
  logic          w_dec_psel_timer_0_axi2apb;
  logic [3:0]    w_dec_pstrb_timer_0_axi2apb;
  logic          w_arb_pslverr_timer_0_axi2apb;
  logic          w_arb_pready_timer_0_axi2apb;
  logic [31:0]   w_arb_prdata_timer_0_axi2apb;
  logic [13:0]   w_dec_paddr_timer_1_axi2apb;
  logic          w_dec_protect_en_timer_1_axi2apb;
  logic          w_dec_slverr_en_timer_1_axi2apb;
  logic [2:0]    w_dec_pprot_timer_1_axi2apb;
  logic [31:0]   w_dec_pwdata_timer_1_axi2apb;
  logic          w_dec_pwrite_timer_1_axi2apb;
  logic          w_dec_penable_timer_1_axi2apb;
  logic          w_dec_psel_timer_1_axi2apb;
  logic [3:0]    w_dec_pstrb_timer_1_axi2apb;
  logic          w_arb_pslverr_timer_1_axi2apb;
  logic          w_arb_pready_timer_1_axi2apb;
  logic [31:0]   w_arb_prdata_timer_1_axi2apb;
  logic [13:0]   w_dec_paddr_uart_0_axi2apb;
  logic          w_dec_protect_en_uart_0_axi2apb;
  logic          w_dec_slverr_en_uart_0_axi2apb;
  logic [2:0]    w_dec_pprot_uart_0_axi2apb;
  logic [31:0]   w_dec_pwdata_uart_0_axi2apb;
  logic          w_dec_pwrite_uart_0_axi2apb;
  logic          w_dec_penable_uart_0_axi2apb;
  logic          w_dec_psel_uart_0_axi2apb;
  logic [3:0]    w_dec_pstrb_uart_0_axi2apb;
  logic          w_arb_pslverr_uart_0_axi2apb;
  logic          w_arb_pready_uart_0_axi2apb;
  logic [31:0]   w_arb_prdata_uart_0_axi2apb;
  logic [13:0]   w_dec_paddr_uart_1_axi2apb;
  logic          w_dec_protect_en_uart_1_axi2apb;
  logic          w_dec_slverr_en_uart_1_axi2apb;
  logic [2:0]    w_dec_pprot_uart_1_axi2apb;
  logic [31:0]   w_dec_pwdata_uart_1_axi2apb;
  logic          w_dec_pwrite_uart_1_axi2apb;
  logic          w_dec_penable_uart_1_axi2apb;
  logic          w_dec_psel_uart_1_axi2apb;
  logic [3:0]    w_dec_pstrb_uart_1_axi2apb;
  logic          w_arb_pslverr_uart_1_axi2apb;
  logic          w_arb_pready_uart_1_axi2apb;
  logic [31:0]   w_arb_prdata_uart_1_axi2apb;
  logic [13:0]   w_dec_paddr_wdt_axi2apb;
  logic          w_dec_protect_en_wdt_axi2apb;
  logic          w_dec_slverr_en_wdt_axi2apb;
  logic [2:0]    w_dec_pprot_wdt_axi2apb;
  logic [31:0]   w_dec_pwdata_wdt_axi2apb;
  logic          w_dec_pwrite_wdt_axi2apb;
  logic          w_dec_penable_wdt_axi2apb;
  logic          w_dec_psel_wdt_axi2apb;
  logic [3:0]    w_dec_pstrb_wdt_axi2apb;
  logic          w_arb_pslverr_wdt_axi2apb;
  logic          w_arb_pready_wdt_axi2apb;
  logic [31:0]   w_arb_prdata_wdt_axi2apb;

  logic          w_arb_mst_pslverr_axi2apb;
  logic          w_arb_mst_pready_axi2apb;
  logic [31:0]   w_arb_mst_prdata_axi2apb;

  // ============================================================================
  // Decoder Instances
  // ============================================================================
  // Decoder for Master AXI2APB
  m_qnsc_p_bus_dec u_decoder_axi2apb (
    .i_paddr         (i_paddr_axi2apb),
    .i_protect_en    (i_protect_en_axi2apb),
    .i_slverr_en     (i_slverr_en_axi2apb),
    .i_pprot         (i_pprot_axi2apb),
    .i_pwdata        (i_pwdata_axi2apb),
    .i_pwrite        (i_pwrite_axi2apb),
    .i_penable       (i_penable_axi2apb),
    .i_psel          (i_psel_axi2apb),
    .i_pstrb         (i_pstrb_axi2apb),
    .o_pslverr       (w_arb_mst_pslverr_axi2apb),
    .o_pready        (w_arb_mst_pready_axi2apb),
    .o_prdata        (w_arb_mst_prdata_axi2apb),
    .o_paddr_scrc       (w_dec_paddr_scrc_axi2apb),
    .o_protect_en_scrc    (w_dec_protect_en_scrc_axi2apb),
    .o_slverr_en_scrc     (w_dec_slverr_en_scrc_axi2apb),
    .o_pprot_scrc         (w_dec_pprot_scrc_axi2apb),
    .o_pwdata_scrc        (w_dec_pwdata_scrc_axi2apb),
    .o_pwrite_scrc        (w_dec_pwrite_scrc_axi2apb),
    .o_penable_scrc       (w_dec_penable_scrc_axi2apb),
    .o_psel_scrc          (w_dec_psel_scrc_axi2apb),
    .o_pstrb_scrc         (w_dec_pstrb_scrc_axi2apb),
    .i_pslverr_scrc       (w_arb_pslverr_scrc_axi2apb),
    .i_pready_scrc        (w_arb_pready_scrc_axi2apb),
    .i_prdata_scrc        (w_arb_prdata_scrc_axi2apb),
    .o_paddr_syscsr     (w_dec_paddr_syscsr_axi2apb),
    .o_protect_en_syscsr  (w_dec_protect_en_syscsr_axi2apb),
    .o_slverr_en_syscsr   (w_dec_slverr_en_syscsr_axi2apb),
    .o_pprot_syscsr       (w_dec_pprot_syscsr_axi2apb),
    .o_pwdata_syscsr      (w_dec_pwdata_syscsr_axi2apb),
    .o_pwrite_syscsr      (w_dec_pwrite_syscsr_axi2apb),
    .o_penable_syscsr     (w_dec_penable_syscsr_axi2apb),
    .o_psel_syscsr        (w_dec_psel_syscsr_axi2apb),
    .o_pstrb_syscsr       (w_dec_pstrb_syscsr_axi2apb),
    .i_pslverr_syscsr     (w_arb_pslverr_syscsr_axi2apb),
    .i_pready_syscsr      (w_arb_pready_syscsr_axi2apb),
    .i_prdata_syscsr      (w_arb_prdata_syscsr_axi2apb),
    .o_paddr_wdt        (w_dec_paddr_wdt_axi2apb),
    .o_protect_en_wdt     (w_dec_protect_en_wdt_axi2apb),
    .o_slverr_en_wdt      (w_dec_slverr_en_wdt_axi2apb),
    .o_pprot_wdt          (w_dec_pprot_wdt_axi2apb),
    .o_pwdata_wdt         (w_dec_pwdata_wdt_axi2apb),
    .o_pwrite_wdt         (w_dec_pwrite_wdt_axi2apb),
    .o_penable_wdt        (w_dec_penable_wdt_axi2apb),
    .o_psel_wdt           (w_dec_psel_wdt_axi2apb),
    .o_pstrb_wdt          (w_dec_pstrb_wdt_axi2apb),
    .i_pslverr_wdt        (w_arb_pslverr_wdt_axi2apb),
    .i_pready_wdt         (w_arb_pready_wdt_axi2apb),
    .i_prdata_wdt         (w_arb_prdata_wdt_axi2apb),
    .o_paddr_gpio_0     (w_dec_paddr_gpio_0_axi2apb),
    .o_protect_en_gpio_0  (w_dec_protect_en_gpio_0_axi2apb),
    .o_slverr_en_gpio_0   (w_dec_slverr_en_gpio_0_axi2apb),
    .o_pprot_gpio_0       (w_dec_pprot_gpio_0_axi2apb),
    .o_pwdata_gpio_0      (w_dec_pwdata_gpio_0_axi2apb),
    .o_pwrite_gpio_0      (w_dec_pwrite_gpio_0_axi2apb),
    .o_penable_gpio_0     (w_dec_penable_gpio_0_axi2apb),
    .o_psel_gpio_0        (w_dec_psel_gpio_0_axi2apb),
    .o_pstrb_gpio_0       (w_dec_pstrb_gpio_0_axi2apb),
    .i_pslverr_gpio_0     (w_arb_pslverr_gpio_0_axi2apb),
    .i_pready_gpio_0      (w_arb_pready_gpio_0_axi2apb),
    .i_prdata_gpio_0      (w_arb_prdata_gpio_0_axi2apb),
    .o_paddr_gpio_1     (w_dec_paddr_gpio_1_axi2apb),
    .o_protect_en_gpio_1  (w_dec_protect_en_gpio_1_axi2apb),
    .o_slverr_en_gpio_1   (w_dec_slverr_en_gpio_1_axi2apb),
    .o_pprot_gpio_1       (w_dec_pprot_gpio_1_axi2apb),
    .o_pwdata_gpio_1      (w_dec_pwdata_gpio_1_axi2apb),
    .o_pwrite_gpio_1      (w_dec_pwrite_gpio_1_axi2apb),
    .o_penable_gpio_1     (w_dec_penable_gpio_1_axi2apb),
    .o_psel_gpio_1        (w_dec_psel_gpio_1_axi2apb),
    .o_pstrb_gpio_1       (w_dec_pstrb_gpio_1_axi2apb),
    .i_pslverr_gpio_1     (w_arb_pslverr_gpio_1_axi2apb),
    .i_pready_gpio_1      (w_arb_pready_gpio_1_axi2apb),
    .i_prdata_gpio_1      (w_arb_prdata_gpio_1_axi2apb),
    .o_paddr_gpio_2     (w_dec_paddr_gpio_2_axi2apb),
    .o_protect_en_gpio_2  (w_dec_protect_en_gpio_2_axi2apb),
    .o_slverr_en_gpio_2   (w_dec_slverr_en_gpio_2_axi2apb),
    .o_pprot_gpio_2       (w_dec_pprot_gpio_2_axi2apb),
    .o_pwdata_gpio_2      (w_dec_pwdata_gpio_2_axi2apb),
    .o_pwrite_gpio_2      (w_dec_pwrite_gpio_2_axi2apb),
    .o_penable_gpio_2     (w_dec_penable_gpio_2_axi2apb),
    .o_psel_gpio_2        (w_dec_psel_gpio_2_axi2apb),
    .o_pstrb_gpio_2       (w_dec_pstrb_gpio_2_axi2apb),
    .i_pslverr_gpio_2     (w_arb_pslverr_gpio_2_axi2apb),
    .i_pready_gpio_2      (w_arb_pready_gpio_2_axi2apb),
    .i_prdata_gpio_2      (w_arb_prdata_gpio_2_axi2apb),
    .o_paddr_timer_0    (w_dec_paddr_timer_0_axi2apb),
    .o_protect_en_timer_0 (w_dec_protect_en_timer_0_axi2apb),
    .o_slverr_en_timer_0  (w_dec_slverr_en_timer_0_axi2apb),
    .o_pprot_timer_0      (w_dec_pprot_timer_0_axi2apb),
    .o_pwdata_timer_0     (w_dec_pwdata_timer_0_axi2apb),
    .o_pwrite_timer_0     (w_dec_pwrite_timer_0_axi2apb),
    .o_penable_timer_0    (w_dec_penable_timer_0_axi2apb),
    .o_psel_timer_0       (w_dec_psel_timer_0_axi2apb),
    .o_pstrb_timer_0      (w_dec_pstrb_timer_0_axi2apb),
    .i_pslverr_timer_0    (w_arb_pslverr_timer_0_axi2apb),
    .i_pready_timer_0     (w_arb_pready_timer_0_axi2apb),
    .i_prdata_timer_0     (w_arb_prdata_timer_0_axi2apb),
    .o_paddr_timer_1    (w_dec_paddr_timer_1_axi2apb),
    .o_protect_en_timer_1 (w_dec_protect_en_timer_1_axi2apb),
    .o_slverr_en_timer_1  (w_dec_slverr_en_timer_1_axi2apb),
    .o_pprot_timer_1      (w_dec_pprot_timer_1_axi2apb),
    .o_pwdata_timer_1     (w_dec_pwdata_timer_1_axi2apb),
    .o_pwrite_timer_1     (w_dec_pwrite_timer_1_axi2apb),
    .o_penable_timer_1    (w_dec_penable_timer_1_axi2apb),
    .o_psel_timer_1       (w_dec_psel_timer_1_axi2apb),
    .o_pstrb_timer_1      (w_dec_pstrb_timer_1_axi2apb),
    .i_pslverr_timer_1    (w_arb_pslverr_timer_1_axi2apb),
    .i_pready_timer_1     (w_arb_pready_timer_1_axi2apb),
    .i_prdata_timer_1     (w_arb_prdata_timer_1_axi2apb),
    .o_paddr_uart_0     (w_dec_paddr_uart_0_axi2apb),
    .o_protect_en_uart_0  (w_dec_protect_en_uart_0_axi2apb),
    .o_slverr_en_uart_0   (w_dec_slverr_en_uart_0_axi2apb),
    .o_pprot_uart_0       (w_dec_pprot_uart_0_axi2apb),
    .o_pwdata_uart_0      (w_dec_pwdata_uart_0_axi2apb),
    .o_pwrite_uart_0      (w_dec_pwrite_uart_0_axi2apb),
    .o_penable_uart_0     (w_dec_penable_uart_0_axi2apb),
    .o_psel_uart_0        (w_dec_psel_uart_0_axi2apb),
    .o_pstrb_uart_0       (w_dec_pstrb_uart_0_axi2apb),
    .i_pslverr_uart_0     (w_arb_pslverr_uart_0_axi2apb),
    .i_pready_uart_0      (w_arb_pready_uart_0_axi2apb),
    .i_prdata_uart_0      (w_arb_prdata_uart_0_axi2apb),
    .o_paddr_uart_1     (w_dec_paddr_uart_1_axi2apb),
    .o_protect_en_uart_1  (w_dec_protect_en_uart_1_axi2apb),
    .o_slverr_en_uart_1   (w_dec_slverr_en_uart_1_axi2apb),
    .o_pprot_uart_1       (w_dec_pprot_uart_1_axi2apb),
    .o_pwdata_uart_1      (w_dec_pwdata_uart_1_axi2apb),
    .o_pwrite_uart_1      (w_dec_pwrite_uart_1_axi2apb),
    .o_penable_uart_1     (w_dec_penable_uart_1_axi2apb),
    .o_psel_uart_1        (w_dec_psel_uart_1_axi2apb),
    .o_pstrb_uart_1       (w_dec_pstrb_uart_1_axi2apb),
    .i_pslverr_uart_1     (w_arb_pslverr_uart_1_axi2apb),
    .i_pready_uart_1      (w_arb_pready_uart_1_axi2apb),
    .i_prdata_uart_1      (w_arb_prdata_uart_1_axi2apb),
    .o_paddr_spi        (w_dec_paddr_spi_axi2apb),
    .o_protect_en_spi     (w_dec_protect_en_spi_axi2apb),
    .o_slverr_en_spi      (w_dec_slverr_en_spi_axi2apb),
    .o_pprot_spi          (w_dec_pprot_spi_axi2apb),
    .o_pwdata_spi         (w_dec_pwdata_spi_axi2apb),
    .o_pwrite_spi         (w_dec_pwrite_spi_axi2apb),
    .o_penable_spi        (w_dec_penable_spi_axi2apb),
    .o_psel_spi           (w_dec_psel_spi_axi2apb),
    .o_pstrb_spi          (w_dec_pstrb_spi_axi2apb),
    .i_pslverr_spi        (w_arb_pslverr_spi_axi2apb),
    .i_pready_spi         (w_arb_pready_spi_axi2apb),
    .i_prdata_spi         (w_arb_prdata_spi_axi2apb),
    .o_paddr_i2c        (w_dec_paddr_i2c_axi2apb),
    .o_protect_en_i2c     (w_dec_protect_en_i2c_axi2apb),
    .o_slverr_en_i2c      (w_dec_slverr_en_i2c_axi2apb),
    .o_pprot_i2c          (w_dec_pprot_i2c_axi2apb),
    .o_pwdata_i2c         (w_dec_pwdata_i2c_axi2apb),
    .o_pwrite_i2c         (w_dec_pwrite_i2c_axi2apb),
    .o_penable_i2c        (w_dec_penable_i2c_axi2apb),
    .o_psel_i2c           (w_dec_psel_i2c_axi2apb),
    .o_pstrb_i2c          (w_dec_pstrb_i2c_axi2apb),
    .i_pslverr_i2c        (w_arb_pslverr_i2c_axi2apb),
    .i_pready_i2c         (w_arb_pready_i2c_axi2apb),
    .i_prdata_i2c         (w_arb_prdata_i2c_axi2apb),
    .o_paddr_pwm        (w_dec_paddr_pwm_axi2apb),
    .o_protect_en_pwm     (w_dec_protect_en_pwm_axi2apb),
    .o_slverr_en_pwm      (w_dec_slverr_en_pwm_axi2apb),
    .o_pprot_pwm          (w_dec_pprot_pwm_axi2apb),
    .o_pwdata_pwm         (w_dec_pwdata_pwm_axi2apb),
    .o_pwrite_pwm         (w_dec_pwrite_pwm_axi2apb),
    .o_penable_pwm        (w_dec_penable_pwm_axi2apb),
    .o_psel_pwm           (w_dec_psel_pwm_axi2apb),
    .o_pstrb_pwm          (w_dec_pstrb_pwm_axi2apb),
    .i_pslverr_pwm        (w_arb_pslverr_pwm_axi2apb),
    .i_pready_pwm         (w_arb_pready_pwm_axi2apb),
    .i_prdata_pwm         (w_arb_prdata_pwm_axi2apb),
    .o_paddr_dma_cfg    (w_dec_paddr_dma_cfg_axi2apb),
    .o_protect_en_dma_cfg (w_dec_protect_en_dma_cfg_axi2apb),
    .o_slverr_en_dma_cfg  (w_dec_slverr_en_dma_cfg_axi2apb),
    .o_pprot_dma_cfg      (w_dec_pprot_dma_cfg_axi2apb),
    .o_pwdata_dma_cfg     (w_dec_pwdata_dma_cfg_axi2apb),
    .o_pwrite_dma_cfg     (w_dec_pwrite_dma_cfg_axi2apb),
    .o_penable_dma_cfg    (w_dec_penable_dma_cfg_axi2apb),
    .o_psel_dma_cfg       (w_dec_psel_dma_cfg_axi2apb),
    .o_pstrb_dma_cfg      (w_dec_pstrb_dma_cfg_axi2apb),
    .i_pslverr_dma_cfg    (w_arb_pslverr_dma_cfg_axi2apb),
    .i_pready_dma_cfg     (w_arb_pready_dma_cfg_axi2apb),
    .i_prdata_dma_cfg     (w_arb_prdata_dma_cfg_axi2apb)
  );

  // ============================================================================
  // Arbiter Instances
  // ============================================================================
  // Arbiter for Slave SCRC
  m_qnsc_p_bus_arb_scrc u_arbiter_scrc (
    .i_clk           (i_clk),
    .i_rstn          (i_rstn),
    .o_paddr         (o_paddr_scrc),
    .o_protect_en    (o_protect_en_scrc),
    .o_slverr_en     (o_slverr_en_scrc),
    .o_pprot         (o_pprot_scrc),
    .o_pwdata        (o_pwdata_scrc),
    .o_pwrite        (o_pwrite_scrc),
    .o_penable       (o_penable_scrc),
    .o_psel          (o_psel_scrc),
    .o_pstrb         (o_pstrb_scrc),
    .i_pslverr       (i_pslverr_scrc),
    .i_pready        (i_pready_scrc),
    .i_prdata        (i_prdata_scrc),
    .i_paddr_axi2apb    (w_dec_paddr_scrc_axi2apb),
    .i_protect_en_axi2apb (w_dec_protect_en_scrc_axi2apb),
    .i_slverr_en_axi2apb  (w_dec_slverr_en_scrc_axi2apb),
    .i_pprot_axi2apb      (w_dec_pprot_scrc_axi2apb),
    .i_pwdata_axi2apb     (w_dec_pwdata_scrc_axi2apb),
    .i_pwrite_axi2apb     (w_dec_pwrite_scrc_axi2apb),
    .i_penable_axi2apb    (w_dec_penable_scrc_axi2apb),
    .i_psel_axi2apb       (w_dec_psel_scrc_axi2apb),
    .i_pstrb_axi2apb      (w_dec_pstrb_scrc_axi2apb),
    .o_pslverr_axi2apb    (w_arb_pslverr_scrc_axi2apb),
    .o_pready_axi2apb     (w_arb_pready_scrc_axi2apb),
    .o_prdata_axi2apb     (w_arb_prdata_scrc_axi2apb)
  );

  // Arbiter for Slave SYSCSR
  m_qnsc_p_bus_arb_syscsr u_arbiter_syscsr (
    .i_clk           (i_clk),
    .i_rstn          (i_rstn),
    .o_paddr         (o_paddr_syscsr),
    .o_protect_en    (o_protect_en_syscsr),
    .o_slverr_en     (o_slverr_en_syscsr),
    .o_pprot         (o_pprot_syscsr),
    .o_pwdata        (o_pwdata_syscsr),
    .o_pwrite        (o_pwrite_syscsr),
    .o_penable       (o_penable_syscsr),
    .o_psel          (o_psel_syscsr),
    .o_pstrb         (o_pstrb_syscsr),
    .i_pslverr       (i_pslverr_syscsr),
    .i_pready        (i_pready_syscsr),
    .i_prdata        (i_prdata_syscsr),
    .i_paddr_axi2apb    (w_dec_paddr_syscsr_axi2apb),
    .i_protect_en_axi2apb (w_dec_protect_en_syscsr_axi2apb),
    .i_slverr_en_axi2apb  (w_dec_slverr_en_syscsr_axi2apb),
    .i_pprot_axi2apb      (w_dec_pprot_syscsr_axi2apb),
    .i_pwdata_axi2apb     (w_dec_pwdata_syscsr_axi2apb),
    .i_pwrite_axi2apb     (w_dec_pwrite_syscsr_axi2apb),
    .i_penable_axi2apb    (w_dec_penable_syscsr_axi2apb),
    .i_psel_axi2apb       (w_dec_psel_syscsr_axi2apb),
    .i_pstrb_axi2apb      (w_dec_pstrb_syscsr_axi2apb),
    .o_pslverr_axi2apb    (w_arb_pslverr_syscsr_axi2apb),
    .o_pready_axi2apb     (w_arb_pready_syscsr_axi2apb),
    .o_prdata_axi2apb     (w_arb_prdata_syscsr_axi2apb)
  );

  // Arbiter for Slave WDT
  m_qnsc_p_bus_arb_wdt u_arbiter_wdt (
    .i_clk           (i_clk),
    .i_rstn          (i_rstn),
    .o_paddr         (o_paddr_wdt),
    .o_protect_en    (o_protect_en_wdt),
    .o_slverr_en     (o_slverr_en_wdt),
    .o_pprot         (o_pprot_wdt),
    .o_pwdata        (o_pwdata_wdt),
    .o_pwrite        (o_pwrite_wdt),
    .o_penable       (o_penable_wdt),
    .o_psel          (o_psel_wdt),
    .o_pstrb         (o_pstrb_wdt),
    .i_pslverr       (i_pslverr_wdt),
    .i_pready        (i_pready_wdt),
    .i_prdata        (i_prdata_wdt),
    .i_paddr_axi2apb    (w_dec_paddr_wdt_axi2apb),
    .i_protect_en_axi2apb (w_dec_protect_en_wdt_axi2apb),
    .i_slverr_en_axi2apb  (w_dec_slverr_en_wdt_axi2apb),
    .i_pprot_axi2apb      (w_dec_pprot_wdt_axi2apb),
    .i_pwdata_axi2apb     (w_dec_pwdata_wdt_axi2apb),
    .i_pwrite_axi2apb     (w_dec_pwrite_wdt_axi2apb),
    .i_penable_axi2apb    (w_dec_penable_wdt_axi2apb),
    .i_psel_axi2apb       (w_dec_psel_wdt_axi2apb),
    .i_pstrb_axi2apb      (w_dec_pstrb_wdt_axi2apb),
    .o_pslverr_axi2apb    (w_arb_pslverr_wdt_axi2apb),
    .o_pready_axi2apb     (w_arb_pready_wdt_axi2apb),
    .o_prdata_axi2apb     (w_arb_prdata_wdt_axi2apb)
  );

  // Arbiter for Slave GPIO_0
  m_qnsc_p_bus_arb_gpio_0 u_arbiter_gpio_0 (
    .i_clk           (i_clk),
    .i_rstn          (i_rstn),
    .o_paddr         (o_paddr_gpio_0),
    .o_protect_en    (o_protect_en_gpio_0),
    .o_slverr_en     (o_slverr_en_gpio_0),
    .o_pprot         (o_pprot_gpio_0),
    .o_pwdata        (o_pwdata_gpio_0),
    .o_pwrite        (o_pwrite_gpio_0),
    .o_penable       (o_penable_gpio_0),
    .o_psel          (o_psel_gpio_0),
    .o_pstrb         (o_pstrb_gpio_0),
    .i_pslverr       (i_pslverr_gpio_0),
    .i_pready        (i_pready_gpio_0),
    .i_prdata        (i_prdata_gpio_0),
    .i_paddr_axi2apb    (w_dec_paddr_gpio_0_axi2apb),
    .i_protect_en_axi2apb (w_dec_protect_en_gpio_0_axi2apb),
    .i_slverr_en_axi2apb  (w_dec_slverr_en_gpio_0_axi2apb),
    .i_pprot_axi2apb      (w_dec_pprot_gpio_0_axi2apb),
    .i_pwdata_axi2apb     (w_dec_pwdata_gpio_0_axi2apb),
    .i_pwrite_axi2apb     (w_dec_pwrite_gpio_0_axi2apb),
    .i_penable_axi2apb    (w_dec_penable_gpio_0_axi2apb),
    .i_psel_axi2apb       (w_dec_psel_gpio_0_axi2apb),
    .i_pstrb_axi2apb      (w_dec_pstrb_gpio_0_axi2apb),
    .o_pslverr_axi2apb    (w_arb_pslverr_gpio_0_axi2apb),
    .o_pready_axi2apb     (w_arb_pready_gpio_0_axi2apb),
    .o_prdata_axi2apb     (w_arb_prdata_gpio_0_axi2apb)
  );

  // Arbiter for Slave GPIO_1
  m_qnsc_p_bus_arb_gpio_1 u_arbiter_gpio_1 (
    .i_clk           (i_clk),
    .i_rstn          (i_rstn),
    .o_paddr         (o_paddr_gpio_1),
    .o_protect_en    (o_protect_en_gpio_1),
    .o_slverr_en     (o_slverr_en_gpio_1),
    .o_pprot         (o_pprot_gpio_1),
    .o_pwdata        (o_pwdata_gpio_1),
    .o_pwrite        (o_pwrite_gpio_1),
    .o_penable       (o_penable_gpio_1),
    .o_psel          (o_psel_gpio_1),
    .o_pstrb         (o_pstrb_gpio_1),
    .i_pslverr       (i_pslverr_gpio_1),
    .i_pready        (i_pready_gpio_1),
    .i_prdata        (i_prdata_gpio_1),
    .i_paddr_axi2apb    (w_dec_paddr_gpio_1_axi2apb),
    .i_protect_en_axi2apb (w_dec_protect_en_gpio_1_axi2apb),
    .i_slverr_en_axi2apb  (w_dec_slverr_en_gpio_1_axi2apb),
    .i_pprot_axi2apb      (w_dec_pprot_gpio_1_axi2apb),
    .i_pwdata_axi2apb     (w_dec_pwdata_gpio_1_axi2apb),
    .i_pwrite_axi2apb     (w_dec_pwrite_gpio_1_axi2apb),
    .i_penable_axi2apb    (w_dec_penable_gpio_1_axi2apb),
    .i_psel_axi2apb       (w_dec_psel_gpio_1_axi2apb),
    .i_pstrb_axi2apb      (w_dec_pstrb_gpio_1_axi2apb),
    .o_pslverr_axi2apb    (w_arb_pslverr_gpio_1_axi2apb),
    .o_pready_axi2apb     (w_arb_pready_gpio_1_axi2apb),
    .o_prdata_axi2apb     (w_arb_prdata_gpio_1_axi2apb)
  );

  // Arbiter for Slave GPIO_2
  m_qnsc_p_bus_arb_gpio_2 u_arbiter_gpio_2 (
    .i_clk           (i_clk),
    .i_rstn          (i_rstn),
    .o_paddr         (o_paddr_gpio_2),
    .o_protect_en    (o_protect_en_gpio_2),
    .o_slverr_en     (o_slverr_en_gpio_2),
    .o_pprot         (o_pprot_gpio_2),
    .o_pwdata        (o_pwdata_gpio_2),
    .o_pwrite        (o_pwrite_gpio_2),
    .o_penable       (o_penable_gpio_2),
    .o_psel          (o_psel_gpio_2),
    .o_pstrb         (o_pstrb_gpio_2),
    .i_pslverr       (i_pslverr_gpio_2),
    .i_pready        (i_pready_gpio_2),
    .i_prdata        (i_prdata_gpio_2),
    .i_paddr_axi2apb    (w_dec_paddr_gpio_2_axi2apb),
    .i_protect_en_axi2apb (w_dec_protect_en_gpio_2_axi2apb),
    .i_slverr_en_axi2apb  (w_dec_slverr_en_gpio_2_axi2apb),
    .i_pprot_axi2apb      (w_dec_pprot_gpio_2_axi2apb),
    .i_pwdata_axi2apb     (w_dec_pwdata_gpio_2_axi2apb),
    .i_pwrite_axi2apb     (w_dec_pwrite_gpio_2_axi2apb),
    .i_penable_axi2apb    (w_dec_penable_gpio_2_axi2apb),
    .i_psel_axi2apb       (w_dec_psel_gpio_2_axi2apb),
    .i_pstrb_axi2apb      (w_dec_pstrb_gpio_2_axi2apb),
    .o_pslverr_axi2apb    (w_arb_pslverr_gpio_2_axi2apb),
    .o_pready_axi2apb     (w_arb_pready_gpio_2_axi2apb),
    .o_prdata_axi2apb     (w_arb_prdata_gpio_2_axi2apb)
  );

  // Arbiter for Slave TIMER_0
  m_qnsc_p_bus_arb_timer_0 u_arbiter_timer_0 (
    .i_clk           (i_clk),
    .i_rstn          (i_rstn),
    .o_paddr         (o_paddr_timer_0),
    .o_protect_en    (o_protect_en_timer_0),
    .o_slverr_en     (o_slverr_en_timer_0),
    .o_pprot         (o_pprot_timer_0),
    .o_pwdata        (o_pwdata_timer_0),
    .o_pwrite        (o_pwrite_timer_0),
    .o_penable       (o_penable_timer_0),
    .o_psel          (o_psel_timer_0),
    .o_pstrb         (o_pstrb_timer_0),
    .i_pslverr       (i_pslverr_timer_0),
    .i_pready        (i_pready_timer_0),
    .i_prdata        (i_prdata_timer_0),
    .i_paddr_axi2apb    (w_dec_paddr_timer_0_axi2apb),
    .i_protect_en_axi2apb (w_dec_protect_en_timer_0_axi2apb),
    .i_slverr_en_axi2apb  (w_dec_slverr_en_timer_0_axi2apb),
    .i_pprot_axi2apb      (w_dec_pprot_timer_0_axi2apb),
    .i_pwdata_axi2apb     (w_dec_pwdata_timer_0_axi2apb),
    .i_pwrite_axi2apb     (w_dec_pwrite_timer_0_axi2apb),
    .i_penable_axi2apb    (w_dec_penable_timer_0_axi2apb),
    .i_psel_axi2apb       (w_dec_psel_timer_0_axi2apb),
    .i_pstrb_axi2apb      (w_dec_pstrb_timer_0_axi2apb),
    .o_pslverr_axi2apb    (w_arb_pslverr_timer_0_axi2apb),
    .o_pready_axi2apb     (w_arb_pready_timer_0_axi2apb),
    .o_prdata_axi2apb     (w_arb_prdata_timer_0_axi2apb)
  );

  // Arbiter for Slave TIMER_1
  m_qnsc_p_bus_arb_timer_1 u_arbiter_timer_1 (
    .i_clk           (i_clk),
    .i_rstn          (i_rstn),
    .o_paddr         (o_paddr_timer_1),
    .o_protect_en    (o_protect_en_timer_1),
    .o_slverr_en     (o_slverr_en_timer_1),
    .o_pprot         (o_pprot_timer_1),
    .o_pwdata        (o_pwdata_timer_1),
    .o_pwrite        (o_pwrite_timer_1),
    .o_penable       (o_penable_timer_1),
    .o_psel          (o_psel_timer_1),
    .o_pstrb         (o_pstrb_timer_1),
    .i_pslverr       (i_pslverr_timer_1),
    .i_pready        (i_pready_timer_1),
    .i_prdata        (i_prdata_timer_1),
    .i_paddr_axi2apb    (w_dec_paddr_timer_1_axi2apb),
    .i_protect_en_axi2apb (w_dec_protect_en_timer_1_axi2apb),
    .i_slverr_en_axi2apb  (w_dec_slverr_en_timer_1_axi2apb),
    .i_pprot_axi2apb      (w_dec_pprot_timer_1_axi2apb),
    .i_pwdata_axi2apb     (w_dec_pwdata_timer_1_axi2apb),
    .i_pwrite_axi2apb     (w_dec_pwrite_timer_1_axi2apb),
    .i_penable_axi2apb    (w_dec_penable_timer_1_axi2apb),
    .i_psel_axi2apb       (w_dec_psel_timer_1_axi2apb),
    .i_pstrb_axi2apb      (w_dec_pstrb_timer_1_axi2apb),
    .o_pslverr_axi2apb    (w_arb_pslverr_timer_1_axi2apb),
    .o_pready_axi2apb     (w_arb_pready_timer_1_axi2apb),
    .o_prdata_axi2apb     (w_arb_prdata_timer_1_axi2apb)
  );

  // Arbiter for Slave UART_0
  m_qnsc_p_bus_arb_uart_0 u_arbiter_uart_0 (
    .i_clk           (i_clk),
    .i_rstn          (i_rstn),
    .o_paddr         (o_paddr_uart_0),
    .o_protect_en    (o_protect_en_uart_0),
    .o_slverr_en     (o_slverr_en_uart_0),
    .o_pprot         (o_pprot_uart_0),
    .o_pwdata        (o_pwdata_uart_0),
    .o_pwrite        (o_pwrite_uart_0),
    .o_penable       (o_penable_uart_0),
    .o_psel          (o_psel_uart_0),
    .o_pstrb         (o_pstrb_uart_0),
    .i_pslverr       (i_pslverr_uart_0),
    .i_pready        (i_pready_uart_0),
    .i_prdata        (i_prdata_uart_0),
    .i_paddr_axi2apb    (w_dec_paddr_uart_0_axi2apb),
    .i_protect_en_axi2apb (w_dec_protect_en_uart_0_axi2apb),
    .i_slverr_en_axi2apb  (w_dec_slverr_en_uart_0_axi2apb),
    .i_pprot_axi2apb      (w_dec_pprot_uart_0_axi2apb),
    .i_pwdata_axi2apb     (w_dec_pwdata_uart_0_axi2apb),
    .i_pwrite_axi2apb     (w_dec_pwrite_uart_0_axi2apb),
    .i_penable_axi2apb    (w_dec_penable_uart_0_axi2apb),
    .i_psel_axi2apb       (w_dec_psel_uart_0_axi2apb),
    .i_pstrb_axi2apb      (w_dec_pstrb_uart_0_axi2apb),
    .o_pslverr_axi2apb    (w_arb_pslverr_uart_0_axi2apb),
    .o_pready_axi2apb     (w_arb_pready_uart_0_axi2apb),
    .o_prdata_axi2apb     (w_arb_prdata_uart_0_axi2apb)
  );

  // Arbiter for Slave UART_1
  m_qnsc_p_bus_arb_uart_1 u_arbiter_uart_1 (
    .i_clk           (i_clk),
    .i_rstn          (i_rstn),
    .o_paddr         (o_paddr_uart_1),
    .o_protect_en    (o_protect_en_uart_1),
    .o_slverr_en     (o_slverr_en_uart_1),
    .o_pprot         (o_pprot_uart_1),
    .o_pwdata        (o_pwdata_uart_1),
    .o_pwrite        (o_pwrite_uart_1),
    .o_penable       (o_penable_uart_1),
    .o_psel          (o_psel_uart_1),
    .o_pstrb         (o_pstrb_uart_1),
    .i_pslverr       (i_pslverr_uart_1),
    .i_pready        (i_pready_uart_1),
    .i_prdata        (i_prdata_uart_1),
    .i_paddr_axi2apb    (w_dec_paddr_uart_1_axi2apb),
    .i_protect_en_axi2apb (w_dec_protect_en_uart_1_axi2apb),
    .i_slverr_en_axi2apb  (w_dec_slverr_en_uart_1_axi2apb),
    .i_pprot_axi2apb      (w_dec_pprot_uart_1_axi2apb),
    .i_pwdata_axi2apb     (w_dec_pwdata_uart_1_axi2apb),
    .i_pwrite_axi2apb     (w_dec_pwrite_uart_1_axi2apb),
    .i_penable_axi2apb    (w_dec_penable_uart_1_axi2apb),
    .i_psel_axi2apb       (w_dec_psel_uart_1_axi2apb),
    .i_pstrb_axi2apb      (w_dec_pstrb_uart_1_axi2apb),
    .o_pslverr_axi2apb    (w_arb_pslverr_uart_1_axi2apb),
    .o_pready_axi2apb     (w_arb_pready_uart_1_axi2apb),
    .o_prdata_axi2apb     (w_arb_prdata_uart_1_axi2apb)
  );

  // Arbiter for Slave SPI
  m_qnsc_p_bus_arb_spi u_arbiter_spi (
    .i_clk           (i_clk),
    .i_rstn          (i_rstn),
    .o_paddr         (o_paddr_spi),
    .o_protect_en    (o_protect_en_spi),
    .o_slverr_en     (o_slverr_en_spi),
    .o_pprot         (o_pprot_spi),
    .o_pwdata        (o_pwdata_spi),
    .o_pwrite        (o_pwrite_spi),
    .o_penable       (o_penable_spi),
    .o_psel          (o_psel_spi),
    .o_pstrb         (o_pstrb_spi),
    .i_pslverr       (i_pslverr_spi),
    .i_pready        (i_pready_spi),
    .i_prdata        (i_prdata_spi),
    .i_paddr_axi2apb    (w_dec_paddr_spi_axi2apb),
    .i_protect_en_axi2apb (w_dec_protect_en_spi_axi2apb),
    .i_slverr_en_axi2apb  (w_dec_slverr_en_spi_axi2apb),
    .i_pprot_axi2apb      (w_dec_pprot_spi_axi2apb),
    .i_pwdata_axi2apb     (w_dec_pwdata_spi_axi2apb),
    .i_pwrite_axi2apb     (w_dec_pwrite_spi_axi2apb),
    .i_penable_axi2apb    (w_dec_penable_spi_axi2apb),
    .i_psel_axi2apb       (w_dec_psel_spi_axi2apb),
    .i_pstrb_axi2apb      (w_dec_pstrb_spi_axi2apb),
    .o_pslverr_axi2apb    (w_arb_pslverr_spi_axi2apb),
    .o_pready_axi2apb     (w_arb_pready_spi_axi2apb),
    .o_prdata_axi2apb     (w_arb_prdata_spi_axi2apb)
  );

  // Arbiter for Slave I2C
  m_qnsc_p_bus_arb_i2c u_arbiter_i2c (
    .i_clk           (i_clk),
    .i_rstn          (i_rstn),
    .o_paddr         (o_paddr_i2c),
    .o_protect_en    (o_protect_en_i2c),
    .o_slverr_en     (o_slverr_en_i2c),
    .o_pprot         (o_pprot_i2c),
    .o_pwdata        (o_pwdata_i2c),
    .o_pwrite        (o_pwrite_i2c),
    .o_penable       (o_penable_i2c),
    .o_psel          (o_psel_i2c),
    .o_pstrb         (o_pstrb_i2c),
    .i_pslverr       (i_pslverr_i2c),
    .i_pready        (i_pready_i2c),
    .i_prdata        (i_prdata_i2c),
    .i_paddr_axi2apb    (w_dec_paddr_i2c_axi2apb),
    .i_protect_en_axi2apb (w_dec_protect_en_i2c_axi2apb),
    .i_slverr_en_axi2apb  (w_dec_slverr_en_i2c_axi2apb),
    .i_pprot_axi2apb      (w_dec_pprot_i2c_axi2apb),
    .i_pwdata_axi2apb     (w_dec_pwdata_i2c_axi2apb),
    .i_pwrite_axi2apb     (w_dec_pwrite_i2c_axi2apb),
    .i_penable_axi2apb    (w_dec_penable_i2c_axi2apb),
    .i_psel_axi2apb       (w_dec_psel_i2c_axi2apb),
    .i_pstrb_axi2apb      (w_dec_pstrb_i2c_axi2apb),
    .o_pslverr_axi2apb    (w_arb_pslverr_i2c_axi2apb),
    .o_pready_axi2apb     (w_arb_pready_i2c_axi2apb),
    .o_prdata_axi2apb     (w_arb_prdata_i2c_axi2apb)
  );

  // Arbiter for Slave PWM
  m_qnsc_p_bus_arb_pwm u_arbiter_pwm (
    .i_clk           (i_clk),
    .i_rstn          (i_rstn),
    .o_paddr         (o_paddr_pwm),
    .o_protect_en    (o_protect_en_pwm),
    .o_slverr_en     (o_slverr_en_pwm),
    .o_pprot         (o_pprot_pwm),
    .o_pwdata        (o_pwdata_pwm),
    .o_pwrite        (o_pwrite_pwm),
    .o_penable       (o_penable_pwm),
    .o_psel          (o_psel_pwm),
    .o_pstrb         (o_pstrb_pwm),
    .i_pslverr       (i_pslverr_pwm),
    .i_pready        (i_pready_pwm),
    .i_prdata        (i_prdata_pwm),
    .i_paddr_axi2apb    (w_dec_paddr_pwm_axi2apb),
    .i_protect_en_axi2apb (w_dec_protect_en_pwm_axi2apb),
    .i_slverr_en_axi2apb  (w_dec_slverr_en_pwm_axi2apb),
    .i_pprot_axi2apb      (w_dec_pprot_pwm_axi2apb),
    .i_pwdata_axi2apb     (w_dec_pwdata_pwm_axi2apb),
    .i_pwrite_axi2apb     (w_dec_pwrite_pwm_axi2apb),
    .i_penable_axi2apb    (w_dec_penable_pwm_axi2apb),
    .i_psel_axi2apb       (w_dec_psel_pwm_axi2apb),
    .i_pstrb_axi2apb      (w_dec_pstrb_pwm_axi2apb),
    .o_pslverr_axi2apb    (w_arb_pslverr_pwm_axi2apb),
    .o_pready_axi2apb     (w_arb_pready_pwm_axi2apb),
    .o_prdata_axi2apb     (w_arb_prdata_pwm_axi2apb)
  );

  // Arbiter for Slave DMA_CFG
  m_qnsc_p_bus_arb_dma_cfg u_arbiter_dma_cfg (
    .i_clk           (i_clk),
    .i_rstn          (i_rstn),
    .o_paddr         (o_paddr_dma_cfg),
    .o_protect_en    (o_protect_en_dma_cfg),
    .o_slverr_en     (o_slverr_en_dma_cfg),
    .o_pprot         (o_pprot_dma_cfg),
    .o_pwdata        (o_pwdata_dma_cfg),
    .o_pwrite        (o_pwrite_dma_cfg),
    .o_penable       (o_penable_dma_cfg),
    .o_psel          (o_psel_dma_cfg),
    .o_pstrb         (o_pstrb_dma_cfg),
    .i_pslverr       (i_pslverr_dma_cfg),
    .i_pready        (i_pready_dma_cfg),
    .i_prdata        (i_prdata_dma_cfg),
    .i_paddr_axi2apb    (w_dec_paddr_dma_cfg_axi2apb),
    .i_protect_en_axi2apb (w_dec_protect_en_dma_cfg_axi2apb),
    .i_slverr_en_axi2apb  (w_dec_slverr_en_dma_cfg_axi2apb),
    .i_pprot_axi2apb      (w_dec_pprot_dma_cfg_axi2apb),
    .i_pwdata_axi2apb     (w_dec_pwdata_dma_cfg_axi2apb),
    .i_pwrite_axi2apb     (w_dec_pwrite_dma_cfg_axi2apb),
    .i_penable_axi2apb    (w_dec_penable_dma_cfg_axi2apb),
    .i_psel_axi2apb       (w_dec_psel_dma_cfg_axi2apb),
    .i_pstrb_axi2apb      (w_dec_pstrb_dma_cfg_axi2apb),
    .o_pslverr_axi2apb    (w_arb_pslverr_dma_cfg_axi2apb),
    .o_pready_axi2apb     (w_arb_pready_dma_cfg_axi2apb),
    .o_prdata_axi2apb     (w_arb_prdata_dma_cfg_axi2apb)
  );

  // ============================================================================
  // Master Response Outputs
  // ============================================================================
  assign o_pslverr_axi2apb = w_arb_mst_pslverr_axi2apb;
  assign o_pready_axi2apb  = w_arb_mst_pready_axi2apb;
  assign o_prdata_axi2apb  = w_arb_mst_prdata_axi2apb;
endmodule
