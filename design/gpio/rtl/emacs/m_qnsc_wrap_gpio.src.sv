`timescale 1ns/1ps

// QNSC wrapper of apb_gpio: the QSoC GPIO.
// Spec: doc/specs/QNSC_GPIO_MAS.md.
//
// Edit this .src.sv, then `make wrap BLOCK=gpio`: emacs verilog-mode expands
// the AUTO comments and writes rtl/m_qnsc_wrap_gpio.sv, the file gpio.f compiles.
// Template functions: doc/rules/EMACS_quick_guide.pdf.
//
// Declare no port by hand: map every IP port in the AUTO_TEMPLATE, bit slices
// included (.ch_0_o (o_pad_x[3:0])), so the AUTOs declare them. Then this file
// is valid SystemVerilog before expansion, and the editor shows no false errors.
//
// Wrapper = core + bridge. The core is the IP; the bridge, only when the IP
// speaks another protocol than the chip bus, converts it (APB to TL-UL, APB to
// OBI, ...). One wrapper per IP, owned by the IP owner.

// This wrapper is IP: it imports no chip package and declares no parameter.
module m_qnsc_wrap_gpio
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
// Integration policy
//---------------------------------------------------------------
// The selected PULP IP already speaks APB. It does not implement PSTRB or
// PPROT, so this wrapper deliberately does not add them. Sub-word writes are
// therefore software-prohibited: firmware writes aligned 32-bit words.
// Address aliases implemented by the IP are accepted, and its PREADY/PSLVERR
// outputs pass through unchanged. QSOC v1 has no DFT control source, so the
// IP's clock-gate test enable is tied low.

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
/* apb_gpio AUTO_TEMPLATE(
    .HCLK                                 (i_clk_peri),
    .HRESETn                              (i_rst_n_peri),
    .dft_cg_enable_i                      (1'b0),
    .P\(ADDR\|WDATA\|WRITE\|SEL\|ENABLE\) (i_bus_apb_p@"(downcase (symbol-name '\1))"[]),
    .P\(.*\)                              (o_bus_apb_p@"(downcase (symbol-name '\1))"[]),
    .gpio_in                              (i_pad_gpio[]),
    .gpio_in_sync                         (),
    .gpio_out                             (o_pad_gpio[]),
    .gpio_dir                             (o_pad_gpio_oe[]),
    // verilog-mode keeps only the last dimension of the IP's packed
    // [7:0][3:0] port. Flatten it explicitly; bits [4*n +: 4] configure pin n.
    .gpio_padcfg                          (o_pad_gpio_cfg[31:0]),
    .interrupt                            (o_int_gpio),
);
*/
apb_gpio #(
  .APB_ADDR_WIDTH (12), // contract: meta.apb_paddr_width
  .PAD_NUM        (8),
  .NBIT_PADCFG    (4)
) u_apb_gpio (/*AUTOINST*/);

endmodule
// Local Variables:
// verilog-library-flags:("-f filelist_emacs.f")
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: t
// indent-tabs-mode: nil
// eval: (setq large-file-warning-threshold nil)
// End:
