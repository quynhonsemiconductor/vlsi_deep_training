`timescale 1ns/1ps
//--------------------------------------
//Project: APB BUS Generator
//Module: m_vlsi_apb_router
//Function: APB Router Top-Level
//Author: link
//Script Author: Trthinh (Ethan), Thang Luong (superzeldalink)
//Page: VLSI Technology
//--------------------------------------

module m_vlsi_apb_router (
  // ============================================================================
  // Global Signals
  // ============================================================================
  input  logic          i_clk,
  input  logic          i_rstn,

  // ============================================================================
  // Master Interfaces
  // ============================================================================
  // Master: CPU0
  input  logic [23:0]   i_paddr_cpu0,
  input  logic          i_protect_en_cpu0,
  input  logic          i_slverr_en_cpu0,
  input  logic [2:0]    i_pprot_cpu0,
  input  logic [31:0]   i_pwdata_cpu0,
  input  logic          i_pwrite_cpu0,
  input  logic          i_penable_cpu0,
  input  logic          i_psel_cpu0,
  input  logic [3:0]    i_pstrb_cpu0,
  output logic          o_pslverr_cpu0,
  output logic          o_pready_cpu0,
  output logic [31:0]   o_prdata_cpu0,

  // Master: CPU1
  input  logic [15:0]   i_paddr_cpu1,
  input  logic          i_protect_en_cpu1,
  input  logic          i_slverr_en_cpu1,
  input  logic [2:0]    i_pprot_cpu1,
  input  logic [31:0]   i_pwdata_cpu1,
  input  logic          i_pwrite_cpu1,
  input  logic          i_penable_cpu1,
  input  logic          i_psel_cpu1,
  input  logic [3:0]    i_pstrb_cpu1,
  output logic          o_pslverr_cpu1,
  output logic          o_pready_cpu1,
  output logic [31:0]   o_prdata_cpu1,

  // Master: GPU
  input  logic [23:0]   i_paddr_gpu,
  input  logic          i_protect_en_gpu,
  input  logic          i_slverr_en_gpu,
  input  logic [2:0]    i_pprot_gpu,
  input  logic [31:0]   i_pwdata_gpu,
  input  logic          i_pwrite_gpu,
  input  logic          i_penable_gpu,
  input  logic          i_psel_gpu,
  input  logic [3:0]    i_pstrb_gpu,
  output logic          o_pslverr_gpu,
  output logic          o_pready_gpu,
  output logic [31:0]   o_prdata_gpu,

  // Master: NPU
  input  logic [23:0]   i_paddr_npu,
  input  logic          i_protect_en_npu,
  input  logic          i_slverr_en_npu,
  input  logic [2:0]    i_pprot_npu,
  input  logic [31:0]   i_pwdata_npu,
  input  logic          i_pwrite_npu,
  input  logic          i_penable_npu,
  input  logic          i_psel_npu,
  input  logic [3:0]    i_pstrb_npu,
  output logic          o_pslverr_npu,
  output logic          o_pready_npu,
  output logic [31:0]   o_prdata_npu,

  // Master: TPU
  input  logic [15:0]   i_paddr_tpu,
  input  logic          i_protect_en_tpu,
  input  logic          i_slverr_en_tpu,
  input  logic [2:0]    i_pprot_tpu,
  input  logic [31:0]   i_pwdata_tpu,
  input  logic          i_pwrite_tpu,
  input  logic          i_penable_tpu,
  input  logic          i_psel_tpu,
  input  logic [3:0]    i_pstrb_tpu,
  output logic          o_pslverr_tpu,
  output logic          o_pready_tpu,
  output logic [31:0]   o_prdata_tpu,

  // Master: PPU
  input  logic [23:0]   i_paddr_ppu,
  input  logic          i_protect_en_ppu,
  input  logic          i_slverr_en_ppu,
  input  logic [2:0]    i_pprot_ppu,
  input  logic [31:0]   i_pwdata_ppu,
  input  logic          i_pwrite_ppu,
  input  logic          i_penable_ppu,
  input  logic          i_psel_ppu,
  input  logic [3:0]    i_pstrb_ppu,
  output logic          o_pslverr_ppu,
  output logic          o_pready_ppu,
  output logic [31:0]   o_prdata_ppu,

  // ============================================================================
  // Slave Interfaces
  // ============================================================================
  // Slave: UART
  output logic [7:0]   o_paddr_uart,
  output logic          o_protect_en_uart,
  output logic          o_slverr_en_uart,
  output logic [2:0]    o_pprot_uart,
  output logic [31:0]   o_pwdata_uart,
  output logic          o_pwrite_uart,
  output logic          o_penable_uart,
  output logic          o_psel_uart,
  output logic [3:0]    o_pstrb_uart,
  input  logic          i_pslverr_uart,
  input  logic          i_pready_uart,
  input  logic [31:0]   i_prdata_uart,

  // Slave: I2C
  output logic [3:0]   o_paddr_i2c,
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

  // Slave: SPI
  output logic [11:0]   o_paddr_spi,
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

  // Slave: CAN
  output logic [14:0]   o_paddr_can,
  output logic          o_protect_en_can,
  output logic          o_slverr_en_can,
  output logic [2:0]    o_pprot_can,
  output logic [31:0]   o_pwdata_can,
  output logic          o_pwrite_can,
  output logic          o_penable_can,
  output logic          o_psel_can,
  output logic [3:0]    o_pstrb_can,
  input  logic          i_pslverr_can,
  input  logic          i_pready_can,
  input  logic [31:0]   i_prdata_can,

  // Slave: PWM
  output logic [7:0]   o_paddr_pwm,
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

  // Slave: PCIE
  output logic [19:0]   o_paddr_pcie,
  output logic          o_protect_en_pcie,
  output logic          o_slverr_en_pcie,
  output logic [2:0]    o_pprot_pcie,
  output logic [31:0]   o_pwdata_pcie,
  output logic          o_pwrite_pcie,
  output logic          o_penable_pcie,
  output logic          o_psel_pcie,
  output logic [3:0]    o_pstrb_pcie,
  input  logic          i_pslverr_pcie,
  input  logic          i_pready_pcie,
  input  logic [31:0]   i_prdata_pcie
);

  // ============================================================================
  // Internal Interconnect Wires
  // ============================================================================
  // Decoder <-> Arbiter per master-slave connections
  logic [3:0]   w_dec_paddr_i2c_cpu0;
  logic          w_dec_protect_en_i2c_cpu0;
  logic          w_dec_slverr_en_i2c_cpu0;
  logic [2:0]    w_dec_pprot_i2c_cpu0;
  logic [31:0]   w_dec_pwdata_i2c_cpu0;
  logic          w_dec_pwrite_i2c_cpu0;
  logic          w_dec_penable_i2c_cpu0;
  logic          w_dec_psel_i2c_cpu0;
  logic [3:0]    w_dec_pstrb_i2c_cpu0;
  logic          w_arb_pslverr_i2c_cpu0;
  logic          w_arb_pready_i2c_cpu0;
  logic [31:0]   w_arb_prdata_i2c_cpu0;
  logic [7:0]   w_dec_paddr_pwm_cpu0;
  logic          w_dec_protect_en_pwm_cpu0;
  logic          w_dec_slverr_en_pwm_cpu0;
  logic [2:0]    w_dec_pprot_pwm_cpu0;
  logic [31:0]   w_dec_pwdata_pwm_cpu0;
  logic          w_dec_pwrite_pwm_cpu0;
  logic          w_dec_penable_pwm_cpu0;
  logic          w_dec_psel_pwm_cpu0;
  logic [3:0]    w_dec_pstrb_pwm_cpu0;
  logic          w_arb_pslverr_pwm_cpu0;
  logic          w_arb_pready_pwm_cpu0;
  logic [31:0]   w_arb_prdata_pwm_cpu0;
  logic [7:0]   w_dec_paddr_uart_cpu0;
  logic          w_dec_protect_en_uart_cpu0;
  logic          w_dec_slverr_en_uart_cpu0;
  logic [2:0]    w_dec_pprot_uart_cpu0;
  logic [31:0]   w_dec_pwdata_uart_cpu0;
  logic          w_dec_pwrite_uart_cpu0;
  logic          w_dec_penable_uart_cpu0;
  logic          w_dec_psel_uart_cpu0;
  logic [3:0]    w_dec_pstrb_uart_cpu0;
  logic          w_arb_pslverr_uart_cpu0;
  logic          w_arb_pready_uart_cpu0;
  logic [31:0]   w_arb_prdata_uart_cpu0;
  logic [14:0]   w_dec_paddr_can_cpu1;
  logic          w_dec_protect_en_can_cpu1;
  logic          w_dec_slverr_en_can_cpu1;
  logic [2:0]    w_dec_pprot_can_cpu1;
  logic [31:0]   w_dec_pwdata_can_cpu1;
  logic          w_dec_pwrite_can_cpu1;
  logic          w_dec_penable_can_cpu1;
  logic          w_dec_psel_can_cpu1;
  logic [3:0]    w_dec_pstrb_can_cpu1;
  logic          w_arb_pslverr_can_cpu1;
  logic          w_arb_pready_can_cpu1;
  logic [31:0]   w_arb_prdata_can_cpu1;
  logic [3:0]   w_dec_paddr_i2c_cpu1;
  logic          w_dec_protect_en_i2c_cpu1;
  logic          w_dec_slverr_en_i2c_cpu1;
  logic [2:0]    w_dec_pprot_i2c_cpu1;
  logic [31:0]   w_dec_pwdata_i2c_cpu1;
  logic          w_dec_pwrite_i2c_cpu1;
  logic          w_dec_penable_i2c_cpu1;
  logic          w_dec_psel_i2c_cpu1;
  logic [3:0]    w_dec_pstrb_i2c_cpu1;
  logic          w_arb_pslverr_i2c_cpu1;
  logic          w_arb_pready_i2c_cpu1;
  logic [31:0]   w_arb_prdata_i2c_cpu1;
  logic [7:0]   w_dec_paddr_uart_cpu1;
  logic          w_dec_protect_en_uart_cpu1;
  logic          w_dec_slverr_en_uart_cpu1;
  logic [2:0]    w_dec_pprot_uart_cpu1;
  logic [31:0]   w_dec_pwdata_uart_cpu1;
  logic          w_dec_pwrite_uart_cpu1;
  logic          w_dec_penable_uart_cpu1;
  logic          w_dec_psel_uart_cpu1;
  logic [3:0]    w_dec_pstrb_uart_cpu1;
  logic          w_arb_pslverr_uart_cpu1;
  logic          w_arb_pready_uart_cpu1;
  logic [31:0]   w_arb_prdata_uart_cpu1;
  logic [3:0]   w_dec_paddr_i2c_gpu;
  logic          w_dec_protect_en_i2c_gpu;
  logic          w_dec_slverr_en_i2c_gpu;
  logic [2:0]    w_dec_pprot_i2c_gpu;
  logic [31:0]   w_dec_pwdata_i2c_gpu;
  logic          w_dec_pwrite_i2c_gpu;
  logic          w_dec_penable_i2c_gpu;
  logic          w_dec_psel_i2c_gpu;
  logic [3:0]    w_dec_pstrb_i2c_gpu;
  logic          w_arb_pslverr_i2c_gpu;
  logic          w_arb_pready_i2c_gpu;
  logic [31:0]   w_arb_prdata_i2c_gpu;
  logic [19:0]   w_dec_paddr_pcie_gpu;
  logic          w_dec_protect_en_pcie_gpu;
  logic          w_dec_slverr_en_pcie_gpu;
  logic [2:0]    w_dec_pprot_pcie_gpu;
  logic [31:0]   w_dec_pwdata_pcie_gpu;
  logic          w_dec_pwrite_pcie_gpu;
  logic          w_dec_penable_pcie_gpu;
  logic          w_dec_psel_pcie_gpu;
  logic [3:0]    w_dec_pstrb_pcie_gpu;
  logic          w_arb_pslverr_pcie_gpu;
  logic          w_arb_pready_pcie_gpu;
  logic [31:0]   w_arb_prdata_pcie_gpu;
  logic [11:0]   w_dec_paddr_spi_gpu;
  logic          w_dec_protect_en_spi_gpu;
  logic          w_dec_slverr_en_spi_gpu;
  logic [2:0]    w_dec_pprot_spi_gpu;
  logic [31:0]   w_dec_pwdata_spi_gpu;
  logic          w_dec_pwrite_spi_gpu;
  logic          w_dec_penable_spi_gpu;
  logic          w_dec_psel_spi_gpu;
  logic [3:0]    w_dec_pstrb_spi_gpu;
  logic          w_arb_pslverr_spi_gpu;
  logic          w_arb_pready_spi_gpu;
  logic [31:0]   w_arb_prdata_spi_gpu;
  logic [3:0]   w_dec_paddr_i2c_npu;
  logic          w_dec_protect_en_i2c_npu;
  logic          w_dec_slverr_en_i2c_npu;
  logic [2:0]    w_dec_pprot_i2c_npu;
  logic [31:0]   w_dec_pwdata_i2c_npu;
  logic          w_dec_pwrite_i2c_npu;
  logic          w_dec_penable_i2c_npu;
  logic          w_dec_psel_i2c_npu;
  logic [3:0]    w_dec_pstrb_i2c_npu;
  logic          w_arb_pslverr_i2c_npu;
  logic          w_arb_pready_i2c_npu;
  logic [31:0]   w_arb_prdata_i2c_npu;
  logic [3:0]   w_dec_paddr_i2c_ppu;
  logic          w_dec_protect_en_i2c_ppu;
  logic          w_dec_slverr_en_i2c_ppu;
  logic [2:0]    w_dec_pprot_i2c_ppu;
  logic [31:0]   w_dec_pwdata_i2c_ppu;
  logic          w_dec_pwrite_i2c_ppu;
  logic          w_dec_penable_i2c_ppu;
  logic          w_dec_psel_i2c_ppu;
  logic [3:0]    w_dec_pstrb_i2c_ppu;
  logic          w_arb_pslverr_i2c_ppu;
  logic          w_arb_pready_i2c_ppu;
  logic [31:0]   w_arb_prdata_i2c_ppu;
  logic [3:0]   w_dec_paddr_i2c_tpu;
  logic          w_dec_protect_en_i2c_tpu;
  logic          w_dec_slverr_en_i2c_tpu;
  logic [2:0]    w_dec_pprot_i2c_tpu;
  logic [31:0]   w_dec_pwdata_i2c_tpu;
  logic          w_dec_pwrite_i2c_tpu;
  logic          w_dec_penable_i2c_tpu;
  logic          w_dec_psel_i2c_tpu;
  logic [3:0]    w_dec_pstrb_i2c_tpu;
  logic          w_arb_pslverr_i2c_tpu;
  logic          w_arb_pready_i2c_tpu;
  logic [31:0]   w_arb_prdata_i2c_tpu;

  logic          w_arb_mst_pslverr_cpu0;
  logic          w_arb_mst_pready_cpu0;
  logic [31:0]   w_arb_mst_prdata_cpu0;
  logic          w_arb_mst_pslverr_cpu1;
  logic          w_arb_mst_pready_cpu1;
  logic [31:0]   w_arb_mst_prdata_cpu1;
  logic          w_arb_mst_pslverr_gpu;
  logic          w_arb_mst_pready_gpu;
  logic [31:0]   w_arb_mst_prdata_gpu;
  logic          w_arb_mst_pslverr_npu;
  logic          w_arb_mst_pready_npu;
  logic [31:0]   w_arb_mst_prdata_npu;
  logic          w_arb_mst_pslverr_ppu;
  logic          w_arb_mst_pready_ppu;
  logic [31:0]   w_arb_mst_prdata_ppu;
  logic          w_arb_mst_pslverr_tpu;
  logic          w_arb_mst_pready_tpu;
  logic [31:0]   w_arb_mst_prdata_tpu;

  // ============================================================================
  // Decoder Instances
  // ============================================================================
  // Decoder for Master CPU0
  m_vlsi_decoder_cpu0 u_decoder_cpu0 (
    .i_paddr         (i_paddr_cpu0),
    .i_protect_en    (i_protect_en_cpu0),
    .i_slverr_en     (i_slverr_en_cpu0),
    .i_pprot         (i_pprot_cpu0),
    .i_pwdata        (i_pwdata_cpu0),
    .i_pwrite        (i_pwrite_cpu0),
    .i_penable       (i_penable_cpu0),
    .i_psel          (i_psel_cpu0),
    .i_pstrb         (i_pstrb_cpu0),
    .o_pslverr       (w_arb_mst_pslverr_cpu0),
    .o_pready        (w_arb_mst_pready_cpu0),
    .o_prdata        (w_arb_mst_prdata_cpu0),
    .o_paddr_uart    (w_dec_paddr_uart_cpu0),
    .o_protect_en_uart (w_dec_protect_en_uart_cpu0),
    .o_slverr_en_uart  (w_dec_slverr_en_uart_cpu0),
    .o_pprot_uart      (w_dec_pprot_uart_cpu0),
    .o_pwdata_uart     (w_dec_pwdata_uart_cpu0),
    .o_pwrite_uart     (w_dec_pwrite_uart_cpu0),
    .o_penable_uart    (w_dec_penable_uart_cpu0),
    .o_psel_uart       (w_dec_psel_uart_cpu0),
    .o_pstrb_uart      (w_dec_pstrb_uart_cpu0),
    .i_pslverr_uart    (w_arb_pslverr_uart_cpu0),
    .i_pready_uart     (w_arb_pready_uart_cpu0),
    .i_prdata_uart     (w_arb_prdata_uart_cpu0),
    .o_paddr_i2c     (w_dec_paddr_i2c_cpu0),
    .o_protect_en_i2c  (w_dec_protect_en_i2c_cpu0),
    .o_slverr_en_i2c   (w_dec_slverr_en_i2c_cpu0),
    .o_pprot_i2c       (w_dec_pprot_i2c_cpu0),
    .o_pwdata_i2c      (w_dec_pwdata_i2c_cpu0),
    .o_pwrite_i2c      (w_dec_pwrite_i2c_cpu0),
    .o_penable_i2c     (w_dec_penable_i2c_cpu0),
    .o_psel_i2c        (w_dec_psel_i2c_cpu0),
    .o_pstrb_i2c       (w_dec_pstrb_i2c_cpu0),
    .i_pslverr_i2c     (w_arb_pslverr_i2c_cpu0),
    .i_pready_i2c      (w_arb_pready_i2c_cpu0),
    .i_prdata_i2c      (w_arb_prdata_i2c_cpu0),
    .o_paddr_pwm     (w_dec_paddr_pwm_cpu0),
    .o_protect_en_pwm  (w_dec_protect_en_pwm_cpu0),
    .o_slverr_en_pwm   (w_dec_slverr_en_pwm_cpu0),
    .o_pprot_pwm       (w_dec_pprot_pwm_cpu0),
    .o_pwdata_pwm      (w_dec_pwdata_pwm_cpu0),
    .o_pwrite_pwm      (w_dec_pwrite_pwm_cpu0),
    .o_penable_pwm     (w_dec_penable_pwm_cpu0),
    .o_psel_pwm        (w_dec_psel_pwm_cpu0),
    .o_pstrb_pwm       (w_dec_pstrb_pwm_cpu0),
    .i_pslverr_pwm     (w_arb_pslverr_pwm_cpu0),
    .i_pready_pwm      (w_arb_pready_pwm_cpu0),
    .i_prdata_pwm      (w_arb_prdata_pwm_cpu0)
  );

  // Decoder for Master CPU1
  m_vlsi_decoder_cpu1 u_decoder_cpu1 (
    .i_paddr         (i_paddr_cpu1),
    .i_protect_en    (i_protect_en_cpu1),
    .i_slverr_en     (i_slverr_en_cpu1),
    .i_pprot         (i_pprot_cpu1),
    .i_pwdata        (i_pwdata_cpu1),
    .i_pwrite        (i_pwrite_cpu1),
    .i_penable       (i_penable_cpu1),
    .i_psel          (i_psel_cpu1),
    .i_pstrb         (i_pstrb_cpu1),
    .o_pslverr       (w_arb_mst_pslverr_cpu1),
    .o_pready        (w_arb_mst_pready_cpu1),
    .o_prdata        (w_arb_mst_prdata_cpu1),
    .o_paddr_uart    (w_dec_paddr_uart_cpu1),
    .o_protect_en_uart (w_dec_protect_en_uart_cpu1),
    .o_slverr_en_uart  (w_dec_slverr_en_uart_cpu1),
    .o_pprot_uart      (w_dec_pprot_uart_cpu1),
    .o_pwdata_uart     (w_dec_pwdata_uart_cpu1),
    .o_pwrite_uart     (w_dec_pwrite_uart_cpu1),
    .o_penable_uart    (w_dec_penable_uart_cpu1),
    .o_psel_uart       (w_dec_psel_uart_cpu1),
    .o_pstrb_uart      (w_dec_pstrb_uart_cpu1),
    .i_pslverr_uart    (w_arb_pslverr_uart_cpu1),
    .i_pready_uart     (w_arb_pready_uart_cpu1),
    .i_prdata_uart     (w_arb_prdata_uart_cpu1),
    .o_paddr_i2c     (w_dec_paddr_i2c_cpu1),
    .o_protect_en_i2c  (w_dec_protect_en_i2c_cpu1),
    .o_slverr_en_i2c   (w_dec_slverr_en_i2c_cpu1),
    .o_pprot_i2c       (w_dec_pprot_i2c_cpu1),
    .o_pwdata_i2c      (w_dec_pwdata_i2c_cpu1),
    .o_pwrite_i2c      (w_dec_pwrite_i2c_cpu1),
    .o_penable_i2c     (w_dec_penable_i2c_cpu1),
    .o_psel_i2c        (w_dec_psel_i2c_cpu1),
    .o_pstrb_i2c       (w_dec_pstrb_i2c_cpu1),
    .i_pslverr_i2c     (w_arb_pslverr_i2c_cpu1),
    .i_pready_i2c      (w_arb_pready_i2c_cpu1),
    .i_prdata_i2c      (w_arb_prdata_i2c_cpu1),
    .o_paddr_can     (w_dec_paddr_can_cpu1),
    .o_protect_en_can  (w_dec_protect_en_can_cpu1),
    .o_slverr_en_can   (w_dec_slverr_en_can_cpu1),
    .o_pprot_can       (w_dec_pprot_can_cpu1),
    .o_pwdata_can      (w_dec_pwdata_can_cpu1),
    .o_pwrite_can      (w_dec_pwrite_can_cpu1),
    .o_penable_can     (w_dec_penable_can_cpu1),
    .o_psel_can        (w_dec_psel_can_cpu1),
    .o_pstrb_can       (w_dec_pstrb_can_cpu1),
    .i_pslverr_can     (w_arb_pslverr_can_cpu1),
    .i_pready_can      (w_arb_pready_can_cpu1),
    .i_prdata_can      (w_arb_prdata_can_cpu1)
  );

  // Decoder for Master GPU
  m_vlsi_decoder_gpu u_decoder_gpu (
    .i_paddr         (i_paddr_gpu),
    .i_protect_en    (i_protect_en_gpu),
    .i_slverr_en     (i_slverr_en_gpu),
    .i_pprot         (i_pprot_gpu),
    .i_pwdata        (i_pwdata_gpu),
    .i_pwrite        (i_pwrite_gpu),
    .i_penable       (i_penable_gpu),
    .i_psel          (i_psel_gpu),
    .i_pstrb         (i_pstrb_gpu),
    .o_pslverr       (w_arb_mst_pslverr_gpu),
    .o_pready        (w_arb_mst_pready_gpu),
    .o_prdata        (w_arb_mst_prdata_gpu),
    .o_paddr_i2c     (w_dec_paddr_i2c_gpu),
    .o_protect_en_i2c  (w_dec_protect_en_i2c_gpu),
    .o_slverr_en_i2c   (w_dec_slverr_en_i2c_gpu),
    .o_pprot_i2c       (w_dec_pprot_i2c_gpu),
    .o_pwdata_i2c      (w_dec_pwdata_i2c_gpu),
    .o_pwrite_i2c      (w_dec_pwrite_i2c_gpu),
    .o_penable_i2c     (w_dec_penable_i2c_gpu),
    .o_psel_i2c        (w_dec_psel_i2c_gpu),
    .o_pstrb_i2c       (w_dec_pstrb_i2c_gpu),
    .i_pslverr_i2c     (w_arb_pslverr_i2c_gpu),
    .i_pready_i2c      (w_arb_pready_i2c_gpu),
    .i_prdata_i2c      (w_arb_prdata_i2c_gpu),
    .o_paddr_spi     (w_dec_paddr_spi_gpu),
    .o_protect_en_spi  (w_dec_protect_en_spi_gpu),
    .o_slverr_en_spi   (w_dec_slverr_en_spi_gpu),
    .o_pprot_spi       (w_dec_pprot_spi_gpu),
    .o_pwdata_spi      (w_dec_pwdata_spi_gpu),
    .o_pwrite_spi      (w_dec_pwrite_spi_gpu),
    .o_penable_spi     (w_dec_penable_spi_gpu),
    .o_psel_spi        (w_dec_psel_spi_gpu),
    .o_pstrb_spi       (w_dec_pstrb_spi_gpu),
    .i_pslverr_spi     (w_arb_pslverr_spi_gpu),
    .i_pready_spi      (w_arb_pready_spi_gpu),
    .i_prdata_spi      (w_arb_prdata_spi_gpu),
    .o_paddr_pcie    (w_dec_paddr_pcie_gpu),
    .o_protect_en_pcie (w_dec_protect_en_pcie_gpu),
    .o_slverr_en_pcie  (w_dec_slverr_en_pcie_gpu),
    .o_pprot_pcie      (w_dec_pprot_pcie_gpu),
    .o_pwdata_pcie     (w_dec_pwdata_pcie_gpu),
    .o_pwrite_pcie     (w_dec_pwrite_pcie_gpu),
    .o_penable_pcie    (w_dec_penable_pcie_gpu),
    .o_psel_pcie       (w_dec_psel_pcie_gpu),
    .o_pstrb_pcie      (w_dec_pstrb_pcie_gpu),
    .i_pslverr_pcie    (w_arb_pslverr_pcie_gpu),
    .i_pready_pcie     (w_arb_pready_pcie_gpu),
    .i_prdata_pcie     (w_arb_prdata_pcie_gpu)
  );

  // Decoder for Master NPU
  m_vlsi_decoder_npu u_decoder_npu (
    .i_paddr         (i_paddr_npu),
    .i_protect_en    (i_protect_en_npu),
    .i_slverr_en     (i_slverr_en_npu),
    .i_pprot         (i_pprot_npu),
    .i_pwdata        (i_pwdata_npu),
    .i_pwrite        (i_pwrite_npu),
    .i_penable       (i_penable_npu),
    .i_psel          (i_psel_npu),
    .i_pstrb         (i_pstrb_npu),
    .o_pslverr       (w_arb_mst_pslverr_npu),
    .o_pready        (w_arb_mst_pready_npu),
    .o_prdata        (w_arb_mst_prdata_npu),
    .o_paddr_i2c     (w_dec_paddr_i2c_npu),
    .o_protect_en_i2c  (w_dec_protect_en_i2c_npu),
    .o_slverr_en_i2c   (w_dec_slverr_en_i2c_npu),
    .o_pprot_i2c       (w_dec_pprot_i2c_npu),
    .o_pwdata_i2c      (w_dec_pwdata_i2c_npu),
    .o_pwrite_i2c      (w_dec_pwrite_i2c_npu),
    .o_penable_i2c     (w_dec_penable_i2c_npu),
    .o_psel_i2c        (w_dec_psel_i2c_npu),
    .o_pstrb_i2c       (w_dec_pstrb_i2c_npu),
    .i_pslverr_i2c     (w_arb_pslverr_i2c_npu),
    .i_pready_i2c      (w_arb_pready_i2c_npu),
    .i_prdata_i2c      (w_arb_prdata_i2c_npu)
  );

  // Decoder for Master TPU
  m_vlsi_decoder_tpu u_decoder_tpu (
    .i_paddr         (i_paddr_tpu),
    .i_protect_en    (i_protect_en_tpu),
    .i_slverr_en     (i_slverr_en_tpu),
    .i_pprot         (i_pprot_tpu),
    .i_pwdata        (i_pwdata_tpu),
    .i_pwrite        (i_pwrite_tpu),
    .i_penable       (i_penable_tpu),
    .i_psel          (i_psel_tpu),
    .i_pstrb         (i_pstrb_tpu),
    .o_pslverr       (w_arb_mst_pslverr_tpu),
    .o_pready        (w_arb_mst_pready_tpu),
    .o_prdata        (w_arb_mst_prdata_tpu),
    .o_paddr_i2c     (w_dec_paddr_i2c_tpu),
    .o_protect_en_i2c  (w_dec_protect_en_i2c_tpu),
    .o_slverr_en_i2c   (w_dec_slverr_en_i2c_tpu),
    .o_pprot_i2c       (w_dec_pprot_i2c_tpu),
    .o_pwdata_i2c      (w_dec_pwdata_i2c_tpu),
    .o_pwrite_i2c      (w_dec_pwrite_i2c_tpu),
    .o_penable_i2c     (w_dec_penable_i2c_tpu),
    .o_psel_i2c        (w_dec_psel_i2c_tpu),
    .o_pstrb_i2c       (w_dec_pstrb_i2c_tpu),
    .i_pslverr_i2c     (w_arb_pslverr_i2c_tpu),
    .i_pready_i2c      (w_arb_pready_i2c_tpu),
    .i_prdata_i2c      (w_arb_prdata_i2c_tpu)
  );

  // Decoder for Master PPU
  m_vlsi_decoder_ppu u_decoder_ppu (
    .i_paddr         (i_paddr_ppu),
    .i_protect_en    (i_protect_en_ppu),
    .i_slverr_en     (i_slverr_en_ppu),
    .i_pprot         (i_pprot_ppu),
    .i_pwdata        (i_pwdata_ppu),
    .i_pwrite        (i_pwrite_ppu),
    .i_penable       (i_penable_ppu),
    .i_psel          (i_psel_ppu),
    .i_pstrb         (i_pstrb_ppu),
    .o_pslverr       (w_arb_mst_pslverr_ppu),
    .o_pready        (w_arb_mst_pready_ppu),
    .o_prdata        (w_arb_mst_prdata_ppu),
    .o_paddr_i2c     (w_dec_paddr_i2c_ppu),
    .o_protect_en_i2c  (w_dec_protect_en_i2c_ppu),
    .o_slverr_en_i2c   (w_dec_slverr_en_i2c_ppu),
    .o_pprot_i2c       (w_dec_pprot_i2c_ppu),
    .o_pwdata_i2c      (w_dec_pwdata_i2c_ppu),
    .o_pwrite_i2c      (w_dec_pwrite_i2c_ppu),
    .o_penable_i2c     (w_dec_penable_i2c_ppu),
    .o_psel_i2c        (w_dec_psel_i2c_ppu),
    .o_pstrb_i2c       (w_dec_pstrb_i2c_ppu),
    .i_pslverr_i2c     (w_arb_pslverr_i2c_ppu),
    .i_pready_i2c      (w_arb_pready_i2c_ppu),
    .i_prdata_i2c      (w_arb_prdata_i2c_ppu)
  );

  // ============================================================================
  // Arbiter Instances
  // ============================================================================
  // Arbiter for Slave UART
  m_vlsi_arbiter_uart u_arbiter_uart (
    .i_clk           (i_clk),
    .i_rstn          (i_rstn),
    .o_paddr         (o_paddr_uart),
    .o_protect_en    (o_protect_en_uart),
    .o_slverr_en     (o_slverr_en_uart),
    .o_pprot         (o_pprot_uart),
    .o_pwdata        (o_pwdata_uart),
    .o_pwrite        (o_pwrite_uart),
    .o_penable       (o_penable_uart),
    .o_psel          (o_psel_uart),
    .o_pstrb         (o_pstrb_uart),
    .i_pslverr       (i_pslverr_uart),
    .i_pready        (i_pready_uart),
    .i_prdata        (i_prdata_uart),
    .i_paddr_cpu0    (w_dec_paddr_uart_cpu0),
    .i_protect_en_cpu0 (w_dec_protect_en_uart_cpu0),
    .i_slverr_en_cpu0  (w_dec_slverr_en_uart_cpu0),
    .i_pprot_cpu0      (w_dec_pprot_uart_cpu0),
    .i_pwdata_cpu0     (w_dec_pwdata_uart_cpu0),
    .i_pwrite_cpu0     (w_dec_pwrite_uart_cpu0),
    .i_penable_cpu0    (w_dec_penable_uart_cpu0),
    .i_psel_cpu0       (w_dec_psel_uart_cpu0),
    .i_pstrb_cpu0      (w_dec_pstrb_uart_cpu0),
    .o_pslverr_cpu0    (w_arb_pslverr_uart_cpu0),
    .o_pready_cpu0     (w_arb_pready_uart_cpu0),
    .o_prdata_cpu0     (w_arb_prdata_uart_cpu0),
    .i_paddr_cpu1    (w_dec_paddr_uart_cpu1),
    .i_protect_en_cpu1 (w_dec_protect_en_uart_cpu1),
    .i_slverr_en_cpu1  (w_dec_slverr_en_uart_cpu1),
    .i_pprot_cpu1      (w_dec_pprot_uart_cpu1),
    .i_pwdata_cpu1     (w_dec_pwdata_uart_cpu1),
    .i_pwrite_cpu1     (w_dec_pwrite_uart_cpu1),
    .i_penable_cpu1    (w_dec_penable_uart_cpu1),
    .i_psel_cpu1       (w_dec_psel_uart_cpu1),
    .i_pstrb_cpu1      (w_dec_pstrb_uart_cpu1),
    .o_pslverr_cpu1    (w_arb_pslverr_uart_cpu1),
    .o_pready_cpu1     (w_arb_pready_uart_cpu1),
    .o_prdata_cpu1     (w_arb_prdata_uart_cpu1)
  );

  // Arbiter for Slave I2C
  m_vlsi_arbiter_i2c u_arbiter_i2c (
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
    .i_paddr_cpu0    (w_dec_paddr_i2c_cpu0),
    .i_protect_en_cpu0 (w_dec_protect_en_i2c_cpu0),
    .i_slverr_en_cpu0  (w_dec_slverr_en_i2c_cpu0),
    .i_pprot_cpu0      (w_dec_pprot_i2c_cpu0),
    .i_pwdata_cpu0     (w_dec_pwdata_i2c_cpu0),
    .i_pwrite_cpu0     (w_dec_pwrite_i2c_cpu0),
    .i_penable_cpu0    (w_dec_penable_i2c_cpu0),
    .i_psel_cpu0       (w_dec_psel_i2c_cpu0),
    .i_pstrb_cpu0      (w_dec_pstrb_i2c_cpu0),
    .o_pslverr_cpu0    (w_arb_pslverr_i2c_cpu0),
    .o_pready_cpu0     (w_arb_pready_i2c_cpu0),
    .o_prdata_cpu0     (w_arb_prdata_i2c_cpu0),
    .i_paddr_cpu1    (w_dec_paddr_i2c_cpu1),
    .i_protect_en_cpu1 (w_dec_protect_en_i2c_cpu1),
    .i_slverr_en_cpu1  (w_dec_slverr_en_i2c_cpu1),
    .i_pprot_cpu1      (w_dec_pprot_i2c_cpu1),
    .i_pwdata_cpu1     (w_dec_pwdata_i2c_cpu1),
    .i_pwrite_cpu1     (w_dec_pwrite_i2c_cpu1),
    .i_penable_cpu1    (w_dec_penable_i2c_cpu1),
    .i_psel_cpu1       (w_dec_psel_i2c_cpu1),
    .i_pstrb_cpu1      (w_dec_pstrb_i2c_cpu1),
    .o_pslverr_cpu1    (w_arb_pslverr_i2c_cpu1),
    .o_pready_cpu1     (w_arb_pready_i2c_cpu1),
    .o_prdata_cpu1     (w_arb_prdata_i2c_cpu1),
    .i_paddr_gpu     (w_dec_paddr_i2c_gpu),
    .i_protect_en_gpu  (w_dec_protect_en_i2c_gpu),
    .i_slverr_en_gpu   (w_dec_slverr_en_i2c_gpu),
    .i_pprot_gpu       (w_dec_pprot_i2c_gpu),
    .i_pwdata_gpu      (w_dec_pwdata_i2c_gpu),
    .i_pwrite_gpu      (w_dec_pwrite_i2c_gpu),
    .i_penable_gpu     (w_dec_penable_i2c_gpu),
    .i_psel_gpu        (w_dec_psel_i2c_gpu),
    .i_pstrb_gpu       (w_dec_pstrb_i2c_gpu),
    .o_pslverr_gpu     (w_arb_pslverr_i2c_gpu),
    .o_pready_gpu      (w_arb_pready_i2c_gpu),
    .o_prdata_gpu      (w_arb_prdata_i2c_gpu),
    .i_paddr_npu     (w_dec_paddr_i2c_npu),
    .i_protect_en_npu  (w_dec_protect_en_i2c_npu),
    .i_slverr_en_npu   (w_dec_slverr_en_i2c_npu),
    .i_pprot_npu       (w_dec_pprot_i2c_npu),
    .i_pwdata_npu      (w_dec_pwdata_i2c_npu),
    .i_pwrite_npu      (w_dec_pwrite_i2c_npu),
    .i_penable_npu     (w_dec_penable_i2c_npu),
    .i_psel_npu        (w_dec_psel_i2c_npu),
    .i_pstrb_npu       (w_dec_pstrb_i2c_npu),
    .o_pslverr_npu     (w_arb_pslverr_i2c_npu),
    .o_pready_npu      (w_arb_pready_i2c_npu),
    .o_prdata_npu      (w_arb_prdata_i2c_npu),
    .i_paddr_tpu     (w_dec_paddr_i2c_tpu),
    .i_protect_en_tpu  (w_dec_protect_en_i2c_tpu),
    .i_slverr_en_tpu   (w_dec_slverr_en_i2c_tpu),
    .i_pprot_tpu       (w_dec_pprot_i2c_tpu),
    .i_pwdata_tpu      (w_dec_pwdata_i2c_tpu),
    .i_pwrite_tpu      (w_dec_pwrite_i2c_tpu),
    .i_penable_tpu     (w_dec_penable_i2c_tpu),
    .i_psel_tpu        (w_dec_psel_i2c_tpu),
    .i_pstrb_tpu       (w_dec_pstrb_i2c_tpu),
    .o_pslverr_tpu     (w_arb_pslverr_i2c_tpu),
    .o_pready_tpu      (w_arb_pready_i2c_tpu),
    .o_prdata_tpu      (w_arb_prdata_i2c_tpu),
    .i_paddr_ppu     (w_dec_paddr_i2c_ppu),
    .i_protect_en_ppu  (w_dec_protect_en_i2c_ppu),
    .i_slverr_en_ppu   (w_dec_slverr_en_i2c_ppu),
    .i_pprot_ppu       (w_dec_pprot_i2c_ppu),
    .i_pwdata_ppu      (w_dec_pwdata_i2c_ppu),
    .i_pwrite_ppu      (w_dec_pwrite_i2c_ppu),
    .i_penable_ppu     (w_dec_penable_i2c_ppu),
    .i_psel_ppu        (w_dec_psel_i2c_ppu),
    .i_pstrb_ppu       (w_dec_pstrb_i2c_ppu),
    .o_pslverr_ppu     (w_arb_pslverr_i2c_ppu),
    .o_pready_ppu      (w_arb_pready_i2c_ppu),
    .o_prdata_ppu      (w_arb_prdata_i2c_ppu)
  );

  // Arbiter for Slave SPI
  m_vlsi_arbiter_spi u_arbiter_spi (
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
    .i_paddr_gpu     (w_dec_paddr_spi_gpu),
    .i_protect_en_gpu  (w_dec_protect_en_spi_gpu),
    .i_slverr_en_gpu   (w_dec_slverr_en_spi_gpu),
    .i_pprot_gpu       (w_dec_pprot_spi_gpu),
    .i_pwdata_gpu      (w_dec_pwdata_spi_gpu),
    .i_pwrite_gpu      (w_dec_pwrite_spi_gpu),
    .i_penable_gpu     (w_dec_penable_spi_gpu),
    .i_psel_gpu        (w_dec_psel_spi_gpu),
    .i_pstrb_gpu       (w_dec_pstrb_spi_gpu),
    .o_pslverr_gpu     (w_arb_pslverr_spi_gpu),
    .o_pready_gpu      (w_arb_pready_spi_gpu),
    .o_prdata_gpu      (w_arb_prdata_spi_gpu)
  );

  // Arbiter for Slave CAN
  m_vlsi_arbiter_can u_arbiter_can (
    .i_clk           (i_clk),
    .i_rstn          (i_rstn),
    .o_paddr         (o_paddr_can),
    .o_protect_en    (o_protect_en_can),
    .o_slverr_en     (o_slverr_en_can),
    .o_pprot         (o_pprot_can),
    .o_pwdata        (o_pwdata_can),
    .o_pwrite        (o_pwrite_can),
    .o_penable       (o_penable_can),
    .o_psel          (o_psel_can),
    .o_pstrb         (o_pstrb_can),
    .i_pslverr       (i_pslverr_can),
    .i_pready        (i_pready_can),
    .i_prdata        (i_prdata_can),
    .i_paddr_cpu1    (w_dec_paddr_can_cpu1),
    .i_protect_en_cpu1 (w_dec_protect_en_can_cpu1),
    .i_slverr_en_cpu1  (w_dec_slverr_en_can_cpu1),
    .i_pprot_cpu1      (w_dec_pprot_can_cpu1),
    .i_pwdata_cpu1     (w_dec_pwdata_can_cpu1),
    .i_pwrite_cpu1     (w_dec_pwrite_can_cpu1),
    .i_penable_cpu1    (w_dec_penable_can_cpu1),
    .i_psel_cpu1       (w_dec_psel_can_cpu1),
    .i_pstrb_cpu1      (w_dec_pstrb_can_cpu1),
    .o_pslverr_cpu1    (w_arb_pslverr_can_cpu1),
    .o_pready_cpu1     (w_arb_pready_can_cpu1),
    .o_prdata_cpu1     (w_arb_prdata_can_cpu1)
  );

  // Arbiter for Slave PWM
  m_vlsi_arbiter_pwm u_arbiter_pwm (
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
    .i_paddr_cpu0    (w_dec_paddr_pwm_cpu0),
    .i_protect_en_cpu0 (w_dec_protect_en_pwm_cpu0),
    .i_slverr_en_cpu0  (w_dec_slverr_en_pwm_cpu0),
    .i_pprot_cpu0      (w_dec_pprot_pwm_cpu0),
    .i_pwdata_cpu0     (w_dec_pwdata_pwm_cpu0),
    .i_pwrite_cpu0     (w_dec_pwrite_pwm_cpu0),
    .i_penable_cpu0    (w_dec_penable_pwm_cpu0),
    .i_psel_cpu0       (w_dec_psel_pwm_cpu0),
    .i_pstrb_cpu0      (w_dec_pstrb_pwm_cpu0),
    .o_pslverr_cpu0    (w_arb_pslverr_pwm_cpu0),
    .o_pready_cpu0     (w_arb_pready_pwm_cpu0),
    .o_prdata_cpu0     (w_arb_prdata_pwm_cpu0)
  );

  // Arbiter for Slave PCIE
  m_vlsi_arbiter_pcie u_arbiter_pcie (
    .i_clk           (i_clk),
    .i_rstn          (i_rstn),
    .o_paddr         (o_paddr_pcie),
    .o_protect_en    (o_protect_en_pcie),
    .o_slverr_en     (o_slverr_en_pcie),
    .o_pprot         (o_pprot_pcie),
    .o_pwdata        (o_pwdata_pcie),
    .o_pwrite        (o_pwrite_pcie),
    .o_penable       (o_penable_pcie),
    .o_psel          (o_psel_pcie),
    .o_pstrb         (o_pstrb_pcie),
    .i_pslverr       (i_pslverr_pcie),
    .i_pready        (i_pready_pcie),
    .i_prdata        (i_prdata_pcie),
    .i_paddr_gpu     (w_dec_paddr_pcie_gpu),
    .i_protect_en_gpu  (w_dec_protect_en_pcie_gpu),
    .i_slverr_en_gpu   (w_dec_slverr_en_pcie_gpu),
    .i_pprot_gpu       (w_dec_pprot_pcie_gpu),
    .i_pwdata_gpu      (w_dec_pwdata_pcie_gpu),
    .i_pwrite_gpu      (w_dec_pwrite_pcie_gpu),
    .i_penable_gpu     (w_dec_penable_pcie_gpu),
    .i_psel_gpu        (w_dec_psel_pcie_gpu),
    .i_pstrb_gpu       (w_dec_pstrb_pcie_gpu),
    .o_pslverr_gpu     (w_arb_pslverr_pcie_gpu),
    .o_pready_gpu      (w_arb_pready_pcie_gpu),
    .o_prdata_gpu      (w_arb_prdata_pcie_gpu)
  );

  // ============================================================================
  // Master Response Outputs
  // ============================================================================
  assign o_pslverr_cpu0 = w_arb_mst_pslverr_cpu0;
  assign o_pready_cpu0  = w_arb_mst_pready_cpu0;
  assign o_prdata_cpu0  = w_arb_mst_prdata_cpu0;
  assign o_pslverr_cpu1 = w_arb_mst_pslverr_cpu1;
  assign o_pready_cpu1  = w_arb_mst_pready_cpu1;
  assign o_prdata_cpu1  = w_arb_mst_prdata_cpu1;
  assign o_pslverr_gpu = w_arb_mst_pslverr_gpu;
  assign o_pready_gpu  = w_arb_mst_pready_gpu;
  assign o_prdata_gpu  = w_arb_mst_prdata_gpu;
  assign o_pslverr_npu = w_arb_mst_pslverr_npu;
  assign o_pready_npu  = w_arb_mst_pready_npu;
  assign o_prdata_npu  = w_arb_mst_prdata_npu;
  assign o_pslverr_tpu = w_arb_mst_pslverr_tpu;
  assign o_pready_tpu  = w_arb_mst_pready_tpu;
  assign o_prdata_tpu  = w_arb_mst_prdata_tpu;
  assign o_pslverr_ppu = w_arb_mst_pslverr_ppu;
  assign o_pready_ppu  = w_arb_mst_pready_ppu;
  assign o_prdata_ppu  = w_arb_mst_prdata_ppu;
endmodule
