`timescale 1ns/1ps

// QNSC wrapper of @IP_MODULE@: the QSoC @BLOCK_UPPER@.
// Spec: doc/src/QNSC_@BLOCK_UPPER@_MAS.md.
//
// Edit this .src.sv, then `make wrap BLOCK=@BLOCK@`: emacs verilog-mode expands
// the AUTO comments and writes rtl/@DESIGN@.sv, the file @BLOCK@.f compiles.
// Template functions: doc/rules/EMACS_quick_guide.pdf.
//
// Wrapper = core + bridge. The core is the IP; the bridge, only when the IP
// speaks another protocol than the chip bus, converts it (APB to TL-UL, APB to
// OBI, ...). One wrapper per IP, owned by the IP owner.

module @DESIGN@
  import qnsc_pkg::*;
(
//---------------------------------------------------------------
// Clock/Reset
//---------------------------------------------------------------
/*AUTOINPUT("^i_clk\|^i_rst")*/

//---------------------------------------------------------------
// Bus interface (APB slave; for AXI use ^i_bus_axi / ^o_bus_axi)
//---------------------------------------------------------------
/*AUTOINPUT("^i_bus_apb")*/
/*AUTOOUTPUT("^o_bus_apb")*/

//---------------------------------------------------------------
// PAD, through IO MUX (Naming Rule 3.8: i_pad_ / o_pad_ / io_pad_)
//---------------------------------------------------------------
/*AUTOINPUT("^i_pad")*/
/*AUTOOUTPUT("^o_pad")*/
/*AUTOINOUT("^io_pad")*/

//---------------------------------------------------------------
// DMA
//---------------------------------------------------------------
/*AUTOINPUT("^i_dma")*/
/*AUTOOUTPUT("^o_dma")*/

//---------------------------------------------------------------
// Interrupt, to INTMAP
//---------------------------------------------------------------
/*AUTOOUTPUT("^o_int")*/

//---------------------------------------------------------------
// Others -- must stay empty once the template below is complete
//---------------------------------------------------------------
/*AUTOINOUT*/
/*AUTOINPUT*/
/*AUTOOUTPUT*/
);

/*AUTOWIRE*/

//---------------------------------------------------------------
// Logic the wrapper adds: synchronisers, tie-offs, bridge, ...
// Internal signals are r_* / w_*; w_* never become ports (see below).
//---------------------------------------------------------------

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

// Map every IP port to a QNSC name. First match wins; [] keeps the width.
//   .P\(ADDR\|WDATA\|WRITE\|SEL\|ENABLE\) (i_bus_apb_p@"(downcase (symbol-name '\1))"[]),
//   .P\(.*\)                              (o_bus_apb_p@"(downcase (symbol-name '\1))"[]),
//   .\(.*\)_pad_o                         (o_pad_@BLOCK@_\1[]),
//   .\(.*\)_padoen_o                      (o_pad_@BLOCK@_\1_oe_n[]),   active low: _n
//   .irq_o                                (o_int_@BLOCK@),
//   .dft_\(.*\)_i                         (1'b0),                        tie-off
//   .unused_o                             (),                            left open
//   .ERR_\(.*\) (@"(if (equal vl-dir \"input\") \"'0\" \"\")"),   inputs to 0, outputs open
// Instance parameters are substituted into widths (verilog-auto-inst-param-value t):
//   @IP_MODULE@ #(.APB_ADDR_WIDTH(C_APB_PADDR_WIDTH)) u_@IP_MODULE@ (/*AUTOINST*/);
/* @IP_MODULE@ AUTO_TEMPLATE(
    .HCLK                                 (i_clk_peri),
    .HRESETn                              (i_rst_n_peri),
    .P\(ADDR\|WDATA\|WRITE\|SEL\|ENABLE\) (i_bus_apb_p@"(downcase (symbol-name '\1))"[]),
    .P\(.*\)                              (o_bus_apb_p@"(downcase (symbol-name '\1))"[]),
);
*/
@IP_MODULE@ u_@IP_MODULE@ (/*AUTOINST*/);

endmodule
// Local Variables:
// verilog-library-flags:("-f filelist_emacs.f")
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: t
// eval: (setq large-file-warning-threshold nil)
// End:
