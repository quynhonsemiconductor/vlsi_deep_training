`default_nettype none
`timescale 1ns/1ps
//==============================================================================
// Module      : m_qnsc_wrap_bus
// Description : S_BUS -- the AXI4 crossbar (axi_xbar) plus the AXI2APB bridge
//               (axi_to_axi_lite + axi_lite_to_apb) toward P_BUS. Three
//               masters issue transactions here (SYSDBG on AXI_S0, CPU on
//               AXI_S1, DMA on AXI_S2); four destinations answer them (ROM
//               AXI_M0, ISRAM AXI_M1, DSRAM AXI_M2, AXI2APB AXI_M3 toward
//               P_BUS's 14 peripherals). No packed structs cross this
//               module's own boundary, per the naming rule.
// Spec ref    : doc/specs/QNSC_BUS_MAS.md
//==============================================================================
module m_qnsc_wrap_bus
  import qnsc_pkg::*;
  import s_bus_pkg::*;
#(
)
(
//---------------------------------------------------------------
// Clock/Reset -- shared with cpu and sysdbg (qnsc_pkg's own "cpu"
// clock cluster: hardwired on, never gated).
//---------------------------------------------------------------
input  logic i_clk_cpu,
input  logic i_rst_n_cpu,

//---------------------------------------------------------------
// AXI4 slave ports -- masters issuing transactions on S_BUS.
//---------------------------------------------------------------
// ==== SLAVE PORT s_0 (debug/SYSDBG) ====
input  logic [P_SLV_ID_W-1:0] i_axi_s_0_aw_id,
input  logic [31:0] i_axi_s_0_aw_addr,
input  logic [7:0] i_axi_s_0_aw_len,
input  logic [2:0] i_axi_s_0_aw_size,
input  logic [1:0] i_axi_s_0_aw_burst,
input  logic  i_axi_s_0_aw_lock,
input  logic [3:0] i_axi_s_0_aw_cache,
input  logic [2:0] i_axi_s_0_aw_prot,
input  logic [3:0] i_axi_s_0_aw_qos,
input  logic [3:0] i_axi_s_0_aw_region,
input  logic [5:0] i_axi_s_0_aw_atop,
input  logic [P_AXI_USER_W-1:0] i_axi_s_0_aw_user,
input  logic  i_axi_s_0_aw_valid,
output logic  o_axi_s_0_aw_ready,
input  logic [31:0] i_axi_s_0_w_data,
input  logic [3:0] i_axi_s_0_w_strb,
input  logic  i_axi_s_0_w_last,
input  logic [P_AXI_USER_W-1:0] i_axi_s_0_w_user,
input  logic  i_axi_s_0_w_valid,
output logic  o_axi_s_0_w_ready,
output logic [P_SLV_ID_W-1:0] o_axi_s_0_b_id,
output logic [1:0] o_axi_s_0_b_resp,
output logic [P_AXI_USER_W-1:0] o_axi_s_0_b_user,
output logic  o_axi_s_0_b_valid,
input  logic  i_axi_s_0_b_ready,
input  logic [P_SLV_ID_W-1:0] i_axi_s_0_ar_id,
input  logic [31:0] i_axi_s_0_ar_addr,
input  logic [7:0] i_axi_s_0_ar_len,
input  logic [2:0] i_axi_s_0_ar_size,
input  logic [1:0] i_axi_s_0_ar_burst,
input  logic  i_axi_s_0_ar_lock,
input  logic [3:0] i_axi_s_0_ar_cache,
input  logic [2:0] i_axi_s_0_ar_prot,
input  logic [3:0] i_axi_s_0_ar_qos,
input  logic [3:0] i_axi_s_0_ar_region,
input  logic [P_AXI_USER_W-1:0] i_axi_s_0_ar_user,
input  logic  i_axi_s_0_ar_valid,
output logic  o_axi_s_0_ar_ready,
output logic [P_SLV_ID_W-1:0] o_axi_s_0_r_id,
output logic [31:0] o_axi_s_0_r_data,
output logic [1:0] o_axi_s_0_r_resp,
output logic  o_axi_s_0_r_last,
output logic [P_AXI_USER_W-1:0] o_axi_s_0_r_user,
output logic  o_axi_s_0_r_valid,
input  logic  i_axi_s_0_r_ready,

// ==== SLAVE PORT s_1 (cpu) ====
input  logic [P_SLV_ID_W-1:0] i_axi_s_1_aw_id,
input  logic [31:0] i_axi_s_1_aw_addr,
input  logic [7:0] i_axi_s_1_aw_len,
input  logic [2:0] i_axi_s_1_aw_size,
input  logic [1:0] i_axi_s_1_aw_burst,
input  logic  i_axi_s_1_aw_lock,
input  logic [3:0] i_axi_s_1_aw_cache,
input  logic [2:0] i_axi_s_1_aw_prot,
input  logic [3:0] i_axi_s_1_aw_qos,
input  logic [3:0] i_axi_s_1_aw_region,
input  logic [5:0] i_axi_s_1_aw_atop,
input  logic [P_AXI_USER_W-1:0] i_axi_s_1_aw_user,
input  logic  i_axi_s_1_aw_valid,
output logic  o_axi_s_1_aw_ready,
input  logic [31:0] i_axi_s_1_w_data,
input  logic [3:0] i_axi_s_1_w_strb,
input  logic  i_axi_s_1_w_last,
input  logic [P_AXI_USER_W-1:0] i_axi_s_1_w_user,
input  logic  i_axi_s_1_w_valid,
output logic  o_axi_s_1_w_ready,
output logic [P_SLV_ID_W-1:0] o_axi_s_1_b_id,
output logic [1:0] o_axi_s_1_b_resp,
output logic [P_AXI_USER_W-1:0] o_axi_s_1_b_user,
output logic  o_axi_s_1_b_valid,
input  logic  i_axi_s_1_b_ready,
input  logic [P_SLV_ID_W-1:0] i_axi_s_1_ar_id,
input  logic [31:0] i_axi_s_1_ar_addr,
input  logic [7:0] i_axi_s_1_ar_len,
input  logic [2:0] i_axi_s_1_ar_size,
input  logic [1:0] i_axi_s_1_ar_burst,
input  logic  i_axi_s_1_ar_lock,
input  logic [3:0] i_axi_s_1_ar_cache,
input  logic [2:0] i_axi_s_1_ar_prot,
input  logic [3:0] i_axi_s_1_ar_qos,
input  logic [3:0] i_axi_s_1_ar_region,
input  logic [P_AXI_USER_W-1:0] i_axi_s_1_ar_user,
input  logic  i_axi_s_1_ar_valid,
output logic  o_axi_s_1_ar_ready,
output logic [P_SLV_ID_W-1:0] o_axi_s_1_r_id,
output logic [31:0] o_axi_s_1_r_data,
output logic [1:0] o_axi_s_1_r_resp,
output logic  o_axi_s_1_r_last,
output logic [P_AXI_USER_W-1:0] o_axi_s_1_r_user,
output logic  o_axi_s_1_r_valid,
input  logic  i_axi_s_1_r_ready,

// ==== SLAVE PORT s_2 (dma) ====
input  logic [P_SLV_ID_W-1:0] i_axi_s_2_aw_id,
input  logic [31:0] i_axi_s_2_aw_addr,
input  logic [7:0] i_axi_s_2_aw_len,
input  logic [2:0] i_axi_s_2_aw_size,
input  logic [1:0] i_axi_s_2_aw_burst,
input  logic  i_axi_s_2_aw_lock,
input  logic [3:0] i_axi_s_2_aw_cache,
input  logic [2:0] i_axi_s_2_aw_prot,
input  logic [3:0] i_axi_s_2_aw_qos,
input  logic [3:0] i_axi_s_2_aw_region,
input  logic [5:0] i_axi_s_2_aw_atop,
input  logic [P_AXI_USER_W-1:0] i_axi_s_2_aw_user,
input  logic  i_axi_s_2_aw_valid,
output logic  o_axi_s_2_aw_ready,
input  logic [31:0] i_axi_s_2_w_data,
input  logic [3:0] i_axi_s_2_w_strb,
input  logic  i_axi_s_2_w_last,
input  logic [P_AXI_USER_W-1:0] i_axi_s_2_w_user,
input  logic  i_axi_s_2_w_valid,
output logic  o_axi_s_2_w_ready,
output logic [P_SLV_ID_W-1:0] o_axi_s_2_b_id,
output logic [1:0] o_axi_s_2_b_resp,
output logic [P_AXI_USER_W-1:0] o_axi_s_2_b_user,
output logic  o_axi_s_2_b_valid,
input  logic  i_axi_s_2_b_ready,
input  logic [P_SLV_ID_W-1:0] i_axi_s_2_ar_id,
input  logic [31:0] i_axi_s_2_ar_addr,
input  logic [7:0] i_axi_s_2_ar_len,
input  logic [2:0] i_axi_s_2_ar_size,
input  logic [1:0] i_axi_s_2_ar_burst,
input  logic  i_axi_s_2_ar_lock,
input  logic [3:0] i_axi_s_2_ar_cache,
input  logic [2:0] i_axi_s_2_ar_prot,
input  logic [3:0] i_axi_s_2_ar_qos,
input  logic [3:0] i_axi_s_2_ar_region,
input  logic [P_AXI_USER_W-1:0] i_axi_s_2_ar_user,
input  logic  i_axi_s_2_ar_valid,
output logic  o_axi_s_2_ar_ready,
output logic [P_SLV_ID_W-1:0] o_axi_s_2_r_id,
output logic [31:0] o_axi_s_2_r_data,
output logic [1:0] o_axi_s_2_r_resp,
output logic  o_axi_s_2_r_last,
output logic [P_AXI_USER_W-1:0] o_axi_s_2_r_user,
output logic  o_axi_s_2_r_valid,
input  logic  i_axi_s_2_r_ready,

// ==== MASTER PORT m_0 (rom) ====
output logic [P_MST_ID_W-1:0] o_axi_m_0_aw_id,
output logic [31:0] o_axi_m_0_aw_addr,
output logic [7:0] o_axi_m_0_aw_len,
output logic [2:0] o_axi_m_0_aw_size,
output logic [1:0] o_axi_m_0_aw_burst,
output logic  o_axi_m_0_aw_lock,
output logic [3:0] o_axi_m_0_aw_cache,
output logic [2:0] o_axi_m_0_aw_prot,
output logic [3:0] o_axi_m_0_aw_qos,
output logic [3:0] o_axi_m_0_aw_region,
output logic [5:0] o_axi_m_0_aw_atop,
output logic [P_AXI_USER_W-1:0] o_axi_m_0_aw_user,
output logic  o_axi_m_0_aw_valid,
input  logic  i_axi_m_0_aw_ready,
output logic [31:0] o_axi_m_0_w_data,
output logic [3:0] o_axi_m_0_w_strb,
output logic  o_axi_m_0_w_last,
output logic [P_AXI_USER_W-1:0] o_axi_m_0_w_user,
output logic  o_axi_m_0_w_valid,
input  logic  i_axi_m_0_w_ready,
input  logic [P_MST_ID_W-1:0] i_axi_m_0_b_id,
input  logic [1:0] i_axi_m_0_b_resp,
input  logic [P_AXI_USER_W-1:0] i_axi_m_0_b_user,
input  logic  i_axi_m_0_b_valid,
output logic  o_axi_m_0_b_ready,
output logic [P_MST_ID_W-1:0] o_axi_m_0_ar_id,
output logic [31:0] o_axi_m_0_ar_addr,
output logic [7:0] o_axi_m_0_ar_len,
output logic [2:0] o_axi_m_0_ar_size,
output logic [1:0] o_axi_m_0_ar_burst,
output logic  o_axi_m_0_ar_lock,
output logic [3:0] o_axi_m_0_ar_cache,
output logic [2:0] o_axi_m_0_ar_prot,
output logic [3:0] o_axi_m_0_ar_qos,
output logic [3:0] o_axi_m_0_ar_region,
output logic [P_AXI_USER_W-1:0] o_axi_m_0_ar_user,
output logic  o_axi_m_0_ar_valid,
input  logic  i_axi_m_0_ar_ready,
input  logic [P_MST_ID_W-1:0] i_axi_m_0_r_id,
input  logic [31:0] i_axi_m_0_r_data,
input  logic [1:0] i_axi_m_0_r_resp,
input  logic  i_axi_m_0_r_last,
input  logic [P_AXI_USER_W-1:0] i_axi_m_0_r_user,
input  logic  i_axi_m_0_r_valid,
output logic  o_axi_m_0_r_ready,

// ==== MASTER PORT m_1 (isram) ====
output logic [P_MST_ID_W-1:0] o_axi_m_1_aw_id,
output logic [31:0] o_axi_m_1_aw_addr,
output logic [7:0] o_axi_m_1_aw_len,
output logic [2:0] o_axi_m_1_aw_size,
output logic [1:0] o_axi_m_1_aw_burst,
output logic  o_axi_m_1_aw_lock,
output logic [3:0] o_axi_m_1_aw_cache,
output logic [2:0] o_axi_m_1_aw_prot,
output logic [3:0] o_axi_m_1_aw_qos,
output logic [3:0] o_axi_m_1_aw_region,
output logic [5:0] o_axi_m_1_aw_atop,
output logic [P_AXI_USER_W-1:0] o_axi_m_1_aw_user,
output logic  o_axi_m_1_aw_valid,
input  logic  i_axi_m_1_aw_ready,
output logic [31:0] o_axi_m_1_w_data,
output logic [3:0] o_axi_m_1_w_strb,
output logic  o_axi_m_1_w_last,
output logic [P_AXI_USER_W-1:0] o_axi_m_1_w_user,
output logic  o_axi_m_1_w_valid,
input  logic  i_axi_m_1_w_ready,
input  logic [P_MST_ID_W-1:0] i_axi_m_1_b_id,
input  logic [1:0] i_axi_m_1_b_resp,
input  logic [P_AXI_USER_W-1:0] i_axi_m_1_b_user,
input  logic  i_axi_m_1_b_valid,
output logic  o_axi_m_1_b_ready,
output logic [P_MST_ID_W-1:0] o_axi_m_1_ar_id,
output logic [31:0] o_axi_m_1_ar_addr,
output logic [7:0] o_axi_m_1_ar_len,
output logic [2:0] o_axi_m_1_ar_size,
output logic [1:0] o_axi_m_1_ar_burst,
output logic  o_axi_m_1_ar_lock,
output logic [3:0] o_axi_m_1_ar_cache,
output logic [2:0] o_axi_m_1_ar_prot,
output logic [3:0] o_axi_m_1_ar_qos,
output logic [3:0] o_axi_m_1_ar_region,
output logic [P_AXI_USER_W-1:0] o_axi_m_1_ar_user,
output logic  o_axi_m_1_ar_valid,
input  logic  i_axi_m_1_ar_ready,
input  logic [P_MST_ID_W-1:0] i_axi_m_1_r_id,
input  logic [31:0] i_axi_m_1_r_data,
input  logic [1:0] i_axi_m_1_r_resp,
input  logic  i_axi_m_1_r_last,
input  logic [P_AXI_USER_W-1:0] i_axi_m_1_r_user,
input  logic  i_axi_m_1_r_valid,
output logic  o_axi_m_1_r_ready,

// ==== MASTER PORT m_2 (dsram) ====
output logic [P_MST_ID_W-1:0] o_axi_m_2_aw_id,
output logic [31:0] o_axi_m_2_aw_addr,
output logic [7:0] o_axi_m_2_aw_len,
output logic [2:0] o_axi_m_2_aw_size,
output logic [1:0] o_axi_m_2_aw_burst,
output logic  o_axi_m_2_aw_lock,
output logic [3:0] o_axi_m_2_aw_cache,
output logic [2:0] o_axi_m_2_aw_prot,
output logic [3:0] o_axi_m_2_aw_qos,
output logic [3:0] o_axi_m_2_aw_region,
output logic [5:0] o_axi_m_2_aw_atop,
output logic [P_AXI_USER_W-1:0] o_axi_m_2_aw_user,
output logic  o_axi_m_2_aw_valid,
input  logic  i_axi_m_2_aw_ready,
output logic [31:0] o_axi_m_2_w_data,
output logic [3:0] o_axi_m_2_w_strb,
output logic  o_axi_m_2_w_last,
output logic [P_AXI_USER_W-1:0] o_axi_m_2_w_user,
output logic  o_axi_m_2_w_valid,
input  logic  i_axi_m_2_w_ready,
input  logic [P_MST_ID_W-1:0] i_axi_m_2_b_id,
input  logic [1:0] i_axi_m_2_b_resp,
input  logic [P_AXI_USER_W-1:0] i_axi_m_2_b_user,
input  logic  i_axi_m_2_b_valid,
output logic  o_axi_m_2_b_ready,
output logic [P_MST_ID_W-1:0] o_axi_m_2_ar_id,
output logic [31:0] o_axi_m_2_ar_addr,
output logic [7:0] o_axi_m_2_ar_len,
output logic [2:0] o_axi_m_2_ar_size,
output logic [1:0] o_axi_m_2_ar_burst,
output logic  o_axi_m_2_ar_lock,
output logic [3:0] o_axi_m_2_ar_cache,
output logic [2:0] o_axi_m_2_ar_prot,
output logic [3:0] o_axi_m_2_ar_qos,
output logic [3:0] o_axi_m_2_ar_region,
output logic [P_AXI_USER_W-1:0] o_axi_m_2_ar_user,
output logic  o_axi_m_2_ar_valid,
input  logic  i_axi_m_2_ar_ready,
input  logic [P_MST_ID_W-1:0] i_axi_m_2_r_id,
input  logic [31:0] i_axi_m_2_r_data,
input  logic [1:0] i_axi_m_2_r_resp,
input  logic  i_axi_m_2_r_last,
input  logic [P_AXI_USER_W-1:0] i_axi_m_2_r_user,
input  logic  i_axi_m_2_r_valid,
output logic  o_axi_m_2_r_ready,


//---------------------------------------------------------------
// APB4 master port -- the AXI2APB bridge's output, P_BUS's single
// master-input port (APB_S0 in P_BUS's own naming).
//---------------------------------------------------------------
output logic [31:0] o_apb_paddr,
output logic [2:0]  o_apb_pprot,
output logic         o_apb_psel,
output logic         o_apb_penable,
output logic         o_apb_pwrite,
output logic [31:0] o_apb_pwdata,
output logic [3:0]  o_apb_pstrb,
input  logic         i_apb_pready,
input  logic [31:0] i_apb_prdata,
input  logic         i_apb_pslverr
);

// ==================================================================
// Internal signals
// ==================================================================
slv_req_t  w_axi_s_0_req,  w_axi_s_1_req,  w_axi_s_2_req;
slv_resp_t w_axi_s_0_resp, w_axi_s_1_resp, w_axi_s_2_resp;

mst_req_t  w_axi_m_0_req,  w_axi_m_1_req,  w_axi_m_2_req;
mst_resp_t w_axi_m_0_resp, w_axi_m_1_resp, w_axi_m_2_resp;

slv_req_t  [P_NO_SLV_PORTS-1:0] w_slv_reqs;
slv_resp_t [P_NO_SLV_PORTS-1:0] w_slv_resps;
mst_req_t  [P_NO_MST_PORTS-1:0] w_mst_reqs;
mst_resp_t [P_NO_MST_PORTS-1:0] w_mst_resps;

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
// mst_reqs[3]/mst_resps[3] (AXI2APB) feed the bridge chain directly below,
// never flattened to this module's own ports -- AXI_M3 does not leave this
// block as AXI, it leaves as the APB4 port above.

lite_req_t  w_axi2apb_lite_req;
lite_resp_t w_axi2apb_lite_resp;

apb_req_t  [P_NO_APB_SLAVES-1:0] w_apb_req;
apb_resp_t [P_NO_APB_SLAVES-1:0] w_apb_resp;

// ==================================================================
// The crossbar itself
// ==================================================================
axi_xbar #(
  .Cfg           (P_CFG),
  .ATOPs         (1'b0),  // no evidence any master here issues AXI5 atomics
  .Connectivity  ('1),    // every slave port reaches every master port
  .slv_aw_chan_t (slv_aw_chan_t),
  .mst_aw_chan_t (mst_aw_chan_t),
  .w_chan_t      (w_chan_t),
  .slv_b_chan_t  (slv_b_chan_t),
  .mst_b_chan_t  (mst_b_chan_t),
  .slv_ar_chan_t (slv_ar_chan_t),
  .mst_ar_chan_t (mst_ar_chan_t),
  .slv_r_chan_t  (slv_r_chan_t),
  .mst_r_chan_t  (mst_r_chan_t),
  .slv_req_t     (slv_req_t),
  .slv_resp_t    (slv_resp_t),
  .mst_req_t     (mst_req_t),
  .mst_resp_t    (mst_resp_t),
  .rule_t        (rule_t)
) u_axi_xbar (
  .clk_i                 (i_clk_cpu),
  .rst_ni                (i_rst_n_cpu),
  .slv_ports_req_i       (w_slv_reqs),
  .slv_ports_resp_o      (w_slv_resps),
  .mst_ports_req_o       (w_mst_reqs),
  .mst_ports_resp_i      (w_mst_resps),
  .addr_map_i            (P_ADDR_MAP),
  .en_default_mst_port_i ('0),  // no default port on any slave port: an
                                // unmapped address always reaches the
                                // private decode-error responder, never a
                                // guessed destination
  .default_mst_port_i    ('0)
);

// ==================================================================
// AXI2APB: AXI4 (AXI_M3) -> AXI4-Lite -> APB4 (P_BUS's APB_S0)
// ==================================================================
axi_to_axi_lite #(
  .AxiAddrWidth    (P_AXI_ADDR_W),
  .AxiDataWidth    (P_AXI_DATA_W),
  .AxiIdWidth      (P_MST_ID_W),
  .AxiUserWidth    (P_AXI_USER_W),
  .AxiMaxWriteTxns (2),
  .AxiMaxReadTxns  (2),
  .FallThrough     (1'b1),
  .full_req_t      (mst_req_t),
  .full_resp_t     (mst_resp_t),
  .lite_req_t      (lite_req_t),
  .lite_resp_t     (lite_resp_t)
) u_axi_to_axi_lite (
  .clk_i      (i_clk_cpu),
  .rst_ni     (i_rst_n_cpu),
  .slv_req_i  (w_mst_reqs[3]),
  .slv_resp_o (w_mst_resps[3]),
  .mst_req_o  (w_axi2apb_lite_req),
  .mst_resp_i (w_axi2apb_lite_resp)
);

axi_lite_to_apb #(
  .NoApbSlaves      (P_NO_APB_SLAVES),
  .NoRules          (P_NO_APB_RULES),
  .AddrWidth        (P_AXI_ADDR_W),
  .DataWidth        (P_AXI_DATA_W),
  .PipelineRequest  (1'b0),
  .PipelineResponse (1'b0),
  .axi_lite_req_t   (lite_req_t),
  .axi_lite_resp_t  (lite_resp_t),
  .apb_req_t        (apb_req_t),
  .apb_resp_t       (apb_resp_t),
  .rule_t           (rule_t)
) u_axi_lite_to_apb (
  .clk_i           (i_clk_cpu),
  .rst_ni          (i_rst_n_cpu),
  .axi_lite_req_i  (w_axi2apb_lite_req),
  .axi_lite_resp_o (w_axi2apb_lite_resp),
  .apb_req_o       (w_apb_req),
  .apb_resp_i      (w_apb_resp),
  .addr_map_i      (P_APB_ADDR_MAP)
);

assign o_apb_paddr   = w_apb_req[0].paddr;
assign o_apb_pprot   = w_apb_req[0].pprot;
assign o_apb_psel    = w_apb_req[0].psel;
assign o_apb_penable = w_apb_req[0].penable;
assign o_apb_pwrite  = w_apb_req[0].pwrite;
assign o_apb_pwdata  = w_apb_req[0].pwdata;
assign o_apb_pstrb   = w_apb_req[0].pstrb;
assign w_apb_resp[0].pready  = i_apb_pready;
assign w_apb_resp[0].prdata  = i_apb_prdata;
assign w_apb_resp[0].pslverr = i_apb_pslverr;

// ==================================================================
// Boundary normalization: pack/unpack the flattened per-channel AXI4
// ports against the packed-struct ports axi_xbar itself uses.
// AUTOINST cannot decompose SV packed structs, so this glue is
// hand-written, not tool-generated (same convention as
// design/cpu/rtl/emacs/m_qnsc_wrap_cpu_cpu2axi.sv).
// ==================================================================
  // ---- axi_s_0 ----
  assign w_axi_s_0_req.aw.id     = i_axi_s_0_aw_id;
  assign w_axi_s_0_req.aw.addr   = i_axi_s_0_aw_addr;
  assign w_axi_s_0_req.aw.len    = i_axi_s_0_aw_len;
  assign w_axi_s_0_req.aw.size   = i_axi_s_0_aw_size;
  assign w_axi_s_0_req.aw.burst  = i_axi_s_0_aw_burst;
  assign w_axi_s_0_req.aw.lock   = i_axi_s_0_aw_lock;
  assign w_axi_s_0_req.aw.cache  = i_axi_s_0_aw_cache;
  assign w_axi_s_0_req.aw.prot   = i_axi_s_0_aw_prot;
  assign w_axi_s_0_req.aw.qos    = i_axi_s_0_aw_qos;
  assign w_axi_s_0_req.aw.region = i_axi_s_0_aw_region;
  assign w_axi_s_0_req.aw.atop   = i_axi_s_0_aw_atop;
  assign w_axi_s_0_req.aw.user   = i_axi_s_0_aw_user;
  assign w_axi_s_0_req.aw_valid = i_axi_s_0_aw_valid;
  assign o_axi_s_0_aw_ready = w_axi_s_0_resp.aw_ready;

  assign w_axi_s_0_req.w.data   = i_axi_s_0_w_data;
  assign w_axi_s_0_req.w.strb   = i_axi_s_0_w_strb;
  assign w_axi_s_0_req.w.last   = i_axi_s_0_w_last;
  assign w_axi_s_0_req.w.user   = i_axi_s_0_w_user;
  assign w_axi_s_0_req.w_valid  = i_axi_s_0_w_valid;
  assign o_axi_s_0_w_ready  = w_axi_s_0_resp.w_ready;

  assign o_axi_s_0_b_id     = w_axi_s_0_resp.b.id;
  assign o_axi_s_0_b_resp   = w_axi_s_0_resp.b.resp;
  assign o_axi_s_0_b_user   = w_axi_s_0_resp.b.user;
  assign o_axi_s_0_b_valid  = w_axi_s_0_resp.b_valid;
  assign w_axi_s_0_req.b_ready  = i_axi_s_0_b_ready;

  assign w_axi_s_0_req.ar.id     = i_axi_s_0_ar_id;
  assign w_axi_s_0_req.ar.addr   = i_axi_s_0_ar_addr;
  assign w_axi_s_0_req.ar.len    = i_axi_s_0_ar_len;
  assign w_axi_s_0_req.ar.size   = i_axi_s_0_ar_size;
  assign w_axi_s_0_req.ar.burst  = i_axi_s_0_ar_burst;
  assign w_axi_s_0_req.ar.lock   = i_axi_s_0_ar_lock;
  assign w_axi_s_0_req.ar.cache  = i_axi_s_0_ar_cache;
  assign w_axi_s_0_req.ar.prot   = i_axi_s_0_ar_prot;
  assign w_axi_s_0_req.ar.qos    = i_axi_s_0_ar_qos;
  assign w_axi_s_0_req.ar.region = i_axi_s_0_ar_region;
  assign w_axi_s_0_req.ar.user   = i_axi_s_0_ar_user;
  assign w_axi_s_0_req.ar_valid = i_axi_s_0_ar_valid;
  assign o_axi_s_0_ar_ready = w_axi_s_0_resp.ar_ready;

  assign o_axi_s_0_r_id     = w_axi_s_0_resp.r.id;
  assign o_axi_s_0_r_data   = w_axi_s_0_resp.r.data;
  assign o_axi_s_0_r_resp   = w_axi_s_0_resp.r.resp;
  assign o_axi_s_0_r_last   = w_axi_s_0_resp.r.last;
  assign o_axi_s_0_r_user   = w_axi_s_0_resp.r.user;
  assign o_axi_s_0_r_valid  = w_axi_s_0_resp.r_valid;
  assign w_axi_s_0_req.r_ready  = i_axi_s_0_r_ready;

  // ---- axi_s_1 ----
  assign w_axi_s_1_req.aw.id     = i_axi_s_1_aw_id;
  assign w_axi_s_1_req.aw.addr   = i_axi_s_1_aw_addr;
  assign w_axi_s_1_req.aw.len    = i_axi_s_1_aw_len;
  assign w_axi_s_1_req.aw.size   = i_axi_s_1_aw_size;
  assign w_axi_s_1_req.aw.burst  = i_axi_s_1_aw_burst;
  assign w_axi_s_1_req.aw.lock   = i_axi_s_1_aw_lock;
  assign w_axi_s_1_req.aw.cache  = i_axi_s_1_aw_cache;
  assign w_axi_s_1_req.aw.prot   = i_axi_s_1_aw_prot;
  assign w_axi_s_1_req.aw.qos    = i_axi_s_1_aw_qos;
  assign w_axi_s_1_req.aw.region = i_axi_s_1_aw_region;
  assign w_axi_s_1_req.aw.atop   = i_axi_s_1_aw_atop;
  assign w_axi_s_1_req.aw.user   = i_axi_s_1_aw_user;
  assign w_axi_s_1_req.aw_valid = i_axi_s_1_aw_valid;
  assign o_axi_s_1_aw_ready = w_axi_s_1_resp.aw_ready;

  assign w_axi_s_1_req.w.data   = i_axi_s_1_w_data;
  assign w_axi_s_1_req.w.strb   = i_axi_s_1_w_strb;
  assign w_axi_s_1_req.w.last   = i_axi_s_1_w_last;
  assign w_axi_s_1_req.w.user   = i_axi_s_1_w_user;
  assign w_axi_s_1_req.w_valid  = i_axi_s_1_w_valid;
  assign o_axi_s_1_w_ready  = w_axi_s_1_resp.w_ready;

  assign o_axi_s_1_b_id     = w_axi_s_1_resp.b.id;
  assign o_axi_s_1_b_resp   = w_axi_s_1_resp.b.resp;
  assign o_axi_s_1_b_user   = w_axi_s_1_resp.b.user;
  assign o_axi_s_1_b_valid  = w_axi_s_1_resp.b_valid;
  assign w_axi_s_1_req.b_ready  = i_axi_s_1_b_ready;

  assign w_axi_s_1_req.ar.id     = i_axi_s_1_ar_id;
  assign w_axi_s_1_req.ar.addr   = i_axi_s_1_ar_addr;
  assign w_axi_s_1_req.ar.len    = i_axi_s_1_ar_len;
  assign w_axi_s_1_req.ar.size   = i_axi_s_1_ar_size;
  assign w_axi_s_1_req.ar.burst  = i_axi_s_1_ar_burst;
  assign w_axi_s_1_req.ar.lock   = i_axi_s_1_ar_lock;
  assign w_axi_s_1_req.ar.cache  = i_axi_s_1_ar_cache;
  assign w_axi_s_1_req.ar.prot   = i_axi_s_1_ar_prot;
  assign w_axi_s_1_req.ar.qos    = i_axi_s_1_ar_qos;
  assign w_axi_s_1_req.ar.region = i_axi_s_1_ar_region;
  assign w_axi_s_1_req.ar.user   = i_axi_s_1_ar_user;
  assign w_axi_s_1_req.ar_valid = i_axi_s_1_ar_valid;
  assign o_axi_s_1_ar_ready = w_axi_s_1_resp.ar_ready;

  assign o_axi_s_1_r_id     = w_axi_s_1_resp.r.id;
  assign o_axi_s_1_r_data   = w_axi_s_1_resp.r.data;
  assign o_axi_s_1_r_resp   = w_axi_s_1_resp.r.resp;
  assign o_axi_s_1_r_last   = w_axi_s_1_resp.r.last;
  assign o_axi_s_1_r_user   = w_axi_s_1_resp.r.user;
  assign o_axi_s_1_r_valid  = w_axi_s_1_resp.r_valid;
  assign w_axi_s_1_req.r_ready  = i_axi_s_1_r_ready;

  // ---- axi_s_2 ----
  assign w_axi_s_2_req.aw.id     = i_axi_s_2_aw_id;
  assign w_axi_s_2_req.aw.addr   = i_axi_s_2_aw_addr;
  assign w_axi_s_2_req.aw.len    = i_axi_s_2_aw_len;
  assign w_axi_s_2_req.aw.size   = i_axi_s_2_aw_size;
  assign w_axi_s_2_req.aw.burst  = i_axi_s_2_aw_burst;
  assign w_axi_s_2_req.aw.lock   = i_axi_s_2_aw_lock;
  assign w_axi_s_2_req.aw.cache  = i_axi_s_2_aw_cache;
  assign w_axi_s_2_req.aw.prot   = i_axi_s_2_aw_prot;
  assign w_axi_s_2_req.aw.qos    = i_axi_s_2_aw_qos;
  assign w_axi_s_2_req.aw.region = i_axi_s_2_aw_region;
  assign w_axi_s_2_req.aw.atop   = i_axi_s_2_aw_atop;
  assign w_axi_s_2_req.aw.user   = i_axi_s_2_aw_user;
  assign w_axi_s_2_req.aw_valid = i_axi_s_2_aw_valid;
  assign o_axi_s_2_aw_ready = w_axi_s_2_resp.aw_ready;

  assign w_axi_s_2_req.w.data   = i_axi_s_2_w_data;
  assign w_axi_s_2_req.w.strb   = i_axi_s_2_w_strb;
  assign w_axi_s_2_req.w.last   = i_axi_s_2_w_last;
  assign w_axi_s_2_req.w.user   = i_axi_s_2_w_user;
  assign w_axi_s_2_req.w_valid  = i_axi_s_2_w_valid;
  assign o_axi_s_2_w_ready  = w_axi_s_2_resp.w_ready;

  assign o_axi_s_2_b_id     = w_axi_s_2_resp.b.id;
  assign o_axi_s_2_b_resp   = w_axi_s_2_resp.b.resp;
  assign o_axi_s_2_b_user   = w_axi_s_2_resp.b.user;
  assign o_axi_s_2_b_valid  = w_axi_s_2_resp.b_valid;
  assign w_axi_s_2_req.b_ready  = i_axi_s_2_b_ready;

  assign w_axi_s_2_req.ar.id     = i_axi_s_2_ar_id;
  assign w_axi_s_2_req.ar.addr   = i_axi_s_2_ar_addr;
  assign w_axi_s_2_req.ar.len    = i_axi_s_2_ar_len;
  assign w_axi_s_2_req.ar.size   = i_axi_s_2_ar_size;
  assign w_axi_s_2_req.ar.burst  = i_axi_s_2_ar_burst;
  assign w_axi_s_2_req.ar.lock   = i_axi_s_2_ar_lock;
  assign w_axi_s_2_req.ar.cache  = i_axi_s_2_ar_cache;
  assign w_axi_s_2_req.ar.prot   = i_axi_s_2_ar_prot;
  assign w_axi_s_2_req.ar.qos    = i_axi_s_2_ar_qos;
  assign w_axi_s_2_req.ar.region = i_axi_s_2_ar_region;
  assign w_axi_s_2_req.ar.user   = i_axi_s_2_ar_user;
  assign w_axi_s_2_req.ar_valid = i_axi_s_2_ar_valid;
  assign o_axi_s_2_ar_ready = w_axi_s_2_resp.ar_ready;

  assign o_axi_s_2_r_id     = w_axi_s_2_resp.r.id;
  assign o_axi_s_2_r_data   = w_axi_s_2_resp.r.data;
  assign o_axi_s_2_r_resp   = w_axi_s_2_resp.r.resp;
  assign o_axi_s_2_r_last   = w_axi_s_2_resp.r.last;
  assign o_axi_s_2_r_user   = w_axi_s_2_resp.r.user;
  assign o_axi_s_2_r_valid  = w_axi_s_2_resp.r_valid;
  assign w_axi_s_2_req.r_ready  = i_axi_s_2_r_ready;

  // ---- axi_m_0 ----
  assign o_axi_m_0_aw_id     = w_axi_m_0_req.aw.id;
  assign o_axi_m_0_aw_addr   = w_axi_m_0_req.aw.addr;
  assign o_axi_m_0_aw_len    = w_axi_m_0_req.aw.len;
  assign o_axi_m_0_aw_size   = w_axi_m_0_req.aw.size;
  assign o_axi_m_0_aw_burst  = w_axi_m_0_req.aw.burst;
  assign o_axi_m_0_aw_lock   = w_axi_m_0_req.aw.lock;
  assign o_axi_m_0_aw_cache  = w_axi_m_0_req.aw.cache;
  assign o_axi_m_0_aw_prot   = w_axi_m_0_req.aw.prot;
  assign o_axi_m_0_aw_qos    = w_axi_m_0_req.aw.qos;
  assign o_axi_m_0_aw_region = w_axi_m_0_req.aw.region;
  assign o_axi_m_0_aw_atop   = w_axi_m_0_req.aw.atop;
  assign o_axi_m_0_aw_user   = w_axi_m_0_req.aw.user;
  assign o_axi_m_0_aw_valid = w_axi_m_0_req.aw_valid;
  assign w_axi_m_0_resp.aw_ready = i_axi_m_0_aw_ready;

  assign o_axi_m_0_w_data   = w_axi_m_0_req.w.data;
  assign o_axi_m_0_w_strb   = w_axi_m_0_req.w.strb;
  assign o_axi_m_0_w_last   = w_axi_m_0_req.w.last;
  assign o_axi_m_0_w_user   = w_axi_m_0_req.w.user;
  assign o_axi_m_0_w_valid  = w_axi_m_0_req.w_valid;
  assign w_axi_m_0_resp.w_ready  = i_axi_m_0_w_ready;

  assign w_axi_m_0_resp.b.id     = i_axi_m_0_b_id;
  assign w_axi_m_0_resp.b.resp   = i_axi_m_0_b_resp;
  assign w_axi_m_0_resp.b.user   = i_axi_m_0_b_user;
  assign w_axi_m_0_resp.b_valid  = i_axi_m_0_b_valid;
  assign o_axi_m_0_b_ready  = w_axi_m_0_req.b_ready;

  assign o_axi_m_0_ar_id     = w_axi_m_0_req.ar.id;
  assign o_axi_m_0_ar_addr   = w_axi_m_0_req.ar.addr;
  assign o_axi_m_0_ar_len    = w_axi_m_0_req.ar.len;
  assign o_axi_m_0_ar_size   = w_axi_m_0_req.ar.size;
  assign o_axi_m_0_ar_burst  = w_axi_m_0_req.ar.burst;
  assign o_axi_m_0_ar_lock   = w_axi_m_0_req.ar.lock;
  assign o_axi_m_0_ar_cache  = w_axi_m_0_req.ar.cache;
  assign o_axi_m_0_ar_prot   = w_axi_m_0_req.ar.prot;
  assign o_axi_m_0_ar_qos    = w_axi_m_0_req.ar.qos;
  assign o_axi_m_0_ar_region = w_axi_m_0_req.ar.region;
  assign o_axi_m_0_ar_user   = w_axi_m_0_req.ar.user;
  assign o_axi_m_0_ar_valid = w_axi_m_0_req.ar_valid;
  assign w_axi_m_0_resp.ar_ready = i_axi_m_0_ar_ready;

  assign w_axi_m_0_resp.r.id     = i_axi_m_0_r_id;
  assign w_axi_m_0_resp.r.data   = i_axi_m_0_r_data;
  assign w_axi_m_0_resp.r.resp   = i_axi_m_0_r_resp;
  assign w_axi_m_0_resp.r.last   = i_axi_m_0_r_last;
  assign w_axi_m_0_resp.r.user   = i_axi_m_0_r_user;
  assign w_axi_m_0_resp.r_valid  = i_axi_m_0_r_valid;
  assign o_axi_m_0_r_ready  = w_axi_m_0_req.r_ready;

  // ---- axi_m_1 ----
  assign o_axi_m_1_aw_id     = w_axi_m_1_req.aw.id;
  assign o_axi_m_1_aw_addr   = w_axi_m_1_req.aw.addr;
  assign o_axi_m_1_aw_len    = w_axi_m_1_req.aw.len;
  assign o_axi_m_1_aw_size   = w_axi_m_1_req.aw.size;
  assign o_axi_m_1_aw_burst  = w_axi_m_1_req.aw.burst;
  assign o_axi_m_1_aw_lock   = w_axi_m_1_req.aw.lock;
  assign o_axi_m_1_aw_cache  = w_axi_m_1_req.aw.cache;
  assign o_axi_m_1_aw_prot   = w_axi_m_1_req.aw.prot;
  assign o_axi_m_1_aw_qos    = w_axi_m_1_req.aw.qos;
  assign o_axi_m_1_aw_region = w_axi_m_1_req.aw.region;
  assign o_axi_m_1_aw_atop   = w_axi_m_1_req.aw.atop;
  assign o_axi_m_1_aw_user   = w_axi_m_1_req.aw.user;
  assign o_axi_m_1_aw_valid = w_axi_m_1_req.aw_valid;
  assign w_axi_m_1_resp.aw_ready = i_axi_m_1_aw_ready;

  assign o_axi_m_1_w_data   = w_axi_m_1_req.w.data;
  assign o_axi_m_1_w_strb   = w_axi_m_1_req.w.strb;
  assign o_axi_m_1_w_last   = w_axi_m_1_req.w.last;
  assign o_axi_m_1_w_user   = w_axi_m_1_req.w.user;
  assign o_axi_m_1_w_valid  = w_axi_m_1_req.w_valid;
  assign w_axi_m_1_resp.w_ready  = i_axi_m_1_w_ready;

  assign w_axi_m_1_resp.b.id     = i_axi_m_1_b_id;
  assign w_axi_m_1_resp.b.resp   = i_axi_m_1_b_resp;
  assign w_axi_m_1_resp.b.user   = i_axi_m_1_b_user;
  assign w_axi_m_1_resp.b_valid  = i_axi_m_1_b_valid;
  assign o_axi_m_1_b_ready  = w_axi_m_1_req.b_ready;

  assign o_axi_m_1_ar_id     = w_axi_m_1_req.ar.id;
  assign o_axi_m_1_ar_addr   = w_axi_m_1_req.ar.addr;
  assign o_axi_m_1_ar_len    = w_axi_m_1_req.ar.len;
  assign o_axi_m_1_ar_size   = w_axi_m_1_req.ar.size;
  assign o_axi_m_1_ar_burst  = w_axi_m_1_req.ar.burst;
  assign o_axi_m_1_ar_lock   = w_axi_m_1_req.ar.lock;
  assign o_axi_m_1_ar_cache  = w_axi_m_1_req.ar.cache;
  assign o_axi_m_1_ar_prot   = w_axi_m_1_req.ar.prot;
  assign o_axi_m_1_ar_qos    = w_axi_m_1_req.ar.qos;
  assign o_axi_m_1_ar_region = w_axi_m_1_req.ar.region;
  assign o_axi_m_1_ar_user   = w_axi_m_1_req.ar.user;
  assign o_axi_m_1_ar_valid = w_axi_m_1_req.ar_valid;
  assign w_axi_m_1_resp.ar_ready = i_axi_m_1_ar_ready;

  assign w_axi_m_1_resp.r.id     = i_axi_m_1_r_id;
  assign w_axi_m_1_resp.r.data   = i_axi_m_1_r_data;
  assign w_axi_m_1_resp.r.resp   = i_axi_m_1_r_resp;
  assign w_axi_m_1_resp.r.last   = i_axi_m_1_r_last;
  assign w_axi_m_1_resp.r.user   = i_axi_m_1_r_user;
  assign w_axi_m_1_resp.r_valid  = i_axi_m_1_r_valid;
  assign o_axi_m_1_r_ready  = w_axi_m_1_req.r_ready;

  // ---- axi_m_2 ----
  assign o_axi_m_2_aw_id     = w_axi_m_2_req.aw.id;
  assign o_axi_m_2_aw_addr   = w_axi_m_2_req.aw.addr;
  assign o_axi_m_2_aw_len    = w_axi_m_2_req.aw.len;
  assign o_axi_m_2_aw_size   = w_axi_m_2_req.aw.size;
  assign o_axi_m_2_aw_burst  = w_axi_m_2_req.aw.burst;
  assign o_axi_m_2_aw_lock   = w_axi_m_2_req.aw.lock;
  assign o_axi_m_2_aw_cache  = w_axi_m_2_req.aw.cache;
  assign o_axi_m_2_aw_prot   = w_axi_m_2_req.aw.prot;
  assign o_axi_m_2_aw_qos    = w_axi_m_2_req.aw.qos;
  assign o_axi_m_2_aw_region = w_axi_m_2_req.aw.region;
  assign o_axi_m_2_aw_atop   = w_axi_m_2_req.aw.atop;
  assign o_axi_m_2_aw_user   = w_axi_m_2_req.aw.user;
  assign o_axi_m_2_aw_valid = w_axi_m_2_req.aw_valid;
  assign w_axi_m_2_resp.aw_ready = i_axi_m_2_aw_ready;

  assign o_axi_m_2_w_data   = w_axi_m_2_req.w.data;
  assign o_axi_m_2_w_strb   = w_axi_m_2_req.w.strb;
  assign o_axi_m_2_w_last   = w_axi_m_2_req.w.last;
  assign o_axi_m_2_w_user   = w_axi_m_2_req.w.user;
  assign o_axi_m_2_w_valid  = w_axi_m_2_req.w_valid;
  assign w_axi_m_2_resp.w_ready  = i_axi_m_2_w_ready;

  assign w_axi_m_2_resp.b.id     = i_axi_m_2_b_id;
  assign w_axi_m_2_resp.b.resp   = i_axi_m_2_b_resp;
  assign w_axi_m_2_resp.b.user   = i_axi_m_2_b_user;
  assign w_axi_m_2_resp.b_valid  = i_axi_m_2_b_valid;
  assign o_axi_m_2_b_ready  = w_axi_m_2_req.b_ready;

  assign o_axi_m_2_ar_id     = w_axi_m_2_req.ar.id;
  assign o_axi_m_2_ar_addr   = w_axi_m_2_req.ar.addr;
  assign o_axi_m_2_ar_len    = w_axi_m_2_req.ar.len;
  assign o_axi_m_2_ar_size   = w_axi_m_2_req.ar.size;
  assign o_axi_m_2_ar_burst  = w_axi_m_2_req.ar.burst;
  assign o_axi_m_2_ar_lock   = w_axi_m_2_req.ar.lock;
  assign o_axi_m_2_ar_cache  = w_axi_m_2_req.ar.cache;
  assign o_axi_m_2_ar_prot   = w_axi_m_2_req.ar.prot;
  assign o_axi_m_2_ar_qos    = w_axi_m_2_req.ar.qos;
  assign o_axi_m_2_ar_region = w_axi_m_2_req.ar.region;
  assign o_axi_m_2_ar_user   = w_axi_m_2_req.ar.user;
  assign o_axi_m_2_ar_valid = w_axi_m_2_req.ar_valid;
  assign w_axi_m_2_resp.ar_ready = i_axi_m_2_ar_ready;

  assign w_axi_m_2_resp.r.id     = i_axi_m_2_r_id;
  assign w_axi_m_2_resp.r.data   = i_axi_m_2_r_data;
  assign w_axi_m_2_resp.r.resp   = i_axi_m_2_r_resp;
  assign w_axi_m_2_resp.r.last   = i_axi_m_2_r_last;
  assign w_axi_m_2_resp.r.user   = i_axi_m_2_r_user;
  assign w_axi_m_2_resp.r_valid  = i_axi_m_2_r_valid;
  assign o_axi_m_2_r_ready  = w_axi_m_2_req.r_ready;

endmodule
`default_nettype wire
