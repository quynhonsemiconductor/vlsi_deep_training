`timescale 1ns / 1ps
//--------------------------------------
//Project: AXI4 SRAM Controller
//Module: m_vlsi_sram_misc
//Function: Centralized control/datapath glue logic for AXI4-SRAM top
//Author: Refactor from m_vlsi_axi4_sram
//--------------------------------------

module m_vlsi_sram_misc #(
    parameter PARA_DATA_WD = 32,
    parameter PARA_ADDR_WD = 32,
    parameter PARA_ID_WD   = 4
) (
    // ============================================================================
    // Global Signals
    // ============================================================================
    input logic i_clk,
    input logic i_rst_n,

    // ============================================================================
    // AXI Side Handshake Inputs
    // ============================================================================
    input logic i_wvalid,
    input logic i_rready,
    input logic i_bready,

    // ============================================================================
    // AXFSM Outputs (for AW/AR FIFO input packing)
    // ============================================================================
    input logic [PARA_ADDR_WD-1:0] i_axaddr_wr,
    input logic [  PARA_ID_WD-1:0] i_id_wr,
    input logic                    i_awlast_wr,
    input logic [PARA_ADDR_WD-1:0] i_axaddr_rd,
    input logic [  PARA_ID_WD-1:0] i_id_rd,
    input logic                    i_arlast,

    // ============================================================================
    // Arbiter Result Inputs
    // ============================================================================
    input logic i_arb_sel,
    input logic i_arb_write_en,

    // ============================================================================
    // FIFO Status/Data Inputs
    // ============================================================================
    input logic [  PARA_ADDR_WD+PARA_ID_WD:0] i_awfifo_data_out,
    input logic                               i_awfifo_empty,
    input logic [           PARA_DATA_WD-1:0] i_wfifo_data_out,
    input logic                               i_wfifo_empty,
    input logic                               i_wfifo_full,
    input logic [  PARA_ADDR_WD+PARA_ID_WD:0] i_arfifo_data_out,
    input logic                               i_arfifo_empty,
    input logic [PARA_DATA_WD+PARA_ID_WD+2:0] i_rfifo_data_out,
    input logic                               i_rfifo_empty,
    input logic                               i_rfifo_full,
    input logic [             PARA_ID_WD+1:0] i_bfifo_data_out,
    input logic                               i_bfifo_empty,

    // ============================================================================
    // SRAM Read Data Input
    // ============================================================================
    input logic [PARA_DATA_WD-1:0] i_sram_rdata,

    // ============================================================================
    // FIFO Control/Data Outputs
    // ============================================================================
    output logic [PARA_ADDR_WD+PARA_ID_WD:0] o_awfifo_data_in,
    output logic                              o_awfifo_pop,
    output logic                              o_wfifo_push,
    output logic                              o_wfifo_pop,
    output logic [PARA_ADDR_WD+PARA_ID_WD:0] o_arfifo_data_in,
    output logic                              o_arfifo_pop,
    output logic [PARA_DATA_WD+PARA_ID_WD+2:0] o_rfifo_data_in,
    output logic                                o_rfifo_push,
    output logic                                o_rfifo_pop,
    output logic [PARA_ID_WD+1:0]               o_bfifo_data_in,
    output logic                                o_bfifo_push,
    output logic                                o_bfifo_pop,

    // ============================================================================
    // Arbiter Request Outputs
    // ============================================================================
    output logic o_req_write,
    output logic o_req_read,

    // ============================================================================
    // AXI Outputs
    // ============================================================================
    output logic [  PARA_ID_WD-1:0] o_rid,
    output logic [PARA_DATA_WD-1:0] o_rdata,
    output logic [             1:0] o_rresp,
    output logic                    o_rvalid,
    output logic                    o_rlast,
    output logic [  PARA_ID_WD-1:0] o_bid,
    output logic [             1:0] o_bresp,
    output logic                    o_bvalid,
    output logic                    o_wready,

    // ============================================================================
    // SRAM Outputs
    // ============================================================================
    output logic [PARA_ADDR_WD-1:0] o_sram_addr,
    output logic [PARA_DATA_WD-1:0] o_sram_wdata,
    output logic                    o_sram_we,
    output logic                    o_sram_oe
);

  logic                    w_rd_issue;
  logic                    reg_rd_pending;
  logic [PARA_ID_WD-1:0]   reg_rd_id_d;
  logic                    reg_rd_last_d;

  assign o_awfifo_data_in = {i_awlast_wr, i_id_wr, i_axaddr_wr};
  assign o_arfifo_data_in = {i_arlast, i_id_rd, i_axaddr_rd};

  assign o_rfifo_data_in = {
    reg_rd_id_d,
    2'b00,
    i_sram_rdata,
    reg_rd_last_d
  };

  assign o_bfifo_data_in = {i_awfifo_data_out[PARA_ADDR_WD+PARA_ID_WD-1:PARA_ADDR_WD], 2'b00};

  assign o_req_write = ~i_awfifo_empty & ~i_wfifo_empty;
  assign o_req_read  = ~i_arfifo_empty & ~i_rfifo_full & ~reg_rd_pending;

  assign o_sram_addr  = i_arb_write_en ? i_awfifo_data_out[PARA_ADDR_WD-1:0] : i_arfifo_data_out[PARA_ADDR_WD-1:0];
  assign o_sram_wdata = i_wfifo_data_out;
  assign o_sram_we    = i_arb_write_en;
  assign o_sram_oe    = w_rd_issue;

  assign o_awfifo_pop = i_arb_write_en;
  assign o_wfifo_pop  = i_arb_write_en;

  assign w_rd_issue   = ~i_arb_write_en & i_arb_sel & ~i_arfifo_empty & ~i_rfifo_full & ~reg_rd_pending;
  assign o_arfifo_pop = w_rd_issue;

  assign o_rfifo_push = reg_rd_pending;
  assign o_rfifo_pop  = i_rready & ~i_rfifo_empty;

  assign o_bfifo_push = i_arb_write_en & i_awfifo_data_out[PARA_ADDR_WD+PARA_ID_WD];
  assign o_bfifo_pop  = i_bready & ~i_bfifo_empty;

  assign o_wready    = ~i_wfifo_full;
  assign o_wfifo_push = i_wvalid & o_wready;

  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      reg_rd_pending <= 1'b0;
      reg_rd_id_d    <= '0;
      reg_rd_last_d  <= 1'b0;
    end else begin
      reg_rd_pending <= w_rd_issue;
      if (w_rd_issue) begin
        reg_rd_id_d   <= i_arfifo_data_out[PARA_ADDR_WD+PARA_ID_WD-1:PARA_ADDR_WD];
        reg_rd_last_d <= i_arfifo_data_out[PARA_ADDR_WD+PARA_ID_WD];
      end
    end
  end

  assign o_rid    = i_rfifo_data_out[PARA_DATA_WD+PARA_ID_WD+2:PARA_DATA_WD+3];
  assign o_rdata  = i_rfifo_data_out[PARA_DATA_WD:1];
  assign o_rresp  = i_rfifo_data_out[PARA_DATA_WD+2:PARA_DATA_WD+1];
  assign o_rlast  = i_rfifo_data_out[0];
  assign o_rvalid = ~i_rfifo_empty;

  assign o_bid    = i_bfifo_data_out[PARA_ID_WD+1:2];
  assign o_bresp  = i_bfifo_data_out[1:0];
  assign o_bvalid = ~i_bfifo_empty;

endmodule : m_vlsi_sram_misc
