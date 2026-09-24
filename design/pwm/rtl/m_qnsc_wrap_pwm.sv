`timescale 1ns/1ps

// QNSC wrapper of pulp-platform/apb_adv_timer: the QSoC PWM on APB_M13.
// Spec: doc/src/QNSC_PWM_MAS.md.
//
// Edit m_qnsc_wrap_pwm.src.sv, then run `make` in this directory: emacs
// verilog-mode expands the AUTO comments and the result is copied to ../.
// The IP already speaks APB, so the wrapper has a core and no bridge.

module m_qnsc_wrap_pwm
  import qnsc_pkg::*;
(
//---------------------------------------------------------------
// Clock/Reset
//---------------------------------------------------------------
/*AUTOINPUT("^i_clk\|^i_rst")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic		i_clk_peri,		// To u_apb_adv_timer of apb_adv_timer.v
input logic		i_rst_n_peri,		// To u_apb_adv_timer of apb_adv_timer.v
// End of automatics

//---------------------------------------------------------------
// APB interface
//---------------------------------------------------------------
/*AUTOINPUT("^i_bus_apb")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic [C_APB_PADDR_WIDTH-1:0] i_bus_apb_paddr,// To u_apb_adv_timer of apb_adv_timer.v
input logic		i_bus_apb_penable,	// To u_apb_adv_timer of apb_adv_timer.v
input logic		i_bus_apb_psel,		// To u_apb_adv_timer of apb_adv_timer.v
input logic [31:0]	i_bus_apb_pwdata,	// To u_apb_adv_timer of apb_adv_timer.v
input logic		i_bus_apb_pwrite,	// To u_apb_adv_timer of apb_adv_timer.v
// End of automatics
/*AUTOOUTPUT("^o_bus_apb")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic [31:0]	o_bus_apb_prdata,	// From u_apb_adv_timer of apb_adv_timer.v
output logic		o_bus_apb_pready,	// From u_apb_adv_timer of apb_adv_timer.v
output logic		o_bus_apb_pslverr,	// From u_apb_adv_timer of apb_adv_timer.v
// End of automatics

//---------------------------------------------------------------
// PWM PAD, through IO MUX
//---------------------------------------------------------------
input  logic [3:0] i_tim_ext,  // TIM_EXT0-3, asynchronous
output logic [7:0] o_pwm,      // PWM_0-3 = module 0, PWM_4-7 = module 1

//---------------------------------------------------------------
// Interrupt, to INTMAP line C_INT_LINE_PWM
//---------------------------------------------------------------
/*AUTOOUTPUT("^o_int")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic [3:0]	o_int_pwm		// From u_apb_adv_timer of apb_adv_timer.v
// End of automatics

//---------------------------------------------------------------
// Others
//---------------------------------------------------------------
/*AUTOINOUT*/
/*AUTOINPUT*/
/*AUTOOUTPUT*/
);

/*AUTOWIRE*/
// Beginning of automatic wires (for undeclared instantiated-module outputs)
logic [3:0]		w_pwm_ch_0;		// From u_apb_adv_timer of apb_adv_timer.v
logic [3:0]		w_pwm_ch_1;		// From u_apb_adv_timer of apb_adv_timer.v
// End of automatics

//---------------------------------------------------------------
// TIM_EXT: two flops to i_clk_peri, then ext_sig_i[3:0]; [31:4] tied 0
//---------------------------------------------------------------
logic [3:0]  r_tim_ext_meta;
logic [3:0]  r_tim_ext_sync;
logic [31:0] w_ext_sig;

always_ff @(posedge i_clk_peri or negedge i_rst_n_peri) begin
  if (!i_rst_n_peri) begin
    r_tim_ext_meta <= '0;
    r_tim_ext_sync <= '0;
  end else begin
    r_tim_ext_meta <= i_tim_ext;
    r_tim_ext_sync <= r_tim_ext_meta;
  end
end

assign w_ext_sig = {28'b0, r_tim_ext_sync};

//---------------------------------------------------------------
// Pads carry modules 0 and 1; modules 2 and 3 stay internal
//---------------------------------------------------------------
assign o_pwm = {w_pwm_ch_1, w_pwm_ch_0};

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
  "^w_"
  "\\|unuse_output"
  ))
*/

/* apb_adv_timer AUTO_TEMPLATE(
    .HCLK                                 (i_clk_peri),
    .HRESETn                              (i_rst_n_peri),
    .P\(ADDR\|WDATA\|WRITE\|SEL\|ENABLE\) (i_bus_apb_p@"(downcase (symbol-name '\1))"[]),
    .P\(.*\)                              (o_bus_apb_p@"(downcase (symbol-name '\1))"[]),
    .dft_cg_enable_i                      (1'b0),
    .low_speed_clk_i                      (1'b0),
    .ext_sig_i                            (w_ext_sig),
    .events_o                             (o_int_pwm[]),
    .ch_\([01]\)_o                        (w_pwm_ch_\1[]),
    .ch_\([23]\)_o                        (),
);
*/
apb_adv_timer #(
  .APB_ADDR_WIDTH (C_APB_PADDR_WIDTH),
  .EXTSIG_NUM     (32),
  .TIMER_NBITS    (16)
) u_apb_adv_timer (/*AUTOINST*/
		   // Outputs
		   .PRDATA		(o_bus_apb_prdata[31:0]), // Templated
		   .PREADY		(o_bus_apb_pready),	 // Templated
		   .PSLVERR		(o_bus_apb_pslverr),	 // Templated
		   .events_o		(o_int_pwm[3:0]),	 // Templated
		   .ch_0_o		(w_pwm_ch_0[3:0]),	 // Templated
		   .ch_1_o		(w_pwm_ch_1[3:0]),	 // Templated
		   .ch_2_o		(),			 // Templated
		   .ch_3_o		(),			 // Templated
		   // Inputs
		   .HCLK		(i_clk_peri),		 // Templated
		   .HRESETn		(i_rst_n_peri),		 // Templated
		   .PADDR		(i_bus_apb_paddr[C_APB_PADDR_WIDTH-1:0]), // Templated
		   .PWDATA		(i_bus_apb_pwdata[31:0]), // Templated
		   .PWRITE		(i_bus_apb_pwrite),	 // Templated
		   .PSEL		(i_bus_apb_psel),	 // Templated
		   .PENABLE		(i_bus_apb_penable),	 // Templated
		   .dft_cg_enable_i	(1'b0),			 // Templated
		   .low_speed_clk_i	(1'b0),			 // Templated
		   .ext_sig_i		(w_ext_sig));		 // Templated

endmodule
// Local Variables:
// verilog-library-flags:("-f filelist_emacs.f")
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: nil
// eval: (setq large-file-warning-threshold nil)
// End:
