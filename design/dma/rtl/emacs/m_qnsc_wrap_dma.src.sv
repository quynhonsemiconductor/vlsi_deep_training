`timescale 1ns/1ps

// QNSC wrapper of freecores dma_axi32 (Provartec PR200): the QSoC DMA.
// Registers on APB_M13, data as an AXI4 master on AXI_S2, one interrupt to
// INTMAP fast line 0. Spec: QNSC_DMA_MAS (team SharePoint).
//
// Edit this .src.sv, then `make wrap BLOCK=dma`: emacs verilog-mode expands
// the AUTO comments and writes rtl/m_qnsc_wrap_dma.sv, the file dma.f compiles.
// Template functions: doc/rules/EMACS_quick_guide.pdf.
//
// Wrapper = core + bridge, in this one file. The core is dma_axi32; the bridge
// is the assigns below: the IP's AXI3 master becomes the AXI4 master of S_BUS.
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
//   - PSTRB and PPROT: the IP has neither. Both ports are kept, not connected
//     to the IP (they end in w_unused): a byte or halfword store writes the
//     whole register.
//   - PREADY and PSLVERR come from the IP. pclken is tied 1: the APB runs on
//     i_clk_peri itself.
//   - The IP resets on reset = 1: it gets ~i_rst_n_peri.
//
// Peripheral handshake (dma_axi32_core0_ch_periph_mux.v): bit n of
// i_dma_rx_req / i_dma_tx_req is peripheral number n of STATIC_LINE4
// (RD_PERIPH_NUM / WR_PERIPH_NUM); number 0 is memory, so the vectors are
// [31:1] as on the IP. design/top drives i_dma_rx_req from o_dma_rx_req of
// UART0 and UART1 (LSR.data_ready, a level) and ties the other bits 0; which
// bit each UART takes is the contract's tbd item. A level request needs
// PERIPH_DELAY >= 1 on that channel. periph_tx_clr / periph_rx_clr are left
// open: the UART has no clear input, its request falls when RHR is read.
//
// AXI3 to AXI4: the IP has ID 1 bit, LEN 4 bits, SIZE 2 bits (dma_axi32_defines.v),
// a WID and no burst, lock, cache, prot, qos, region, atop or user. The fields
// are zero-extended to S_BUS's widths (ID 5, LEN 8, SIZE 3, USER 1) and the
// missing ones are constant. WID0 is dropped: the IP drives every ID 0
// (dma_axi32.v:103-105), so its W beats follow AW order, as AXI4 requires.
// The IP splits a burst at 4 KiB (dma_axi32_core0_axim_cmd.v:120-123).
//
// Ports declared by hand, as the last group: AUTOINPUT/AUTOOUTPUT declare a
// port only at the width an IP pin uses, and these are wider than the IP's
// pin (paddr, AXI ID/LEN/SIZE) or have no IP pin at all (PSTRB, PPROT, the
// AXI4-only fields). Being last, they leave no trailing comma, so this file
// stays valid SystemVerilog before expansion (doc/guides/EMACS_AUTO.md, section 2 (1)),
// as in m_qnsc_wrap_uart. The bits nobody reads end in w_unused.

module m_qnsc_wrap_dma
(
//---------------------------------------------------------------
// Clock/Reset: peri cluster, SCRC o_clk_dma / o_rst_n_dma
//---------------------------------------------------------------
/*AUTOINPUT("^i_clk\|^i_rst")*/

//---------------------------------------------------------------
// APB slave, from P_BUS (APB_M13)
//---------------------------------------------------------------
/*AUTOINPUT("^i_bus_apb")*/
/*AUTOOUTPUT("^o_bus_apb")*/

//---------------------------------------------------------------
// AXI4 master, to S_BUS (AXI_S2)
//---------------------------------------------------------------
/*AUTOINPUT("^i_bus_axi")*/
/*AUTOOUTPUT("^o_bus_axi")*/

//---------------------------------------------------------------
// Peripheral handshake: requests from UART0 / UART1 (design/top), idle
//---------------------------------------------------------------
/*AUTOINPUT("^i_dma")*/
/*AUTOOUTPUT("^o_dma")*/

//---------------------------------------------------------------
// Interrupt, to INTMAP i_int_dma: level, cleared by an INT_CLEAR write
//---------------------------------------------------------------
/*AUTOOUTPUT("^o_int")*/

//---------------------------------------------------------------
// Others -- must stay empty
//---------------------------------------------------------------
/*AUTOINOUT*/
/*AUTOINPUT*/
/*AUTOOUTPUT*/

//---------------------------------------------------------------
// Declared by hand: wider than the IP's pin, or no IP pin
//---------------------------------------------------------------
input  logic [13:0]     i_bus_apb_paddr,        // contract: meta.apb_paddr_width; bits 12:0 used
input  logic [3:0]      i_bus_apb_pstrb,        // not used: a store writes the whole register
input  logic [2:0]      i_bus_apb_pprot,        // not used
output logic [4:0]      o_bus_axi_aw_id,
output logic [7:0]      o_bus_axi_aw_len,
output logic [2:0]      o_bus_axi_aw_size,
output logic [1:0]      o_bus_axi_aw_burst,
output logic            o_bus_axi_aw_lock,
output logic [3:0]      o_bus_axi_aw_cache,
output logic [2:0]      o_bus_axi_aw_prot,
output logic [3:0]      o_bus_axi_aw_qos,
output logic [3:0]      o_bus_axi_aw_region,
output logic [5:0]      o_bus_axi_aw_atop,
output logic            o_bus_axi_aw_user,
output logic            o_bus_axi_w_user,
input  logic [4:0]      i_bus_axi_b_id,
input  logic            i_bus_axi_b_user,
output logic [4:0]      o_bus_axi_ar_id,
output logic [7:0]      o_bus_axi_ar_len,
output logic [2:0]      o_bus_axi_ar_size,
output logic [1:0]      o_bus_axi_ar_burst,
output logic            o_bus_axi_ar_lock,
output logic [3:0]      o_bus_axi_ar_cache,
output logic [2:0]      o_bus_axi_ar_prot,
output logic [3:0]      o_bus_axi_ar_qos,
output logic [3:0]      o_bus_axi_ar_region,
output logic            o_bus_axi_ar_user,
input  logic [4:0]      i_bus_axi_r_id,
input  logic            i_bus_axi_r_user
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
// Bridge, write address: AXI3 fields zero-extended, AXI4 fields constant
//---------------------------------------------------------------
assign o_bus_axi_aw_id     = {4'b0, w_ip_aw_id};
assign o_bus_axi_aw_len    = {4'b0, w_ip_aw_len};
assign o_bus_axi_aw_size   = {1'b0, w_ip_aw_size};
assign o_bus_axi_aw_burst  = 2'b01;             // INCR: every burst of the IP
assign o_bus_axi_aw_lock   = 1'b0;              // normal access
assign o_bus_axi_aw_cache  = 4'b0000;           // device, non-bufferable
assign o_bus_axi_aw_prot   = 3'b000;            // unprivileged, secure, data
assign o_bus_axi_aw_qos    = 4'b0000;
assign o_bus_axi_aw_region = 4'b0000;
assign o_bus_axi_aw_atop   = 6'b00_0000;        // no atomic operation
assign o_bus_axi_aw_user   = 1'b0;

//---------------------------------------------------------------
// Bridge, write data: AXI4 has no WID
//---------------------------------------------------------------
assign o_bus_axi_w_user    = 1'b0;

//---------------------------------------------------------------
// Bridge, read address
//---------------------------------------------------------------
assign o_bus_axi_ar_id     = {4'b0, w_ip_ar_id};
assign o_bus_axi_ar_len    = {4'b0, w_ip_ar_len};
assign o_bus_axi_ar_size   = {1'b0, w_ip_ar_size};
assign o_bus_axi_ar_burst  = 2'b01;             // INCR
assign o_bus_axi_ar_lock   = 1'b0;
assign o_bus_axi_ar_cache  = 4'b0000;
assign o_bus_axi_ar_prot   = 3'b000;
assign o_bus_axi_ar_qos    = 4'b0000;
assign o_bus_axi_ar_region = 4'b0000;
assign o_bus_axi_ar_user   = 1'b0;

//---------------------------------------------------------------
// Not used: paddr[13], PSTRB, PPROT, the upper ID bits (the IP issues ID 0
// only), USER
//---------------------------------------------------------------
logic w_unused;

assign w_unused = ^{i_bus_apb_paddr[13], i_bus_apb_pstrb, i_bus_apb_pprot,
                    i_bus_axi_b_id[4:1], i_bus_axi_r_id[4:1],
                    i_bus_axi_b_user, i_bus_axi_r_user};

//---------------------------------------------------------------
// Core: dma_axi32
// The AXI3 port AWADDR0 ... RREADY0 becomes o_bus_axi_aw_addr ...
// o_bus_axi_r_ready; ID, LEN and SIZE go through w_ip_* to the bridge.
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
    .idle                                 (o_dma_idle),
    .periph_\(tx\|rx\)_req                (i_dma_\1_req[]),
    .periph_\(tx\|rx\)_clr                (),
    .WID0                                 (),
    .A\([WR]\)ID0                         (w_ip_a@"(downcase (symbol-name '\1))"_id[0:0]),       // `ID_BITS 1
    .\([BR]\)ID0                          (i_bus_axi_@"(downcase (symbol-name '\1))"_id[0:0]),   // `ID_BITS 1
    .A\([WR]\)LEN0                        (w_ip_a@"(downcase (symbol-name '\1))"_len[3:0]),     // `LEN_BITS 4
    .A\([WR]\)SIZE0                       (w_ip_a@"(downcase (symbol-name '\1))"_size[1:0]),    // `SIZE_BITS 2
    .\([BR]\)READY0                       (o_bus_axi_@"(downcase (symbol-name '\1))"_ready),
    .\(A[WR]\|W\)READY0                   (i_bus_axi_@"(downcase (symbol-name '\1))"_ready),
    .\([BR]\)\([A-Z]+\)0                  (i_bus_axi_@"(downcase (symbol-name '\1))"_@"(downcase (symbol-name '\2))"[]),
    .\(A[WR]\|W\)\([A-Z]+\)0              (o_bus_axi_@"(downcase (symbol-name '\1))"_@"(downcase (symbol-name '\2))"[]),
);
*/
dma_axi32                               // naming-check: ignore -- upstream module name, vendor/ is never renamed
u_dma (/*AUTOINST*/);

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
