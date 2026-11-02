`timescale 1ns/1ps
//--------------------------------------
//Project: APB BUS Generator
//Module: m_qnsc_scrc_apb_bus_dec_mcpu
//Function: APB Decoder
//Author: apb-bus-generator
//Script Author: Trthinh (Ethan), Thang Luong (superzeldalink)
//Page: VLSI Technology
//--------------------------------------

module m_qnsc_scrc_apb_bus_dec_mcpu (
  // ============================================================================
  // Interface of Master MCPU
  // ============================================================================
  input  logic [13:0]   i_paddr,
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
  // Interface of Slave SCRC_CSR
  // ============================================================================
  output logic [4:0]   o_paddr_scrc_csr,  // to SCRC_CSR
  output logic          o_protect_en_scrc_csr,
  output logic          o_slverr_en_scrc_csr,
  output logic [2:0]    o_pprot_scrc_csr,
  output logic [31:0]   o_pwdata_scrc_csr,
  output logic          o_pwrite_scrc_csr,
  output logic          o_penable_scrc_csr,
  output logic          o_psel_scrc_csr,
  output logic [3:0]    o_pstrb_scrc_csr,
  input  logic          i_pslverr_scrc_csr,
  input  logic          i_pready_scrc_csr,
  input  logic [31:0]   i_prdata_scrc_csr
);
  logic [0:0] w_sel;

  // ============================================================================
  // Address Decode Logic
  // ============================================================================
  assign w_sel[0] = (i_paddr <= 14'h001F);  // SCRC_CSR

  // ============================================================================
  // PREADY, PSLVERR, PRDATA Logic
  // ============================================================================
  always_comb begin
    casez (w_sel)
      1'b1: begin  // SCRC_CSR
        o_pready  = i_pready_scrc_csr;
        o_pslverr = i_pslverr_scrc_csr;
        o_prdata  = i_prdata_scrc_csr;
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
  // SCRC_CSR
  assign o_psel_scrc_csr    = w_sel[0] & i_psel;
  assign o_penable_scrc_csr = i_penable;
  assign o_pwrite_scrc_csr  = i_pwrite;
  assign o_paddr_scrc_csr   = 5'(i_paddr);
  assign o_pwdata_scrc_csr  = i_pwdata;
  assign o_pstrb_scrc_csr   = i_pstrb;
  assign o_protect_en_scrc_csr = i_protect_en;
  assign o_slverr_en_scrc_csr  = i_slverr_en;
  assign o_pprot_scrc_csr      = i_pprot;


endmodule
