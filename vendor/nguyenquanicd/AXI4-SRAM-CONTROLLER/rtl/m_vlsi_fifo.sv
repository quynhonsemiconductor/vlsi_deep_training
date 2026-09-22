`timescale 1ns/1ps
//--------------------------------------
//Project: AXI4 SRAM Controller
//Module: m_vlsi_fifo
//Function: Parameterized Synchronous FIFO
//Author: Trthinh (Ethan), Thang Luong (superzeldalink)
//Page: VLSI Technology
//--------------------------------------

module m_vlsi_fifo #(
  parameter PARA_DATA_WD = 32,
  parameter PARA_DEPTH   = 4
) (
  // ============================================================================
  // Global Signals
  // ============================================================================
  input  logic                     i_clk,
  input  logic                     i_rst_n,

  // ============================================================================
  // Write Port
  // ============================================================================
  input  logic [PARA_DATA_WD-1:0]  i_data,
  input  logic                     i_push,

  // ============================================================================
  // Read Port
  // ============================================================================
  input  logic                     i_pop,
  output logic [PARA_DATA_WD-1:0]  o_data_out,

  // ============================================================================
  // Status Flags
  // ============================================================================
  output logic                     o_empty,
  output logic                     o_full
);

  // ============================================================================
  // Parameter Declarations
  // ============================================================================
  localparam PARA_ADDR_WD = PARA_DEPTH;
  localparam PARA_DEPTH_SIZE = 1 << PARA_DEPTH;

  // ============================================================================
  // Signal Declarations
  // ============================================================================
  // Memory array (2D packed)
  logic [PARA_DEPTH_SIZE-1:0][PARA_DATA_WD-1:0]  mem;

  // Read/Write pointers
  logic [PARA_ADDR_WD:0]  wr_ptr;
  logic [PARA_ADDR_WD:0]  rd_ptr;

  // Next pointers
  logic [PARA_ADDR_WD:0]  nxt_wr_ptr;
  logic [PARA_ADDR_WD:0]  nxt_rd_ptr;

  // Push/Pop control
  logic  push_en;
  logic  pop_en;

  // ============================================================================
  // Push/Pop Enable Logic (prevent overflow/underflow)
  // ============================================================================
  assign push_en = i_push & ~o_full;
  assign pop_en  = i_pop  & ~o_empty;

  // ============================================================================
  // Write Pointer (Sequential)
  // ============================================================================
  assign nxt_wr_ptr = push_en ? (wr_ptr + 1'b1) : wr_ptr;

  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n)
      wr_ptr <= {PARA_ADDR_WD + 1{1'b0}};
    else
      wr_ptr <= nxt_wr_ptr;
  end

  // ============================================================================
  // Read Pointer (Sequential)
  // ============================================================================
  assign nxt_rd_ptr = pop_en ? (rd_ptr + 1'b1) : rd_ptr;

  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n)
      rd_ptr <= {PARA_ADDR_WD + 1{1'b0}};
    else
      rd_ptr <= nxt_rd_ptr;
  end

  // ============================================================================
  // Memory Write (Sequential)
  // ============================================================================
  always_ff @(posedge i_clk, negedge i_rst_n) begin
    if (!i_rst_n)
      mem <= '0;
    else if (push_en)
      mem[wr_ptr[PARA_ADDR_WD-1:0]] <= i_data;
  end

  // ============================================================================
  // Memory Read (Combinational)
  // ============================================================================
  assign o_data_out = mem[rd_ptr[PARA_ADDR_WD-1:0]];

  // ============================================================================
  // Full / Empty Flags (Combinational)
  // ============================================================================
  assign o_full  = (wr_ptr[PARA_ADDR_WD] != rd_ptr[PARA_ADDR_WD]) &
                   (wr_ptr[PARA_ADDR_WD-1:0] == rd_ptr[PARA_ADDR_WD-1:0]);

  assign o_empty = (wr_ptr == rd_ptr);

endmodule
