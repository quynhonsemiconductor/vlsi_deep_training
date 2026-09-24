`timescale 1ns/1ps

module m_qnsc_wrap_i2c #(
)
(
//---------------------------------------------------------------
// Clock/Reset 
//---------------------------------------------------------------
/*AUTOINPUT("^i_clk\|^i_rst")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic		i_clk_i2c,		// To u_apb_i2c of apb_i2c.v
input logic		i_rst_n_i2c,		// To u_apb_i2c of apb_i2c.v
// End of automatics

//---------------------------------------------------------------
// APB interface 
//---------------------------------------------------------------
/*AUTOINPUT("^i_bus_apb")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic [11:0] i_bus_apb_paddr,// To u_apb_i2c of apb_i2c.v
input logic		i_bus_apb_penable,	// To u_apb_i2c of apb_i2c.v
input logic		i_bus_apb_psel,		// To u_apb_i2c of apb_i2c.v
input logic [31:0]	i_bus_apb_pwdata,	// To u_apb_i2c of apb_i2c.v
input logic		i_bus_apb_pwrite,	// To u_apb_i2c of apb_i2c.v
// End of automatics
/*AUTOOUTPUT("^o_bus_apb")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic [31:0]	o_bus_apb_prdata,	// From u_apb_i2c of apb_i2c.v
output logic		o_bus_apb_pready,	// From u_apb_i2c of apb_i2c.v
output logic		o_bus_apb_pslverr,	// From u_apb_i2c of apb_i2c.v
// End of automatics

//---------------------------------------------------------------
// I2C PAD 
//---------------------------------------------------------------
/*AUTOINPUT("^i_pad")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic		i_pad_i2c_scl,		// To u_apb_i2c of apb_i2c.v
input logic		i_pad_i2c_sda,		// To u_apb_i2c of apb_i2c.v
// End of automatics
/*AUTOOUTPUT("^o_pad")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic		o_pad_i2c_scl,		// From u_apb_i2c of apb_i2c.v
output logic		o_pad_i2c_scl_oe_n,	// From u_apb_i2c of apb_i2c.v
output logic		o_pad_i2c_sda,		// From u_apb_i2c of apb_i2c.v
output logic		o_pad_i2c_sda_oe_n,	// From u_apb_i2c of apb_i2c.v
// End of automatics

//---------------------------------------------------------------
// I2C DMA 
//---------------------------------------------------------------
/*AUTOINPUT("^i_dma")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic		i_dma_last,		// To u_apb_i2c of apb_i2c.v
// End of automatics
/*AUTOOUTPUT("^o_dma")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic		o_dma_rx_req,		// From u_apb_i2c of apb_i2c.v
output logic		o_dma_tx_req,		// From u_apb_i2c of apb_i2c.v
// End of automatics

//---------------------------------------------------------------
// Others 
//---------------------------------------------------------------
/*AUTOINOUT*/
/*AUTOINPUT*/
/*AUTOOUTPUT*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic		o_interrupt_i2c	// From u_apb_i2c of apb_i2c.v
// End of automatics
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
apb_i2c #(.P_APB_ADDR_WIDTH(12)) u_apb_i2c(/*AUTOINST*/
					   // Outputs
					   .PRDATA		(o_bus_apb_prdata[31:0]), // Templated
					   .PREADY		(o_bus_apb_pready), // Templated
					   .PSLVERR		(o_bus_apb_pslverr), // Templated
					   .interrupt_o		(o_interrupt_i2c), // Templated
					   .dma_tx_req_o	(o_dma_tx_req),	 // Templated
					   .dma_rx_req_o	(o_dma_rx_req),	 // Templated
					   .scl_pad_o		(o_pad_i2c_scl), // Templated
					   .scl_padoen_o	(o_pad_i2c_scl_oe_n), // Templated
					   .sda_pad_o		(o_pad_i2c_sda), // Templated
					   .sda_padoen_o	(o_pad_i2c_sda_oe_n), // Templated
					   // Inputs
					   .HCLK		(i_clk_i2c),	 // Templated
					   .HRESETn		(i_rst_n_i2c),	 // Templated
					   .PADDR		(i_bus_apb_paddr[11:0]), // Templated
					   .PWDATA		(i_bus_apb_pwdata[31:0]), // Templated
					   .PWRITE		(i_bus_apb_pwrite), // Templated
					   .PSEL		(i_bus_apb_psel), // Templated
					   .PENABLE		(i_bus_apb_penable), // Templated
					   .dma_last_i		(i_dma_last),	 // Templated
					   .scl_pad_i		(i_pad_i2c_scl), // Templated
					   .sda_pad_i		(i_pad_i2c_sda)); // Templated

endmodule
// Local Variables:
// verilog-library-flags:("-f filelist_emacs.f")
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: nil
// eval: (setq large-file-warning-threshold nil)
// End:
