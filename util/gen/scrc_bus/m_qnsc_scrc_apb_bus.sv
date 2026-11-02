`timescale 1ns/1ps
//--------------------------------------
//Project: APB BUS Generator
//Module: m_qnsc_scrc_apb_bus
//Function: APB Router Top-Level
//Author: apb-bus-generator
//Script Author: Trthinh (Ethan), Thang Luong (superzeldalink)
//Page: VLSI Technology
//--------------------------------------

module m_qnsc_scrc_apb_bus (
  // ============================================================================
  // Global Signals
  // ============================================================================
  input  logic          i_clk,
  input  logic          i_rstn,

  // ============================================================================
  // Master Interfaces
  // ============================================================================
  // Master: MCPU
  input  logic [13:0]   i_paddr_mcpu,
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

  // Master: IBEX
  input  logic [13:0]   i_paddr_ibex,
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
  output logic [31:0]   o_prdata_ibex,

  // ============================================================================
  // Slave Interfaces
  // ============================================================================
  // Slave: SCRC_CSR
  output logic [4:0]   o_paddr_scrc_csr,
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

  // ============================================================================
  // Internal Interconnect Wires
  // ============================================================================
  // Decoder <-> Arbiter per master-slave connections
  logic [4:0]   w_dec_paddr_scrc_csr_ibex;
  logic          w_dec_protect_en_scrc_csr_ibex;
  logic          w_dec_slverr_en_scrc_csr_ibex;
  logic [2:0]    w_dec_pprot_scrc_csr_ibex;
  logic [31:0]   w_dec_pwdata_scrc_csr_ibex;
  logic          w_dec_pwrite_scrc_csr_ibex;
  logic          w_dec_penable_scrc_csr_ibex;
  logic          w_dec_psel_scrc_csr_ibex;
  logic [3:0]    w_dec_pstrb_scrc_csr_ibex;
  logic          w_arb_pslverr_scrc_csr_ibex;
  logic          w_arb_pready_scrc_csr_ibex;
  logic [31:0]   w_arb_prdata_scrc_csr_ibex;
  logic [4:0]   w_dec_paddr_scrc_csr_mcpu;
  logic          w_dec_protect_en_scrc_csr_mcpu;
  logic          w_dec_slverr_en_scrc_csr_mcpu;
  logic [2:0]    w_dec_pprot_scrc_csr_mcpu;
  logic [31:0]   w_dec_pwdata_scrc_csr_mcpu;
  logic          w_dec_pwrite_scrc_csr_mcpu;
  logic          w_dec_penable_scrc_csr_mcpu;
  logic          w_dec_psel_scrc_csr_mcpu;
  logic [3:0]    w_dec_pstrb_scrc_csr_mcpu;
  logic          w_arb_pslverr_scrc_csr_mcpu;
  logic          w_arb_pready_scrc_csr_mcpu;
  logic [31:0]   w_arb_prdata_scrc_csr_mcpu;

  logic          w_arb_mst_pslverr_ibex;
  logic          w_arb_mst_pready_ibex;
  logic [31:0]   w_arb_mst_prdata_ibex;
  logic          w_arb_mst_pslverr_mcpu;
  logic          w_arb_mst_pready_mcpu;
  logic [31:0]   w_arb_mst_prdata_mcpu;

  // ============================================================================
  // Decoder Instances
  // ============================================================================
  // Decoder for Master MCPU
  m_qnsc_scrc_apb_bus_dec_mcpu u_decoder_mcpu (
    .i_paddr         (i_paddr_mcpu),
    .i_protect_en    (i_protect_en_mcpu),
    .i_slverr_en     (i_slverr_en_mcpu),
    .i_pprot         (i_pprot_mcpu),
    .i_pwdata        (i_pwdata_mcpu),
    .i_pwrite        (i_pwrite_mcpu),
    .i_penable       (i_penable_mcpu),
    .i_psel          (i_psel_mcpu),
    .i_pstrb         (i_pstrb_mcpu),
    .o_pslverr       (w_arb_mst_pslverr_mcpu),
    .o_pready        (w_arb_mst_pready_mcpu),
    .o_prdata        (w_arb_mst_prdata_mcpu),
    .o_paddr_scrc_csr    (w_dec_paddr_scrc_csr_mcpu),
    .o_protect_en_scrc_csr (w_dec_protect_en_scrc_csr_mcpu),
    .o_slverr_en_scrc_csr  (w_dec_slverr_en_scrc_csr_mcpu),
    .o_pprot_scrc_csr      (w_dec_pprot_scrc_csr_mcpu),
    .o_pwdata_scrc_csr     (w_dec_pwdata_scrc_csr_mcpu),
    .o_pwrite_scrc_csr     (w_dec_pwrite_scrc_csr_mcpu),
    .o_penable_scrc_csr    (w_dec_penable_scrc_csr_mcpu),
    .o_psel_scrc_csr       (w_dec_psel_scrc_csr_mcpu),
    .o_pstrb_scrc_csr      (w_dec_pstrb_scrc_csr_mcpu),
    .i_pslverr_scrc_csr    (w_arb_pslverr_scrc_csr_mcpu),
    .i_pready_scrc_csr     (w_arb_pready_scrc_csr_mcpu),
    .i_prdata_scrc_csr     (w_arb_prdata_scrc_csr_mcpu)
  );

  // Decoder for Master IBEX
  m_qnsc_scrc_apb_bus_dec_ibex u_decoder_ibex (
    .i_paddr         (i_paddr_ibex),
    .i_protect_en    (i_protect_en_ibex),
    .i_slverr_en     (i_slverr_en_ibex),
    .i_pprot         (i_pprot_ibex),
    .i_pwdata        (i_pwdata_ibex),
    .i_pwrite        (i_pwrite_ibex),
    .i_penable       (i_penable_ibex),
    .i_psel          (i_psel_ibex),
    .i_pstrb         (i_pstrb_ibex),
    .o_pslverr       (w_arb_mst_pslverr_ibex),
    .o_pready        (w_arb_mst_pready_ibex),
    .o_prdata        (w_arb_mst_prdata_ibex),
    .o_paddr_scrc_csr    (w_dec_paddr_scrc_csr_ibex),
    .o_protect_en_scrc_csr (w_dec_protect_en_scrc_csr_ibex),
    .o_slverr_en_scrc_csr  (w_dec_slverr_en_scrc_csr_ibex),
    .o_pprot_scrc_csr      (w_dec_pprot_scrc_csr_ibex),
    .o_pwdata_scrc_csr     (w_dec_pwdata_scrc_csr_ibex),
    .o_pwrite_scrc_csr     (w_dec_pwrite_scrc_csr_ibex),
    .o_penable_scrc_csr    (w_dec_penable_scrc_csr_ibex),
    .o_psel_scrc_csr       (w_dec_psel_scrc_csr_ibex),
    .o_pstrb_scrc_csr      (w_dec_pstrb_scrc_csr_ibex),
    .i_pslverr_scrc_csr    (w_arb_pslverr_scrc_csr_ibex),
    .i_pready_scrc_csr     (w_arb_pready_scrc_csr_ibex),
    .i_prdata_scrc_csr     (w_arb_prdata_scrc_csr_ibex)
  );

  // ============================================================================
  // Arbiter Instances
  // ============================================================================
  // Arbiter for Slave SCRC_CSR
  m_qnsc_scrc_apb_bus_arb_csr u_arbiter_scrc_csr (
    .i_clk           (i_clk),
    .i_rstn          (i_rstn),
    .o_paddr         (o_paddr_scrc_csr),
    .o_protect_en    (o_protect_en_scrc_csr),
    .o_slverr_en     (o_slverr_en_scrc_csr),
    .o_pprot         (o_pprot_scrc_csr),
    .o_pwdata        (o_pwdata_scrc_csr),
    .o_pwrite        (o_pwrite_scrc_csr),
    .o_penable       (o_penable_scrc_csr),
    .o_psel          (o_psel_scrc_csr),
    .o_pstrb         (o_pstrb_scrc_csr),
    .i_pslverr       (i_pslverr_scrc_csr),
    .i_pready        (i_pready_scrc_csr),
    .i_prdata        (i_prdata_scrc_csr),
    .i_paddr_mcpu    (w_dec_paddr_scrc_csr_mcpu),
    .i_protect_en_mcpu (w_dec_protect_en_scrc_csr_mcpu),
    .i_slverr_en_mcpu  (w_dec_slverr_en_scrc_csr_mcpu),
    .i_pprot_mcpu      (w_dec_pprot_scrc_csr_mcpu),
    .i_pwdata_mcpu     (w_dec_pwdata_scrc_csr_mcpu),
    .i_pwrite_mcpu     (w_dec_pwrite_scrc_csr_mcpu),
    .i_penable_mcpu    (w_dec_penable_scrc_csr_mcpu),
    .i_psel_mcpu       (w_dec_psel_scrc_csr_mcpu),
    .i_pstrb_mcpu      (w_dec_pstrb_scrc_csr_mcpu),
    .o_pslverr_mcpu    (w_arb_pslverr_scrc_csr_mcpu),
    .o_pready_mcpu     (w_arb_pready_scrc_csr_mcpu),
    .o_prdata_mcpu     (w_arb_prdata_scrc_csr_mcpu),
    .i_paddr_ibex    (w_dec_paddr_scrc_csr_ibex),
    .i_protect_en_ibex (w_dec_protect_en_scrc_csr_ibex),
    .i_slverr_en_ibex  (w_dec_slverr_en_scrc_csr_ibex),
    .i_pprot_ibex      (w_dec_pprot_scrc_csr_ibex),
    .i_pwdata_ibex     (w_dec_pwdata_scrc_csr_ibex),
    .i_pwrite_ibex     (w_dec_pwrite_scrc_csr_ibex),
    .i_penable_ibex    (w_dec_penable_scrc_csr_ibex),
    .i_psel_ibex       (w_dec_psel_scrc_csr_ibex),
    .i_pstrb_ibex      (w_dec_pstrb_scrc_csr_ibex),
    .o_pslverr_ibex    (w_arb_pslverr_scrc_csr_ibex),
    .o_pready_ibex     (w_arb_pready_scrc_csr_ibex),
    .o_prdata_ibex     (w_arb_prdata_scrc_csr_ibex)
  );

  // ============================================================================
  // Master Response Outputs
  // ============================================================================
  assign o_pslverr_mcpu = w_arb_mst_pslverr_mcpu;
  assign o_pready_mcpu  = w_arb_mst_pready_mcpu;
  assign o_prdata_mcpu  = w_arb_mst_prdata_mcpu;
  assign o_pslverr_ibex = w_arb_mst_pslverr_ibex;
  assign o_pready_ibex  = w_arb_mst_pready_ibex;
  assign o_prdata_ibex  = w_arb_mst_prdata_ibex;
endmodule
