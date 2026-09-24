`timescale 1ns/1ps

module m_qnsc_wrap_i2c #(
)
(
//---------------------------------------------------------------
// Clock/Reset 
//---------------------------------------------------------------
/*AUTOINPUT("^i_clk\|^i_rst")*/

//---------------------------------------------------------------
// APB interface 
//---------------------------------------------------------------
/*AUTOINPUT("^i_bus_apb")*/
/*AUTOOUTPUT("^o_bus_apb")*/

//---------------------------------------------------------------
// I2C PAD 
//---------------------------------------------------------------
/*AUTOINPUT("^i_pad")*/
/*AUTOOUTPUT("^o_pad")*/

//---------------------------------------------------------------
// I2C DMA 
//---------------------------------------------------------------
/*AUTOINPUT("^i_dma")*/
/*AUTOOUTPUT("^o_dma")*/

//---------------------------------------------------------------
// Others 
//---------------------------------------------------------------
/*AUTOINOUT*/
/*AUTOINPUT*/
/*AUTOOUTPUT*/
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
  "unuse_input"
  "\\|unuse_input"
  ))
*/

/*AUTO_LISP(setq verilog-auto-output-ignore-regexp
  (concat
  "unuse_output"
  "\\|unuse_output"
  ))
*/

/* apb_i2c AUTO_TEMPLATE(
    .HCLK                                 (i_clk_i2c),                           
    .HRESETn                              (i_rst_n_i2c),                         
    .P\(ADDR\|WDATA\|WRITE\|SEL\|ENABLE\) (i_bus_apb_p@"(downcase (symbol-name '\1))"[]),
    .P\(.*\)                              (o_bus_apb_p@"(downcase (symbol-name '\1))"[]),
    .interrupt_o                          (o_interrupt_i2c),                     
    .dma_\(.*\)_o                         (o_dma_\1[]),                          
    .dma_\(.*\)_i                         (i_dma_\1[]),                          
    .\(.*\)_pad_o                         (o_pad_i2c_\1[]),                      
    .\(.*\)_pad_i                         (i_pad_i2c_\1[]),                      
    .\(.*\)_padoen_o                      (o_pad_i2c_\1_oe_n[]),                   
);
*/
apb_i2c #(.P_APB_ADDR_WIDTH(12)) u_apb_i2c(/*AUTOINST*/);

endmodule
// Local Variables:
// verilog-library-flags:("-f filelist_emacs.f")
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: nil
// eval: (setq large-file-warning-threshold nil)
// End:
