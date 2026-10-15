// Behavioural single-port SRAM macro for the ISRAM and DSRAM testbenches.
//
// What the MAS (QNSC_RAM_MAS 12) asks of the model, and the IP's own model lacks
// (sim/vcs/env/m_vlsi_sram_sp.sv has no byte enables and resets its array):
//   - byte write enables: bit n of i_be writes i_wdata[8n+7:8n]; i_be = 0 writes nothing
//   - read data valid in the cycle after i_oe, the timing the controller samples
//   - NO reset: the array keeps its contents through an i_rst_n_mem pulse (MAS 7.6)
// It is a testbench file (dv/README.md, rule 3), not a technology cell: the macro of
// the chip is placed by design/top.
module tb_sram_model #(
  parameter int unsigned WORDS = 16384
) (
  input  logic                       i_clk,
  input  logic [$clog2(WORDS)-1:0]   i_addr,
  input  logic [31:0]                i_wdata,
  input  logic                       i_we,
  input  logic [3:0]                 i_be,
  input  logic                       i_oe,
  output logic [31:0]                o_rdata
);
  logic [31:0] mem [WORDS];

  always_ff @(posedge i_clk) begin
    if (i_we) begin
      for (int b = 0; b < 4; b++)
        if (i_be[b]) mem[i_addr][8*b +: 8] <= i_wdata[8*b +: 8];
    end
    if (i_oe) o_rdata <= mem[i_addr];
  end

  // For the testbench: the array, without going through the bus.
  function automatic logic [31:0] peek(input int unsigned word);
    return mem[word];
  endfunction
endmodule
