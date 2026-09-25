`timescale 1ns/1ps

// QNSC wrapper of apb_adv_timer: the QSoC PWM.
// Spec: doc/src/QNSC_PWM_MAS.md.
//
// Edit this .src.sv, then `make wrap BLOCK=pwm`: emacs verilog-mode expands
// the AUTO comments and writes rtl/m_qnsc_wrap_apb_adv_timer.sv, the file pwm.f compiles.
// Template functions: DM/EMACS/EMACS_quick_guide.pdf in MCU_guide_ws.
//
// Wrapper = core + bridge. The core is the IP; the bridge, only when the IP
// speaks another protocol than the chip bus, converts it (APB to TL-UL, APB to
// OBI, ...). One wrapper per IP, owned by the IP owner.

module m_qnsc_wrap_apb_adv_timer
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
input  logic [3:0] i_pad_tim_ext,  // TIM_EXT0-3, asynchronous
output logic [7:0] o_pad_pwm,      // PWM_0-3 = module 0, PWM_4-7 = module 1
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
logic [3:0]  r_tim_ext_meta;
logic [3:0]  r_tim_ext_sync;
logic [31:0] w_ext_sig;

always_ff @(posedge i_clk_peri or negedge i_rst_n_peri) begin
  if (!i_rst_n_peri) begin
    r_tim_ext_meta <= '0;
    r_tim_ext_sync <= '0;
  end else begin
    r_tim_ext_meta <= i_pad_tim_ext;
    r_tim_ext_sync <= r_tim_ext_meta;
  end
end

assign w_ext_sig = {28'b0, r_tim_ext_sync};
assign o_pad_pwm = {w_pwm_ch_1, w_pwm_ch_0};

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
//   .\(.*\)_pad_o                         (o_pad_pwm_\1[]),
//   .\(.*\)_padoen_o                      (o_pad_pwm_\1_oe_n[]),   active low: _n
//   .irq_o                                (o_int_pwm),
//   .dft_\(.*\)_i                         (1'b0),                        tie-off
//   .unused_o                             (),                            left open
//   .ERR_\(.*\) (@"(if (equal vl-dir \"input\") \"'0\" \"\")"),   inputs to 0, outputs open
// Instance parameters are substituted into widths (verilog-auto-inst-param-value t):
//   apb_adv_timer #(.APB_ADDR_WIDTH(C_APB_PADDR_WIDTH)) u_apb_adv_timer (/*AUTOINST*/);
/* apb_adv_timer AUTO_TEMPLATE(
    .HCLK                                 (i_clk_peri),
    .HRESETn                              (i_rst_n_peri),
    .P\(ADDR\|WDATA\|WRITE\|SEL\|ENABLE\) (i_bus_apb_p@"(downcase (symbol-name '\1))"[]),
    .P\(.*\)                              (o_bus_apb_p@"(downcase (symbol-name '\1))"[]),
    .dft_cg_enable_i                      (1'b0),
    .low_speed_clk_i                      (1'b0),
    .ext_sig_i                            (w_ext_sig[]),
    .events_o                             (o_int_pwm[]),
    .ch_\([01]\)_o                        (w_pwm_ch_\1[]),
    .ch_\([23]\)_o                        (),
);
*/
apb_adv_timer #(
  .APB_ADDR_WIDTH (C_APB_PADDR_WIDTH),
  .EXTSIG_NUM     (32),
  .TIMER_NBITS    (16)
) u_apb_adv_timer (/*AUTOINST*/);

endmodule
// Local Variables:
// verilog-library-flags:("-f filelist_emacs.f")
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: t
// eval: (setq large-file-warning-threshold nil)
// End:
