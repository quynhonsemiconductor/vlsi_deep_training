`timescale 1ns/1ps
//--------------------------------------
//Project: APB BUS Generator
//Module: m_vlsi_decoder_gpu
//Function: APB Decoder
//Author: link
//Script Author: Trthinh (Ethan), Thang Luong (superzeldalink)
//Page: VLSI Technology
//--------------------------------------

module m_vlsi_decoder_gpu (
  // ============================================================================
  // Interface of Master GPU
  // ============================================================================
  input  logic [23:0]   i_paddr,
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
  // Interface of Slave I2C
  // ============================================================================
  output logic [3:0]   o_paddr_i2c,  // to I2C
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
  // Interface of Slave SPI
  // ============================================================================
  output logic [11:0]   o_paddr_spi,  // to SPI
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
  // Interface of Slave PCIE
  // ============================================================================
  output logic [19:0]   o_paddr_pcie,  // to PCIE
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
  logic [2:0] w_sel;

  // ============================================================================
  // Address Decode Logic
  // ============================================================================
  assign w_sel[0] = (i_paddr >= 24'h001000) & (i_paddr <= 24'h00100F);  // I2C
  assign w_sel[1] = (i_paddr <= 24'h000FFF);  // SPI
  assign w_sel[2] = (i_paddr >= 24'h002000) & (i_paddr <= 24'h101FFF);  // PCIE

  // ============================================================================
  // PREADY, PSLVERR, PRDATA Logic
  // ============================================================================
  always_comb begin
    casez (w_sel)
      3'b001: begin  // I2C
        o_pready  = i_pready_i2c;
        o_pslverr = i_pslverr_i2c;
        o_prdata  = i_prdata_i2c;
      end
      3'b010: begin  // SPI
        o_pready  = i_pready_spi;
        o_pslverr = i_pslverr_spi;
        o_prdata  = i_prdata_spi;
      end
      3'b100: begin  // PCIE
        o_pready  = i_pready_pcie;
        o_pslverr = i_pslverr_pcie;
        o_prdata  = i_prdata_pcie;
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
  // I2C
  assign o_psel_i2c     = w_sel[0] & i_psel;
  assign o_penable_i2c  = i_penable;
  assign o_pwrite_i2c   = i_pwrite;
  assign o_paddr_i2c    = 4'(i_paddr - 24'h001000);
  assign o_pwdata_i2c   = i_pwdata;
  assign o_pstrb_i2c    = i_pstrb;
  assign o_protect_en_i2c  = i_protect_en;
  assign o_slverr_en_i2c   = i_slverr_en;
  assign o_pprot_i2c       = i_pprot;

  // SPI
  assign o_psel_spi     = w_sel[1] & i_psel;
  assign o_penable_spi  = i_penable;
  assign o_pwrite_spi   = i_pwrite;
  assign o_paddr_spi    = 12'(i_paddr);
  assign o_pwdata_spi   = i_pwdata;
  assign o_pstrb_spi    = i_pstrb;
  assign o_protect_en_spi  = i_protect_en;
  assign o_slverr_en_spi   = i_slverr_en;
  assign o_pprot_spi       = i_pprot;

  // PCIE
  assign o_psel_pcie    = w_sel[2] & i_psel;
  assign o_penable_pcie = i_penable;
  assign o_pwrite_pcie  = i_pwrite;
  assign o_paddr_pcie   = 20'(i_paddr - 24'h002000);
  assign o_pwdata_pcie  = i_pwdata;
  assign o_pstrb_pcie   = i_pstrb;
  assign o_protect_en_pcie = i_protect_en;
  assign o_slverr_en_pcie  = i_slverr_en;
  assign o_pprot_pcie      = i_pprot;


endmodule
