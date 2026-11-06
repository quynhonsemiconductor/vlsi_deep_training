`timescale 1ns/1ps
//--------------------------------------
//Project: APB BUS Generator
//Module: m_qnsc_p_bus_arb_uart_0
//Function: APB Arbiter
//Author: apb-bus-generator
//Script Author: Trthinh (Ethan), Thang Luong (superzeldalink)
//Page: VLSI Technology
//--------------------------------------

module m_qnsc_p_bus_arb_uart_0 (
  // ============================================================================
  // Slave Interface: UART_0
  // ============================================================================
  input  logic          i_clk,
  input  logic          i_rstn,
  output logic [13:0]   o_paddr,
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
  // Master Interface: AXI2APB
  // ============================================================================
  input  logic [13:0]   i_paddr_axi2apb,
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
  output logic [31:0]   o_prdata_axi2apb

);
  // ============================================================================
  // Direct Signal Routing (Single Master)
  // ============================================================================
  assign o_paddr         = i_paddr_axi2apb;
  assign o_protect_en    = i_protect_en_axi2apb;
  assign o_slverr_en     = i_slverr_en_axi2apb;
  assign o_pprot         = i_pprot_axi2apb;
  assign o_pwdata        = i_pwdata_axi2apb;
  assign o_pwrite        = i_pwrite_axi2apb;
  assign o_penable       = i_penable_axi2apb;
  assign o_psel          = i_psel_axi2apb;
  assign o_pstrb         = i_pstrb_axi2apb;
  assign o_pslverr_axi2apb = i_pslverr;
  assign o_pready_axi2apb  = i_pready;
  assign o_prdata_axi2apb  = i_prdata;

endmodule
