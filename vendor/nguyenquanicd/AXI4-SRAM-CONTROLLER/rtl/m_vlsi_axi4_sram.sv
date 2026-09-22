`timescale 1ns / 1ps
//--------------------------------------
//Project: AXI4 SRAM Controller
//Module: m_vlsi_axi4_sram
//Function: AXI4 to SRAM Bridge Top-Level
//Author: Trthinh (Ethan), Thang Luong (superzeldalink)
//Page: VLSI Technology
//--------------------------------------

module m_vlsi_axi4_sram #(
    parameter PARA_DATA_WD    = 32,
    parameter PARA_ADDR_WD    = 32,
    parameter PARA_ID_WD      = 4,
    parameter PARA_LEN_WD     = 8,
    parameter PARA_FIFO_DEPTH = 8
) (
    // ============================================================================
    // Global Signals
    // ============================================================================
    input logic i_clk,
    input logic i_rst_n,

    // ============================================================================
    // AXI Write Address Channel (AW)
    // ============================================================================
    input  logic [PARA_ADDR_WD-1:0] i_awaddr,
    input  logic                    i_awvalid,
    output logic                    o_awready,
    input  logic [             1:0] i_awburst,
    input  logic [ PARA_LEN_WD-1:0] i_awlen,
    input  logic [  PARA_ID_WD-1:0] i_awid,

    // ============================================================================
    // AXI Write Data Channel (W)
    // ============================================================================
    input  logic [PARA_DATA_WD-1:0] i_wdata,
    input  logic                    i_wvalid,
    output logic                    o_wready,
    input  logic                    i_wlast,

    // ============================================================================
    // AXI Write Response Channel (B)
    // ============================================================================
    output logic [PARA_ID_WD-1:0] o_bid,
    output logic [           1:0] o_bresp,
    output logic                  o_bvalid,
    input  logic                  i_bready,

    // ============================================================================
    // AXI Read Address Channel (AR)
    // ============================================================================
    input  logic [PARA_ADDR_WD-1:0] i_araddr,
    input  logic                    i_arvalid,
    output logic                    o_arready,
    input  logic [             1:0] i_arburst,
    input  logic [ PARA_LEN_WD-1:0] i_arlen,
    input  logic [  PARA_ID_WD-1:0] i_arid,

    // ============================================================================
    // AXI Read Data Channel (R)
    // ============================================================================
    output logic [  PARA_ID_WD-1:0] o_rid,
    output logic [PARA_DATA_WD-1:0] o_rdata,
    output logic [             1:0] o_rresp,
    output logic                    o_rvalid,
    output logic                    o_rlast,
    input  logic                    i_rready,

    // ============================================================================
    // SRAM Interface (exposed for external SRAM instance)
    // ============================================================================
    output logic [PARA_ADDR_WD-1:0] o_sram_addr,
    output logic [PARA_DATA_WD-1:0] o_sram_wdata,
    output logic                    o_sram_we,
    output logic                    o_sram_oe,
    input  logic [PARA_DATA_WD-1:0] i_sram_rdata
);

  localparam PARA_FIFO_AW = (PARA_FIFO_DEPTH <= 2) ? 1 : $clog2(PARA_FIFO_DEPTH);
  localparam PARA_AW_DEPTH = PARA_FIFO_AW;
  localparam PARA_W_DEPTH  = PARA_FIFO_AW;
  localparam PARA_AR_DEPTH = PARA_FIFO_AW;
  localparam PARA_R_DEPTH  = PARA_FIFO_AW;
  localparam PARA_B_DEPTH  = PARA_FIFO_AW;

  logic [           PARA_ADDR_WD-1:0] w_axaddr_wr;
  logic                               w_push_wr;
  logic [             PARA_ID_WD-1:0] w_id_wr;

  logic [           PARA_ADDR_WD-1:0] w_axaddr_rd;
  logic                               w_push_rd;
  logic [             PARA_ID_WD-1:0] w_id_rd;

  logic [  PARA_ADDR_WD+PARA_ID_WD:0] w_awfifo_data_out;
  logic [  PARA_ADDR_WD+PARA_ID_WD:0] w_awfifo_data_in;
  logic                               w_awfifo_empty;
  logic                               w_awfifo_full;
  logic                               w_awfifo_pop;
  logic                               w_awlast_wr;

  logic [           PARA_DATA_WD-1:0] w_wfifo_data_out;
  logic                               w_wfifo_empty;
  logic                               w_wfifo_full;
  logic                               w_wfifo_push;
  logic                               w_wfifo_pop;

  logic [  PARA_ADDR_WD+PARA_ID_WD:0] w_arfifo_data_out;
  logic [  PARA_ADDR_WD+PARA_ID_WD:0] w_arfifo_data_in;
  logic                               w_arfifo_empty;
  logic                               w_arfifo_full;
  logic                               w_arfifo_pop;

  logic [PARA_DATA_WD+PARA_ID_WD+2:0] w_rfifo_data_out;
  logic [PARA_DATA_WD+PARA_ID_WD+2:0] w_rfifo_data_in;
  logic                               w_rfifo_empty;
  logic                               w_rfifo_full;
  logic                               w_rfifo_pop;
  logic                               w_rfifo_push;
  logic                               w_arlast;

  logic [             PARA_ID_WD+1:0] w_bfifo_data_out;
  logic [             PARA_ID_WD+1:0] w_bfifo_data_in;
  logic                               w_bfifo_empty;
  logic                               w_bfifo_full;
  logic                               w_bfifo_pop;
  logic                               w_bfifo_push;

  logic                               w_req_write;
  logic                               w_req_read;
  logic                               w_arb_sel;
  logic                               w_arb_write_en;

  m_vlsi_axfsm #(
      .PARA_ADDR_WD(PARA_ADDR_WD),
      .PARA_ID_WD  (PARA_ID_WD),
      .PARA_DATA_WD(PARA_DATA_WD),
      .PARA_LEN_WD (PARA_LEN_WD)
  ) u_axfsm_wr (
      .i_clk          (i_clk),
      .i_rst_n        (i_rst_n),
      .i_axaddr       (i_awaddr),
      .i_axvalid      (i_awvalid),
      .o_axready      (o_awready),
      .i_axburst      (i_awburst),
      .i_axlen        (i_awlen),
      .i_axid         (i_awid),
      .i_fifo_not_full(~w_awfifo_full),
      .o_axaddr_out   (w_axaddr_wr),
      .o_push_fifo    (w_push_wr),
      .o_id           (w_id_wr),
      .o_last         (w_awlast_wr)
  );

  m_vlsi_axfsm #(
      .PARA_ADDR_WD(PARA_ADDR_WD),
      .PARA_ID_WD  (PARA_ID_WD),
      .PARA_DATA_WD(PARA_DATA_WD),
      .PARA_LEN_WD (PARA_LEN_WD)
  ) u_axfsm_rd (
      .i_clk          (i_clk),
      .i_rst_n        (i_rst_n),
      .i_axaddr       (i_araddr),
      .i_axvalid      (i_arvalid),
      .o_axready      (o_arready),
      .i_axburst      (i_arburst),
      .i_axlen        (i_arlen),
      .i_axid         (i_arid),
      .i_fifo_not_full(~w_arfifo_full),
      .o_axaddr_out   (w_axaddr_rd),
      .o_push_fifo    (w_push_rd),
      .o_id           (w_id_rd),
      .o_last         (w_arlast)
  );

  m_vlsi_fifo #(
      .PARA_DATA_WD(PARA_ADDR_WD + PARA_ID_WD + 1),
      .PARA_DEPTH  (PARA_AW_DEPTH)
  ) u_awfifo (
      .i_clk     (i_clk),
      .i_rst_n   (i_rst_n),
      .i_data    (w_awfifo_data_in),
      .i_push    (w_push_wr),
      .i_pop     (w_awfifo_pop),
      .o_data_out(w_awfifo_data_out),
      .o_empty   (w_awfifo_empty),
      .o_full    (w_awfifo_full)
  );

  m_vlsi_fifo #(
      .PARA_DATA_WD(PARA_DATA_WD),
      .PARA_DEPTH  (PARA_W_DEPTH)
  ) u_wfifo (
      .i_clk     (i_clk),
      .i_rst_n   (i_rst_n),
      .i_data    (i_wdata),
      .i_push    (w_wfifo_push),
      .i_pop     (w_wfifo_pop),
      .o_data_out(w_wfifo_data_out),
      .o_empty   (w_wfifo_empty),
      .o_full    (w_wfifo_full)
  );

  m_vlsi_fifo #(
      .PARA_DATA_WD(PARA_ADDR_WD + PARA_ID_WD + 1),
      .PARA_DEPTH  (PARA_AR_DEPTH)
  ) u_arfifo (
      .i_clk     (i_clk),
      .i_rst_n   (i_rst_n),
      .i_data    (w_arfifo_data_in),
      .i_push    (w_push_rd),
      .i_pop     (w_arfifo_pop),
      .o_data_out(w_arfifo_data_out),
      .o_empty   (w_arfifo_empty),
      .o_full    (w_arfifo_full)
  );

  m_vlsi_fifo #(
      .PARA_DATA_WD(PARA_DATA_WD + PARA_ID_WD + 2 + 1),
      .PARA_DEPTH  (PARA_R_DEPTH)
  ) u_rfifo (
      .i_clk     (i_clk),
      .i_rst_n   (i_rst_n),
      .i_data    (w_rfifo_data_in),
      .i_push    (w_rfifo_push),
      .i_pop     (w_rfifo_pop),
      .o_data_out(w_rfifo_data_out),
      .o_empty   (w_rfifo_empty),
      .o_full    (w_rfifo_full)
  );

  m_vlsi_fifo #(
      .PARA_DATA_WD(PARA_ID_WD + 2),
      .PARA_DEPTH  (PARA_B_DEPTH)
  ) u_bfifo (
      .i_clk     (i_clk),
      .i_rst_n   (i_rst_n),
      .i_data    (w_bfifo_data_in),
      .i_push    (w_bfifo_push),
      .i_pop     (w_bfifo_pop),
      .o_data_out(w_bfifo_data_out),
      .o_empty   (w_bfifo_empty),
      .o_full    (w_bfifo_full)
  );

  m_vlsi_arbiter u_arbiter (
      .i_clk         (i_clk),
      .i_rst_n       (i_rst_n),
      .i_req_write   (w_req_write),
      .i_req_read    (w_req_read),
      .o_arb_sel     (w_arb_sel),
      .o_arb_write_en(w_arb_write_en)
  );

  m_vlsi_sram_misc #(
      .PARA_DATA_WD(PARA_DATA_WD),
      .PARA_ADDR_WD(PARA_ADDR_WD),
      .PARA_ID_WD  (PARA_ID_WD)
  ) u_sram_misc (
      .i_clk          (i_clk),
      .i_rst_n        (i_rst_n),
      .i_wvalid       (i_wvalid),
      .i_rready       (i_rready),
      .i_bready       (i_bready),
      .i_axaddr_wr    (w_axaddr_wr),
      .i_id_wr        (w_id_wr),
      .i_awlast_wr    (w_awlast_wr),
      .i_axaddr_rd    (w_axaddr_rd),
      .i_id_rd        (w_id_rd),
      .i_arlast       (w_arlast),
      .i_arb_sel      (w_arb_sel),
      .i_arb_write_en (w_arb_write_en),
      .i_awfifo_data_out(w_awfifo_data_out),
      .i_awfifo_empty (w_awfifo_empty),
      .i_wfifo_data_out(w_wfifo_data_out),
      .i_wfifo_empty  (w_wfifo_empty),
      .i_wfifo_full   (w_wfifo_full),
      .i_arfifo_data_out(w_arfifo_data_out),
      .i_arfifo_empty (w_arfifo_empty),
      .i_rfifo_data_out(w_rfifo_data_out),
      .i_rfifo_empty  (w_rfifo_empty),
      .i_rfifo_full   (w_rfifo_full),
      .i_bfifo_data_out(w_bfifo_data_out),
      .i_bfifo_empty  (w_bfifo_empty),
      .i_sram_rdata   (i_sram_rdata),
      .o_awfifo_data_in(w_awfifo_data_in),
      .o_awfifo_pop   (w_awfifo_pop),
      .o_wfifo_push   (w_wfifo_push),
      .o_wfifo_pop    (w_wfifo_pop),
      .o_arfifo_data_in(w_arfifo_data_in),
      .o_arfifo_pop   (w_arfifo_pop),
      .o_rfifo_data_in(w_rfifo_data_in),
      .o_rfifo_push   (w_rfifo_push),
      .o_rfifo_pop    (w_rfifo_pop),
      .o_bfifo_data_in(w_bfifo_data_in),
      .o_bfifo_push   (w_bfifo_push),
      .o_bfifo_pop    (w_bfifo_pop),
      .o_req_write    (w_req_write),
      .o_req_read     (w_req_read),
      .o_rid          (o_rid),
      .o_rdata        (o_rdata),
      .o_rresp        (o_rresp),
      .o_rvalid       (o_rvalid),
      .o_rlast        (o_rlast),
      .o_bid          (o_bid),
      .o_bresp        (o_bresp),
      .o_bvalid       (o_bvalid),
      .o_wready       (o_wready),
      .o_sram_addr    (o_sram_addr),
      .o_sram_wdata   (o_sram_wdata),
      .o_sram_we      (o_sram_we),
      .o_sram_oe      (o_sram_oe)
  );

endmodule : m_vlsi_axi4_sram
