`timescale 1ns/1ps

// QNSC wrapper of freecores dma_axi32 (Provartec PR200): the QSoC DMA.
// Registers on APB_M13, data as an AXI4 master on AXI_S2, one interrupt to
// INTMAP fast line 0. Spec: QNSC_DMA_MAS (team SharePoint).
//
// Edit this .src.sv, then `make wrap BLOCK=dma`: emacs verilog-mode expands
// the AUTO comments and writes rtl/m_qnsc_wrap_dma.sv, the file dma.f compiles.
// Template functions: doc/rules/EMACS_quick_guide.pdf.
//
// The wrapper only renames dma_axi32's pins to the QSOC port names and ties
// its test and clock-enable inputs; it adds no logic. Ports exist only for
// what the IP has: a field the IP lacks gets no port, and a width that differs
// from S_BUS or P_BUS is matched at design/top, where both sides are known.
// A wrapper is IP (design/README.md, "Shared numbers"): no import, no parameter.
// dma_axi32 has no parameter; its configuration is the `define file
// dma_axi32_defines.v, reached through +incdir+.
//
// APB slave (design/README.md, "APB slave conventions"):
//   - i_bus_apb_paddr is the 14-bit offset in the 16 KiB window. The IP takes
//     paddr[12:0] (dma_axi32_apb_mux.v:72-74): 0x0000-0x07FF core 0 channels
//     (CH0 at 0x0000, CH1-7 PSLVERR), 0x0800-0x0FFF core 1 (absent, PSLVERR),
//     0x1000-0x1FFF global registers. paddr[13] is not decoded, so
//     0x2000-0x3FFF aliases 0x0000-0x1FFF.
//   - PSTRB and PPROT: the IP has neither, so the wrapper has no such port. A
//     byte or halfword store writes the whole register.
//   - PREADY and PSLVERR come from the IP. pclken is tied 1: the APB runs on
//     i_clk_peri itself.
//   - The IP resets on reset = 1: it gets ~i_rst_n_peri.
//
// Peripheral handshake (dma_axi32_core0_ch_periph_mux.v): bit n of
// i_dma_rx_req / i_dma_tx_req is peripheral number n of STATIC_LINE4
// (RD_PERIPH_NUM / WR_PERIPH_NUM); number 0 is memory, so the vectors are
// [31:1] as on the IP. design/top drives i_dma_rx_req from o_dma_rx_req of
// UART1 (LSR.data_ready, a level) and ties the other bits 0; which bit UART1
// takes is the contract's tbd item. A level request needs
// PERIPH_DELAY >= 1 on that channel. periph_tx_clr / periph_rx_clr are left
// open: the UART has no clear input, its request falls when RHR is read.
//
// AXI master: the ports are the IP's AXI3 pins (dma_axi32_defines.v): ID 1
// bit, LEN 4 bits, SIZE 2 bits. The IP has no burst, lock, cache, prot, qos,
// region, atop or user, so the wrapper has none of them; design/top ties
// S_BUS's inputs for them and zero-extends LEN to 8 and SIZE to 3 bits. Every
// burst of the IP is INCR. WID0 is left open: the IP drives every ID 0
// (dma_axi32.v:103-105), so its W beats follow AW order, as AXI4 requires.
// The IP splits a burst at 4 KiB (dma_axi32_core0_axim_cmd.v:120-123).
//
// idle is left open: no QSOC block reads it (SCRC has no DMA idle input), so
// it has no port.
//
// i_bus_apb_paddr is declared by hand, as the last group: AUTOINPUT declares
// it at the IP pin's width (13 bits), and the convention is 14. Being last, it
// leaves no trailing comma, so this file stays valid SystemVerilog before
// expansion (doc/guides/EMACS_AUTO.md, section 2 (1)), as in m_qnsc_wrap_uart.
// paddr[13] ends in w_unused.

module m_qnsc_wrap_dma
(
//---------------------------------------------------------------
// Clock/Reset: peri cluster, SCRC o_clk_dma / o_rst_n_dma
//---------------------------------------------------------------
/*AUTOINPUT("^i_clk\|^i_rst")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic             i_clk_peri,             // To u_dma of dma_axi32.v
input logic             i_rst_n_peri,           // To u_dma of dma_axi32.v
// End of automatics

//---------------------------------------------------------------
// APB slave, from P_BUS (APB_M13)
//---------------------------------------------------------------
/*AUTOINPUT("^i_bus_apb")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic             i_bus_apb_penable,      // To u_dma of dma_axi32.v
input logic             i_bus_apb_psel,         // To u_dma of dma_axi32.v
input logic [31:0]      i_bus_apb_pwdata,       // To u_dma of dma_axi32.v
input logic             i_bus_apb_pwrite,       // To u_dma of dma_axi32.v
// End of automatics
/*AUTOOUTPUT("^o_bus_apb")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic [31:0]     o_bus_apb_prdata,       // From u_dma of dma_axi32.v
output logic            o_bus_apb_pready,       // From u_dma of dma_axi32.v
output logic            o_bus_apb_pslverr,      // From u_dma of dma_axi32.v
// End of automatics

//---------------------------------------------------------------
// AXI master, to S_BUS (AXI_S2): the IP's AXI3 pins, no AXI4-only field
//---------------------------------------------------------------
/*AUTOINPUT("^i_bus_axi")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic             i_bus_axi_ar_ready,     // To u_dma of dma_axi32.v
input logic             i_bus_axi_aw_ready,     // To u_dma of dma_axi32.v
input logic [0:0]       i_bus_axi_b_id,         // To u_dma of dma_axi32.v
input logic [1:0]       i_bus_axi_b_resp,       // To u_dma of dma_axi32.v
input logic             i_bus_axi_b_valid,      // To u_dma of dma_axi32.v
input logic [31:0]      i_bus_axi_r_data,       // To u_dma of dma_axi32.v
input logic [0:0]       i_bus_axi_r_id,         // To u_dma of dma_axi32.v
input logic             i_bus_axi_r_last,       // To u_dma of dma_axi32.v
input logic [1:0]       i_bus_axi_r_resp,       // To u_dma of dma_axi32.v
input logic             i_bus_axi_r_valid,      // To u_dma of dma_axi32.v
input logic             i_bus_axi_w_ready,      // To u_dma of dma_axi32.v
// End of automatics
/*AUTOOUTPUT("^o_bus_axi")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic [31:0]     o_bus_axi_ar_addr,      // From u_dma of dma_axi32.v
output logic [0:0]      o_bus_axi_ar_id,        // From u_dma of dma_axi32.v
output logic [3:0]      o_bus_axi_ar_len,       // From u_dma of dma_axi32.v
output logic [1:0]      o_bus_axi_ar_size,      // From u_dma of dma_axi32.v
output logic            o_bus_axi_ar_valid,     // From u_dma of dma_axi32.v
output logic [31:0]     o_bus_axi_aw_addr,      // From u_dma of dma_axi32.v
output logic [0:0]      o_bus_axi_aw_id,        // From u_dma of dma_axi32.v
output logic [3:0]      o_bus_axi_aw_len,       // From u_dma of dma_axi32.v
output logic [1:0]      o_bus_axi_aw_size,      // From u_dma of dma_axi32.v
output logic            o_bus_axi_aw_valid,     // From u_dma of dma_axi32.v
output logic            o_bus_axi_b_ready,      // From u_dma of dma_axi32.v
output logic            o_bus_axi_r_ready,      // From u_dma of dma_axi32.v
output logic [31:0]     o_bus_axi_w_data,       // From u_dma of dma_axi32.v
output logic            o_bus_axi_w_last,       // From u_dma of dma_axi32.v
output logic [3:0]      o_bus_axi_w_strb,       // From u_dma of dma_axi32.v
output logic            o_bus_axi_w_valid,      // From u_dma of dma_axi32.v
// End of automatics

//---------------------------------------------------------------
// Peripheral handshake: request from UART1 (design/top)
//---------------------------------------------------------------
/*AUTOINPUT("^i_dma")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic [31:1]      i_dma_rx_req,           // To u_dma of dma_axi32.v
input logic [31:1]      i_dma_tx_req,           // To u_dma of dma_axi32.v
// End of automatics

//---------------------------------------------------------------
// Interrupt, to INTMAP i_int_dma: level, cleared by an INT_CLEAR write
//---------------------------------------------------------------
/*AUTOOUTPUT("^o_int")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic            o_int_dma,              // From u_dma of dma_axi32.v
// End of automatics

//---------------------------------------------------------------
// Others -- must stay empty
//---------------------------------------------------------------
/*AUTOINOUT*/
/*AUTOINPUT*/
/*AUTOOUTPUT*/

//---------------------------------------------------------------
// Declared by hand: wider than the IP's pin
//---------------------------------------------------------------
input  logic [13:0]     i_bus_apb_paddr         // contract: meta.apb_paddr_width; bits 12:0 used
);

/*AUTOWIRE*/

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
// Not used: paddr[13], the IP decodes paddr[12:0]
//---------------------------------------------------------------
logic w_unused;

assign w_unused = i_bus_apb_paddr[13];

//---------------------------------------------------------------
// Core: dma_axi32
// The AXI3 port AWID0 ... RREADY0 becomes o_bus_axi_aw_id ...
// o_bus_axi_r_ready, at the IP's widths.
//---------------------------------------------------------------
/* dma_axi32 AUTO_TEMPLATE(
    .clk                                  (i_clk_peri),
    .reset                                (~i_rst_n_peri),      // the IP resets on 1
    .scan_en                              (1'b0),
    .pclken                               (1'b1),
    .paddr                                (i_bus_apb_paddr[12:0]),
    .p\(sel\|enable\|write\|wdata\)       (i_bus_apb_p\1[]),
    .p\(rdata\|slverr\|ready\)            (o_bus_apb_p\1[]),
    .INT                                  (o_int_dma),
    .idle                                 (),                   // no reader in QSOC
    .periph_\(tx\|rx\)_req                (i_dma_\1_req[]),
    .periph_\(tx\|rx\)_clr                (),
    .WID0                                 (),
    .A\([WR]\)ID0                         (o_bus_axi_a@"(downcase (symbol-name '\1))"_id[0:0]),  // `ID_BITS 1
    .\([BR]\)ID0                          (i_bus_axi_@"(downcase (symbol-name '\1))"_id[0:0]),   // `ID_BITS 1
    .A\([WR]\)LEN0                        (o_bus_axi_a@"(downcase (symbol-name '\1))"_len[3:0]),   // `LEN_BITS 4
    .A\([WR]\)SIZE0                       (o_bus_axi_a@"(downcase (symbol-name '\1))"_size[1:0]),  // `SIZE_BITS 2
    .\([BR]\)READY0                       (o_bus_axi_@"(downcase (symbol-name '\1))"_ready),
    .\(A[WR]\|W\)READY0                   (i_bus_axi_@"(downcase (symbol-name '\1))"_ready),
    .\([BR]\)\([A-Z]+\)0                  (i_bus_axi_@"(downcase (symbol-name '\1))"_@"(downcase (symbol-name '\2))"[]),
    .\(A[WR]\|W\)\([A-Z]+\)0              (o_bus_axi_@"(downcase (symbol-name '\1))"_@"(downcase (symbol-name '\2))"[]),
);
*/
dma_axi32                               // naming-check: ignore -- upstream module name, vendor/ is never renamed
u_dma (/*AUTOINST*/
       // Outputs
       .idle                            (),                      // Templated
       .INT                             (o_int_dma),             // Templated
       .periph_tx_clr                   (),                      // Templated
       .periph_rx_clr                   (),                      // Templated
       .prdata                          (o_bus_apb_prdata[31:0]), // Templated
       .pslverr                         (o_bus_apb_pslverr),     // Templated
       .pready                          (o_bus_apb_pready),      // Templated
       .AWID0                           (o_bus_axi_aw_id[0:0]),  // Templated
       .AWADDR0                         (o_bus_axi_aw_addr[32-1:0]), // Templated
       .AWLEN0                          (o_bus_axi_aw_len[3:0]), // Templated
       .AWSIZE0                         (o_bus_axi_aw_size[1:0]), // Templated
       .AWVALID0                        (o_bus_axi_aw_valid),    // Templated
       .WID0                            (),                      // Templated
       .WDATA0                          (o_bus_axi_w_data[32-1:0]), // Templated
       .WSTRB0                          (o_bus_axi_w_strb[32/8-1:0]), // Templated
       .WLAST0                          (o_bus_axi_w_last),      // Templated
       .WVALID0                         (o_bus_axi_w_valid),     // Templated
       .BREADY0                         (o_bus_axi_b_ready),     // Templated
       .ARID0                           (o_bus_axi_ar_id[0:0]),  // Templated
       .ARADDR0                         (o_bus_axi_ar_addr[32-1:0]), // Templated
       .ARLEN0                          (o_bus_axi_ar_len[3:0]), // Templated
       .ARSIZE0                         (o_bus_axi_ar_size[1:0]), // Templated
       .ARVALID0                        (o_bus_axi_ar_valid),    // Templated
       .RREADY0                         (o_bus_axi_r_ready),     // Templated
       // Inputs
       .clk                             (i_clk_peri),            // Templated
       .reset                           (~i_rst_n_peri),         // Templated
       .scan_en                         (1'b0),                  // Templated
       .periph_tx_req                   (i_dma_tx_req[31:1]),    // Templated
       .periph_rx_req                   (i_dma_rx_req[31:1]),    // Templated
       .pclken                          (1'b1),                  // Templated
       .psel                            (i_bus_apb_psel),        // Templated
       .penable                         (i_bus_apb_penable),     // Templated
       .paddr                           (i_bus_apb_paddr[12:0]), // Templated
       .pwrite                          (i_bus_apb_pwrite),      // Templated
       .pwdata                          (i_bus_apb_pwdata[31:0]), // Templated
       .AWREADY0                        (i_bus_axi_aw_ready),    // Templated
       .WREADY0                         (i_bus_axi_w_ready),     // Templated
       .BID0                            (i_bus_axi_b_id[0:0]),   // Templated
       .BRESP0                          (i_bus_axi_b_resp[1:0]), // Templated
       .BVALID0                         (i_bus_axi_b_valid),     // Templated
       .ARREADY0                        (i_bus_axi_ar_ready),    // Templated
       .RID0                            (i_bus_axi_r_id[0:0]),   // Templated
       .RDATA0                          (i_bus_axi_r_data[32-1:0]), // Templated
       .RRESP0                          (i_bus_axi_r_resp[1:0]), // Templated
       .RLAST0                          (i_bus_axi_r_last),      // Templated
       .RVALID0                         (i_bus_axi_r_valid));    // Templated

endmodule
// Local Variables:
// verilog-library-flags:("-f filelist_emacs.f")
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: t
// verilog-auto-declare-nettype: "logic"
// verilog-auto-wire-type: "logic"
// indent-tabs-mode: nil
// eval: (setq large-file-warning-threshold nil)
// End:
