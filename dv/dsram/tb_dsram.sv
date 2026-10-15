`timescale 1ns/1ps

// Testbench of m_qnsc_wrap_dsram: the DSRAM, 32 KiB on S_BUS AXI_M2, and a behavioural
// macro with byte enables and no reset behind it (QNSC_RAM_MAS 12). The body and the
// tests are shared with the other RAM, in ../ram_common: the two wrappers differ only
// in the width of o_mem_addr.
//
//   make sim BLOCK=dsram                  every test
//   make sim BLOCK=dsram TEST=ram_005     one test
module tb_dsram;
  localparam int unsigned C_WORDS = 8192;
  localparam int unsigned C_AW    = 13;
  `define RAM_DUT m_qnsc_wrap_dsram
  `define RAM_TB  tb_dsram
  `include "../ram_common/ram_tb.svh"
endmodule
