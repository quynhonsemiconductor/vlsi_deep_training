`timescale 1ns/1ps

// Testbench of m_qnsc_wrap_isram: the ISRAM, 64 KiB on S_BUS AXI_M1, and a behavioural
// macro with byte enables and no reset behind it (QNSC_RAM_MAS 12). The body and the
// tests are shared with the other RAM, in ../ram_common: the two wrappers differ only
// in the width of o_mem_addr.
//
//   make sim BLOCK=isram                  every test
//   make sim BLOCK=isram TEST=ram_005     one test
module tb_isram;
  localparam int unsigned C_WORDS = 16384;
  localparam int unsigned C_AW    = 14;
  `define RAM_DUT m_qnsc_wrap_isram
  `define RAM_TB  tb_isram
  `include "../ram_common/ram_tb.svh"
endmodule
