`timescale 1ns/1ps
//--------------------------------------
//Project: APB BUS Generator
//Module: m_vlsi_arbiter_uart
//Function: APB Arbiter
//Author: link
//Script Author: Trthinh (Ethan), Thang Luong (superzeldalink)
//Page: VLSI Technology
//--------------------------------------

module m_vlsi_arbiter_uart (
  // ============================================================================
  // Slave Interface: UART
  // ============================================================================
  input  logic          i_clk,
  input  logic          i_rstn,
  output logic [7:0]   o_paddr,
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
  // Master Interface 1: CPU0
  // ============================================================================
  input  logic [7:0]   i_paddr_cpu0,
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
  // ============================================================================
  // Master Interface 2: CPU1
  // ============================================================================
  input  logic [7:0]   i_paddr_cpu1,
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
  output logic [31:0]   o_prdata_cpu1
);
  logic [1:0] psel_comb;
  logic [1:0] grant_comb;

  // ============================================================================
  // Master Select Logic
  // ============================================================================
  assign psel_comb = {i_psel_cpu1, i_psel_cpu0};

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



  ArbBalanceRR #(
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
      2'b?1: begin  // CPU0
        o_paddr         = i_paddr_cpu0;
        o_protect_en    = i_protect_en_cpu0;
        o_slverr_en     = i_slverr_en_cpu0;
        o_pprot         = i_pprot_cpu0;
        o_pwdata        = i_pwdata_cpu0;
        o_pwrite        = i_pwrite_cpu0;
        sel_penable     = i_penable_cpu0;
        o_psel          = i_psel_cpu0;
        o_pstrb         = i_pstrb_cpu0;
      end

      2'b10: begin  // CPU1
        o_paddr         = i_paddr_cpu1;
        o_protect_en    = i_protect_en_cpu1;
        o_slverr_en     = i_slverr_en_cpu1;
        o_pprot         = i_pprot_cpu1;
        o_pwdata        = i_pwdata_cpu1;
        o_pwrite        = i_pwrite_cpu1;
        sel_penable     = i_penable_cpu1;
        o_psel          = i_psel_cpu1;
        o_pstrb         = i_pstrb_cpu1;
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
  assign o_pslverr_cpu0 = grant_comb[0] ? i_pslverr : '0;
  assign o_pready_cpu0  = grant_comb[0] ? i_pready  : '0;
  assign o_prdata_cpu0  = grant_comb[0] ? i_prdata  : '0;
  assign o_pslverr_cpu1 = grant_comb[1] ? i_pslverr : '0;
  assign o_pready_cpu1  = grant_comb[1] ? i_pready  : '0;
  assign o_prdata_cpu1  = grant_comb[1] ? i_prdata  : '0;

endmodule
