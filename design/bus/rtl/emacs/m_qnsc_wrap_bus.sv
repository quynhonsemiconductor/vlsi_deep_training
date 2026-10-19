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
//               No packed struct crosses this module's own boundary.
// Spec ref    : doc/specs/QNSC_BUS_MAS.md
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
// Clock/Reset -- S_BUS and P_BUS are each their own hardwired-on domain
// (qnsc_pkg's "sbus"/"pbus" clusters), separate from cpu's, per
// QNSC_SCRC_MAS V3.0 Table 5-2. The AXI2APB bridge is clocked from pbus: it is
// P_BUS's ingress logic (doc/specs/QNSC_BUS_DECISIONS.md).
//---------------------------------------------------------------
/*AUTOINPUT("^i_clk\|^i_rst")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic             i_clk_pbus,             // To u_axi_to_axi_lite of axi_to_axi_lite.v, ...
input logic             i_clk_sbus,             // To u_axi_xbar of axi_xbar.v
input logic             i_rst_n_pbus,           // To u_axi_to_axi_lite of axi_to_axi_lite.v, ...
input logic             i_rst_n_sbus,           // To u_axi_xbar of axi_xbar.v
// End of automatics

//---------------------------------------------------------------
// APB4 -- the AXI2APB bridge's one master port (AXI_M3 after conversion).
// paddr is the offset inside the AXI2APB window: the low
// qnsc_pkg::C_PBUS_PADDR_WIDTH address bits (contract meta.pbus_paddr_width).
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
// Ports emacs cannot derive, written by hand. Keep this group last (the final
// port has no trailing comma). axi_xbar speaks packed structs, which verilog-mode
// does not decompose, so the flat AXI4 ports are listed here and joined to the
// structs by the assigns below. Widths are numbers (module rules, flat ports);
// the elaboration checks below fail if they drift from qnsc_s_bus_pkg.
//   slave ports  : ID 5 bit, from the masters (SYSDBG, CPU, DMA)
//   master ports : ID 7 bit = 5 + clog2(3), axi_xbar widens it, to ROM / ISRAM / DSRAM
//---------------------------------------------------------------
// ---- slave port s_0: SYSDBG (AXI_S0) ----
input  logic [4:0]   i_bus_axi_s_0_aw_id,
input  logic [31:0]  i_bus_axi_s_0_aw_addr,
input  logic [7:0]   i_bus_axi_s_0_aw_len,
input  logic [2:0]   i_bus_axi_s_0_aw_size,
input  logic [1:0]   i_bus_axi_s_0_aw_burst,
input  logic         i_bus_axi_s_0_aw_lock,
input  logic [3:0]   i_bus_axi_s_0_aw_cache,
input  logic [2:0]   i_bus_axi_s_0_aw_prot,
input  logic [3:0]   i_bus_axi_s_0_aw_qos,
input  logic [3:0]   i_bus_axi_s_0_aw_region,
input  logic [5:0]   i_bus_axi_s_0_aw_atop,
input  logic [0:0]   i_bus_axi_s_0_aw_user,
input  logic         i_bus_axi_s_0_aw_valid,
output logic         o_bus_axi_s_0_aw_ready,
input  logic [31:0]  i_bus_axi_s_0_w_data,
input  logic [3:0]   i_bus_axi_s_0_w_strb,
input  logic         i_bus_axi_s_0_w_last,
input  logic [0:0]   i_bus_axi_s_0_w_user,
input  logic         i_bus_axi_s_0_w_valid,
output logic         o_bus_axi_s_0_w_ready,
output logic [4:0]   o_bus_axi_s_0_b_id,
output logic [1:0]   o_bus_axi_s_0_b_resp,
output logic [0:0]   o_bus_axi_s_0_b_user,
output logic         o_bus_axi_s_0_b_valid,
input  logic         i_bus_axi_s_0_b_ready,
input  logic [4:0]   i_bus_axi_s_0_ar_id,
input  logic [31:0]  i_bus_axi_s_0_ar_addr,
input  logic [7:0]   i_bus_axi_s_0_ar_len,
input  logic [2:0]   i_bus_axi_s_0_ar_size,
input  logic [1:0]   i_bus_axi_s_0_ar_burst,
input  logic         i_bus_axi_s_0_ar_lock,
input  logic [3:0]   i_bus_axi_s_0_ar_cache,
input  logic [2:0]   i_bus_axi_s_0_ar_prot,
input  logic [3:0]   i_bus_axi_s_0_ar_qos,
input  logic [3:0]   i_bus_axi_s_0_ar_region,
input  logic [0:0]   i_bus_axi_s_0_ar_user,
input  logic         i_bus_axi_s_0_ar_valid,
output logic         o_bus_axi_s_0_ar_ready,
output logic [4:0]   o_bus_axi_s_0_r_id,
output logic [31:0]  o_bus_axi_s_0_r_data,
output logic [1:0]   o_bus_axi_s_0_r_resp,
output logic         o_bus_axi_s_0_r_last,
output logic [0:0]   o_bus_axi_s_0_r_user,
output logic         o_bus_axi_s_0_r_valid,
input  logic         i_bus_axi_s_0_r_ready,

// ---- slave port s_1: CPU, CPU2AXI bridge (AXI_S1) ----
input  logic [4:0]   i_bus_axi_s_1_aw_id,
input  logic [31:0]  i_bus_axi_s_1_aw_addr,
input  logic [7:0]   i_bus_axi_s_1_aw_len,
input  logic [2:0]   i_bus_axi_s_1_aw_size,
input  logic [1:0]   i_bus_axi_s_1_aw_burst,
input  logic         i_bus_axi_s_1_aw_lock,
input  logic [3:0]   i_bus_axi_s_1_aw_cache,
input  logic [2:0]   i_bus_axi_s_1_aw_prot,
input  logic [3:0]   i_bus_axi_s_1_aw_qos,
input  logic [3:0]   i_bus_axi_s_1_aw_region,
input  logic [5:0]   i_bus_axi_s_1_aw_atop,
input  logic [0:0]   i_bus_axi_s_1_aw_user,
input  logic         i_bus_axi_s_1_aw_valid,
output logic         o_bus_axi_s_1_aw_ready,
input  logic [31:0]  i_bus_axi_s_1_w_data,
input  logic [3:0]   i_bus_axi_s_1_w_strb,
input  logic         i_bus_axi_s_1_w_last,
input  logic [0:0]   i_bus_axi_s_1_w_user,
input  logic         i_bus_axi_s_1_w_valid,
output logic         o_bus_axi_s_1_w_ready,
output logic [4:0]   o_bus_axi_s_1_b_id,
output logic [1:0]   o_bus_axi_s_1_b_resp,
output logic [0:0]   o_bus_axi_s_1_b_user,
output logic         o_bus_axi_s_1_b_valid,
input  logic         i_bus_axi_s_1_b_ready,
input  logic [4:0]   i_bus_axi_s_1_ar_id,
input  logic [31:0]  i_bus_axi_s_1_ar_addr,
input  logic [7:0]   i_bus_axi_s_1_ar_len,
input  logic [2:0]   i_bus_axi_s_1_ar_size,
input  logic [1:0]   i_bus_axi_s_1_ar_burst,
input  logic         i_bus_axi_s_1_ar_lock,
input  logic [3:0]   i_bus_axi_s_1_ar_cache,
input  logic [2:0]   i_bus_axi_s_1_ar_prot,
input  logic [3:0]   i_bus_axi_s_1_ar_qos,
input  logic [3:0]   i_bus_axi_s_1_ar_region,
input  logic [0:0]   i_bus_axi_s_1_ar_user,
input  logic         i_bus_axi_s_1_ar_valid,
output logic         o_bus_axi_s_1_ar_ready,
output logic [4:0]   o_bus_axi_s_1_r_id,
output logic [31:0]  o_bus_axi_s_1_r_data,
output logic [1:0]   o_bus_axi_s_1_r_resp,
output logic         o_bus_axi_s_1_r_last,
output logic [0:0]   o_bus_axi_s_1_r_user,
output logic         o_bus_axi_s_1_r_valid,
input  logic         i_bus_axi_s_1_r_ready,

// ---- slave port s_2: DMA (AXI_S2) ----
input  logic [4:0]   i_bus_axi_s_2_aw_id,
input  logic [31:0]  i_bus_axi_s_2_aw_addr,
input  logic [7:0]   i_bus_axi_s_2_aw_len,
input  logic [2:0]   i_bus_axi_s_2_aw_size,
input  logic [1:0]   i_bus_axi_s_2_aw_burst,
input  logic         i_bus_axi_s_2_aw_lock,
input  logic [3:0]   i_bus_axi_s_2_aw_cache,
input  logic [2:0]   i_bus_axi_s_2_aw_prot,
input  logic [3:0]   i_bus_axi_s_2_aw_qos,
input  logic [3:0]   i_bus_axi_s_2_aw_region,
input  logic [5:0]   i_bus_axi_s_2_aw_atop,
input  logic [0:0]   i_bus_axi_s_2_aw_user,
input  logic         i_bus_axi_s_2_aw_valid,
output logic         o_bus_axi_s_2_aw_ready,
input  logic [31:0]  i_bus_axi_s_2_w_data,
input  logic [3:0]   i_bus_axi_s_2_w_strb,
input  logic         i_bus_axi_s_2_w_last,
input  logic [0:0]   i_bus_axi_s_2_w_user,
input  logic         i_bus_axi_s_2_w_valid,
output logic         o_bus_axi_s_2_w_ready,
output logic [4:0]   o_bus_axi_s_2_b_id,
output logic [1:0]   o_bus_axi_s_2_b_resp,
output logic [0:0]   o_bus_axi_s_2_b_user,
output logic         o_bus_axi_s_2_b_valid,
input  logic         i_bus_axi_s_2_b_ready,
input  logic [4:0]   i_bus_axi_s_2_ar_id,
input  logic [31:0]  i_bus_axi_s_2_ar_addr,
input  logic [7:0]   i_bus_axi_s_2_ar_len,
input  logic [2:0]   i_bus_axi_s_2_ar_size,
input  logic [1:0]   i_bus_axi_s_2_ar_burst,
input  logic         i_bus_axi_s_2_ar_lock,
input  logic [3:0]   i_bus_axi_s_2_ar_cache,
input  logic [2:0]   i_bus_axi_s_2_ar_prot,
input  logic [3:0]   i_bus_axi_s_2_ar_qos,
input  logic [3:0]   i_bus_axi_s_2_ar_region,
input  logic [0:0]   i_bus_axi_s_2_ar_user,
input  logic         i_bus_axi_s_2_ar_valid,
output logic         o_bus_axi_s_2_ar_ready,
output logic [4:0]   o_bus_axi_s_2_r_id,
output logic [31:0]  o_bus_axi_s_2_r_data,
output logic [1:0]   o_bus_axi_s_2_r_resp,
output logic         o_bus_axi_s_2_r_last,
output logic [0:0]   o_bus_axi_s_2_r_user,
output logic         o_bus_axi_s_2_r_valid,
input  logic         i_bus_axi_s_2_r_ready,

// ---- master port m_0: ROM (AXI_M0) ----
output logic [6:0]   o_bus_axi_m_0_aw_id,
output logic [31:0]  o_bus_axi_m_0_aw_addr,
output logic [7:0]   o_bus_axi_m_0_aw_len,
output logic [2:0]   o_bus_axi_m_0_aw_size,
output logic [1:0]   o_bus_axi_m_0_aw_burst,
output logic         o_bus_axi_m_0_aw_lock,
output logic [3:0]   o_bus_axi_m_0_aw_cache,
output logic [2:0]   o_bus_axi_m_0_aw_prot,
output logic [3:0]   o_bus_axi_m_0_aw_qos,
output logic [3:0]   o_bus_axi_m_0_aw_region,
output logic [5:0]   o_bus_axi_m_0_aw_atop,
output logic [0:0]   o_bus_axi_m_0_aw_user,
output logic         o_bus_axi_m_0_aw_valid,
input  logic         i_bus_axi_m_0_aw_ready,
output logic [31:0]  o_bus_axi_m_0_w_data,
output logic [3:0]   o_bus_axi_m_0_w_strb,
output logic         o_bus_axi_m_0_w_last,
output logic [0:0]   o_bus_axi_m_0_w_user,
output logic         o_bus_axi_m_0_w_valid,
input  logic         i_bus_axi_m_0_w_ready,
input  logic [6:0]   i_bus_axi_m_0_b_id,
input  logic [1:0]   i_bus_axi_m_0_b_resp,
input  logic [0:0]   i_bus_axi_m_0_b_user,
input  logic         i_bus_axi_m_0_b_valid,
output logic         o_bus_axi_m_0_b_ready,
output logic [6:0]   o_bus_axi_m_0_ar_id,
output logic [31:0]  o_bus_axi_m_0_ar_addr,
output logic [7:0]   o_bus_axi_m_0_ar_len,
output logic [2:0]   o_bus_axi_m_0_ar_size,
output logic [1:0]   o_bus_axi_m_0_ar_burst,
output logic         o_bus_axi_m_0_ar_lock,
output logic [3:0]   o_bus_axi_m_0_ar_cache,
output logic [2:0]   o_bus_axi_m_0_ar_prot,
output logic [3:0]   o_bus_axi_m_0_ar_qos,
output logic [3:0]   o_bus_axi_m_0_ar_region,
output logic [0:0]   o_bus_axi_m_0_ar_user,
output logic         o_bus_axi_m_0_ar_valid,
input  logic         i_bus_axi_m_0_ar_ready,
input  logic [6:0]   i_bus_axi_m_0_r_id,
input  logic [31:0]  i_bus_axi_m_0_r_data,
input  logic [1:0]   i_bus_axi_m_0_r_resp,
input  logic         i_bus_axi_m_0_r_last,
input  logic [0:0]   i_bus_axi_m_0_r_user,
input  logic         i_bus_axi_m_0_r_valid,
output logic         o_bus_axi_m_0_r_ready,

// ---- master port m_1: ISRAM, debug window and application (AXI_M1) ----
output logic [6:0]   o_bus_axi_m_1_aw_id,
output logic [31:0]  o_bus_axi_m_1_aw_addr,
output logic [7:0]   o_bus_axi_m_1_aw_len,
output logic [2:0]   o_bus_axi_m_1_aw_size,
output logic [1:0]   o_bus_axi_m_1_aw_burst,
output logic         o_bus_axi_m_1_aw_lock,
output logic [3:0]   o_bus_axi_m_1_aw_cache,
output logic [2:0]   o_bus_axi_m_1_aw_prot,
output logic [3:0]   o_bus_axi_m_1_aw_qos,
output logic [3:0]   o_bus_axi_m_1_aw_region,
output logic [5:0]   o_bus_axi_m_1_aw_atop,
output logic [0:0]   o_bus_axi_m_1_aw_user,
output logic         o_bus_axi_m_1_aw_valid,
input  logic         i_bus_axi_m_1_aw_ready,
output logic [31:0]  o_bus_axi_m_1_w_data,
output logic [3:0]   o_bus_axi_m_1_w_strb,
output logic         o_bus_axi_m_1_w_last,
output logic [0:0]   o_bus_axi_m_1_w_user,
output logic         o_bus_axi_m_1_w_valid,
input  logic         i_bus_axi_m_1_w_ready,
input  logic [6:0]   i_bus_axi_m_1_b_id,
input  logic [1:0]   i_bus_axi_m_1_b_resp,
input  logic [0:0]   i_bus_axi_m_1_b_user,
input  logic         i_bus_axi_m_1_b_valid,
output logic         o_bus_axi_m_1_b_ready,
output logic [6:0]   o_bus_axi_m_1_ar_id,
output logic [31:0]  o_bus_axi_m_1_ar_addr,
output logic [7:0]   o_bus_axi_m_1_ar_len,
output logic [2:0]   o_bus_axi_m_1_ar_size,
output logic [1:0]   o_bus_axi_m_1_ar_burst,
output logic         o_bus_axi_m_1_ar_lock,
output logic [3:0]   o_bus_axi_m_1_ar_cache,
output logic [2:0]   o_bus_axi_m_1_ar_prot,
output logic [3:0]   o_bus_axi_m_1_ar_qos,
output logic [3:0]   o_bus_axi_m_1_ar_region,
output logic [0:0]   o_bus_axi_m_1_ar_user,
output logic         o_bus_axi_m_1_ar_valid,
input  logic         i_bus_axi_m_1_ar_ready,
input  logic [6:0]   i_bus_axi_m_1_r_id,
input  logic [31:0]  i_bus_axi_m_1_r_data,
input  logic [1:0]   i_bus_axi_m_1_r_resp,
input  logic         i_bus_axi_m_1_r_last,
input  logic [0:0]   i_bus_axi_m_1_r_user,
input  logic         i_bus_axi_m_1_r_valid,
output logic         o_bus_axi_m_1_r_ready,

// ---- master port m_2: DSRAM (AXI_M2) ----
output logic [6:0]   o_bus_axi_m_2_aw_id,
output logic [31:0]  o_bus_axi_m_2_aw_addr,
output logic [7:0]   o_bus_axi_m_2_aw_len,
output logic [2:0]   o_bus_axi_m_2_aw_size,
output logic [1:0]   o_bus_axi_m_2_aw_burst,
output logic         o_bus_axi_m_2_aw_lock,
output logic [3:0]   o_bus_axi_m_2_aw_cache,
output logic [2:0]   o_bus_axi_m_2_aw_prot,
output logic [3:0]   o_bus_axi_m_2_aw_qos,
output logic [3:0]   o_bus_axi_m_2_aw_region,
output logic [5:0]   o_bus_axi_m_2_aw_atop,
output logic [0:0]   o_bus_axi_m_2_aw_user,
output logic         o_bus_axi_m_2_aw_valid,
input  logic         i_bus_axi_m_2_aw_ready,
output logic [31:0]  o_bus_axi_m_2_w_data,
output logic [3:0]   o_bus_axi_m_2_w_strb,
output logic         o_bus_axi_m_2_w_last,
output logic [0:0]   o_bus_axi_m_2_w_user,
output logic         o_bus_axi_m_2_w_valid,
input  logic         i_bus_axi_m_2_w_ready,
input  logic [6:0]   i_bus_axi_m_2_b_id,
input  logic [1:0]   i_bus_axi_m_2_b_resp,
input  logic [0:0]   i_bus_axi_m_2_b_user,
input  logic         i_bus_axi_m_2_b_valid,
output logic         o_bus_axi_m_2_b_ready,
output logic [6:0]   o_bus_axi_m_2_ar_id,
output logic [31:0]  o_bus_axi_m_2_ar_addr,
output logic [7:0]   o_bus_axi_m_2_ar_len,
output logic [2:0]   o_bus_axi_m_2_ar_size,
output logic [1:0]   o_bus_axi_m_2_ar_burst,
output logic         o_bus_axi_m_2_ar_lock,
output logic [3:0]   o_bus_axi_m_2_ar_cache,
output logic [2:0]   o_bus_axi_m_2_ar_prot,
output logic [3:0]   o_bus_axi_m_2_ar_qos,
output logic [3:0]   o_bus_axi_m_2_ar_region,
output logic [0:0]   o_bus_axi_m_2_ar_user,
output logic         o_bus_axi_m_2_ar_valid,
input  logic         i_bus_axi_m_2_ar_ready,
input  logic [6:0]   i_bus_axi_m_2_r_id,
input  logic [31:0]  i_bus_axi_m_2_r_data,
input  logic [1:0]   i_bus_axi_m_2_r_resp,
input  logic         i_bus_axi_m_2_r_last,
input  logic [0:0]   i_bus_axi_m_2_r_user,
input  logic         i_bus_axi_m_2_r_valid,
output logic         o_bus_axi_m_2_r_ready
);

/*AUTOWIRE*/

// ---- elaboration checks: the numbers above equal the package's ----
if ($bits(i_bus_axi_s_0_aw_id) != qnsc_s_bus_pkg::P_SLV_ID_W) begin : g_chk_slv_id
  $error("slave-port ID width differs from qnsc_s_bus_pkg::P_SLV_ID_W");
end
if ($bits(o_bus_axi_m_0_aw_id) != qnsc_s_bus_pkg::P_MST_ID_W) begin : g_chk_mst_id
  $error("master-port ID width differs from qnsc_s_bus_pkg::P_MST_ID_W");
end
if ($bits(i_bus_axi_s_0_aw_user) != qnsc_s_bus_pkg::P_AXI_USER_W) begin : g_chk_user
  $error("AXI user width differs from qnsc_s_bus_pkg::P_AXI_USER_W");
end
if ($bits(o_bus_apb_m_0_paddr) != qnsc_pkg::C_PBUS_PADDR_WIDTH) begin : g_chk_apb_paddr
  $error("APB paddr width differs from qnsc_pkg::C_PBUS_PADDR_WIDTH");
end
if ($bits(o_bus_apb_m_0_pwdata) != qnsc_pkg::C_DATA_WIDTH) begin : g_chk_apb_data
  $error("APB data width differs from qnsc_pkg::C_DATA_WIDTH");
end

// ---- structs the crossbar and the bridge speak ----
qnsc_s_bus_pkg::slv_req_t  w_axi_s_0_req,  w_axi_s_1_req,  w_axi_s_2_req;
qnsc_s_bus_pkg::slv_resp_t w_axi_s_0_resp, w_axi_s_1_resp, w_axi_s_2_resp;

qnsc_s_bus_pkg::mst_req_t  w_axi_m_0_req,  w_axi_m_1_req,  w_axi_m_2_req;
qnsc_s_bus_pkg::mst_resp_t w_axi_m_0_resp, w_axi_m_1_resp, w_axi_m_2_resp;

qnsc_s_bus_pkg::slv_req_t  [qnsc_s_bus_pkg::P_NO_SLV_PORTS-1:0] w_slv_reqs;
qnsc_s_bus_pkg::slv_resp_t [qnsc_s_bus_pkg::P_NO_SLV_PORTS-1:0] w_slv_resps;
qnsc_s_bus_pkg::mst_req_t  [qnsc_s_bus_pkg::P_NO_MST_PORTS-1:0] w_mst_reqs;
qnsc_s_bus_pkg::mst_resp_t [qnsc_s_bus_pkg::P_NO_MST_PORTS-1:0] w_mst_resps;

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

qnsc_s_bus_pkg::apb_req_t  [qnsc_s_bus_pkg::P_NO_APB_SLAVES-1:0] w_apb_req;
qnsc_s_bus_pkg::apb_resp_t [qnsc_s_bus_pkg::P_NO_APB_SLAVES-1:0] w_apb_resp;

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
    .clk_i                 (i_clk_sbus),
    .rst_ni                (i_rst_n_sbus),
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
  .Connectivity  ('1),    // every slave port reaches every master port
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
              .Cfg                      (Cfg),
              // Outputs
              .slv_resp_t               (),                      // Templated
              .slv_ports_resp_o         (w_slv_resps),           // Templated
              .mst_req_t                (),                      // Templated
              .mst_ports_req_o          (w_mst_reqs),            // Templated
              // Inputs
              .clk_i                    (i_clk_sbus),            // Templated
              .rst_ni                   (i_rst_n_sbus),          // Templated
              .slv_req_t                (),                      // Templated
              .slv_ports_req_i          (w_slv_reqs),            // Templated
              .mst_resp_t               (),                      // Templated
              .mst_ports_resp_i         (w_mst_resps),           // Templated
              .rule_t                   (),                      // Templated
              .addr_map_i               (qnsc_s_bus_pkg::P_ADDR_MAP), // Templated
              .en_default_mst_port_i    ('0),                    // Templated
              .default_mst_port_i       ('0));                   // Templated

// ==================================================================
// AXI2APB: AXI4 (AXI_M3) -> AXI4-Lite -> APB4, on the pbus clock
// ==================================================================
/* axi_to_axi_lite AUTO_TEMPLATE(
    .clk_i      (i_clk_pbus),
    .rst_ni     (i_rst_n_pbus),
    .slv_req_i  (w_mst_reqs[3]),
    .slv_resp_o (w_mst_resps[3]),
    .mst_req_o  (w_axi2apb_lite_req),
    .mst_resp_i (w_axi2apb_lite_resp),
    // verilog-mode reads a struct port's type name as a pin of its own; the flow drops those lines
    .\(.*_t\)               (),
);
*/
axi_to_axi_lite #(
  .AxiAddrWidth    (qnsc_s_bus_pkg::P_AXI_ADDR_W),
  .AxiDataWidth    (qnsc_s_bus_pkg::P_AXI_DATA_W),
  .AxiIdWidth      (qnsc_s_bus_pkg::P_MST_ID_W),
  .AxiUserWidth    (qnsc_s_bus_pkg::P_AXI_USER_W),
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
                     .clk_i             (i_clk_pbus),            // Templated
                     .rst_ni            (i_rst_n_pbus));         // Templated

/* axi_lite_to_apb AUTO_TEMPLATE(
    .clk_i           (i_clk_pbus),
    .rst_ni          (i_rst_n_pbus),
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
  .NoApbSlaves      (qnsc_s_bus_pkg::P_NO_APB_SLAVES),
  .NoRules          (qnsc_s_bus_pkg::P_NO_APB_RULES),
  .AddrWidth        (qnsc_s_bus_pkg::P_AXI_ADDR_W),
  .DataWidth        (qnsc_s_bus_pkg::P_AXI_DATA_W),
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
                     .apb_req_t         (),                      // Templated
                     .apb_req_o         (w_apb_req),             // Templated
                     // Inputs
                     .clk_i             (i_clk_pbus),            // Templated
                     .rst_ni            (i_rst_n_pbus),          // Templated
                     .apb_resp_t        (),                      // Templated
                     .apb_resp_i        (w_apb_resp),            // Templated
                     .rule_t            (),                      // Templated
                     .addr_map_i        (qnsc_s_bus_pkg::P_APB_ADDR_MAP)); // Templated

// ==================================================================
// The bridge's APB master drives this block's one APB port. pprot has no port
// here and is dropped.
// ==================================================================
assign o_bus_apb_m_0_paddr   = w_apb_req[0].paddr[qnsc_pkg::C_PBUS_PADDR_WIDTH-1:0];
assign o_bus_apb_m_0_pwdata  = w_apb_req[0].pwdata;
assign o_bus_apb_m_0_pstrb   = w_apb_req[0].pstrb;
assign o_bus_apb_m_0_pwrite  = w_apb_req[0].pwrite;
assign o_bus_apb_m_0_psel    = w_apb_req[0].psel;
assign o_bus_apb_m_0_penable = w_apb_req[0].penable;
assign w_apb_resp[0].pready  = i_bus_apb_m_0_pready;
assign w_apb_resp[0].pslverr = i_bus_apb_m_0_pslverr;
assign w_apb_resp[0].prdata  = i_bus_apb_m_0_prdata;

// ==================================================================
// Boundary glue: the flat AXI4 ports against the packed structs axi_xbar uses.
// verilog-mode cannot decompose a struct, so this is written, not derived.
// ==================================================================
// ---- slave port s_0 ----
assign w_axi_s_0_req.aw.id              = i_bus_axi_s_0_aw_id;
assign w_axi_s_0_req.aw.addr            = i_bus_axi_s_0_aw_addr;
assign w_axi_s_0_req.aw.len             = i_bus_axi_s_0_aw_len;
assign w_axi_s_0_req.aw.size            = i_bus_axi_s_0_aw_size;
assign w_axi_s_0_req.aw.burst           = i_bus_axi_s_0_aw_burst;
assign w_axi_s_0_req.aw.lock            = i_bus_axi_s_0_aw_lock;
assign w_axi_s_0_req.aw.cache           = i_bus_axi_s_0_aw_cache;
assign w_axi_s_0_req.aw.prot            = i_bus_axi_s_0_aw_prot;
assign w_axi_s_0_req.aw.qos             = i_bus_axi_s_0_aw_qos;
assign w_axi_s_0_req.aw.region          = i_bus_axi_s_0_aw_region;
assign w_axi_s_0_req.aw.atop            = i_bus_axi_s_0_aw_atop;
assign w_axi_s_0_req.aw.user            = i_bus_axi_s_0_aw_user;
assign w_axi_s_0_req.aw_valid           = i_bus_axi_s_0_aw_valid;
assign o_bus_axi_s_0_aw_ready           = w_axi_s_0_resp.aw_ready;

assign w_axi_s_0_req.w.data             = i_bus_axi_s_0_w_data;
assign w_axi_s_0_req.w.strb             = i_bus_axi_s_0_w_strb;
assign w_axi_s_0_req.w.last             = i_bus_axi_s_0_w_last;
assign w_axi_s_0_req.w.user             = i_bus_axi_s_0_w_user;
assign w_axi_s_0_req.w_valid            = i_bus_axi_s_0_w_valid;
assign o_bus_axi_s_0_w_ready            = w_axi_s_0_resp.w_ready;

assign o_bus_axi_s_0_b_id               = w_axi_s_0_resp.b.id;
assign o_bus_axi_s_0_b_resp             = w_axi_s_0_resp.b.resp;
assign o_bus_axi_s_0_b_user             = w_axi_s_0_resp.b.user;
assign o_bus_axi_s_0_b_valid            = w_axi_s_0_resp.b_valid;
assign w_axi_s_0_req.b_ready            = i_bus_axi_s_0_b_ready;

assign w_axi_s_0_req.ar.id              = i_bus_axi_s_0_ar_id;
assign w_axi_s_0_req.ar.addr            = i_bus_axi_s_0_ar_addr;
assign w_axi_s_0_req.ar.len             = i_bus_axi_s_0_ar_len;
assign w_axi_s_0_req.ar.size            = i_bus_axi_s_0_ar_size;
assign w_axi_s_0_req.ar.burst           = i_bus_axi_s_0_ar_burst;
assign w_axi_s_0_req.ar.lock            = i_bus_axi_s_0_ar_lock;
assign w_axi_s_0_req.ar.cache           = i_bus_axi_s_0_ar_cache;
assign w_axi_s_0_req.ar.prot            = i_bus_axi_s_0_ar_prot;
assign w_axi_s_0_req.ar.qos             = i_bus_axi_s_0_ar_qos;
assign w_axi_s_0_req.ar.region          = i_bus_axi_s_0_ar_region;
assign w_axi_s_0_req.ar.user            = i_bus_axi_s_0_ar_user;
assign w_axi_s_0_req.ar_valid           = i_bus_axi_s_0_ar_valid;
assign o_bus_axi_s_0_ar_ready           = w_axi_s_0_resp.ar_ready;

assign o_bus_axi_s_0_r_id               = w_axi_s_0_resp.r.id;
assign o_bus_axi_s_0_r_data             = w_axi_s_0_resp.r.data;
assign o_bus_axi_s_0_r_resp             = w_axi_s_0_resp.r.resp;
assign o_bus_axi_s_0_r_last             = w_axi_s_0_resp.r.last;
assign o_bus_axi_s_0_r_user             = w_axi_s_0_resp.r.user;
assign o_bus_axi_s_0_r_valid            = w_axi_s_0_resp.r_valid;
assign w_axi_s_0_req.r_ready            = i_bus_axi_s_0_r_ready;

// ---- slave port s_1 ----
assign w_axi_s_1_req.aw.id              = i_bus_axi_s_1_aw_id;
assign w_axi_s_1_req.aw.addr            = i_bus_axi_s_1_aw_addr;
assign w_axi_s_1_req.aw.len             = i_bus_axi_s_1_aw_len;
assign w_axi_s_1_req.aw.size            = i_bus_axi_s_1_aw_size;
assign w_axi_s_1_req.aw.burst           = i_bus_axi_s_1_aw_burst;
assign w_axi_s_1_req.aw.lock            = i_bus_axi_s_1_aw_lock;
assign w_axi_s_1_req.aw.cache           = i_bus_axi_s_1_aw_cache;
assign w_axi_s_1_req.aw.prot            = i_bus_axi_s_1_aw_prot;
assign w_axi_s_1_req.aw.qos             = i_bus_axi_s_1_aw_qos;
assign w_axi_s_1_req.aw.region          = i_bus_axi_s_1_aw_region;
assign w_axi_s_1_req.aw.atop            = i_bus_axi_s_1_aw_atop;
assign w_axi_s_1_req.aw.user            = i_bus_axi_s_1_aw_user;
assign w_axi_s_1_req.aw_valid           = i_bus_axi_s_1_aw_valid;
assign o_bus_axi_s_1_aw_ready           = w_axi_s_1_resp.aw_ready;

assign w_axi_s_1_req.w.data             = i_bus_axi_s_1_w_data;
assign w_axi_s_1_req.w.strb             = i_bus_axi_s_1_w_strb;
assign w_axi_s_1_req.w.last             = i_bus_axi_s_1_w_last;
assign w_axi_s_1_req.w.user             = i_bus_axi_s_1_w_user;
assign w_axi_s_1_req.w_valid            = i_bus_axi_s_1_w_valid;
assign o_bus_axi_s_1_w_ready            = w_axi_s_1_resp.w_ready;

assign o_bus_axi_s_1_b_id               = w_axi_s_1_resp.b.id;
assign o_bus_axi_s_1_b_resp             = w_axi_s_1_resp.b.resp;
assign o_bus_axi_s_1_b_user             = w_axi_s_1_resp.b.user;
assign o_bus_axi_s_1_b_valid            = w_axi_s_1_resp.b_valid;
assign w_axi_s_1_req.b_ready            = i_bus_axi_s_1_b_ready;

assign w_axi_s_1_req.ar.id              = i_bus_axi_s_1_ar_id;
assign w_axi_s_1_req.ar.addr            = i_bus_axi_s_1_ar_addr;
assign w_axi_s_1_req.ar.len             = i_bus_axi_s_1_ar_len;
assign w_axi_s_1_req.ar.size            = i_bus_axi_s_1_ar_size;
assign w_axi_s_1_req.ar.burst           = i_bus_axi_s_1_ar_burst;
assign w_axi_s_1_req.ar.lock            = i_bus_axi_s_1_ar_lock;
assign w_axi_s_1_req.ar.cache           = i_bus_axi_s_1_ar_cache;
assign w_axi_s_1_req.ar.prot            = i_bus_axi_s_1_ar_prot;
assign w_axi_s_1_req.ar.qos             = i_bus_axi_s_1_ar_qos;
assign w_axi_s_1_req.ar.region          = i_bus_axi_s_1_ar_region;
assign w_axi_s_1_req.ar.user            = i_bus_axi_s_1_ar_user;
assign w_axi_s_1_req.ar_valid           = i_bus_axi_s_1_ar_valid;
assign o_bus_axi_s_1_ar_ready           = w_axi_s_1_resp.ar_ready;

assign o_bus_axi_s_1_r_id               = w_axi_s_1_resp.r.id;
assign o_bus_axi_s_1_r_data             = w_axi_s_1_resp.r.data;
assign o_bus_axi_s_1_r_resp             = w_axi_s_1_resp.r.resp;
assign o_bus_axi_s_1_r_last             = w_axi_s_1_resp.r.last;
assign o_bus_axi_s_1_r_user             = w_axi_s_1_resp.r.user;
assign o_bus_axi_s_1_r_valid            = w_axi_s_1_resp.r_valid;
assign w_axi_s_1_req.r_ready            = i_bus_axi_s_1_r_ready;

// ---- slave port s_2 ----
assign w_axi_s_2_req.aw.id              = i_bus_axi_s_2_aw_id;
assign w_axi_s_2_req.aw.addr            = i_bus_axi_s_2_aw_addr;
assign w_axi_s_2_req.aw.len             = i_bus_axi_s_2_aw_len;
assign w_axi_s_2_req.aw.size            = i_bus_axi_s_2_aw_size;
assign w_axi_s_2_req.aw.burst           = i_bus_axi_s_2_aw_burst;
assign w_axi_s_2_req.aw.lock            = i_bus_axi_s_2_aw_lock;
assign w_axi_s_2_req.aw.cache           = i_bus_axi_s_2_aw_cache;
assign w_axi_s_2_req.aw.prot            = i_bus_axi_s_2_aw_prot;
assign w_axi_s_2_req.aw.qos             = i_bus_axi_s_2_aw_qos;
assign w_axi_s_2_req.aw.region          = i_bus_axi_s_2_aw_region;
assign w_axi_s_2_req.aw.atop            = i_bus_axi_s_2_aw_atop;
assign w_axi_s_2_req.aw.user            = i_bus_axi_s_2_aw_user;
assign w_axi_s_2_req.aw_valid           = i_bus_axi_s_2_aw_valid;
assign o_bus_axi_s_2_aw_ready           = w_axi_s_2_resp.aw_ready;

assign w_axi_s_2_req.w.data             = i_bus_axi_s_2_w_data;
assign w_axi_s_2_req.w.strb             = i_bus_axi_s_2_w_strb;
assign w_axi_s_2_req.w.last             = i_bus_axi_s_2_w_last;
assign w_axi_s_2_req.w.user             = i_bus_axi_s_2_w_user;
assign w_axi_s_2_req.w_valid            = i_bus_axi_s_2_w_valid;
assign o_bus_axi_s_2_w_ready            = w_axi_s_2_resp.w_ready;

assign o_bus_axi_s_2_b_id               = w_axi_s_2_resp.b.id;
assign o_bus_axi_s_2_b_resp             = w_axi_s_2_resp.b.resp;
assign o_bus_axi_s_2_b_user             = w_axi_s_2_resp.b.user;
assign o_bus_axi_s_2_b_valid            = w_axi_s_2_resp.b_valid;
assign w_axi_s_2_req.b_ready            = i_bus_axi_s_2_b_ready;

assign w_axi_s_2_req.ar.id              = i_bus_axi_s_2_ar_id;
assign w_axi_s_2_req.ar.addr            = i_bus_axi_s_2_ar_addr;
assign w_axi_s_2_req.ar.len             = i_bus_axi_s_2_ar_len;
assign w_axi_s_2_req.ar.size            = i_bus_axi_s_2_ar_size;
assign w_axi_s_2_req.ar.burst           = i_bus_axi_s_2_ar_burst;
assign w_axi_s_2_req.ar.lock            = i_bus_axi_s_2_ar_lock;
assign w_axi_s_2_req.ar.cache           = i_bus_axi_s_2_ar_cache;
assign w_axi_s_2_req.ar.prot            = i_bus_axi_s_2_ar_prot;
assign w_axi_s_2_req.ar.qos             = i_bus_axi_s_2_ar_qos;
assign w_axi_s_2_req.ar.region          = i_bus_axi_s_2_ar_region;
assign w_axi_s_2_req.ar.user            = i_bus_axi_s_2_ar_user;
assign w_axi_s_2_req.ar_valid           = i_bus_axi_s_2_ar_valid;
assign o_bus_axi_s_2_ar_ready           = w_axi_s_2_resp.ar_ready;

assign o_bus_axi_s_2_r_id               = w_axi_s_2_resp.r.id;
assign o_bus_axi_s_2_r_data             = w_axi_s_2_resp.r.data;
assign o_bus_axi_s_2_r_resp             = w_axi_s_2_resp.r.resp;
assign o_bus_axi_s_2_r_last             = w_axi_s_2_resp.r.last;
assign o_bus_axi_s_2_r_user             = w_axi_s_2_resp.r.user;
assign o_bus_axi_s_2_r_valid            = w_axi_s_2_resp.r_valid;
assign w_axi_s_2_req.r_ready            = i_bus_axi_s_2_r_ready;

// ---- master port m_0 ----
assign o_bus_axi_m_0_aw_id              = w_axi_m_0_req.aw.id;
assign o_bus_axi_m_0_aw_addr            = w_axi_m_0_req.aw.addr;
assign o_bus_axi_m_0_aw_len             = w_axi_m_0_req.aw.len;
assign o_bus_axi_m_0_aw_size            = w_axi_m_0_req.aw.size;
assign o_bus_axi_m_0_aw_burst           = w_axi_m_0_req.aw.burst;
assign o_bus_axi_m_0_aw_lock            = w_axi_m_0_req.aw.lock;
assign o_bus_axi_m_0_aw_cache           = w_axi_m_0_req.aw.cache;
assign o_bus_axi_m_0_aw_prot            = w_axi_m_0_req.aw.prot;
assign o_bus_axi_m_0_aw_qos             = w_axi_m_0_req.aw.qos;
assign o_bus_axi_m_0_aw_region          = w_axi_m_0_req.aw.region;
assign o_bus_axi_m_0_aw_atop            = w_axi_m_0_req.aw.atop;
assign o_bus_axi_m_0_aw_user            = w_axi_m_0_req.aw.user;
assign o_bus_axi_m_0_aw_valid           = w_axi_m_0_req.aw_valid;
assign w_axi_m_0_resp.aw_ready          = i_bus_axi_m_0_aw_ready;

assign o_bus_axi_m_0_w_data             = w_axi_m_0_req.w.data;
assign o_bus_axi_m_0_w_strb             = w_axi_m_0_req.w.strb;
assign o_bus_axi_m_0_w_last             = w_axi_m_0_req.w.last;
assign o_bus_axi_m_0_w_user             = w_axi_m_0_req.w.user;
assign o_bus_axi_m_0_w_valid            = w_axi_m_0_req.w_valid;
assign w_axi_m_0_resp.w_ready           = i_bus_axi_m_0_w_ready;

assign w_axi_m_0_resp.b.id              = i_bus_axi_m_0_b_id;
assign w_axi_m_0_resp.b.resp            = i_bus_axi_m_0_b_resp;
assign w_axi_m_0_resp.b.user            = i_bus_axi_m_0_b_user;
assign w_axi_m_0_resp.b_valid           = i_bus_axi_m_0_b_valid;
assign o_bus_axi_m_0_b_ready            = w_axi_m_0_req.b_ready;

assign o_bus_axi_m_0_ar_id              = w_axi_m_0_req.ar.id;
assign o_bus_axi_m_0_ar_addr            = w_axi_m_0_req.ar.addr;
assign o_bus_axi_m_0_ar_len             = w_axi_m_0_req.ar.len;
assign o_bus_axi_m_0_ar_size            = w_axi_m_0_req.ar.size;
assign o_bus_axi_m_0_ar_burst           = w_axi_m_0_req.ar.burst;
assign o_bus_axi_m_0_ar_lock            = w_axi_m_0_req.ar.lock;
assign o_bus_axi_m_0_ar_cache           = w_axi_m_0_req.ar.cache;
assign o_bus_axi_m_0_ar_prot            = w_axi_m_0_req.ar.prot;
assign o_bus_axi_m_0_ar_qos             = w_axi_m_0_req.ar.qos;
assign o_bus_axi_m_0_ar_region          = w_axi_m_0_req.ar.region;
assign o_bus_axi_m_0_ar_user            = w_axi_m_0_req.ar.user;
assign o_bus_axi_m_0_ar_valid           = w_axi_m_0_req.ar_valid;
assign w_axi_m_0_resp.ar_ready          = i_bus_axi_m_0_ar_ready;

assign w_axi_m_0_resp.r.id              = i_bus_axi_m_0_r_id;
assign w_axi_m_0_resp.r.data            = i_bus_axi_m_0_r_data;
assign w_axi_m_0_resp.r.resp            = i_bus_axi_m_0_r_resp;
assign w_axi_m_0_resp.r.last            = i_bus_axi_m_0_r_last;
assign w_axi_m_0_resp.r.user            = i_bus_axi_m_0_r_user;
assign w_axi_m_0_resp.r_valid           = i_bus_axi_m_0_r_valid;
assign o_bus_axi_m_0_r_ready            = w_axi_m_0_req.r_ready;

// ---- master port m_1 ----
assign o_bus_axi_m_1_aw_id              = w_axi_m_1_req.aw.id;
assign o_bus_axi_m_1_aw_addr            = w_axi_m_1_req.aw.addr;
assign o_bus_axi_m_1_aw_len             = w_axi_m_1_req.aw.len;
assign o_bus_axi_m_1_aw_size            = w_axi_m_1_req.aw.size;
assign o_bus_axi_m_1_aw_burst           = w_axi_m_1_req.aw.burst;
assign o_bus_axi_m_1_aw_lock            = w_axi_m_1_req.aw.lock;
assign o_bus_axi_m_1_aw_cache           = w_axi_m_1_req.aw.cache;
assign o_bus_axi_m_1_aw_prot            = w_axi_m_1_req.aw.prot;
assign o_bus_axi_m_1_aw_qos             = w_axi_m_1_req.aw.qos;
assign o_bus_axi_m_1_aw_region          = w_axi_m_1_req.aw.region;
assign o_bus_axi_m_1_aw_atop            = w_axi_m_1_req.aw.atop;
assign o_bus_axi_m_1_aw_user            = w_axi_m_1_req.aw.user;
assign o_bus_axi_m_1_aw_valid           = w_axi_m_1_req.aw_valid;
assign w_axi_m_1_resp.aw_ready          = i_bus_axi_m_1_aw_ready;

assign o_bus_axi_m_1_w_data             = w_axi_m_1_req.w.data;
assign o_bus_axi_m_1_w_strb             = w_axi_m_1_req.w.strb;
assign o_bus_axi_m_1_w_last             = w_axi_m_1_req.w.last;
assign o_bus_axi_m_1_w_user             = w_axi_m_1_req.w.user;
assign o_bus_axi_m_1_w_valid            = w_axi_m_1_req.w_valid;
assign w_axi_m_1_resp.w_ready           = i_bus_axi_m_1_w_ready;

assign w_axi_m_1_resp.b.id              = i_bus_axi_m_1_b_id;
assign w_axi_m_1_resp.b.resp            = i_bus_axi_m_1_b_resp;
assign w_axi_m_1_resp.b.user            = i_bus_axi_m_1_b_user;
assign w_axi_m_1_resp.b_valid           = i_bus_axi_m_1_b_valid;
assign o_bus_axi_m_1_b_ready            = w_axi_m_1_req.b_ready;

assign o_bus_axi_m_1_ar_id              = w_axi_m_1_req.ar.id;
assign o_bus_axi_m_1_ar_addr            = w_axi_m_1_req.ar.addr;
assign o_bus_axi_m_1_ar_len             = w_axi_m_1_req.ar.len;
assign o_bus_axi_m_1_ar_size            = w_axi_m_1_req.ar.size;
assign o_bus_axi_m_1_ar_burst           = w_axi_m_1_req.ar.burst;
assign o_bus_axi_m_1_ar_lock            = w_axi_m_1_req.ar.lock;
assign o_bus_axi_m_1_ar_cache           = w_axi_m_1_req.ar.cache;
assign o_bus_axi_m_1_ar_prot            = w_axi_m_1_req.ar.prot;
assign o_bus_axi_m_1_ar_qos             = w_axi_m_1_req.ar.qos;
assign o_bus_axi_m_1_ar_region          = w_axi_m_1_req.ar.region;
assign o_bus_axi_m_1_ar_user            = w_axi_m_1_req.ar.user;
assign o_bus_axi_m_1_ar_valid           = w_axi_m_1_req.ar_valid;
assign w_axi_m_1_resp.ar_ready          = i_bus_axi_m_1_ar_ready;

assign w_axi_m_1_resp.r.id              = i_bus_axi_m_1_r_id;
assign w_axi_m_1_resp.r.data            = i_bus_axi_m_1_r_data;
assign w_axi_m_1_resp.r.resp            = i_bus_axi_m_1_r_resp;
assign w_axi_m_1_resp.r.last            = i_bus_axi_m_1_r_last;
assign w_axi_m_1_resp.r.user            = i_bus_axi_m_1_r_user;
assign w_axi_m_1_resp.r_valid           = i_bus_axi_m_1_r_valid;
assign o_bus_axi_m_1_r_ready            = w_axi_m_1_req.r_ready;

// ---- master port m_2 ----
assign o_bus_axi_m_2_aw_id              = w_axi_m_2_req.aw.id;
assign o_bus_axi_m_2_aw_addr            = w_axi_m_2_req.aw.addr;
assign o_bus_axi_m_2_aw_len             = w_axi_m_2_req.aw.len;
assign o_bus_axi_m_2_aw_size            = w_axi_m_2_req.aw.size;
assign o_bus_axi_m_2_aw_burst           = w_axi_m_2_req.aw.burst;
assign o_bus_axi_m_2_aw_lock            = w_axi_m_2_req.aw.lock;
assign o_bus_axi_m_2_aw_cache           = w_axi_m_2_req.aw.cache;
assign o_bus_axi_m_2_aw_prot            = w_axi_m_2_req.aw.prot;
assign o_bus_axi_m_2_aw_qos             = w_axi_m_2_req.aw.qos;
assign o_bus_axi_m_2_aw_region          = w_axi_m_2_req.aw.region;
assign o_bus_axi_m_2_aw_atop            = w_axi_m_2_req.aw.atop;
assign o_bus_axi_m_2_aw_user            = w_axi_m_2_req.aw.user;
assign o_bus_axi_m_2_aw_valid           = w_axi_m_2_req.aw_valid;
assign w_axi_m_2_resp.aw_ready          = i_bus_axi_m_2_aw_ready;

assign o_bus_axi_m_2_w_data             = w_axi_m_2_req.w.data;
assign o_bus_axi_m_2_w_strb             = w_axi_m_2_req.w.strb;
assign o_bus_axi_m_2_w_last             = w_axi_m_2_req.w.last;
assign o_bus_axi_m_2_w_user             = w_axi_m_2_req.w.user;
assign o_bus_axi_m_2_w_valid            = w_axi_m_2_req.w_valid;
assign w_axi_m_2_resp.w_ready           = i_bus_axi_m_2_w_ready;

assign w_axi_m_2_resp.b.id              = i_bus_axi_m_2_b_id;
assign w_axi_m_2_resp.b.resp            = i_bus_axi_m_2_b_resp;
assign w_axi_m_2_resp.b.user            = i_bus_axi_m_2_b_user;
assign w_axi_m_2_resp.b_valid           = i_bus_axi_m_2_b_valid;
assign o_bus_axi_m_2_b_ready            = w_axi_m_2_req.b_ready;

assign o_bus_axi_m_2_ar_id              = w_axi_m_2_req.ar.id;
assign o_bus_axi_m_2_ar_addr            = w_axi_m_2_req.ar.addr;
assign o_bus_axi_m_2_ar_len             = w_axi_m_2_req.ar.len;
assign o_bus_axi_m_2_ar_size            = w_axi_m_2_req.ar.size;
assign o_bus_axi_m_2_ar_burst           = w_axi_m_2_req.ar.burst;
assign o_bus_axi_m_2_ar_lock            = w_axi_m_2_req.ar.lock;
assign o_bus_axi_m_2_ar_cache           = w_axi_m_2_req.ar.cache;
assign o_bus_axi_m_2_ar_prot            = w_axi_m_2_req.ar.prot;
assign o_bus_axi_m_2_ar_qos             = w_axi_m_2_req.ar.qos;
assign o_bus_axi_m_2_ar_region          = w_axi_m_2_req.ar.region;
assign o_bus_axi_m_2_ar_user            = w_axi_m_2_req.ar.user;
assign o_bus_axi_m_2_ar_valid           = w_axi_m_2_req.ar_valid;
assign w_axi_m_2_resp.ar_ready          = i_bus_axi_m_2_ar_ready;

assign w_axi_m_2_resp.r.id              = i_bus_axi_m_2_r_id;
assign w_axi_m_2_resp.r.data            = i_bus_axi_m_2_r_data;
assign w_axi_m_2_resp.r.resp            = i_bus_axi_m_2_r_resp;
assign w_axi_m_2_resp.r.last            = i_bus_axi_m_2_r_last;
assign w_axi_m_2_resp.r.user            = i_bus_axi_m_2_r_user;
assign w_axi_m_2_resp.r_valid           = i_bus_axi_m_2_r_valid;
assign o_bus_axi_m_2_r_ready            = w_axi_m_2_req.r_ready;

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
