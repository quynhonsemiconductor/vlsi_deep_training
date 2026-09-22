`timescale 1ns / 1ps
//--------------------------------------
//Project: AXI4 SRAM Controller
//Module: m_vlsi_axfsm
//Function: AXI Address Channel FSM (shared for AW/AR)
//Author: Trthinh (Ethan), Thang Luong (superzeldalink)
//Page: VLSI Technology
//--------------------------------------

module m_vlsi_axfsm #(
    parameter PARA_ADDR_WD = 32,
    parameter PARA_ID_WD   = 4,
    parameter PARA_DATA_WD = 32,
    parameter PARA_LEN_WD  = 8
) (
    // ============================================================================
    // Global Signals
    // ============================================================================
    input logic i_clk,
    input logic i_rst_n,

    // ============================================================================
    // AXI Address Channel (AX) — shared for AW and AR
    // ============================================================================
    input  logic [PARA_ADDR_WD-1:0] i_axaddr,
    input  logic                    i_axvalid,
    output logic                    o_axready,
    input  logic [             1:0] i_axburst,
    input  logic [ PARA_LEN_WD-1:0] i_axlen,
    input  logic [  PARA_ID_WD-1:0] i_axid,

    // ============================================================================
    // FIFO Status (for AXREADY generation)
    // ============================================================================
    input logic i_fifo_not_full,

    // ============================================================================
    // Outputs to FIFO / Downstream Logic
    // ============================================================================
    output logic [PARA_ADDR_WD-1:0] o_axaddr_out,
    output logic                    o_push_fifo,
    output logic [  PARA_ID_WD-1:0] o_id,
    output logic                    o_last
);

  // ============================================================================
  // Parameter Declarations
  // ============================================================================
  localparam PARA_BYTE_COUNT = PARA_DATA_WD / 8;

  // ============================================================================
  // State Encoding
  // ============================================================================
  localparam S_IDLE = 1'b0;
  localparam S_ADDR = 1'b1;

  // ============================================================================
  // Signal Declarations
  // ============================================================================
  // State registers
  logic                    reg_state;
  logic                    nxt_state;

  // Address counter
  logic [ PARA_LEN_WD-1:0] reg_cnt_addr;
  logic                    cnt_addr_done;

  // Burst type register
  logic [             1:0] reg_axburst;

  // Burst address register (for subsequent beats)
  logic [PARA_ADDR_WD-1:0] reg_axaddr;

  // AXID register
  logic [  PARA_ID_WD-1:0] reg_id;

  // Burst address calculation wires
  logic [PARA_ADDR_WD-1:0] addr_fixed;
  logic [PARA_ADDR_WD-1:0] addr_incr;
  logic [PARA_ADDR_WD-1:0] addr_wrap;
  logic [PARA_ADDR_WD-1:0] addr_calc;

  // Handshake detect (combinational)
  logic                    hs;

  // Beat emit control: one beat is emitted only when FIFO can accept it.
  logic                    beat_fire;

  // ============================================================================
  // Handshake Detection (Combinational)
  // ============================================================================
  assign hs = (reg_state == S_IDLE) & i_axvalid & o_axready;

  // Emit beats only in S_ADDR, and only when FIFO can accept.
  // The first beat is emitted in the cycle after AX handshake (original behavior).
  assign beat_fire = (reg_state == S_ADDR) & ~cnt_addr_done & i_fifo_not_full;

  // ============================================================================
  // FSM State Transition Logic (Combinational)
  // ============================================================================
  always_comb begin
    case (reg_state)
      S_IDLE: begin
        if (hs) nxt_state = S_ADDR;
        else nxt_state = S_IDLE;
      end
      S_ADDR: begin
        if (cnt_addr_done) nxt_state = S_IDLE;
        else nxt_state = S_ADDR;
      end
      default: nxt_state = S_IDLE;
    endcase
  end

  // ============================================================================
  // State Register (Sequential)
  // ============================================================================
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) reg_state <= S_IDLE;
    else reg_state <= nxt_state;
  end

  // ============================================================================
  // Address Counter Logic
  // ============================================================================
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) reg_cnt_addr <= {PARA_LEN_WD{1'b0}};
    else if (hs) reg_cnt_addr <= i_axlen + {{(PARA_LEN_WD - 1) {1'b0}}, 1'b1};
    else if ((reg_state == S_ADDR) & ~cnt_addr_done & i_fifo_not_full)
      reg_cnt_addr <= reg_cnt_addr - {{(PARA_LEN_WD - 1) {1'b0}}, 1'b1};
  end

  assign cnt_addr_done = (reg_cnt_addr == {PARA_LEN_WD{1'b0}});

  // ============================================================================
  // Burst Type Register
  // ============================================================================
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) reg_axburst <= 2'b01;  // default INCR
    else if (hs) reg_axburst <= i_axburst;
  end

  // ============================================================================
  // Burst Address Calculation
  // ============================================================================
  assign addr_fixed = reg_axaddr;
  assign addr_incr = reg_axaddr + PARA_BYTE_COUNT;
  assign addr_wrap = (reg_axaddr + PARA_BYTE_COUNT) & ~(PARA_BYTE_COUNT - 1);

  assign addr_calc = (reg_axburst == 2'b00) ? addr_fixed :
                     (reg_axburst == 2'b01) ? addr_incr  :
                     addr_wrap;

  // ============================================================================
  // Address Register
  // ============================================================================
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) reg_axaddr <= {PARA_ADDR_WD{1'b0}};
    else if (hs) reg_axaddr <= i_axaddr;
    else if ((reg_state == S_ADDR) & ~cnt_addr_done & i_fifo_not_full) reg_axaddr <= addr_calc;
  end

  // ============================================================================
  // AXID Register
  // ============================================================================
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) reg_id <= {PARA_ID_WD{1'b0}};
    else if (hs) reg_id <= i_axid;
  end

  // ============================================================================
  // AXREADY Logic
  // ============================================================================
  // Keep READY combinational with true accept capability so VALID&READY
  // always matches a transfer the FSM will actually capture this cycle.
  assign o_axready    = (reg_state == S_IDLE) & i_fifo_not_full;

  // ============================================================================
  // Output Assignments
  // On handshake cycle: output i_axaddr/i_axid directly (combinational)
  // so FIFO captures correct data on the clock edge.
  // During burst: output reg_axaddr/reg_id.
  // ============================================================================
  assign o_axaddr_out = reg_axaddr;
  assign o_push_fifo  = beat_fire;
  assign o_id         = reg_id;
  assign o_last       = beat_fire & (reg_cnt_addr == {{(PARA_LEN_WD - 1) {1'b0}}, 1'b1});

endmodule : m_vlsi_axfsm
