`timescale 1ns/1ps

// QNSC wrapper of pulp-platform/timer_unit: the QSoC general-purpose timer.
// One wrapper, two instances in design/top, both 64-bit: timer_0 on APB_M6
// (INTMAP fast line 10) and timer_1 on APB_M7 (fast line 6).
// Spec: QNSC_MAS_TIMER (team SharePoint).
//
// Edit this .src.sv, then `make wrap BLOCK=timer`: emacs verilog-mode expands
// the AUTO comments and writes rtl/m_qnsc_wrap_timer.sv, the file timer.f
// compiles. Template functions: doc/rules/EMACS_quick_guide.pdf.
//
// Wrapper = core + bridge. apb_timer_unit already speaks APB, so the wrapper
// adds no bridge and no logic: it renames the ports and ties off what QSOC
// does not use. A wrapper is IP (design/README.md, "Shared numbers"): no
// import, no parameter. MODE_64 is a register bit written by firmware, not a
// parameter, so both instances are the same wrapper (MAS TIMER section 8).
//
// What the wrapper does:
//   - APB_ADDR_WIDTH = 14: the offset inside the 16 KiB APB window.
//     apb_timer_unit decodes PADDR[5:0] only (apb_timer_unit.sv:110, 214), so
//     its 64-byte map aliases every 0x40 across the window (MAS TIMER 7.6).
//   - PSTRB and PPROT: apb_timer_unit is APB3 and has neither, and the
//     wrapper has no such port: a byte or halfword store writes all 32 bits.
//   - PREADY = PSEL & PENABLE and PSLVERR = 0 inside apb_timer_unit
//     (apb_timer_unit.sv:204-205): passed through. The error for an access
//     while the clock is gated comes from the SCRC APB guard in design/top
//     (QNSC_SCRC_MAS 7.7), not from this wrapper.
//   - o_int_timer = {irq_hi_o, irq_lo_o}: combinational, match & IRQ_EN
//     (apb_timer_unit.sv:397-411); a pulse, or a level in one-shot when
//     prescaled (MAS TIMER 7.3). Both instances run 64-bit, so design/top
//     connects bit 0 only of timer_0 and timer_1; bit 1 is 0 (MAS TIMER 10).
//   - Tie-offs, MAS TIMER Table 10-1:
//       event_lo_i, event_hi_i = 0: no hardware start source; IEM has no effect.
//       ref_clk_i = 0: no reference clock; REF_CLK_EN = 1 stops the counter.
//       busy_o open: no consumer in QSOC.

module m_qnsc_wrap_timer
(
//---------------------------------------------------------------
// Clock/Reset: peri cluster, SCRC gate CLK_EN[2] / CLK_EN[3], o_rst_n_timer_<n>
//---------------------------------------------------------------
/*AUTOINPUT("^i_clk\|^i_rst")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic             i_clk_peri,             // To u_apb_timer_unit of apb_timer_unit.v
input logic             i_rst_n_peri,           // To u_apb_timer_unit of apb_timer_unit.v
// End of automatics

//---------------------------------------------------------------
// APB slave, from P_BUS through the SCRC APB guard (APB_M6 / APB_M7)
//---------------------------------------------------------------
/*AUTOINPUT("^i_bus_apb")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic [13:0]      i_bus_apb_paddr,        // To u_apb_timer_unit of apb_timer_unit.v
input logic             i_bus_apb_penable,      // To u_apb_timer_unit of apb_timer_unit.v
input logic             i_bus_apb_psel,         // To u_apb_timer_unit of apb_timer_unit.v
input logic [31:0]      i_bus_apb_pwdata,       // To u_apb_timer_unit of apb_timer_unit.v
input logic             i_bus_apb_pwrite,       // To u_apb_timer_unit of apb_timer_unit.v
// End of automatics
/*AUTOOUTPUT("^o_bus_apb")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic [31:0]     o_bus_apb_prdata,       // From u_apb_timer_unit of apb_timer_unit.v
output logic            o_bus_apb_pready,       // From u_apb_timer_unit of apb_timer_unit.v
output logic            o_bus_apb_pslverr,      // From u_apb_timer_unit of apb_timer_unit.v
// End of automatics

//---------------------------------------------------------------
// Interrupt, to INTMAP: [0] irq_lo_o, [1] irq_hi_o
//---------------------------------------------------------------
/*AUTOOUTPUT("^o_int")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic [1:0]      o_int_timer            // From u_apb_timer_unit of apb_timer_unit.v, ...
// End of automatics

//---------------------------------------------------------------
// Others -- must stay empty
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
// Core: apb_timer_unit, unmodified
//---------------------------------------------------------------
/* apb_timer_unit AUTO_TEMPLATE(
    .HCLK                                 (i_clk_peri),
    .HRESETn                              (i_rst_n_peri),
    .P\(ADDR\|WDATA\|WRITE\|SEL\|ENABLE\) (i_bus_apb_p@"(downcase (symbol-name '\1))"[]),
    .P\(.*\)                              (o_bus_apb_p@"(downcase (symbol-name '\1))"[]),
    .irq_lo_o                             (o_int_timer[0]),
    .irq_hi_o                             (o_int_timer[1]),
    .event_\(lo\|hi\)_i                   (1'b0),
    .ref_clk_i                            (1'b0),
    .busy_o                               (),
);
*/
apb_timer_unit #(
  .APB_ADDR_WIDTH (14)                  // contract: meta.apb_paddr_width
) u_apb_timer_unit (/*AUTOINST*/
                    // Outputs
                    .PRDATA             (o_bus_apb_prdata[31:0]), // Templated
                    .PREADY             (o_bus_apb_pready),      // Templated
                    .PSLVERR            (o_bus_apb_pslverr),     // Templated
                    .irq_lo_o           (o_int_timer[0]),        // Templated
                    .irq_hi_o           (o_int_timer[1]),        // Templated
                    .busy_o             (),                      // Templated
                    // Inputs
                    .HCLK               (i_clk_peri),            // Templated
                    .HRESETn            (i_rst_n_peri),          // Templated
                    .PADDR              (i_bus_apb_paddr[13:0]), // Templated
                    .PWDATA             (i_bus_apb_pwdata[31:0]), // Templated
                    .PWRITE             (i_bus_apb_pwrite),      // Templated
                    .PSEL               (i_bus_apb_psel),        // Templated
                    .PENABLE            (i_bus_apb_penable),     // Templated
                    .ref_clk_i          (1'b0),                  // Templated
                    .event_lo_i         (1'b0),                  // Templated
                    .event_hi_i         (1'b0));                 // Templated

endmodule
// Local Variables:
// verilog-library-flags:("-f filelist_emacs.f")
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: t
// indent-tabs-mode: nil
// eval: (setq large-file-warning-threshold nil)
// End:
