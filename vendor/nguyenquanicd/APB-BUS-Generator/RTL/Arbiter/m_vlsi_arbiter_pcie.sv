`timescale 1ns/1ps
//--------------------------------------
//Project: APB BUS Generator
//Module: m_vlsi_arbiter_pcie
//Function: APB Arbiter
//Author: link
//Script Author: Trthinh (Ethan), Thang Luong (superzeldalink)
//Page: VLSI Technology
//--------------------------------------

module m_vlsi_arbiter_pcie (
  // ============================================================================
  // Slave Interface: PCIE
  // ============================================================================
  input  logic          i_clk,
  input  logic          i_rstn,
  output logic [19:0]   o_paddr,
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
  // Master Interface: GPU
  // ============================================================================
  input  logic [19:0]   i_paddr_gpu,
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
  output logic [31:0]   o_prdata_gpu

);
  // ============================================================================
  // Direct Signal Routing (Single Master)
  // ============================================================================
  assign o_paddr         = i_paddr_gpu;
  assign o_protect_en    = i_protect_en_gpu;
  assign o_slverr_en     = i_slverr_en_gpu;
  assign o_pprot         = i_pprot_gpu;
  assign o_pwdata        = i_pwdata_gpu;
  assign o_pwrite        = i_pwrite_gpu;
  assign o_penable       = i_penable_gpu;
  assign o_psel          = i_psel_gpu;
  assign o_pstrb         = i_pstrb_gpu;
  assign o_pslverr_gpu = i_pslverr;
  assign o_pready_gpu  = i_pready;
  assign o_prdata_gpu  = i_prdata;

endmodule
