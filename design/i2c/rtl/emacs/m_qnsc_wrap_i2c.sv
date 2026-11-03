`timescale 1ns/1ps

// QNSC wrapper of pulp-platform/apb_i2c: the QSoC I2C master, on APB_M11,
// INTMAP fast line 3. Spec: QNSC_I2C_MAS (team SharePoint).
//
// Edit this .src.sv, then `make wrap BLOCK=i2c`: emacs verilog-mode expands
// the AUTO comments and writes rtl/m_qnsc_wrap_i2c.sv, the file i2c.f compiles.
// Template functions: doc/rules/EMACS_quick_guide.pdf.
//
// Wrapper = core + bridge. apb_i2c already speaks APB, so the wrapper adds no
// bridge: it renames the ports, fixes the IP's configuration and inverts the
// two pad output enables, its only logic.
// A wrapper is IP (design/README.md, "Shared numbers"): no import, no parameter.
//
// What the wrapper does:
//   - APB_ADDR_WIDTH = 14: the offset inside the 16 KiB APB window. apb_i2c
//     decodes PADDR[5:2] only (apb_i2c.sv:65), so its six registers alias
//     every 64 bytes across the window.
//   - PSTRB and PPROT: apb_i2c has neither. The wrapper keeps both ports and
//     leaves them unconnected (APB slave conventions, design/README.md): a
//     byte or halfword store writes the whole register.
//   - PREADY is 1 and PSLVERR is 0 inside apb_i2c: passed through.
//   - SCL and SDA are open drain: the IP drives scl_pad_o = sda_pad_o = 0
//     (i2c_master_bit_ctrl.sv:541-542) and releases the line with padoen_o,
//     active low (i2c_master_bit_ctrl.sv:157, 160). The IO pad wants OE
//     active high (QNSC_I2C_MAS V3.0, IOPAD pin summary), so the wrapper
//     inverts it: o_pad_i2c_*_oe = 1 pulls the line low, 0 releases it to Hi-Z.
//   - The pad inputs are synchronised inside the IP by two flops
//     (cSCL/cSDA, i2c_master_bit_ctrl.sv:239-240): the wrapper adds none.
//   - interrupt_o is a flop, a level held until CMD.IACK (apb_i2c.sv:183, 193).
//
// Ports declared by hand. AUTOINPUT/AUTOOUTPUT declare a port only from an
// instance pin:
//   - o_pad_i2c_scl_oe, o_pad_i2c_sda_oe: driven by the inverters, not by a pin.
//   - i_bus_apb_pstrb, i_bus_apb_pprot: apb_i2c has no such pin. They are the
//     last ports, so this file stays valid SystemVerilog before expansion; they
//     are waived as unused in design/i2c/waivers.vlt.

module m_qnsc_wrap_i2c
(
//---------------------------------------------------------------
// Clock/Reset: peri cluster, SCRC o_clk_i2c / o_rst_n_i2c
//---------------------------------------------------------------
/*AUTOINPUT("^i_clk\|^i_rst")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic             i_clk_peri,             // To u_apb_i2c of apb_i2c.v
input logic             i_rst_n_peri,           // To u_apb_i2c of apb_i2c.v
// End of automatics

//---------------------------------------------------------------
// APB slave, from P_BUS (APB_M11)
//---------------------------------------------------------------
/*AUTOINPUT("^i_bus_apb")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic [13:0]      i_bus_apb_paddr,        // To u_apb_i2c of apb_i2c.v
input logic             i_bus_apb_penable,      // To u_apb_i2c of apb_i2c.v
input logic             i_bus_apb_psel,         // To u_apb_i2c of apb_i2c.v
input logic [31:0]      i_bus_apb_pwdata,       // To u_apb_i2c of apb_i2c.v
input logic             i_bus_apb_pwrite,       // To u_apb_i2c of apb_i2c.v
// End of automatics
/*AUTOOUTPUT("^o_bus_apb")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic [31:0]     o_bus_apb_prdata,       // From u_apb_i2c of apb_i2c.v
output logic            o_bus_apb_pready,       // From u_apb_i2c of apb_i2c.v
output logic            o_bus_apb_pslverr,      // From u_apb_i2c of apb_i2c.v
// End of automatics

//---------------------------------------------------------------
// PAD, through IO MUX: open drain, output enable active high
//---------------------------------------------------------------
/*AUTOINPUT("^i_pad")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic             i_pad_i2c_scl,          // To u_apb_i2c of apb_i2c.v
input logic             i_pad_i2c_sda,          // To u_apb_i2c of apb_i2c.v
// End of automatics
/*AUTOOUTPUT("^o_pad")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic            o_pad_i2c_scl,          // From u_apb_i2c of apb_i2c.v
output logic            o_pad_i2c_sda,          // From u_apb_i2c of apb_i2c.v
// End of automatics
output logic            o_pad_i2c_scl_oe,       // 1 = pull SCL low, 0 = Hi-Z
output logic            o_pad_i2c_sda_oe,       // 1 = pull SDA low, 0 = Hi-Z

//---------------------------------------------------------------
// Interrupt, to INTMAP i_int_i2c: level
//---------------------------------------------------------------
/*AUTOOUTPUT("^o_int")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic            o_int_i2c,              // From u_apb_i2c of apb_i2c.v
// End of automatics

//---------------------------------------------------------------
// Others -- must stay empty
//---------------------------------------------------------------
/*AUTOINOUT*/
/*AUTOINPUT*/
/*AUTOOUTPUT*/

//---------------------------------------------------------------
// APB fields apb_i2c does not have: declared by hand, not connected
//---------------------------------------------------------------
input  logic [3:0]      i_bus_apb_pstrb,        // not used: a store writes the whole register
input  logic [2:0]      i_bus_apb_pprot         // not used
);

/*AUTOWIRE*/
// Beginning of automatic wires (for undeclared instantiated-module outputs)
logic                   w_scl_oe_n;             // From u_apb_i2c of apb_i2c.v
logic                   w_sda_oe_n;             // From u_apb_i2c of apb_i2c.v
// End of automatics

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
// Core: apb_i2c, unmodified
//---------------------------------------------------------------
/* apb_i2c AUTO_TEMPLATE(
    .HCLK                                 (i_clk_peri),
    .HRESETn                              (i_rst_n_peri),
    .P\(ADDR\|WDATA\|WRITE\|SEL\|ENABLE\) (i_bus_apb_p@"(downcase (symbol-name '\1))"[]),
    .P\(.*\)                              (o_bus_apb_p@"(downcase (symbol-name '\1))"[]),
    .interrupt_o                          (o_int_i2c),
    .\(.*\)_pad_i                         (i_pad_i2c_\1),
    .\(.*\)_pad_o                         (o_pad_i2c_\1),
    .\(.*\)_padoen_o                      (w_\1_oe_n),
);
*/
apb_i2c #(
  .APB_ADDR_WIDTH (14)                  // contract: meta.apb_paddr_width
) u_apb_i2c (/*AUTOINST*/
             // Outputs
             .PRDATA                    (o_bus_apb_prdata[31:0]), // Templated
             .PREADY                    (o_bus_apb_pready),      // Templated
             .PSLVERR                   (o_bus_apb_pslverr),     // Templated
             .interrupt_o               (o_int_i2c),             // Templated
             .scl_pad_o                 (o_pad_i2c_scl),         // Templated
             .scl_padoen_o              (w_scl_oe_n),            // Templated
             .sda_pad_o                 (o_pad_i2c_sda),         // Templated
             .sda_padoen_o              (w_sda_oe_n),            // Templated
             // Inputs
             .HCLK                      (i_clk_peri),            // Templated
             .HRESETn                   (i_rst_n_peri),          // Templated
             .PADDR                     (i_bus_apb_paddr[13:0]), // Templated
             .PWDATA                    (i_bus_apb_pwdata[31:0]), // Templated
             .PWRITE                    (i_bus_apb_pwrite),      // Templated
             .PSEL                      (i_bus_apb_psel),        // Templated
             .PENABLE                   (i_bus_apb_penable),     // Templated
             .scl_pad_i                 (i_pad_i2c_scl),         // Templated
             .sda_pad_i                 (i_pad_i2c_sda));        // Templated

//---------------------------------------------------------------
// Pad output enable: IP active low -> pad active high
//---------------------------------------------------------------
assign o_pad_i2c_scl_oe = ~w_scl_oe_n;
assign o_pad_i2c_sda_oe = ~w_sda_oe_n;

endmodule
// Local Variables:
// verilog-library-flags:("-f filelist_emacs.f")
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: t
// indent-tabs-mode: nil
// eval: (setq large-file-warning-threshold nil)
// End:
