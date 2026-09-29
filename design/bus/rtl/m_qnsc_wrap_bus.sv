`default_nettype none
`timescale 1ns/1ps
//==============================================================================
// Module      : m_qnsc_wrap_bus
// Description : S_BUS -- the AXI4 crossbar (axi_xbar) plus the AXI2APB bridge
//               (axi_to_axi_lite + axi_lite_to_apb) toward P_BUS, plus P_BUS's
//               own router (m_qnsc_p_bus_dec, generated). Three masters issue
//               transactions here (SYSDBG on AXI_S0, CPU on AXI_S1, DMA on
//               AXI_S2); four destinations answer them (ROM AXI_M0, ISRAM
//               AXI_M1, DSRAM AXI_M2, AXI2APB AXI_M3), and AXI_M3's single
//               APB4 master port fans out to 14 peripheral-facing ports. No
//               packed structs cross this module's own boundary, per the
//               naming rule.
// Spec ref    : doc/specs/QNSC_BUS_MAS.md
//==============================================================================
module m_qnsc_wrap_bus
  import qnsc_pkg::*;
  import s_bus_pkg::*;
#(
)
(
//---------------------------------------------------------------
// Clock/Reset -- S_BUS and P_BUS are each their own hardwired-on
// domain (qnsc_pkg's "sbus"/"pbus" clusters), separate CTRL
// instances from cpu's own, per QNSC_SCRC_MAS V3.0 Table 5-2. The
// AXI2APB bridge is clocked from pbus, not sbus: it is P_BUS's
// ingress logic, sharing a domain with the guards immediately
// downstream of it -- see doc/specs/QNSC_BUS_DECISIONS.md.
//---------------------------------------------------------------
input  logic i_clk_sbus,
input  logic i_rst_n_sbus,
input  logic i_clk_pbus,
input  logic i_rst_n_pbus,

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
// APB4 slave ports -- P_BUS's 14 peripheral-facing ports, fanned out by
// the generated m_qnsc_p_bus_dec (util/gen/p_bus_apb_dec/, see
// vendor/manifest.yml).
//---------------------------------------------------------------
// ==== P_BUS peripheral 0: scrc (APB_M0) ====
output logic [11:0] o_apb_scrc_paddr,
output logic [31:0] o_apb_scrc_pwdata,
output logic [3:0]  o_apb_scrc_pstrb,
output logic        o_apb_scrc_psel,
output logic        o_apb_scrc_penable,
output logic        o_apb_scrc_pwrite,
input  logic        i_apb_scrc_pready,
input  logic        i_apb_scrc_pslverr,
input  logic [31:0] i_apb_scrc_prdata,
// ==== P_BUS peripheral 1: syscsr (APB_M1) ====
output logic [11:0] o_apb_syscsr_paddr,
output logic [31:0] o_apb_syscsr_pwdata,
output logic [3:0]  o_apb_syscsr_pstrb,
output logic        o_apb_syscsr_psel,
output logic        o_apb_syscsr_penable,
output logic        o_apb_syscsr_pwrite,
input  logic        i_apb_syscsr_pready,
input  logic        i_apb_syscsr_pslverr,
input  logic [31:0] i_apb_syscsr_prdata,
// ==== P_BUS peripheral 2: wdt (APB_M2) ====
output logic [11:0] o_apb_wdt_paddr,
output logic [31:0] o_apb_wdt_pwdata,
output logic [3:0]  o_apb_wdt_pstrb,
output logic        o_apb_wdt_psel,
output logic        o_apb_wdt_penable,
output logic        o_apb_wdt_pwrite,
input  logic        i_apb_wdt_pready,
input  logic        i_apb_wdt_pslverr,
input  logic [31:0] i_apb_wdt_prdata,
// ==== P_BUS peripheral 3: gpio_0 (APB_M3) ====
output logic [11:0] o_apb_gpio_0_paddr,
output logic [31:0] o_apb_gpio_0_pwdata,
output logic [3:0]  o_apb_gpio_0_pstrb,
output logic        o_apb_gpio_0_psel,
output logic        o_apb_gpio_0_penable,
output logic        o_apb_gpio_0_pwrite,
input  logic        i_apb_gpio_0_pready,
input  logic        i_apb_gpio_0_pslverr,
input  logic [31:0] i_apb_gpio_0_prdata,
// ==== P_BUS peripheral 4: gpio_1 (APB_M4) ====
output logic [11:0] o_apb_gpio_1_paddr,
output logic [31:0] o_apb_gpio_1_pwdata,
output logic [3:0]  o_apb_gpio_1_pstrb,
output logic        o_apb_gpio_1_psel,
output logic        o_apb_gpio_1_penable,
output logic        o_apb_gpio_1_pwrite,
input  logic        i_apb_gpio_1_pready,
input  logic        i_apb_gpio_1_pslverr,
input  logic [31:0] i_apb_gpio_1_prdata,
// ==== P_BUS peripheral 5: gpio_2 (APB_M5) ====
output logic [11:0] o_apb_gpio_2_paddr,
output logic [31:0] o_apb_gpio_2_pwdata,
output logic [3:0]  o_apb_gpio_2_pstrb,
output logic        o_apb_gpio_2_psel,
output logic        o_apb_gpio_2_penable,
output logic        o_apb_gpio_2_pwrite,
input  logic        i_apb_gpio_2_pready,
input  logic        i_apb_gpio_2_pslverr,
input  logic [31:0] i_apb_gpio_2_prdata,
// ==== P_BUS peripheral 6: timer_0 (APB_M6) ====
output logic [11:0] o_apb_timer_0_paddr,
output logic [31:0] o_apb_timer_0_pwdata,
output logic [3:0]  o_apb_timer_0_pstrb,
output logic        o_apb_timer_0_psel,
output logic        o_apb_timer_0_penable,
output logic        o_apb_timer_0_pwrite,
input  logic        i_apb_timer_0_pready,
input  logic        i_apb_timer_0_pslverr,
input  logic [31:0] i_apb_timer_0_prdata,
// ==== P_BUS peripheral 7: timer_1 (APB_M7) ====
output logic [11:0] o_apb_timer_1_paddr,
output logic [31:0] o_apb_timer_1_pwdata,
output logic [3:0]  o_apb_timer_1_pstrb,
output logic        o_apb_timer_1_psel,
output logic        o_apb_timer_1_penable,
output logic        o_apb_timer_1_pwrite,
input  logic        i_apb_timer_1_pready,
input  logic        i_apb_timer_1_pslverr,
input  logic [31:0] i_apb_timer_1_prdata,
// ==== P_BUS peripheral 8: uart_0 (APB_M8) ====
output logic [11:0] o_apb_uart_0_paddr,
output logic [31:0] o_apb_uart_0_pwdata,
output logic [3:0]  o_apb_uart_0_pstrb,
output logic        o_apb_uart_0_psel,
output logic        o_apb_uart_0_penable,
output logic        o_apb_uart_0_pwrite,
input  logic        i_apb_uart_0_pready,
input  logic        i_apb_uart_0_pslverr,
input  logic [31:0] i_apb_uart_0_prdata,
// ==== P_BUS peripheral 9: uart_1 (APB_M9) ====
output logic [11:0] o_apb_uart_1_paddr,
output logic [31:0] o_apb_uart_1_pwdata,
output logic [3:0]  o_apb_uart_1_pstrb,
output logic        o_apb_uart_1_psel,
output logic        o_apb_uart_1_penable,
output logic        o_apb_uart_1_pwrite,
input  logic        i_apb_uart_1_pready,
input  logic        i_apb_uart_1_pslverr,
input  logic [31:0] i_apb_uart_1_prdata,
// ==== P_BUS peripheral 10: spi (APB_M10) ====
output logic [11:0] o_apb_spi_paddr,
output logic [31:0] o_apb_spi_pwdata,
output logic [3:0]  o_apb_spi_pstrb,
output logic        o_apb_spi_psel,
output logic        o_apb_spi_penable,
output logic        o_apb_spi_pwrite,
input  logic        i_apb_spi_pready,
input  logic        i_apb_spi_pslverr,
input  logic [31:0] i_apb_spi_prdata,
// ==== P_BUS peripheral 11: i2c (APB_M11) ====
output logic [11:0] o_apb_i2c_paddr,
output logic [31:0] o_apb_i2c_pwdata,
output logic [3:0]  o_apb_i2c_pstrb,
output logic        o_apb_i2c_psel,
output logic        o_apb_i2c_penable,
output logic        o_apb_i2c_pwrite,
input  logic        i_apb_i2c_pready,
input  logic        i_apb_i2c_pslverr,
input  logic [31:0] i_apb_i2c_prdata,
// ==== P_BUS peripheral 12: pwm (APB_M12) ====
output logic [11:0] o_apb_pwm_paddr,
output logic [31:0] o_apb_pwm_pwdata,
output logic [3:0]  o_apb_pwm_pstrb,
output logic        o_apb_pwm_psel,
output logic        o_apb_pwm_penable,
output logic        o_apb_pwm_pwrite,
input  logic        i_apb_pwm_pready,
input  logic        i_apb_pwm_pslverr,
input  logic [31:0] i_apb_pwm_prdata,
// ==== P_BUS peripheral 13: dma_cfg (APB_M13) ====
output logic [11:0] o_apb_dma_cfg_paddr,
output logic [31:0] o_apb_dma_cfg_pwdata,
output logic [3:0]  o_apb_dma_cfg_pstrb,
output logic        o_apb_dma_cfg_psel,
output logic        o_apb_dma_cfg_penable,
output logic        o_apb_dma_cfg_pwrite,
input  logic        i_apb_dma_cfg_pready,
input  logic        i_apb_dma_cfg_pslverr,
input  logic [31:0] i_apb_dma_cfg_prdata
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
  .clk_i                 (i_clk_sbus),
  .rst_ni                (i_rst_n_sbus),
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
  .clk_i      (i_clk_pbus),
  .rst_ni     (i_rst_n_pbus),
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
  .clk_i           (i_clk_pbus),
  .rst_ni          (i_rst_n_pbus),
  .axi_lite_req_i  (w_axi2apb_lite_req),
  .axi_lite_resp_o (w_axi2apb_lite_resp),
  .apb_req_o       (w_apb_req),
  .apb_resp_i      (w_apb_resp),
  .addr_map_i      (P_APB_ADDR_MAP)
);

// P_BUS's own router: fans w_apb_req[0]/w_apb_resp[0] (the AXI2APB bridge's
// single master-side port) out to one flat port per peripheral. pprot is not
// carried through -- m_qnsc_p_bus_dec has no such port at all (see
// vendor/manifest.yml, nguyenquanicd/APB-DEC-Generator); w_apb_req[0].pprot
// is intentionally left unconnected here.
m_qnsc_p_bus_dec u_m_qnsc_p_bus_dec (
  .i_paddr    (w_apb_req[0].paddr),
  .i_pwdata   (w_apb_req[0].pwdata),
  .i_pstrb    (w_apb_req[0].pstrb),
  .i_pwrite   (w_apb_req[0].pwrite),
  .i_psel     (w_apb_req[0].psel),
  .i_penable  (w_apb_req[0].penable),
  .o_pready   (w_apb_resp[0].pready),
  .o_pslverr  (w_apb_resp[0].pslverr),
  .o_prdata   (w_apb_resp[0].prdata),
  .o_paddr_scrc    (o_apb_scrc_paddr),
  .o_pwdata_scrc   (o_apb_scrc_pwdata),
  .o_pstrb_scrc    (o_apb_scrc_pstrb),
  .o_psel_scrc     (o_apb_scrc_psel),
  .o_penable_scrc  (o_apb_scrc_penable),
  .o_pwrite_scrc   (o_apb_scrc_pwrite),
  .i_pready_scrc   (i_apb_scrc_pready),
  .i_pslverr_scrc  (i_apb_scrc_pslverr),
  .i_prdata_scrc   (i_apb_scrc_prdata),
  .o_paddr_syscsr    (o_apb_syscsr_paddr),
  .o_pwdata_syscsr   (o_apb_syscsr_pwdata),
  .o_pstrb_syscsr    (o_apb_syscsr_pstrb),
  .o_psel_syscsr     (o_apb_syscsr_psel),
  .o_penable_syscsr  (o_apb_syscsr_penable),
  .o_pwrite_syscsr   (o_apb_syscsr_pwrite),
  .i_pready_syscsr   (i_apb_syscsr_pready),
  .i_pslverr_syscsr  (i_apb_syscsr_pslverr),
  .i_prdata_syscsr   (i_apb_syscsr_prdata),
  .o_paddr_wdt    (o_apb_wdt_paddr),
  .o_pwdata_wdt   (o_apb_wdt_pwdata),
  .o_pstrb_wdt    (o_apb_wdt_pstrb),
  .o_psel_wdt     (o_apb_wdt_psel),
  .o_penable_wdt  (o_apb_wdt_penable),
  .o_pwrite_wdt   (o_apb_wdt_pwrite),
  .i_pready_wdt   (i_apb_wdt_pready),
  .i_pslverr_wdt  (i_apb_wdt_pslverr),
  .i_prdata_wdt   (i_apb_wdt_prdata),
  .o_paddr_gpio_0    (o_apb_gpio_0_paddr),
  .o_pwdata_gpio_0   (o_apb_gpio_0_pwdata),
  .o_pstrb_gpio_0    (o_apb_gpio_0_pstrb),
  .o_psel_gpio_0     (o_apb_gpio_0_psel),
  .o_penable_gpio_0  (o_apb_gpio_0_penable),
  .o_pwrite_gpio_0   (o_apb_gpio_0_pwrite),
  .i_pready_gpio_0   (i_apb_gpio_0_pready),
  .i_pslverr_gpio_0  (i_apb_gpio_0_pslverr),
  .i_prdata_gpio_0   (i_apb_gpio_0_prdata),
  .o_paddr_gpio_1    (o_apb_gpio_1_paddr),
  .o_pwdata_gpio_1   (o_apb_gpio_1_pwdata),
  .o_pstrb_gpio_1    (o_apb_gpio_1_pstrb),
  .o_psel_gpio_1     (o_apb_gpio_1_psel),
  .o_penable_gpio_1  (o_apb_gpio_1_penable),
  .o_pwrite_gpio_1   (o_apb_gpio_1_pwrite),
  .i_pready_gpio_1   (i_apb_gpio_1_pready),
  .i_pslverr_gpio_1  (i_apb_gpio_1_pslverr),
  .i_prdata_gpio_1   (i_apb_gpio_1_prdata),
  .o_paddr_gpio_2    (o_apb_gpio_2_paddr),
  .o_pwdata_gpio_2   (o_apb_gpio_2_pwdata),
  .o_pstrb_gpio_2    (o_apb_gpio_2_pstrb),
  .o_psel_gpio_2     (o_apb_gpio_2_psel),
  .o_penable_gpio_2  (o_apb_gpio_2_penable),
  .o_pwrite_gpio_2   (o_apb_gpio_2_pwrite),
  .i_pready_gpio_2   (i_apb_gpio_2_pready),
  .i_pslverr_gpio_2  (i_apb_gpio_2_pslverr),
  .i_prdata_gpio_2   (i_apb_gpio_2_prdata),
  .o_paddr_timer_0    (o_apb_timer_0_paddr),
  .o_pwdata_timer_0   (o_apb_timer_0_pwdata),
  .o_pstrb_timer_0    (o_apb_timer_0_pstrb),
  .o_psel_timer_0     (o_apb_timer_0_psel),
  .o_penable_timer_0  (o_apb_timer_0_penable),
  .o_pwrite_timer_0   (o_apb_timer_0_pwrite),
  .i_pready_timer_0   (i_apb_timer_0_pready),
  .i_pslverr_timer_0  (i_apb_timer_0_pslverr),
  .i_prdata_timer_0   (i_apb_timer_0_prdata),
  .o_paddr_timer_1    (o_apb_timer_1_paddr),
  .o_pwdata_timer_1   (o_apb_timer_1_pwdata),
  .o_pstrb_timer_1    (o_apb_timer_1_pstrb),
  .o_psel_timer_1     (o_apb_timer_1_psel),
  .o_penable_timer_1  (o_apb_timer_1_penable),
  .o_pwrite_timer_1   (o_apb_timer_1_pwrite),
  .i_pready_timer_1   (i_apb_timer_1_pready),
  .i_pslverr_timer_1  (i_apb_timer_1_pslverr),
  .i_prdata_timer_1   (i_apb_timer_1_prdata),
  .o_paddr_uart_0    (o_apb_uart_0_paddr),
  .o_pwdata_uart_0   (o_apb_uart_0_pwdata),
  .o_pstrb_uart_0    (o_apb_uart_0_pstrb),
  .o_psel_uart_0     (o_apb_uart_0_psel),
  .o_penable_uart_0  (o_apb_uart_0_penable),
  .o_pwrite_uart_0   (o_apb_uart_0_pwrite),
  .i_pready_uart_0   (i_apb_uart_0_pready),
  .i_pslverr_uart_0  (i_apb_uart_0_pslverr),
  .i_prdata_uart_0   (i_apb_uart_0_prdata),
  .o_paddr_uart_1    (o_apb_uart_1_paddr),
  .o_pwdata_uart_1   (o_apb_uart_1_pwdata),
  .o_pstrb_uart_1    (o_apb_uart_1_pstrb),
  .o_psel_uart_1     (o_apb_uart_1_psel),
  .o_penable_uart_1  (o_apb_uart_1_penable),
  .o_pwrite_uart_1   (o_apb_uart_1_pwrite),
  .i_pready_uart_1   (i_apb_uart_1_pready),
  .i_pslverr_uart_1  (i_apb_uart_1_pslverr),
  .i_prdata_uart_1   (i_apb_uart_1_prdata),
  .o_paddr_spi    (o_apb_spi_paddr),
  .o_pwdata_spi   (o_apb_spi_pwdata),
  .o_pstrb_spi    (o_apb_spi_pstrb),
  .o_psel_spi     (o_apb_spi_psel),
  .o_penable_spi  (o_apb_spi_penable),
  .o_pwrite_spi   (o_apb_spi_pwrite),
  .i_pready_spi   (i_apb_spi_pready),
  .i_pslverr_spi  (i_apb_spi_pslverr),
  .i_prdata_spi   (i_apb_spi_prdata),
  .o_paddr_i2c    (o_apb_i2c_paddr),
  .o_pwdata_i2c   (o_apb_i2c_pwdata),
  .o_pstrb_i2c    (o_apb_i2c_pstrb),
  .o_psel_i2c     (o_apb_i2c_psel),
  .o_penable_i2c  (o_apb_i2c_penable),
  .o_pwrite_i2c   (o_apb_i2c_pwrite),
  .i_pready_i2c   (i_apb_i2c_pready),
  .i_pslverr_i2c  (i_apb_i2c_pslverr),
  .i_prdata_i2c   (i_apb_i2c_prdata),
  .o_paddr_pwm    (o_apb_pwm_paddr),
  .o_pwdata_pwm   (o_apb_pwm_pwdata),
  .o_pstrb_pwm    (o_apb_pwm_pstrb),
  .o_psel_pwm     (o_apb_pwm_psel),
  .o_penable_pwm  (o_apb_pwm_penable),
  .o_pwrite_pwm   (o_apb_pwm_pwrite),
  .i_pready_pwm   (i_apb_pwm_pready),
  .i_pslverr_pwm  (i_apb_pwm_pslverr),
  .i_prdata_pwm   (i_apb_pwm_prdata),
  .o_paddr_dma_cfg    (o_apb_dma_cfg_paddr),
  .o_pwdata_dma_cfg   (o_apb_dma_cfg_pwdata),
  .o_pstrb_dma_cfg    (o_apb_dma_cfg_pstrb),
  .o_psel_dma_cfg     (o_apb_dma_cfg_psel),
  .o_penable_dma_cfg  (o_apb_dma_cfg_penable),
  .o_pwrite_dma_cfg   (o_apb_dma_cfg_pwrite),
  .i_pready_dma_cfg   (i_apb_dma_cfg_pready),
  .i_pslverr_dma_cfg  (i_apb_dma_cfg_pslverr),
  .i_prdata_dma_cfg   (i_apb_dma_cfg_prdata)
);

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
