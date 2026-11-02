`default_nettype none
`timescale 1ns/1ps
//==============================================================================
// Module      : m_qnsc_wrap_bus
// Description : S_BUS -- the AXI4 crossbar (axi_xbar) plus the AXI2APB bridge
//               (axi_to_axi_lite + axi_lite_to_apb). Three masters issue
//               transactions here (SYSDBG on AXI_S0, CPU on AXI_S1, DMA on
//               AXI_S2); four destinations answer them (ROM AXI_M0, ISRAM
//               AXI_M1, DSRAM AXI_M2, AXI2APB AXI_M3), and AXI_M3 leaves this
//               block as one APB4 master port. P_BUS's router is not here.
//               The AXI4 ports are packed structs typed from qnsc_s_bus_pkg.
// Spec ref    : QNSC_BUS_MAS (team SharePoint)
//
// Edit this .src.sv, then `make wrap BLOCK=bus`: emacs verilog-mode expands the
// AUTO comments and writes rtl/m_qnsc_wrap_bus.sv, the file bus.f compiles.
// bus is an integration block (design/README.md, "Shared numbers"): it reads
// qnsc_pkg, but a file expanded by emacs has no import, so every name is
// written with its package.
//==============================================================================
module m_qnsc_wrap_bus
(
//---------------------------------------------------------------
// Clock/Reset -- S_BUS is in the contract's cpu clock cluster (clock_domains: cpu, bus,
// sysdbg, syscsr), so its ports are i_clk_cpu / i_rst_n_cpu. The AXI2APB bridge runs on
// the same clock as the crossbar, as the CPU's cpu2axi bridge shares the cpu clock.
//---------------------------------------------------------------
/*AUTOINPUT("^i_clk\|^i_rst")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic             i_clk_cpu,              // To u_axi_xbar of axi_xbar.v, ...
input logic             i_rst_n_cpu,            // To u_axi_xbar of axi_xbar.v, ...
// End of automatics

//---------------------------------------------------------------
// APB4 -- the AXI2APB bridge's one master port (AXI_M3 after conversion).
// paddr is the offset inside the AXI2APB window: the low
// 18 address bits (contract meta.pbus_paddr_width).
//---------------------------------------------------------------
output logic [17:0]  o_bus_apb_m_0_paddr,
output logic [31:0]  o_bus_apb_m_0_pwdata,
output logic [3:0]   o_bus_apb_m_0_pstrb,
output logic         o_bus_apb_m_0_pwrite,
output logic         o_bus_apb_m_0_psel,
output logic         o_bus_apb_m_0_penable,
input  logic [31:0]  i_bus_apb_m_0_prdata,
input  logic         i_bus_apb_m_0_pready,
input  logic         i_bus_apb_m_0_pslverr,

//---------------------------------------------------------------
// Others -- must stay empty once the templates below are complete
//---------------------------------------------------------------
/*AUTOINOUT*/
/*AUTOINPUT*/
/*AUTOOUTPUT*/

//---------------------------------------------------------------
// AXI4 ports, written by hand: one packed struct per direction and port, typed from
// qnsc_s_bus_pkg (written with the package name, no import). A struct carries every
// AXI4 field, so a master or slave connects one signal instead of 45.
//   slave ports  : ID 1 bit, from the masters (SYSDBG, CPU, DMA)      -> slv_req_t / slv_resp_t
//   master ports : ID 3 bit = 1 + clog2(3), axi_xbar widens it, to ROM / ISRAM / DSRAM -> mst_req_t / mst_resp_t
// Keep this group last (the final port has no trailing comma).
//---------------------------------------------------------------
// ---- slave port s_0: SYSDBG (AXI_S0) ----
input  qnsc_s_bus_pkg::slv_req_t   i_bus_axi_s_0_req,  // module-rules: ignore -- AXI4 port as a struct, owner's call 2026-10-19  // naming-check: ignore -- one struct per direction
output qnsc_s_bus_pkg::slv_resp_t  o_bus_axi_s_0_resp,  // module-rules: ignore -- AXI4 port as a struct, owner's call 2026-10-19  // naming-check: ignore -- one struct per direction
// ---- slave port s_1: CPU, CPU2AXI bridge (AXI_S1) ----
input  qnsc_s_bus_pkg::slv_req_t   i_bus_axi_s_1_req,  // module-rules: ignore -- AXI4 port as a struct, owner's call 2026-10-19  // naming-check: ignore -- one struct per direction
output qnsc_s_bus_pkg::slv_resp_t  o_bus_axi_s_1_resp,  // module-rules: ignore -- AXI4 port as a struct, owner's call 2026-10-19  // naming-check: ignore -- one struct per direction
// ---- slave port s_2: DMA (AXI_S2) ----
input  qnsc_s_bus_pkg::slv_req_t   i_bus_axi_s_2_req,  // module-rules: ignore -- AXI4 port as a struct, owner's call 2026-10-19  // naming-check: ignore -- one struct per direction
output qnsc_s_bus_pkg::slv_resp_t  o_bus_axi_s_2_resp,  // module-rules: ignore -- AXI4 port as a struct, owner's call 2026-10-19  // naming-check: ignore -- one struct per direction
// ---- master port m_0: ROM (AXI_M0) ----
output qnsc_s_bus_pkg::mst_req_t   o_bus_axi_m_0_req,  // module-rules: ignore -- AXI4 port as a struct, owner's call 2026-10-19  // naming-check: ignore -- one struct per direction
input  qnsc_s_bus_pkg::mst_resp_t  i_bus_axi_m_0_resp,  // module-rules: ignore -- AXI4 port as a struct, owner's call 2026-10-19  // naming-check: ignore -- one struct per direction
// ---- master port m_1: ISRAM, debug window and application (AXI_M1) ----
output qnsc_s_bus_pkg::mst_req_t   o_bus_axi_m_1_req,  // module-rules: ignore -- AXI4 port as a struct, owner's call 2026-10-19  // naming-check: ignore -- one struct per direction
input  qnsc_s_bus_pkg::mst_resp_t  i_bus_axi_m_1_resp,  // module-rules: ignore -- AXI4 port as a struct, owner's call 2026-10-19  // naming-check: ignore -- one struct per direction
// ---- master port m_2: DSRAM (AXI_M2) ----
output qnsc_s_bus_pkg::mst_req_t   o_bus_axi_m_2_req,  // module-rules: ignore -- AXI4 port as a struct, owner's call 2026-10-19  // naming-check: ignore -- one struct per direction
input  qnsc_s_bus_pkg::mst_resp_t  i_bus_axi_m_2_resp  // module-rules: ignore -- AXI4 port as a struct, owner's call 2026-10-19  // naming-check: ignore -- one struct per direction
);

/*AUTOWIRE*/

// ---- elaboration checks: the APB port widths equal the contract's ----
if ($bits(o_bus_apb_m_0_paddr) != 18) begin : g_chk_apb_paddr
  $error("APB paddr width differs from the contract (C_PBUS_PADDR_WIDTH)");
end
if ($bits(o_bus_apb_m_0_pwdata) != 32) begin : g_chk_apb_data
  $error("APB data width differs from the contract (C_DATA_WIDTH)");
end

// ---- structs the crossbar and the bridge speak ----
qnsc_s_bus_pkg::slv_req_t  w_axi_s_0_req,  w_axi_s_1_req,  w_axi_s_2_req;
qnsc_s_bus_pkg::slv_resp_t w_axi_s_0_resp, w_axi_s_1_resp, w_axi_s_2_resp;

qnsc_s_bus_pkg::mst_req_t  w_axi_m_0_req,  w_axi_m_1_req,  w_axi_m_2_req;
qnsc_s_bus_pkg::mst_resp_t w_axi_m_0_resp, w_axi_m_1_resp, w_axi_m_2_resp;

qnsc_s_bus_pkg::slv_req_t  [3-1:0] w_slv_reqs;
qnsc_s_bus_pkg::slv_resp_t [3-1:0] w_slv_resps;
qnsc_s_bus_pkg::mst_req_t  [4-1:0] w_mst_reqs;
qnsc_s_bus_pkg::mst_resp_t [4-1:0] w_mst_resps;

assign w_slv_reqs[0] = w_axi_s_0_req;
assign w_slv_reqs[1] = w_axi_s_1_req;
assign w_slv_reqs[2] = w_axi_s_2_req;
assign w_axi_s_0_resp = w_slv_resps[0];
assign w_axi_s_1_resp = w_slv_resps[1];
assign w_axi_s_2_resp = w_slv_resps[2];

assign w_axi_m_0_req = w_mst_reqs[0];
assign w_axi_m_1_req = w_mst_reqs[1];
assign w_axi_m_2_req = w_mst_reqs[2];
assign w_mst_resps[0] = w_axi_m_0_resp;
assign w_mst_resps[1] = w_axi_m_1_resp;
assign w_mst_resps[2] = w_axi_m_2_resp;
// mst_reqs[3] / mst_resps[3] (AXI2APB) feed the bridge below and never leave as AXI:
// AXI_M3 leaves this block as the APB4 port above.

qnsc_s_bus_pkg::lite_req_t  w_axi2apb_lite_req;
qnsc_s_bus_pkg::lite_resp_t w_axi2apb_lite_resp;

qnsc_s_bus_pkg::apb_req_t  [1-1:0] w_apb_req;
qnsc_s_bus_pkg::apb_resp_t [1-1:0] w_apb_resp;

/*AUTO_LISP(setq verilog-auto-inout-ignore-regexp
  (concat
  "unuse_inout"
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

// ==================================================================
// The crossbar itself
// ==================================================================
/* axi_xbar AUTO_TEMPLATE(
    .clk_i                 (i_clk_cpu),
    .rst_ni                (i_rst_n_cpu),
    .slv_ports_req_i       (w_slv_reqs),
    .slv_ports_resp_o      (w_slv_resps),
    .mst_ports_req_o       (w_mst_reqs),
    .mst_ports_resp_i      (w_mst_resps),
    .addr_map_i            (qnsc_s_bus_pkg::P_ADDR_MAP),
    // no default port on any slave port: an unmapped address always reaches the
    // private decode-error responder, never a guessed destination
    .en_default_mst_port_i ('0),
    .default_mst_port_i    ('0),
    // verilog-mode reads a struct port's type name as a pin of its own; the flow drops those lines
    .\(.*_t\)               (),
);
*/
axi_xbar #(
  .Cfg           (qnsc_s_bus_pkg::P_CFG),
  .ATOPs         (1'b0),  // no evidence any master here issues AXI5 atomics
  .Connectivity  (qnsc_s_bus_pkg::P_CONNECTIVITY),  // DMA (AXI_S2) cannot reach ROM or ISRAM
  .slv_aw_chan_t (qnsc_s_bus_pkg::slv_aw_chan_t),
  .mst_aw_chan_t (qnsc_s_bus_pkg::mst_aw_chan_t),
  .w_chan_t      (qnsc_s_bus_pkg::w_chan_t),
  .slv_b_chan_t  (qnsc_s_bus_pkg::slv_b_chan_t),
  .mst_b_chan_t  (qnsc_s_bus_pkg::mst_b_chan_t),
  .slv_ar_chan_t (qnsc_s_bus_pkg::slv_ar_chan_t),
  .mst_ar_chan_t (qnsc_s_bus_pkg::mst_ar_chan_t),
  .slv_r_chan_t  (qnsc_s_bus_pkg::slv_r_chan_t),
  .mst_r_chan_t  (qnsc_s_bus_pkg::mst_r_chan_t),
  .slv_req_t     (qnsc_s_bus_pkg::slv_req_t),
  .slv_resp_t    (qnsc_s_bus_pkg::slv_resp_t),
  .mst_req_t     (qnsc_s_bus_pkg::mst_req_t),
  .mst_resp_t    (qnsc_s_bus_pkg::mst_resp_t),
  .rule_t        (qnsc_s_bus_pkg::rule_t)
) u_axi_xbar (/*AUTOINST*/
              // Interfaces
              // Outputs
              .slv_ports_resp_o         (w_slv_resps),           // Templated
              .mst_ports_req_o          (w_mst_reqs),            // Templated
              // Inputs
              .clk_i                    (i_clk_cpu),             // Templated
              .rst_ni                   (i_rst_n_cpu),           // Templated
              .slv_ports_req_i          (w_slv_reqs),            // Templated
              .mst_ports_resp_i         (w_mst_resps),           // Templated
              .addr_map_i               (qnsc_s_bus_pkg::P_ADDR_MAP), // Templated
              .en_default_mst_port_i    ('0),                    // Templated
              .default_mst_port_i       ('0));                   // Templated

// ==================================================================
// AXI2APB: AXI4 (AXI_M3) -> AXI4-Lite -> APB4, on the cpu clock
// ==================================================================
/* axi_to_axi_lite AUTO_TEMPLATE(
    .clk_i      (i_clk_cpu),
    .rst_ni     (i_rst_n_cpu),
    .slv_req_i  (w_mst_reqs[3]),
    .slv_resp_o (w_mst_resps[3]),
    .mst_req_o  (w_axi2apb_lite_req),
    .mst_resp_i (w_axi2apb_lite_resp),
    // verilog-mode reads a struct port's type name as a pin of its own; the flow drops those lines
    .\(.*_t\)               (),
);
*/
axi_to_axi_lite #(
  .AxiAddrWidth    (32),
  .AxiDataWidth    (32),
  .AxiIdWidth      (3),
  .AxiUserWidth    (1),
  .AxiMaxWriteTxns (2),
  .AxiMaxReadTxns  (2),
  .FallThrough     (1'b1),
  .full_req_t      (qnsc_s_bus_pkg::mst_req_t),
  .full_resp_t     (qnsc_s_bus_pkg::mst_resp_t),
  .lite_req_t      (qnsc_s_bus_pkg::lite_req_t),
  .lite_resp_t     (qnsc_s_bus_pkg::lite_resp_t)
) u_axi_to_axi_lite (/*AUTOINST*/
                     // Interfaces
                     .slv_req_i         (w_mst_reqs[3]),         // Templated
                     .slv_resp_o        (w_mst_resps[3]),        // Templated
                     .mst_req_o         (w_axi2apb_lite_req),    // Templated
                     .mst_resp_i        (w_axi2apb_lite_resp),   // Templated
                     // Inputs
                     .clk_i             (i_clk_cpu),             // Templated
                     .rst_ni            (i_rst_n_cpu));          // Templated

/* axi_lite_to_apb AUTO_TEMPLATE(
    .clk_i           (i_clk_cpu),
    .rst_ni          (i_rst_n_cpu),
    .axi_lite_req_i  (w_axi2apb_lite_req),
    .axi_lite_resp_o (w_axi2apb_lite_resp),
    .apb_req_o       (w_apb_req),
    .apb_resp_i      (w_apb_resp),
    .addr_map_i      (qnsc_s_bus_pkg::P_APB_ADDR_MAP),
    // verilog-mode reads a struct port's type name as a pin of its own; the flow drops those lines
    .\(.*_t\)               (),
);
*/
axi_lite_to_apb #(
  .NoApbSlaves      (1),
  .NoRules          (1),
  .AddrWidth        (32),
  .DataWidth        (32),
  .PipelineRequest  (1'b0),
  .PipelineResponse (1'b0),
  .axi_lite_req_t   (qnsc_s_bus_pkg::lite_req_t),
  .axi_lite_resp_t  (qnsc_s_bus_pkg::lite_resp_t),
  .apb_req_t        (qnsc_s_bus_pkg::apb_req_t),
  .apb_resp_t       (qnsc_s_bus_pkg::apb_resp_t),
  .rule_t           (qnsc_s_bus_pkg::rule_t)
) u_axi_lite_to_apb (/*AUTOINST*/
                     // Interfaces
                     .axi_lite_req_i    (w_axi2apb_lite_req),    // Templated
                     .axi_lite_resp_o   (w_axi2apb_lite_resp),   // Templated
                     // Outputs
                     .apb_req_o         (w_apb_req),             // Templated
                     // Inputs
                     .clk_i             (i_clk_cpu),             // Templated
                     .rst_ni            (i_rst_n_cpu),           // Templated
                     .apb_resp_i        (w_apb_resp),            // Templated
                     .addr_map_i        (qnsc_s_bus_pkg::P_APB_ADDR_MAP)); // Templated

// ==================================================================
// The bridge's APB master drives this block's one APB port. pprot has no port
// here and is dropped.
// ==================================================================
assign o_bus_apb_m_0_paddr   = w_apb_req[0].paddr[18-1:0];
assign o_bus_apb_m_0_pwdata  = w_apb_req[0].pwdata;
assign o_bus_apb_m_0_pstrb   = w_apb_req[0].pstrb;
assign o_bus_apb_m_0_pwrite  = w_apb_req[0].pwrite;
assign o_bus_apb_m_0_psel    = w_apb_req[0].psel;
assign o_bus_apb_m_0_penable = w_apb_req[0].penable;
assign w_apb_resp[0].pready  = i_bus_apb_m_0_pready;
assign w_apb_resp[0].pslverr = i_bus_apb_m_0_pslverr;
assign w_apb_resp[0].prdata  = i_bus_apb_m_0_prdata;

// ==================================================================
// The AXI4 struct ports join the crossbar's arrays directly.
// ==================================================================
assign w_axi_s_0_req = i_bus_axi_s_0_req;
assign w_axi_s_1_req = i_bus_axi_s_1_req;
assign w_axi_s_2_req = i_bus_axi_s_2_req;
assign o_bus_axi_s_0_resp = w_axi_s_0_resp;
assign o_bus_axi_s_1_resp = w_axi_s_1_resp;
assign o_bus_axi_s_2_resp = w_axi_s_2_resp;

assign o_bus_axi_m_0_req = w_axi_m_0_req;
assign o_bus_axi_m_1_req = w_axi_m_1_req;
assign o_bus_axi_m_2_req = w_axi_m_2_req;
assign w_axi_m_0_resp = i_bus_axi_m_0_resp;
assign w_axi_m_1_resp = i_bus_axi_m_1_resp;
assign w_axi_m_2_resp = i_bus_axi_m_2_resp;

endmodule
`default_nettype wire
// Local Variables:
// verilog-library-flags:("-f filelist_emacs.f")
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: t
// verilog-typedef-regexp: "_t$"
// indent-tabs-mode: nil
// eval: (setq large-file-warning-threshold nil)
// End:
