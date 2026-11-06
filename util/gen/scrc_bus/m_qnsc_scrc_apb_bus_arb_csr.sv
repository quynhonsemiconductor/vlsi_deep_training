`timescale 1ns/1ps
//--------------------------------------
//Project: APB BUS Generator
//Module: m_qnsc_scrc_apb_bus_arb_csr
//Function: APB Arbiter
//Author: apb-bus-generator
//Script Author: Trthinh (Ethan), Thang Luong (superzeldalink)
//Page: VLSI Technology
//--------------------------------------

module m_qnsc_scrc_apb_bus_arb_csr (
  // ============================================================================
  // Slave Interface: SCRC_CSR
  // ============================================================================
  input  logic          i_clk,
  input  logic          i_rstn,
  output logic [4:0]   o_paddr,
  output logic          o_protect_en,
  output logic          o_slverr_en,
  output logic [2:0]    o_pprot,
  output logic [31:0]   o_pwdata,
  output logic          o_pwrite,
  output logic          o_penable,
  output logic          o_psel,
  output logic [3:0]    o_pstrb,
  input  logic          i_pslverr,
  input  logic          i_pready,
  input  logic [31:0]   i_prdata,
  // ============================================================================
  // Master Interface 1: MCPU
  // ============================================================================
  input  logic [4:0]   i_paddr_mcpu,
  input  logic          i_protect_en_mcpu,
  input  logic          i_slverr_en_mcpu,
  input  logic [2:0]    i_pprot_mcpu,
  input  logic [31:0]   i_pwdata_mcpu,
  input  logic          i_pwrite_mcpu,
  input  logic          i_penable_mcpu,
  input  logic          i_psel_mcpu,
  input  logic [3:0]    i_pstrb_mcpu,
  output logic          o_pslverr_mcpu,
  output logic          o_pready_mcpu,
  output logic [31:0]   o_prdata_mcpu,
  // ============================================================================
  // Master Interface 2: IBEX
  // ============================================================================
  input  logic [4:0]   i_paddr_ibex,
  input  logic          i_protect_en_ibex,
  input  logic          i_slverr_en_ibex,
  input  logic [2:0]    i_pprot_ibex,
  input  logic [31:0]   i_pwdata_ibex,
  input  logic          i_pwrite_ibex,
  input  logic          i_penable_ibex,
  input  logic          i_psel_ibex,
  input  logic [3:0]    i_pstrb_ibex,
  output logic          o_pslverr_ibex,
  output logic          o_pready_ibex,
  output logic [31:0]   o_prdata_ibex
);
  logic [1:0] psel_comb;
  logic [1:0] grant_comb;

  // ============================================================================
  // Master Select Logic
  // ============================================================================
  assign psel_comb = {i_psel_ibex, i_psel_mcpu};

  logic [1:0] grant_prev;
  logic          grant_handover;
  logic          sel_penable;

  always_ff @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn)
      grant_prev <= '0;
    else
      grant_prev <= grant_comb;
  end

  // Force SETUP (PENABLE=0) for one cycle when grant owner changes.
  assign grant_handover = (grant_comb != grant_prev) && (|grant_comb);



  m_qnsc_scrc_apb_bus_rr #(
    .REQ_NUM (2)
  ) u_arb (
  .clk (i_clk),
  .rst_n (i_rstn),
  .req (psel_comb),
  .grant (grant_comb)
  );

  // ============================================================================
  // Master-to-Slave Data Routing
  // ============================================================================
  always_comb begin
    casez (grant_comb)
      2'b?1: begin  // MCPU
        o_paddr         = i_paddr_mcpu;
        o_protect_en    = i_protect_en_mcpu;
        o_slverr_en     = i_slverr_en_mcpu;
        o_pprot         = i_pprot_mcpu;
        o_pwdata        = i_pwdata_mcpu;
        o_pwrite        = i_pwrite_mcpu;
        sel_penable     = i_penable_mcpu;
        o_psel          = i_psel_mcpu;
        o_pstrb         = i_pstrb_mcpu;
      end

      2'b10: begin  // IBEX
        o_paddr         = i_paddr_ibex;
        o_protect_en    = i_protect_en_ibex;
        o_slverr_en     = i_slverr_en_ibex;
        o_pprot         = i_pprot_ibex;
        o_pwdata        = i_pwdata_ibex;
        o_pwrite        = i_pwrite_ibex;
        sel_penable     = i_penable_ibex;
        o_psel          = i_psel_ibex;
        o_pstrb         = i_pstrb_ibex;
      end

      default: begin
        o_paddr         = '0;
        o_protect_en    = '0;
        o_slverr_en     = '0;
        o_pprot         = '0;
        o_pwdata        = '0;
        o_pwrite        = '0;
        sel_penable     = '0;
        o_psel          = '0;
        o_pstrb         = '0;
      end
    endcase
  end

  assign o_penable = o_psel ? (sel_penable & ~grant_handover) : 1'b0;


  // ============================================================================
  // Slave-to-Master Data Routing
  // ============================================================================
  assign o_pslverr_mcpu = grant_comb[0] ? i_pslverr : '0;
  assign o_pready_mcpu  = grant_comb[0] ? i_pready  : '0;
  assign o_prdata_mcpu  = grant_comb[0] ? i_prdata  : '0;
  assign o_pslverr_ibex = grant_comb[1] ? i_pslverr : '0;
  assign o_pready_ibex  = grant_comb[1] ? i_pready  : '0;
  assign o_prdata_ibex  = grant_comb[1] ? i_prdata  : '0;

endmodule
