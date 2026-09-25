`timescale 1ns/1ps

// QNSC wrapper of pulp-platform/apb_adv_timer: the QSoC PWM on APB_M12,
// C_PWM_BASE, INTMAP fast line C_INT_LINE_PWM.
// Spec: doc/src/QNSC_PWM_MAS.md (V2.2).
//
// Edit this .src.sv, then `make wrap BLOCK=pwm`: emacs verilog-mode expands
// the AUTO comments and writes rtl/m_qnsc_wrap_apb_adv_timer.sv, the file
// pwm.f compiles. Template functions: doc/rules/EMACS_quick_guide.pdf.
//
// Wrapper = core + bridge. The IP already speaks APB, so there is no bridge.
// What the wrapper adds (MAS 5, 7.3, 10):
//   - i_pad_tim_ext[3:0] synchronised to i_clk_peri by qnsc_sync, then
//     ext_sig_i[3:0]; ext_sig_i[31:4] tied 0
//   - o_pad_pwm[7:0] = {ch_1_o, ch_0_o}; modules 2 and 3 have no pads
//   - dft_cg_enable_i and low_speed_clk_i tied 0
// pulp_clock_gating, which the IP instantiates, is in rtl/pulp_clock_gating.sv.

module m_qnsc_wrap_apb_adv_timer
  import qnsc_pkg::*;
(
//---------------------------------------------------------------
// Clock/Reset: peri cluster, gated by SCRC CLK_EN
//---------------------------------------------------------------
/*AUTOINPUT("^i_clk\|^i_rst")*/

//---------------------------------------------------------------
// APB slave, from P_BUS (APB_M12)
//---------------------------------------------------------------
/*AUTOINPUT("^i_bus_apb")*/
/*AUTOOUTPUT("^o_bus_apb")*/

//---------------------------------------------------------------
// PAD, through IO MUX: TIM_EXT0-3 in, PWM_0-7 out
//---------------------------------------------------------------
output logic [7:0] o_pad_pwm,  // [3:0] = module 0, [7:4] = module 1
/*AUTOINPUT("^i_pad")*/
/*AUTOOUTPUT("^o_pad")*/

//---------------------------------------------------------------
// Interrupt, to INTMAP fast line C_INT_LINE_PWM: one-cycle pulses
//---------------------------------------------------------------
/*AUTOOUTPUT("^o_int")*/

//---------------------------------------------------------------
// Others -- must stay empty
//---------------------------------------------------------------
/*AUTOINOUT*/
/*AUTOINPUT*/
/*AUTOOUTPUT*/
);

/*AUTOWIRE*/

//---------------------------------------------------------------
// Count sources and pads
//---------------------------------------------------------------
logic [31:0] w_ext_sig;

assign w_ext_sig = {28'b0, w_tim_ext_sync};       // IN_SEL 4-31 select 0
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

//---------------------------------------------------------------
// TIM_EXT pads: asynchronous, two flip-flops to i_clk_peri
//---------------------------------------------------------------
/* qnsc_sync AUTO_TEMPLATE(
    .i_clk_dst                            (i_clk_peri),
    .i_rst_n_dst                          (i_rst_n_peri),
    .i_d                                  (i_pad_tim_ext[]),
    .o_q                                  (w_tim_ext_sync[]),
);
*/
qnsc_sync #(
  .P_WIDTH  (4),
  .P_STAGES (2)
) u_sync_tim_ext (/*AUTOINST*/);

//---------------------------------------------------------------
// Core: apb_adv_timer
//---------------------------------------------------------------
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
