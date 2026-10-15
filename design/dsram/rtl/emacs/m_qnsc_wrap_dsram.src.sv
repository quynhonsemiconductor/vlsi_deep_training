`timescale 1ns/1ps

// QNSC wrapper of m_vlsi_axi4_sram: the QSoC DSRAM, 32 KiB on S_BUS AXI_M2.
// Spec: doc/specs/QNSC_RAM_MAS.md.
//
// Edit this .src.sv, then `make wrap BLOCK=dsram`: emacs verilog-mode expands
// the AUTO comments and writes rtl/m_qnsc_wrap_dsram.sv, the file dsram.f compiles.
// Template functions: doc/rules/EMACS_quick_guide.pdf.
//
// Wrapper = core + bridge. The core is the IP, the AXI4 SRAM controller, unmodified.
// The controller speaks AXI4 already, so the only addition is what it lacks (MAS 7.3):
// the byte enables. u_strbfifo, a vendored m_vlsi_fifo of the controller's own depth,
// holds WSTRB beside the controller's write-data FIFO.
//
// The memory macro is not in the wrapper. The wrapper ends at o_mem_* / i_mem_rdata,
// the macro's pins (MAS 5); design/top puts the macro there.
//
// A wrapper is IP (design/README.md, "Shared numbers: who may use qnsc_pkg"):
// no import, no parameter. The IP's configuration is fixed at the instances below.

module m_qnsc_wrap_dsram
(
//---------------------------------------------------------------
// Clock/Reset: SCRC o_clk_ram, o_rst_n_ram (domain ram, mem cluster, never gated)
//---------------------------------------------------------------
/*AUTOINPUT("^i_clk\|^i_rst")*/

//---------------------------------------------------------------
// Bus interface (AXI4 subordinate, S_BUS AXI_M2)
//---------------------------------------------------------------
/*AUTOINPUT("^i_bus_axi")*/
/*AUTOOUTPUT("^o_bus_axi")*/

//---------------------------------------------------------------
// Memory macro, 8192 words x 32 bits. The macro's pins.
// o_mem_we and o_mem_be are declared by hand: the wrapper reads both inside (the
// strobe path below), and AUTOOUTPUT does not declare a signal the wrapper itself
// uses as an input. The other ports come from the controller.
//---------------------------------------------------------------
/*AUTOINPUT("^i_mem")*/
/*AUTOOUTPUT("^o_mem")*/
output logic            o_mem_we,
output logic [3:0]      o_mem_be,

//---------------------------------------------------------------
// Others -- must stay empty once the templates below are complete
//---------------------------------------------------------------
/*AUTOINOUT*/
/*AUTOINPUT*/
/*AUTOOUTPUT*/
);

/*AUTOWIRE*/

logic                   w_strb_push;

/*AUTO_LISP(setq verilog-auto-inout-ignore-regexp
  (concat
  "unuse_inout"
  "\\|unuse_inout"
  ))
*/

/*AUTO_LISP(setq verilog-auto-input-ignore-regexp
  (concat
  "^w_"
  "\\|unuse_input"
  ))
*/

/*AUTO_LISP(setq verilog-auto-output-ignore-regexp
  (concat
  "^w_"
  "\\|unuse_output"
  ))
*/

//---------------------------------------------------------------
// Core: the AXI4 SRAM controller (QNSC_RAM_MAS 4, 5, 8)
//---------------------------------------------------------------
// Map every IP port to a QNSC name. First match wins; [] keeps the width.
// AXI: i_awaddr -> i_bus_axi_aw_addr, o_rlast -> o_bus_axi_r_last, ...
// The macro word address is the controller's byte address [14:2]; the bits above
// and the two below never reach the macro (MAS 7.2).
/* m_vlsi_axi4_sram AUTO_TEMPLATE(
    .i_clk                  (i_clk_mem),
    .i_rst_n                (i_rst_n_mem),
    .i_aw\(len\)           ({1'b0, i_bus_axi_aw_len[7:0]}),
    .i_ar\(len\)           ({1'b0, i_bus_axi_ar_len[7:0]}),
    .\(i\|o\)_\(aw\|ar\|w\|b\|r\)\(addr\|valid\|ready\|burst\|len\|id\|data\|last\|resp\) (\1_bus_axi_\2_\3[]),
    .o_sram_addr            ({w_mem_addr_hi[31:15], o_mem_addr[12:0], w_mem_addr_lo[1:0]}),
    .o_sram_wdata           (o_mem_wdata[]),
    .o_sram_we              (o_mem_we),
    .o_sram_oe              (o_mem_oe),
    .i_sram_rdata           (i_mem_rdata[]),
);
*/
// AxLEN is 8 bits on the bus and PARA_LEN_WD is 9. The controller's address FSM loads
// its beat counter with AxLEN + 1; with PARA_LEN_WD = 8, a 256-beat burst (AxLEN = 255)
// loads 0, is finished before it starts, and the burst is dropped with no response
// (found in simulation, dv/ram_common, RAM_012). One more bit, tied 0, makes the
// counter wide enough and leaves the vendored RTL as it is (MAS 5, Table 5-2).
m_vlsi_axi4_sram #(  // naming-check: ignore -- vendored module name
  .PARA_DATA_WD    (32), // contract: meta.data_width
  .PARA_ADDR_WD    (32), // contract: meta.addr_width
  .PARA_ID_WD      (7),  // the S_BUS master-port ID width, QNSC_RAM_MAS Table 5-2
  .PARA_LEN_WD     (9),  // 9, not 8: see the note above the instance
  .PARA_FIFO_DEPTH (8)
) u_sram_ctrl (/*AUTOINST*/);

//---------------------------------------------------------------
// Byte enables (QNSC_RAM_MAS 7.3)
//---------------------------------------------------------------
// The controller has no WSTRB. u_strbfifo is pushed with the controller's own
// write-data push (wvalid & wready) and popped with its write grant (o_mem_we), so
// it holds the same number of entries as the write-data FIFO in every cycle and its
// head is the strobe of the beat being written. Depth 2**3 = PARA_FIFO_DEPTH.
/* m_vlsi_fifo AUTO_TEMPLATE(
    .i_clk                  (i_clk_mem),
    .i_rst_n                (i_rst_n_mem),
    .i_data                 (i_bus_axi_w_strb[]),
    .i_push                 (w_strb_push),
    .i_pop                  (o_mem_we),
    .o_data_out             (w_strb_head[]),
    .o_empty                (),
    .o_full                 (),
);
*/
m_vlsi_fifo #(  // naming-check: ignore -- vendored module name
  .PARA_DATA_WD (4),
  .PARA_DEPTH   (3)
) u_strbfifo (/*AUTOINST*/);

assign w_strb_push = i_bus_axi_w_valid & o_bus_axi_w_ready;
assign o_mem_be    = o_mem_we ? w_strb_head : 4'b0000;

endmodule
// Local Variables:
// verilog-library-flags:("-f filelist_emacs.f")
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: t
// indent-tabs-mode: nil
// eval: (setq large-file-warning-threshold nil)
// End:
