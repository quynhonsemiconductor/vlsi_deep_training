`timescale 1ns/1ps
//--------------------------------------
//Project: APB BUS Generator
//Module: m_vlsi_arbiter_can
//Function: APB Arbiter
//Author: link
//Script Author: Trthinh (Ethan), Thang Luong (superzeldalink)
//Page: VLSI Technology
//--------------------------------------

module m_vlsi_arbiter_can (
  // ============================================================================
  // Slave Interface: CAN
  // ============================================================================
  input  logic          i_clk,
  input  logic          i_rstn,
  output logic [14:0]   o_paddr,
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
  // Master Interface: CPU1
  // ============================================================================
  input  logic [14:0]   i_paddr_cpu1,
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
  // ============================================================================
  // Direct Signal Routing (Single Master)
  // ============================================================================
  assign o_paddr         = i_paddr_cpu1;
  assign o_protect_en    = i_protect_en_cpu1;
  assign o_slverr_en     = i_slverr_en_cpu1;
  assign o_pprot         = i_pprot_cpu1;
  assign o_pwdata        = i_pwdata_cpu1;
  assign o_pwrite        = i_pwrite_cpu1;
  assign o_penable       = i_penable_cpu1;
  assign o_psel          = i_psel_cpu1;
  assign o_pstrb         = i_pstrb_cpu1;
  assign o_pslverr_cpu1 = i_pslverr;
  assign o_pready_cpu1  = i_pready;
  assign o_prdata_cpu1  = i_prdata;

endmodule
