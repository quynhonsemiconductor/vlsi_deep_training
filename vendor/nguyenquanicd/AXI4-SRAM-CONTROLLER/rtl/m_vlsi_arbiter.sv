`timescale 1ns/1ps
//--------------------------------------
//Project: AXI4 SRAM Controller
//Module: m_vlsi_arbiter
//Function: Round-Robin Arbiter (Write vs Read)
//Author: Trthinh (Ethan), Thang Luong (superzeldalink)
//Page: VLSI Technology
//--------------------------------------

module m_vlsi_arbiter (
  // ============================================================================
  // Global Signals
  // ============================================================================
  input  logic  i_clk,
  input  logic  i_rst_n,

  // ============================================================================
  // Write Request Condition
  // ============================================================================
  input  logic  i_req_write,

  // ============================================================================
  // Read Request Condition
  // ============================================================================
  input  logic  i_req_read,

  // ============================================================================
  // Arbiter Outputs
  // ============================================================================
  output logic  o_arb_sel,       // 0 = write, 1 = read
  output logic  o_arb_write_en   // 1 = write active, 0 = read active
);

  // ============================================================================
  // Signal Declarations
  // ============================================================================
  logic  arb_toggle;

  // ============================================================================
  // Round-Robin Toggle (flips after each granted operation)
  // ============================================================================
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n)
      arb_toggle <= 1'b0;
    else if (o_arb_write_en | o_arb_sel)
      arb_toggle <= ~arb_toggle;
  end

  // ============================================================================
  // Arbiter Decision Logic
  // ============================================================================
  // Write wins if: write requested AND (no read OR toggle favors write)
  // Read  wins if: read  requested AND (no write OR toggle favors read)
  // ============================================================================
  assign o_arb_sel      = i_req_read  & (~i_req_write |  arb_toggle);
  assign o_arb_write_en = i_req_write & (~i_req_read  | ~arb_toggle);

endmodule: m_vlsi_arbiter
