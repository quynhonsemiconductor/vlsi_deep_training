`timescale 1ns/1ps

// Single-port SRAM macro, generic implementation (simulation, FPGA, open synthesis).
//
// Every memory array of QSOC is this module, so one library cell serves the whole
// chip: an ASIC library in design/common/tech/<tech>/ implements the same module
// and ports on the foundry's compiled macro. Naming Rule 2.8.
//
// Behaviour (QNSC_RAM_MAS 5, 7):
//   - write: when i_we is high, the bytes selected by i_be are written from i_wdata
//   - read:  when i_oe is high, the containing word appears on o_rdata one cycle later
//   - i_we and i_oe are never both high (the controller's arbiter guarantees this)
//   - the array has no reset: contents survive every reset while power is applied (7.6)
//
// Users: ISRAM and DSRAM wrappers (inside, as the macro), ROM (same controller).

module qnsc_sram_sp #(
  parameter int unsigned P_DEPTH   = 16384,   // hardcode-check: ignore -- library default, wrapper overrides
  parameter int unsigned P_DATA_WD = 32       // bits per word
) (
  input  logic                       i_clk,  // naming-check: ignore -- tech cell port, not a domain clock
  input  logic [$clog2(P_DEPTH)-1:0] i_addr,
  input  logic [P_DATA_WD-1:0]       i_wdata,
  input  logic                       i_we,
  input  logic [P_DATA_WD/8-1:0]     i_be,
  input  logic                       i_oe,
  output logic [P_DATA_WD-1:0]       o_rdata
);

  logic [P_DATA_WD-1:0] mem_array [P_DEPTH];  // naming-check: ignore -- the SRAM array

  always_ff @(posedge i_clk) begin
    if (i_we) begin
      for (int k = 0; k < P_DATA_WD/8; k++) begin
        if (i_be[k]) mem_array[i_addr][8*k +: 8] <= i_wdata[8*k +: 8];
      end
    end
    if (i_oe) begin
      o_rdata <= mem_array[i_addr];
    end
  end

endmodule
