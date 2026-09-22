`timescale 1ns/1ps
//--------------------------------------
//Project: APB BUS Generator
//Module: m_vlsi_decoder_cpu1
//Function: APB Decoder
//Author: link
//Script Author: Trthinh (Ethan), Thang Luong (superzeldalink)
//Page: VLSI Technology
//--------------------------------------

module m_vlsi_decoder_cpu1 (
  // ============================================================================
  // Interface of Master CPU1
  // ============================================================================
  input  logic [15:0]   i_paddr,
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
  // Interface of Slave UART
  // ============================================================================
  output logic [7:0]   o_paddr_uart,  // to UART
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
  // Interface of Slave CAN
  // ============================================================================
  output logic [14:0]   o_paddr_can,  // to CAN
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
  input  logic [31:0]   i_prdata_can
);
  logic [2:0] w_sel;

  // ============================================================================
  // Address Decode Logic
  // ============================================================================
  assign w_sel[0] = (i_paddr <= 16'h00FF);  // UART
  assign w_sel[1] = (i_paddr >= 16'h2000) & (i_paddr <= 16'h200F);  // I2C
  assign w_sel[2] = (i_paddr >= 16'h4000) & (i_paddr <= 16'hBFFF);  // CAN

  // ============================================================================
  // PREADY, PSLVERR, PRDATA Logic
  // ============================================================================
  always_comb begin
    casez (w_sel)
      3'b001: begin  // UART
        o_pready  = i_pready_uart;
        o_pslverr = i_pslverr_uart;
        o_prdata  = i_prdata_uart;
      end
      3'b010: begin  // I2C
        o_pready  = i_pready_i2c;
        o_pslverr = i_pslverr_i2c;
        o_prdata  = i_prdata_i2c;
      end
      3'b100: begin  // CAN
        o_pready  = i_pready_can;
        o_pslverr = i_pslverr_can;
        o_prdata  = i_prdata_can;
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
  // UART
  assign o_psel_uart    = w_sel[0] & i_psel;
  assign o_penable_uart = i_penable;
  assign o_pwrite_uart  = i_pwrite;
  assign o_paddr_uart   = 8'(i_paddr);
  assign o_pwdata_uart  = i_pwdata;
  assign o_pstrb_uart   = i_pstrb;
  assign o_protect_en_uart = i_protect_en;
  assign o_slverr_en_uart  = i_slverr_en;
  assign o_pprot_uart      = i_pprot;

  // I2C
  assign o_psel_i2c     = w_sel[1] & i_psel;
  assign o_penable_i2c  = i_penable;
  assign o_pwrite_i2c   = i_pwrite;
  assign o_paddr_i2c    = 4'(i_paddr - 16'h2000);
  assign o_pwdata_i2c   = i_pwdata;
  assign o_pstrb_i2c    = i_pstrb;
  assign o_protect_en_i2c  = i_protect_en;
  assign o_slverr_en_i2c   = i_slverr_en;
  assign o_pprot_i2c       = i_pprot;

  // CAN
  assign o_psel_can     = w_sel[2] & i_psel;
  assign o_penable_can  = i_penable;
  assign o_pwrite_can   = i_pwrite;
  assign o_paddr_can    = 15'(i_paddr - 16'h4000);
  assign o_pwdata_can   = i_pwdata;
  assign o_pstrb_can    = i_pstrb;
  assign o_protect_en_can  = i_protect_en;
  assign o_slverr_en_can   = i_slverr_en;
  assign o_pprot_can       = i_pprot;


endmodule
