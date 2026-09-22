`timescale 1ns/1ps
//--------------------------------------
//Project: APB BUS Generator
//Module: m_vlsi_decoder_npu
//Function: APB Decoder
//Author: link
//Script Author: Trthinh (Ethan), Thang Luong (superzeldalink)
//Page: VLSI Technology
//--------------------------------------

module m_vlsi_decoder_npu (
  // ============================================================================
  // Interface of Master NPU
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
  input  logic [31:0]   i_prdata_i2c
);
  logic [0:0] w_sel;

  // ============================================================================
  // Address Decode Logic
  // ============================================================================
  assign w_sel[0] = (i_paddr <= 24'h00000F);  // I2C

  // ============================================================================
  // PREADY, PSLVERR, PRDATA Logic
  // ============================================================================
  always_comb begin
    casez (w_sel)
      1'b1: begin  // I2C
        o_pready  = i_pready_i2c;
        o_pslverr = i_pslverr_i2c;
        o_prdata  = i_prdata_i2c;
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
  assign o_psel_i2c    = w_sel[0] & i_psel;
  assign o_penable_i2c = i_penable;
  assign o_pwrite_i2c  = i_pwrite;
  assign o_paddr_i2c   = 4'(i_paddr);
  assign o_pwdata_i2c  = i_pwdata;
  assign o_pstrb_i2c   = i_pstrb;
  assign o_protect_en_i2c = i_protect_en;
  assign o_slverr_en_i2c  = i_slverr_en;
  assign o_pprot_i2c      = i_pprot;


endmodule
