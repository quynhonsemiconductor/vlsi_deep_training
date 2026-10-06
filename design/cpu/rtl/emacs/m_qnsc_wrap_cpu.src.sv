`default_nettype none
`timescale 1ns/1ps
// m_qnsc_wrap_cpu -- ibex_top + m_qnsc_cpu2axi in one module.
// See doc/specs/QNSC_CPU_DECISIONS.md.
module m_qnsc_wrap_cpu
#(
)
(
//---------------------------------------------------------------
// Clock/Reset
//---------------------------------------------------------------
/*AUTOINPUT("^i_clk\|^i_rst")*/

//---------------------------------------------------------------
// Config -- tied by design/top from qnsc_pkg (cpu is IP, no
// qnsc_pkg import here).
//---------------------------------------------------------------
// i_dbg_en ? C_ISRAM_BASE : 0. Must be C_ISRAM_BASE, not
// C_ISRAM_DBG_BASE (see DmBaseAddr below) -- see DECISIONS.
input  logic [31:0] i_cfg_boot_addr,
input  logic [31:0] i_cfg_hart_id,

//---------------------------------------------------------------
// Boot / Debug
//---------------------------------------------------------------
input  logic i_dbg_req,

//---------------------------------------------------------------
// Interrupt
//---------------------------------------------------------------
input  logic [10:0] i_int_fast,  // padded to ibex's 15 internally
input  logic         i_int_nm,   // WDT bark (NMI)

//---------------------------------------------------------------
// DFT
//---------------------------------------------------------------
input  logic i_dft_test_en,

//---------------------------------------------------------------
// Power
//---------------------------------------------------------------
/*AUTOOUTPUT("^o_pwr")*/

//---------------------------------------------------------------
// AXI4 master bus, flattened (no packed structs on the boundary).
//---------------------------------------------------------------
input  logic                    i_bus_axi_aw_ready,
output logic [qnsc_cpu2axi_pkg::P_MST_ID_W-1:0]  o_bus_axi_aw_id,
output logic [31:0]             o_bus_axi_aw_addr,
output logic [7:0]              o_bus_axi_aw_len,
output logic [2:0]              o_bus_axi_aw_size,
output logic [1:0]              o_bus_axi_aw_burst,
output logic                    o_bus_axi_aw_lock,
output logic [3:0]              o_bus_axi_aw_cache,
output logic [2:0]              o_bus_axi_aw_prot,
output logic [3:0]              o_bus_axi_aw_qos,
output logic [3:0]              o_bus_axi_aw_region,
output logic [5:0]              o_bus_axi_aw_atop,
output logic [qnsc_cpu2axi_pkg::P_AXI_USER_W-1:0] o_bus_axi_aw_user,
output logic                    o_bus_axi_aw_valid,

input  logic                    i_bus_axi_w_ready,
output logic [31:0]             o_bus_axi_w_data,
output logic [3:0]              o_bus_axi_w_strb,
output logic                    o_bus_axi_w_last,
output logic [qnsc_cpu2axi_pkg::P_AXI_USER_W-1:0] o_bus_axi_w_user,
output logic                    o_bus_axi_w_valid,

output logic                    o_bus_axi_b_ready,
input  logic [qnsc_cpu2axi_pkg::P_MST_ID_W-1:0]  i_bus_axi_b_id,
input  logic [1:0]              i_bus_axi_b_resp,
input  logic [qnsc_cpu2axi_pkg::P_AXI_USER_W-1:0] i_bus_axi_b_user,
input  logic                    i_bus_axi_b_valid,

input  logic                    i_bus_axi_ar_ready,
output logic [qnsc_cpu2axi_pkg::P_MST_ID_W-1:0]  o_bus_axi_ar_id,
output logic [31:0]             o_bus_axi_ar_addr,
output logic [7:0]              o_bus_axi_ar_len,
output logic [2:0]              o_bus_axi_ar_size,
output logic [1:0]              o_bus_axi_ar_burst,
output logic                    o_bus_axi_ar_lock,
output logic [3:0]              o_bus_axi_ar_cache,
output logic [2:0]              o_bus_axi_ar_prot,
output logic [3:0]              o_bus_axi_ar_qos,
output logic [3:0]              o_bus_axi_ar_region,
output logic [qnsc_cpu2axi_pkg::P_AXI_USER_W-1:0] o_bus_axi_ar_user,
output logic                    o_bus_axi_ar_valid,

output logic                    o_bus_axi_r_ready,
input  logic [qnsc_cpu2axi_pkg::P_MST_ID_W-1:0]  i_bus_axi_r_id,
input  logic [31:0]             i_bus_axi_r_data,
input  logic [1:0]              i_bus_axi_r_resp,
input  logic                    i_bus_axi_r_last,
input  logic [qnsc_cpu2axi_pkg::P_AXI_USER_W-1:0] i_bus_axi_r_user,
input  logic                    i_bus_axi_r_valid
);

// ibex_top <-> m_qnsc_cpu2axi, pre-declared for explicit width.
logic        w_ibex_bridge_instr_req;
logic        w_ibex_bridge_instr_gnt;
logic        w_ibex_bridge_instr_rvalid;
logic [31:0] w_ibex_bridge_instr_addr;
logic [31:0] w_ibex_bridge_instr_rdata;
logic        w_ibex_bridge_instr_err;
logic        w_ibex_bridge_data_req;
logic        w_ibex_bridge_data_gnt;
logic        w_ibex_bridge_data_rvalid;
logic        w_ibex_bridge_data_we;
logic [3:0]  w_ibex_bridge_data_be;
logic [31:0] w_ibex_bridge_data_addr;
logic [31:0] w_ibex_bridge_data_wdata;
logic [31:0] w_ibex_bridge_data_rdata;
logic        w_ibex_bridge_data_err;

qnsc_cpu2axi_pkg::axi_s_1_req_t  w_bridge_axi_req;
qnsc_cpu2axi_pkg::axi_s_1_resp_t w_bridge_axi_resp;

/*AUTOWIRE*/

/*AUTO_LISP(setq verilog-auto-input-ignore-regexp
  (concat
  "unuse_input"
  "\\|rvfi_"
  ))
*/

/*AUTO_LISP(setq verilog-auto-output-ignore-regexp
  (concat
  "unuse_output"
  "\\|rvfi_"
  ))
*/

/* ibex_top AUTO_TEMPLATE(
    .clk_i                    (i_clk_cpu),
    .rst_ni                   (i_rst_n_cpu),
    .boot_addr_i              (i_cfg_boot_addr[]),
    .debug_req_i              (i_dbg_req),
    .irq_software_i           (1'b0),
    .irq_timer_i              (1'b0),
    .irq_external_i           (1'b0),
    .irq_fast_i               ({4'b0, i_int_fast}),
    .irq_nm_i                 (i_int_nm),
    .core_sleep_o             (o_pwr_sleep),
    .test_en_i                (i_dft_test_en),
    .scan_rst_ni              (1'b1),
    .instr_req_o              (w_ibex_bridge_instr_req),
    .instr_gnt_i              (w_ibex_bridge_instr_gnt),
    .instr_rvalid_i           (w_ibex_bridge_instr_rvalid),
    .instr_addr_o             (w_ibex_bridge_instr_addr[]),
    .instr_rdata_i            (w_ibex_bridge_instr_rdata[]),
    .instr_rdata_intg_i       (7'h0),
    .instr_err_i              (w_ibex_bridge_instr_err),
    .instr_req_shadow_o       (),
    .instr_addr_shadow_o      (),
    .data_req_o               (w_ibex_bridge_data_req),
    .data_gnt_i               (w_ibex_bridge_data_gnt),
    .data_rvalid_i            (w_ibex_bridge_data_rvalid),
    .data_we_o                (w_ibex_bridge_data_we),
    .data_be_o                (w_ibex_bridge_data_be[]),
    .data_addr_o              (w_ibex_bridge_data_addr[]),
    .data_wdata_o             (w_ibex_bridge_data_wdata[]),
    .data_wdata_intg_o        (),
    .data_tag_o               (),
    .data_rdata_i             (w_ibex_bridge_data_rdata[]),
    .data_rdata_intg_i        (7'h0),
    .data_tag_i               (1'b0),
    .data_err_i               (w_ibex_bridge_data_err),
    .data_req_shadow_o        (),
    .data_we_shadow_o         (),
    .data_be_shadow_o         (),
    .data_addr_shadow_o       (),
    .data_wdata_shadow_o      (),
    .data_wdata_intg_shadow_o (),
    .hart_id_i                (i_cfg_hart_id[]),
    .fetch_enable_i           (ibex_pkg::IbexMuBiOn),
    .mcounteren_writable_i    (ibex_pkg::IbexMuBiOn),
    .cheriot_enable_i         (ibex_pkg::IbexMuBiOff),
    .trvk_heap_base_addr_i    ('0),
    .trvk_revbm_req_o         (),
    .trvk_revbm_gnt_i         (1'b0),
    .trvk_revbm_rvalid_i      (1'b0),
    .trvk_revbm_addr_o        (),
    .trvk_revbm_rdata_i       ('0),
    .trvk_revbm_rdata_intg_i  (7'h0),
    .trvk_revbm_err_i         (1'b0),
    .scramble_key_valid_i     (1'b0),
    .scramble_key_i           ('0),
    .scramble_nonce_i         ('0),
    .scramble_req_o           (),
    .crash_dump_o             (),
    .double_fault_seen_o      (),
    .alert_minor_o            (),
    .alert_major_internal_o   (),
    .alert_major_bus_o        (),
    .lockstep_cmp_en_o        (),
    .ram_cfg_icache_tag_i     ('{default: prim_ram_1p_pkg::RAM_1P_CFG_REQ_DEFAULT}),
    .ram_cfg_icache_tag_o     (),
    .ram_cfg_icache_data_i    ('{default: prim_ram_1p_pkg::RAM_1P_CFG_REQ_DEFAULT}),
    .ram_cfg_icache_data_o    (),
);
*/
ibex_top #(
    .BaseIsa          (ibex_pkg::BaseIsaRV32I),
    .PMPEnable        (1'b0),
    .PMPGranularity   (0),
    .PMPNumRegions    (4),
    .MHPMCounterNum   (0),
    .MHPMCounterWidth (40),
    .RV32E            (1'b0),
    .RV32M            (ibex_pkg::RV32MFast),
    .RV32B            (ibex_pkg::RV32BNone),
    .RV32ZC           (ibex_pkg::RV32Zca),
    .RegFile          (ibex_pkg::RegFileFF),
    .BranchTargetALU  (1'b0),
    .WritebackStage   (1'b0),
    .ICache           (1'b0),
    .ICacheECC        (1'b0),
    .BranchPredictor  (1'b0),
    .DbgTriggerEn     (1'b1),  // leader review: HW trigger CSRs on
    .DbgHwBreakNum    (2),     // leader review: 2 HW breakpoints
    .SecureIbex       (1'b0),
    .LockstepOffset   (1),
    .ICacheScramble   (1'b0),
    .DmBaseAddr       (32'h2000_0000),                    // contract: memory_map.isram_dbg.base
    .DmAddrMask       (32'h0000_0FFF),
    .DmHaltAddr       (32'h2000_0000 + 32'h0000_0800),     // contract: memory_map.isram_dbg.base
    .DmExceptionAddr  (32'h2000_0000 + 32'h0000_0810),     // contract: memory_map.isram_dbg.base
    .CsrMvendorId     (32'h0),
    .CsrMimpId        (32'h1)  // leader review: implementation/revision id
) u_ibex_top(/*AUTOINST*/);

/* m_qnsc_cpu2axi AUTO_TEMPLATE(
    .i_clk_core    (i_clk_cpu),
    .i_rst_n_core  (i_rst_n_cpu),
    .i_instr_req   (w_ibex_bridge_instr_req),
    .o_instr_gnt   (w_ibex_bridge_instr_gnt),
    .o_instr_rvalid (w_ibex_bridge_instr_rvalid),
    .i_instr_addr  (w_ibex_bridge_instr_addr[]),
    .o_instr_rdata (w_ibex_bridge_instr_rdata[]),
    .o_instr_err   (w_ibex_bridge_instr_err),
    .i_data_req    (w_ibex_bridge_data_req),
    .o_data_gnt    (w_ibex_bridge_data_gnt),
    .o_data_rvalid (w_ibex_bridge_data_rvalid),
    .i_data_we     (w_ibex_bridge_data_we),
    .i_data_be     (w_ibex_bridge_data_be[]),
    .i_data_addr   (w_ibex_bridge_data_addr[]),
    .i_data_wdata  (w_ibex_bridge_data_wdata[]),
    .o_data_rdata  (w_ibex_bridge_data_rdata[]),
    .o_data_err    (w_ibex_bridge_data_err),
    .o_bus_axi_req (w_bridge_axi_req),
    .i_bus_axi_rsp (w_bridge_axi_resp),
);
*/
m_qnsc_cpu2axi u_m_qnsc_cpu2axi(/*AUTOINST*/);

// Pack/unpack: struct <-> flat AXI4 (hand-written, not AUTOINST).
assign o_bus_axi_aw_id     = w_bridge_axi_req.aw.id;
assign o_bus_axi_aw_addr   = w_bridge_axi_req.aw.addr;
assign o_bus_axi_aw_len    = w_bridge_axi_req.aw.len;
assign o_bus_axi_aw_size   = w_bridge_axi_req.aw.size;
assign o_bus_axi_aw_burst  = w_bridge_axi_req.aw.burst;
assign o_bus_axi_aw_lock   = w_bridge_axi_req.aw.lock;
assign o_bus_axi_aw_cache  = w_bridge_axi_req.aw.cache;
assign o_bus_axi_aw_prot   = w_bridge_axi_req.aw.prot;
assign o_bus_axi_aw_qos    = w_bridge_axi_req.aw.qos;
assign o_bus_axi_aw_region = w_bridge_axi_req.aw.region;
assign o_bus_axi_aw_atop   = w_bridge_axi_req.aw.atop;
assign o_bus_axi_aw_user   = w_bridge_axi_req.aw.user;
assign o_bus_axi_aw_valid  = w_bridge_axi_req.aw_valid;
assign w_bridge_axi_resp.aw_ready = i_bus_axi_aw_ready;

assign o_bus_axi_w_data  = w_bridge_axi_req.w.data;
assign o_bus_axi_w_strb  = w_bridge_axi_req.w.strb;
assign o_bus_axi_w_last  = w_bridge_axi_req.w.last;
assign o_bus_axi_w_user  = w_bridge_axi_req.w.user;
assign o_bus_axi_w_valid = w_bridge_axi_req.w_valid;
assign w_bridge_axi_resp.w_ready = i_bus_axi_w_ready;

assign o_bus_axi_b_ready = w_bridge_axi_req.b_ready;
assign w_bridge_axi_resp.b.id   = i_bus_axi_b_id;
assign w_bridge_axi_resp.b.resp = i_bus_axi_b_resp;
assign w_bridge_axi_resp.b.user = i_bus_axi_b_user;
assign w_bridge_axi_resp.b_valid = i_bus_axi_b_valid;

assign o_bus_axi_ar_id     = w_bridge_axi_req.ar.id;
assign o_bus_axi_ar_addr   = w_bridge_axi_req.ar.addr;
assign o_bus_axi_ar_len    = w_bridge_axi_req.ar.len;
assign o_bus_axi_ar_size   = w_bridge_axi_req.ar.size;
assign o_bus_axi_ar_burst  = w_bridge_axi_req.ar.burst;
assign o_bus_axi_ar_lock   = w_bridge_axi_req.ar.lock;
assign o_bus_axi_ar_cache  = w_bridge_axi_req.ar.cache;
assign o_bus_axi_ar_prot   = w_bridge_axi_req.ar.prot;
assign o_bus_axi_ar_qos    = w_bridge_axi_req.ar.qos;
assign o_bus_axi_ar_region = w_bridge_axi_req.ar.region;
assign o_bus_axi_ar_user   = w_bridge_axi_req.ar.user;
assign o_bus_axi_ar_valid  = w_bridge_axi_req.ar_valid;
assign w_bridge_axi_resp.ar_ready = i_bus_axi_ar_ready;

assign o_bus_axi_r_ready = w_bridge_axi_req.r_ready;
assign w_bridge_axi_resp.r.id   = i_bus_axi_r_id;
assign w_bridge_axi_resp.r.data = i_bus_axi_r_data;
assign w_bridge_axi_resp.r.resp = i_bus_axi_r_resp;
assign w_bridge_axi_resp.r.last = i_bus_axi_r_last;
assign w_bridge_axi_resp.r.user = i_bus_axi_r_user;
assign w_bridge_axi_resp.r_valid = i_bus_axi_r_valid;

endmodule
`default_nettype wire
// Local Variables:
// verilog-library-flags:("-f filelist_emacs.f" "-f filelist_emacs_bridge.f")
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: nil
// End:
