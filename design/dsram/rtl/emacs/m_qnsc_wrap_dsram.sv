`timescale 1ns/1ps

// QNSC wrapper of m_vlsi_axi4_sram: the QSoC DSRAM, 32 KiB on S_BUS AXI_M2.
// Spec: QNSC_RAM_MAS (V2.5), on the team SharePoint.
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
// The macro IS in the wrapper: qnsc_sram_sp from design/common/tech/.
// The controller's macro-side ports are internal wires, not module ports.
//
// A wrapper is IP (design/README.md, "Shared numbers: who may use qnsc_pkg"):
// no import, no parameter. The IP's configuration is fixed at the instances below.

module m_qnsc_wrap_dsram
(
//---------------------------------------------------------------
// Clock/Reset: SCRC o_clk_ram, o_rst_n_ram (domain ram, mem cluster, never gated)
//---------------------------------------------------------------
/*AUTOINPUT("^i_clk\|^i_rst")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic             i_clk_mem,              // To u_sram_ctrl of m_vlsi_axi4_sram.v, ...
input logic             i_rst_n_mem,            // To u_sram_ctrl of m_vlsi_axi4_sram.v, ...
// End of automatics

//---------------------------------------------------------------
// Bus interface (AXI4 subordinate, S_BUS AXI_M2)
//---------------------------------------------------------------
/*AUTOINPUT("^i_bus_axi")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic [31:0]      i_bus_axi_ar_addr,      // To u_sram_ctrl of m_vlsi_axi4_sram.v
input logic [1:0]       i_bus_axi_ar_burst,     // To u_sram_ctrl of m_vlsi_axi4_sram.v
input logic [6:0]       i_bus_axi_ar_id,        // To u_sram_ctrl of m_vlsi_axi4_sram.v
input logic [7:0]       i_bus_axi_ar_len,       // To u_sram_ctrl of m_vlsi_axi4_sram.v
input logic             i_bus_axi_ar_valid,     // To u_sram_ctrl of m_vlsi_axi4_sram.v
input logic [31:0]      i_bus_axi_aw_addr,      // To u_sram_ctrl of m_vlsi_axi4_sram.v
input logic [1:0]       i_bus_axi_aw_burst,     // To u_sram_ctrl of m_vlsi_axi4_sram.v
input logic [6:0]       i_bus_axi_aw_id,        // To u_sram_ctrl of m_vlsi_axi4_sram.v
input logic [7:0]       i_bus_axi_aw_len,       // To u_sram_ctrl of m_vlsi_axi4_sram.v
input logic             i_bus_axi_aw_valid,     // To u_sram_ctrl of m_vlsi_axi4_sram.v
input logic             i_bus_axi_b_ready,      // To u_sram_ctrl of m_vlsi_axi4_sram.v
input logic             i_bus_axi_r_ready,      // To u_sram_ctrl of m_vlsi_axi4_sram.v
input logic [31:0]      i_bus_axi_w_data,       // To u_sram_ctrl of m_vlsi_axi4_sram.v
input logic             i_bus_axi_w_last,       // To u_sram_ctrl of m_vlsi_axi4_sram.v
input logic [3:0]       i_bus_axi_w_strb,       // To u_strbfifo of m_vlsi_fifo.v
input logic             i_bus_axi_w_valid,      // To u_sram_ctrl of m_vlsi_axi4_sram.v
// End of automatics
/*AUTOOUTPUT("^o_bus_axi")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic            o_bus_axi_ar_ready,     // From u_sram_ctrl of m_vlsi_axi4_sram.v
output logic            o_bus_axi_aw_ready,     // From u_sram_ctrl of m_vlsi_axi4_sram.v
output logic [6:0]      o_bus_axi_b_id,         // From u_sram_ctrl of m_vlsi_axi4_sram.v
output logic [1:0]      o_bus_axi_b_resp,       // From u_sram_ctrl of m_vlsi_axi4_sram.v
output logic            o_bus_axi_b_valid,      // From u_sram_ctrl of m_vlsi_axi4_sram.v
output logic [31:0]     o_bus_axi_r_data,       // From u_sram_ctrl of m_vlsi_axi4_sram.v
output logic [6:0]      o_bus_axi_r_id,         // From u_sram_ctrl of m_vlsi_axi4_sram.v
output logic            o_bus_axi_r_last,       // From u_sram_ctrl of m_vlsi_axi4_sram.v
output logic [1:0]      o_bus_axi_r_resp,       // From u_sram_ctrl of m_vlsi_axi4_sram.v
output logic            o_bus_axi_r_valid,      // From u_sram_ctrl of m_vlsi_axi4_sram.v
output logic            o_bus_axi_w_ready      // From u_sram_ctrl of m_vlsi_axi4_sram.v
// End of automatics

//---------------------------------------------------------------
// Memory macro, 8192 words x 32 bits. The macro's pins.
// All mem-side signals are internal wires (AUTOWIRE + hand declarations below).
// The macro qnsc_sram_sp is instantiated inside this wrapper.
//---------------------------------------------------------------

//---------------------------------------------------------------
// Others -- must stay empty once the templates below are complete
//---------------------------------------------------------------
/*AUTOINOUT*/
/*AUTOINPUT*/
/*AUTOOUTPUT*/
);

/*AUTOWIRE*/
// Beginning of automatic wires (for undeclared instantiated-module outputs)
logic [12:0]            w_mem_addr;             // From u_sram_ctrl of m_vlsi_axi4_sram.v
logic [31:15]           w_mem_addr_hi;          // From u_sram_ctrl of m_vlsi_axi4_sram.v
logic [1:0]             w_mem_addr_lo;          // From u_sram_ctrl of m_vlsi_axi4_sram.v
logic                   w_mem_oe;               // From u_sram_ctrl of m_vlsi_axi4_sram.v
logic [31:0]            w_mem_wdata;            // From u_sram_ctrl of m_vlsi_axi4_sram.v
logic [3:0]             w_strb_head;            // From u_strbfifo of m_vlsi_fifo.v
// End of automatics
// w_mem_we / w_mem_be: hand-declared internal wires (wrapper reads both,
// AUTOOUTPUT will not declare a signal the module itself uses)
logic                   w_mem_we;
logic [3:0]             w_mem_be;
logic [31:0]            w_mem_rdata;

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
  "\\|^i_mem"
  "\\|unuse_input"
  ))
*/

/*AUTO_LISP(setq verilog-auto-output-ignore-regexp
  (concat
  "^w_"
  "\\|^o_mem"
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
    .o_sram_addr            ({w_mem_addr_hi[31:15], w_mem_addr[12:0], w_mem_addr_lo[1:0]}),
    .o_sram_wdata           (w_mem_wdata[]),
    .o_sram_we              (w_mem_we),
    .o_sram_oe              (w_mem_oe),
    .i_sram_rdata           (w_mem_rdata[]),
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
  .PARA_ID_WD      (7),  // contract: meta.sbus_master_port_id_width
  .PARA_LEN_WD     (9),  // 9, not 8: see the note above the instance
  .PARA_FIFO_DEPTH (8)
) u_sram_ctrl (/*AUTOINST*/
               // Outputs
               .o_awready               (o_bus_axi_aw_ready),    // Templated
               .o_wready                (o_bus_axi_w_ready),     // Templated
               .o_bid                   (o_bus_axi_b_id[6:0]),   // Templated
               .o_bresp                 (o_bus_axi_b_resp[1:0]), // Templated
               .o_bvalid                (o_bus_axi_b_valid),     // Templated
               .o_arready               (o_bus_axi_ar_ready),    // Templated
               .o_rid                   (o_bus_axi_r_id[6:0]),   // Templated
               .o_rdata                 (o_bus_axi_r_data[31:0]), // Templated
               .o_rresp                 (o_bus_axi_r_resp[1:0]), // Templated
               .o_rvalid                (o_bus_axi_r_valid),     // Templated
               .o_rlast                 (o_bus_axi_r_last),      // Templated
               .o_sram_addr             ({w_mem_addr_hi[31:15], w_mem_addr[12:0], w_mem_addr_lo[1:0]}), // Templated
               .o_sram_wdata            (w_mem_wdata[31:0]),     // Templated
               .o_sram_we               (w_mem_we),              // Templated
               .o_sram_oe               (w_mem_oe),              // Templated
               // Inputs
               .i_clk                   (i_clk_mem),             // Templated
               .i_rst_n                 (i_rst_n_mem),           // Templated
               .i_awaddr                (i_bus_axi_aw_addr[31:0]), // Templated
               .i_awvalid               (i_bus_axi_aw_valid),    // Templated
               .i_awburst               (i_bus_axi_aw_burst[1:0]), // Templated
               .i_awlen                 ({1'b0, i_bus_axi_aw_len[7:0]}), // Templated
               .i_awid                  (i_bus_axi_aw_id[6:0]),  // Templated
               .i_wdata                 (i_bus_axi_w_data[31:0]), // Templated
               .i_wvalid                (i_bus_axi_w_valid),     // Templated
               .i_wlast                 (i_bus_axi_w_last),      // Templated
               .i_bready                (i_bus_axi_b_ready),     // Templated
               .i_araddr                (i_bus_axi_ar_addr[31:0]), // Templated
               .i_arvalid               (i_bus_axi_ar_valid),    // Templated
               .i_arburst               (i_bus_axi_ar_burst[1:0]), // Templated
               .i_arlen                 ({1'b0, i_bus_axi_ar_len[7:0]}), // Templated
               .i_arid                  (i_bus_axi_ar_id[6:0]),  // Templated
               .i_rready                (i_bus_axi_r_ready),     // Templated
               .i_sram_rdata            (w_mem_rdata[31:0]));    // Templated

//---------------------------------------------------------------
// Byte enables (QNSC_RAM_MAS 7.3)
//---------------------------------------------------------------
// The controller has no WSTRB. u_strbfifo is pushed with the controller's own
// write-data push (wvalid & wready) and popped with its write grant (w_mem_we), so
// it holds the same number of entries as the write-data FIFO in every cycle and its
// head is the strobe of the beat being written. Depth 2**3 = PARA_FIFO_DEPTH.
/* m_vlsi_fifo AUTO_TEMPLATE(
    .i_clk                  (i_clk_mem),
    .i_rst_n                (i_rst_n_mem),
    .i_data                 (i_bus_axi_w_strb[]),
    .i_push                 (w_strb_push),
    .i_pop                  (w_mem_we),
    .o_data_out             (w_strb_head[]),
    .o_empty                (),
    .o_full                 (),
);
*/
m_vlsi_fifo #(  // naming-check: ignore -- vendored module name
  .PARA_DATA_WD (4),
  .PARA_DEPTH   (3)
) u_strbfifo (/*AUTOINST*/
              // Outputs
              .o_data_out               (w_strb_head[3:0]),      // Templated
              .o_empty                  (),                      // Templated
              .o_full                   (),                      // Templated
              // Inputs
              .i_clk                    (i_clk_mem),             // Templated
              .i_rst_n                  (i_rst_n_mem),           // Templated
              .i_data                   (i_bus_axi_w_strb[3:0]), // Templated
              .i_push                   (w_strb_push),           // Templated
              .i_pop                    (w_mem_we));             // Templated

assign w_strb_push = i_bus_axi_w_valid & o_bus_axi_w_ready;
assign w_mem_be    = w_mem_we ? w_strb_head : 4'b0000;

//---------------------------------------------------------------
// Memory macro: qnsc_sram_sp (design/common/tech, Naming Rule 2.8)
//---------------------------------------------------------------
qnsc_sram_sp #(
  .P_DEPTH   (8192),   // hardcode-check: ignore -- block SRAM depth, not a contract number
  .P_DATA_WD (32)
) u_sram_mem (
  .i_clk     (i_clk_mem),
  .i_addr    (w_mem_addr),
  .i_wdata   (w_mem_wdata),
  .i_we      (w_mem_we),
  .i_be      (w_mem_be),
  .i_oe      (w_mem_oe),
  .o_rdata   (w_mem_rdata)
);

endmodule
// Local Variables:
// verilog-library-flags:("-f filelist_emacs.f")
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: t
// indent-tabs-mode: nil
// eval: (setq large-file-warning-threshold nil)
// End:
