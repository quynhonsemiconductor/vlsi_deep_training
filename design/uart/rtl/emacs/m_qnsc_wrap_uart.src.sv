`timescale 1ns/1ps

// QNSC wrapper of pulp-platform/apb_uart: the QSoC UART. design/top instantiates
// it twice, UART0 on APB_M8 (INTMAP fast line 4) and UART1 on APB_M9 (line 5).
// Spec: doc/specs/QNSC_UART_MAS.md (V3.0).
//
// Edit this .src.sv, then `make wrap BLOCK=uart`: emacs verilog-mode expands
// the AUTO comments and writes rtl/m_qnsc_wrap_uart.sv, the file uart.f compiles.
// Template functions: doc/rules/EMACS_quick_guide.pdf.
//
// Wrapper = core + bridge. apb_uart already holds its bridge (apb_to_obi in
// front of obi_uart) and is instantiated unmodified, so the wrapper adds none.
// A wrapper is IP (design/README.md, "Shared numbers"): no import, no parameter.
//
// What the wrapper does (MAS 5, 10):
//   - PADDR[2:0] = i_bus_apb_paddr[4:2]: the register index. Offset bits 11:5
//     are not decoded, so the 32-byte map aliases across the window (MAS 6)
//   - PSTRB and PPROT: apb_uart has neither (it ties them '1 and 0 inside).
//     A byte, halfword or word store writes bits 7:0 (MAS 7.5)
//   - modem inputs CTSN, DSRN, DCDN, RIN tied 1 (inactive), modem outputs open:
//     no flow control
//   - PREADY, PSLVERR passed through: no wait state; PSLVERR on the accesses
//     the MAS 6 table marks
//
// Ports declared by hand: i_bus_apb_paddr, i_bus_apb_pstrb, i_bus_apb_pprot.
// AUTOINPUT declares a port only from what an instance pin uses, and apb_uart
// uses paddr[4:2] and no pstrb/pprot; the APB slave conventions of
// design/README.md want the full 12-bit offset and both fields on every APB
// wrapper. They are the last ports, so this file stays valid SystemVerilog
// before expansion. Their unused bits are waived in design/uart/waivers.vlt.

module m_qnsc_wrap_uart
(
//---------------------------------------------------------------
// Clock/Reset: peri cluster, SCRC o_clk_uart_<n> / o_rst_n_uart_<n>
//---------------------------------------------------------------
/*AUTOINPUT("^i_clk\|^i_rst")*/

//---------------------------------------------------------------
// APB slave, from P_BUS (APB_M8 / APB_M9)
//---------------------------------------------------------------
/*AUTOINPUT("^i_bus_apb")*/
/*AUTOOUTPUT("^o_bus_apb")*/

//---------------------------------------------------------------
// PAD, through IO MUX. Both idle at 1
//---------------------------------------------------------------
/*AUTOINPUT("^i_pad")*/
/*AUTOOUTPUT("^o_pad")*/

//---------------------------------------------------------------
// Interrupt, to INTMAP i_int_uart_<n>: level (MAS 7.4)
//---------------------------------------------------------------
/*AUTOOUTPUT("^o_int")*/

//---------------------------------------------------------------
// Others -- must stay empty
//---------------------------------------------------------------
/*AUTOINOUT*/
/*AUTOINPUT*/
/*AUTOOUTPUT*/

//---------------------------------------------------------------
// APB fields apb_uart does not take in full: declared by hand
//---------------------------------------------------------------
input  logic [11:0]     i_bus_apb_paddr,        // contract: meta.apb_paddr_width; bits 4:2 used
input  logic [3:0]      i_bus_apb_pstrb,        // not used: a store writes bits 7:0
input  logic [2:0]      i_bus_apb_pprot         // not used
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
// Core: apb_uart (apb_to_obi + obi_uart), unmodified
//---------------------------------------------------------------
/* apb_uart AUTO_TEMPLATE(
    .CLK                                  (i_clk_peri),
    .RSTN                                 (i_rst_n_peri),
    .PADDR                                (i_bus_apb_paddr[4:2]),   // register index, MAS 10
    .P\(WDATA\|WRITE\|SEL\|ENABLE\)       (i_bus_apb_p@"(downcase (symbol-name '\1))"[]),
    .P\(.*\)                              (o_bus_apb_p@"(downcase (symbol-name '\1))"[]),
    .INT                                  (o_int_uart),
    .SIN                                  (i_pad_uart_rx),
    .SOUT                                 (o_pad_uart_tx),
    .\(CTSN\|DSRN\|DCDN\|RIN\)            (1'b1),                   // inactive, MAS 10
    .\(RTSN\|DTRN\|OUT1N\|OUT2N\)         (),                       // no flow control
);
*/
apb_uart u_apb_uart (/*AUTOINST*/);

endmodule
// Local Variables:
// verilog-library-flags:("-f filelist_emacs.f")
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: t
// indent-tabs-mode: nil
// eval: (setq large-file-warning-threshold nil)
// End:
