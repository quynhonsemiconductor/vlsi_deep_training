`timescale 1ns/1ps

module m_qnsc_wrap_cpu
  import ibex_pkg::*;
  import cpu2axi_pkg::*;
  import qnsc_pkg::*;
#(
  parameter logic [31:0] P_HART_ID = 32'h0
)
(
//---------------------------------------------------------------
// Clock/Reset
//---------------------------------------------------------------
/*AUTOINPUT("^i_clk\|^i_rst")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic		i_clk_cpu,		// To u_m_qnsc_wrap_ibex of m_qnsc_wrap_ibex.v, ...
input logic		i_rst_n_cpu,		// To u_m_qnsc_wrap_ibex of m_qnsc_wrap_ibex.v, ...
// End of automatics

//---------------------------------------------------------------
// Boot / Debug
//---------------------------------------------------------------
input  logic i_dbg_en,   // drives boot_addr mux: 0=cold boot, 1=debug-ROM entry
input  logic i_dbg_req,

//---------------------------------------------------------------
// Interrupt
//---------------------------------------------------------------
input  logic [10:0] i_int_fast,  // 11 real fast-IRQ sources; padded to ibex's 15 internally
input  logic         i_int_nm,   // WDT bark (NMI), from INTMAP

//---------------------------------------------------------------
// DFT
//---------------------------------------------------------------
input  logic i_dft_test_en,

//---------------------------------------------------------------
// Power
//---------------------------------------------------------------
/*AUTOOUTPUT("^o_pwr")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic		o_pwr_sleep,		// From u_m_qnsc_wrap_ibex of m_qnsc_wrap_ibex.v
// End of automatics

//---------------------------------------------------------------
// AXI4 master bus -- flattened per QNSC naming rule, pass-through
// from m_qnsc_wrap_cpu2axi to the subsystem boundary.
//---------------------------------------------------------------
/*AUTOINPUT("^i_bus_axi")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic		i_bus_axi_ar_ready,	// To u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
input logic		i_bus_axi_aw_ready,	// To u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
input logic [P_MST_ID_W-1:0] i_bus_axi_b_id,	// To u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
input logic [1:0]	i_bus_axi_b_resp,	// To u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
input logic [P_AXI_USER_W-1:0] i_bus_axi_b_user,// To u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
input logic		i_bus_axi_b_valid,	// To u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
input logic [31:0]	i_bus_axi_r_data,	// To u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
input logic [P_MST_ID_W-1:0] i_bus_axi_r_id,	// To u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
input logic		i_bus_axi_r_last,	// To u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
input logic [1:0]	i_bus_axi_r_resp,	// To u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
input logic [P_AXI_USER_W-1:0] i_bus_axi_r_user,// To u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
input logic		i_bus_axi_r_valid,	// To u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
input logic		i_bus_axi_w_ready,	// To u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
// End of automatics
/*AUTOOUTPUT("^o_bus_axi")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic [31:0]	o_bus_axi_ar_addr,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic [1:0]	o_bus_axi_ar_burst,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic [3:0]	o_bus_axi_ar_cache,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic [P_MST_ID_W-1:0] o_bus_axi_ar_id,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic [7:0]	o_bus_axi_ar_len,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic		o_bus_axi_ar_lock,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic [2:0]	o_bus_axi_ar_prot,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic [3:0]	o_bus_axi_ar_qos,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic [3:0]	o_bus_axi_ar_region,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic [2:0]	o_bus_axi_ar_size,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic [P_AXI_USER_W-1:0] o_bus_axi_ar_user,// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic		o_bus_axi_ar_valid,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic [31:0]	o_bus_axi_aw_addr,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic [5:0]	o_bus_axi_aw_atop,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic [1:0]	o_bus_axi_aw_burst,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic [3:0]	o_bus_axi_aw_cache,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic [P_MST_ID_W-1:0] o_bus_axi_aw_id,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic [7:0]	o_bus_axi_aw_len,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic		o_bus_axi_aw_lock,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic [2:0]	o_bus_axi_aw_prot,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic [3:0]	o_bus_axi_aw_qos,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic [3:0]	o_bus_axi_aw_region,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic [2:0]	o_bus_axi_aw_size,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic [P_AXI_USER_W-1:0] o_bus_axi_aw_user,// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic		o_bus_axi_aw_valid,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic		o_bus_axi_b_ready,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic		o_bus_axi_r_ready,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic [31:0]	o_bus_axi_w_data,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic		o_bus_axi_w_last,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic [3:0]	o_bus_axi_w_strb,	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic [P_AXI_USER_W-1:0] o_bus_axi_w_user,// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
output logic		o_bus_axi_w_valid	// From u_m_qnsc_wrap_cpu2axi of m_qnsc_wrap_cpu2axi.v
// End of automatics
);

localparam logic [31:0] P_BOOT_ADDR_COLD = 32'h0000_0000;
// C_ISRAM_BASE, not C_ISRAM_DBG_BASE: debug boot jumps straight to the
// downloaded application at ISRAM's program region (0x2000_1000, entry at
// +0x80 = 0x2000_1080 per HAS Table 6-4 row 18 / ROM MAS V2.1 Section 8),
// not to the 4 KiB debug/DM window C_ISRAM_DBG_BASE (0x2000_0000) that
// DmBaseAddr already uses below -- those are two different regions.
localparam logic [31:0] P_BOOT_ADDR_DBG  = qnsc_pkg::C_ISRAM_BASE;

logic [31:0] w_boot_addr;
assign w_boot_addr = i_dbg_en ? P_BOOT_ADDR_DBG : P_BOOT_ADDR_COLD;

// Pre-declared with explicit widths: AUTOWIRE cannot reliably infer width
// for a wire referenced across two separate AUTOINST/AUTO_TEMPLATE blocks
// (same tool limitation seen on m_qnsc_wrap_ibex's scramble_key/nonce).
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

/*AUTOWIRE*/

/* m_qnsc_wrap_ibex AUTO_TEMPLATE(
    .i_boot_addr             (w_boot_addr),
    .i_dbg_req               (i_dbg_req),
    .i_int_software          (1'b0),
    .i_int_timer             (1'b0),
    .i_int_external          (1'b0),
    .i_int_fast              ({4'b0, i_int_fast}),
    .i_int_nm                (i_int_nm),
    .i_dft_scan_rst_n        (1'b1),
    .i_hart_id               (P_HART_ID),
    .i_cheriot_enable        (ibex_pkg::IbexMuBiOff),
    .i_fetch_enable          (ibex_pkg::IbexMuBiOn),
    .i_mcounteren_writable   (ibex_pkg::IbexMuBiOn),
    .i_scramble_key_valid    (1'b0),
    .i_scramble_key          ('0),
    .i_scramble_nonce        ('0),
    .i_trvk_heap_base_addr   ('0),
    .i_trvk_revbm_gnt        (1'b0),
    .i_trvk_revbm_rvalid     (1'b0),
    .i_trvk_revbm_rdata      ('0),
    .i_trvk_revbm_rdata_intg (7'h0),
    .i_trvk_revbm_err        (1'b0),
    .o_trvk_revbm_req        (),
    .o_trvk_revbm_addr       (),
    .o_scramble_req          (),
    .o_crash_dump            (),
    .o_double_fault_seen     (),
    .o_alert_minor           (),
    .o_alert_major_internal  (),
    .o_alert_major_bus       (),
    .o_lockstep_cmp_en       (),
    .i_mem_icache_data_cfg   ('{default: prim_ram_1p_pkg::RAM_1P_CFG_REQ_DEFAULT}),
    .i_mem_icache_tag_cfg    ('{default: prim_ram_1p_pkg::RAM_1P_CFG_REQ_DEFAULT}),
    .o_mem_icache_data_cfg   (),
    .o_mem_icache_tag_cfg    (),
    .i_mem_instr_rdata_intg  (7'h0),
    .i_mem_data_rdata_intg   (7'h0),
    .i_mem_data_tag          (1'b0),
    .o_mem_data_tag          (),
    .o_mem_data_wdata_intg   (),
    .o_mem_instr_req_shadow  (),
    .o_mem_instr_addr_shadow (),
    .o_mem_data_req_shadow   (),
    .o_mem_data_we_shadow    (),
    .o_mem_data_be_shadow    (),
    .o_mem_data_addr_shadow  (),
    .o_mem_data_wdata_shadow (),
    .o_mem_data_wdata_intg_shadow (),
    .o_mem_instr_req         (w_ibex_bridge_instr_req),
    .i_mem_instr_gnt         (w_ibex_bridge_instr_gnt),
    .i_mem_instr_rvalid      (w_ibex_bridge_instr_rvalid),
    .o_mem_instr_addr        (w_ibex_bridge_instr_addr),
    .i_mem_instr_rdata       (w_ibex_bridge_instr_rdata),
    .i_mem_instr_err         (w_ibex_bridge_instr_err),
    .o_mem_data_req          (w_ibex_bridge_data_req),
    .i_mem_data_gnt          (w_ibex_bridge_data_gnt),
    .i_mem_data_rvalid       (w_ibex_bridge_data_rvalid),
    .o_mem_data_we           (w_ibex_bridge_data_we),
    .o_mem_data_be           (w_ibex_bridge_data_be),
    .o_mem_data_addr         (w_ibex_bridge_data_addr),
    .o_mem_data_wdata        (w_ibex_bridge_data_wdata),
    .i_mem_data_rdata        (w_ibex_bridge_data_rdata),
    .i_mem_data_err          (w_ibex_bridge_data_err),
);
*/
m_qnsc_wrap_ibex u_m_qnsc_wrap_ibex(/*AUTOINST*/
				    // Interfaces
				    .i_cheriot_enable	(ibex_pkg::IbexMuBiOff), // Templated
				    .i_fetch_enable	(ibex_pkg::IbexMuBiOn), // Templated
				    .i_mcounteren_writable(ibex_pkg::IbexMuBiOn), // Templated
				    .o_crash_dump	(),		 // Templated
				    .o_lockstep_cmp_en	(),		 // Templated
				    // Outputs
				    .o_pwr_sleep	(o_pwr_sleep),
				    .o_mem_instr_addr	(w_ibex_bridge_instr_addr), // Templated
				    .o_mem_instr_addr_shadow(),		 // Templated
				    .o_mem_instr_req	(w_ibex_bridge_instr_req), // Templated
				    .o_mem_instr_req_shadow(),		 // Templated
				    .o_mem_data_addr	(w_ibex_bridge_data_addr), // Templated
				    .o_mem_data_addr_shadow(),		 // Templated
				    .o_mem_data_be	(w_ibex_bridge_data_be), // Templated
				    .o_mem_data_be_shadow(),		 // Templated
				    .o_mem_data_req	(w_ibex_bridge_data_req), // Templated
				    .o_mem_data_req_shadow(),		 // Templated
				    .o_mem_data_tag	(),		 // Templated
				    .o_mem_data_wdata	(w_ibex_bridge_data_wdata), // Templated
				    .o_mem_data_wdata_intg(),		 // Templated
				    .o_mem_data_wdata_intg_shadow(),	 // Templated
				    .o_mem_data_wdata_shadow(),		 // Templated
				    .o_mem_data_we	(w_ibex_bridge_data_we), // Templated
				    .o_mem_data_we_shadow(),		 // Templated
				    .o_alert_major_bus	(),		 // Templated
				    .o_alert_major_internal(),		 // Templated
				    .o_alert_minor	(),		 // Templated
				    .o_double_fault_seen(),		 // Templated
				    .o_mem_icache_data_cfg(),		 // Templated
				    .o_mem_icache_tag_cfg(),		 // Templated
				    .o_scramble_req	(),		 // Templated
				    .o_trvk_revbm_addr	(),		 // Templated
				    .o_trvk_revbm_req	(),		 // Templated
				    // Inputs
				    .i_clk_cpu		(i_clk_cpu),
				    .i_rst_n_cpu	(i_rst_n_cpu),
				    .i_boot_addr	(w_boot_addr),	 // Templated
				    .i_dbg_req		(i_dbg_req),	 // Templated
				    .i_int_external	(1'b0),		 // Templated
				    .i_int_fast		({4'b0, i_int_fast}), // Templated
				    .i_int_nm		(i_int_nm),	 // Templated
				    .i_int_software	(1'b0),		 // Templated
				    .i_int_timer	(1'b0),		 // Templated
				    .i_dft_scan_rst_n	(1'b1),		 // Templated
				    .i_dft_test_en	(i_dft_test_en),
				    .i_mem_instr_err	(w_ibex_bridge_instr_err), // Templated
				    .i_mem_instr_gnt	(w_ibex_bridge_instr_gnt), // Templated
				    .i_mem_instr_rdata	(w_ibex_bridge_instr_rdata), // Templated
				    .i_mem_instr_rdata_intg(7'h0),	 // Templated
				    .i_mem_instr_rvalid	(w_ibex_bridge_instr_rvalid), // Templated
				    .i_mem_data_err	(w_ibex_bridge_data_err), // Templated
				    .i_mem_data_gnt	(w_ibex_bridge_data_gnt), // Templated
				    .i_mem_data_rdata	(w_ibex_bridge_data_rdata), // Templated
				    .i_mem_data_rdata_intg(7'h0),	 // Templated
				    .i_mem_data_rvalid	(w_ibex_bridge_data_rvalid), // Templated
				    .i_mem_data_tag	(1'b0),		 // Templated
				    .i_hart_id		(P_HART_ID),	 // Templated
				    .i_mem_icache_data_cfg('{default: prim_ram_1p_pkg::RAM_1P_CFG_REQ_DEFAULT}), // Templated
				    .i_mem_icache_tag_cfg('{default: prim_ram_1p_pkg::RAM_1P_CFG_REQ_DEFAULT}), // Templated
				    .i_scramble_key	('0),		 // Templated
				    .i_scramble_key_valid(1'b0),	 // Templated
				    .i_scramble_nonce	('0),		 // Templated
				    .i_trvk_heap_base_addr('0),		 // Templated
				    .i_trvk_revbm_err	(1'b0),		 // Templated
				    .i_trvk_revbm_gnt	(1'b0),		 // Templated
				    .i_trvk_revbm_rdata	('0),		 // Templated
				    .i_trvk_revbm_rdata_intg(7'h0),	 // Templated
				    .i_trvk_revbm_rvalid(1'b0));		 // Templated

/* m_qnsc_wrap_cpu2axi AUTO_TEMPLATE(
    .i_mem_instr_req    (w_ibex_bridge_instr_req),
    .o_mem_instr_gnt    (w_ibex_bridge_instr_gnt),
    .o_mem_instr_rvalid (w_ibex_bridge_instr_rvalid),
    .i_mem_instr_addr   (w_ibex_bridge_instr_addr),
    .o_mem_instr_rdata  (w_ibex_bridge_instr_rdata),
    .o_mem_instr_err    (w_ibex_bridge_instr_err),
    .i_mem_data_req     (w_ibex_bridge_data_req),
    .o_mem_data_gnt     (w_ibex_bridge_data_gnt),
    .o_mem_data_rvalid  (w_ibex_bridge_data_rvalid),
    .i_mem_data_we      (w_ibex_bridge_data_we),
    .i_mem_data_be      (w_ibex_bridge_data_be),
    .i_mem_data_addr    (w_ibex_bridge_data_addr),
    .i_mem_data_wdata   (w_ibex_bridge_data_wdata),
    .o_mem_data_rdata   (w_ibex_bridge_data_rdata),
    .o_mem_data_err     (w_ibex_bridge_data_err),
);
*/
m_qnsc_wrap_cpu2axi u_m_qnsc_wrap_cpu2axi(/*AUTOINST*/
					  // Outputs
					  .o_mem_instr_err	(w_ibex_bridge_instr_err), // Templated
					  .o_mem_instr_gnt	(w_ibex_bridge_instr_gnt), // Templated
					  .o_mem_instr_rdata	(w_ibex_bridge_instr_rdata), // Templated
					  .o_mem_instr_rvalid	(w_ibex_bridge_instr_rvalid), // Templated
					  .o_mem_data_err	(w_ibex_bridge_data_err), // Templated
					  .o_mem_data_gnt	(w_ibex_bridge_data_gnt), // Templated
					  .o_mem_data_rdata	(w_ibex_bridge_data_rdata), // Templated
					  .o_mem_data_rvalid	(w_ibex_bridge_data_rvalid), // Templated
					  .o_bus_axi_aw_id	(o_bus_axi_aw_id[P_MST_ID_W-1:0]),
					  .o_bus_axi_aw_addr	(o_bus_axi_aw_addr[31:0]),
					  .o_bus_axi_aw_len	(o_bus_axi_aw_len[7:0]),
					  .o_bus_axi_aw_size	(o_bus_axi_aw_size[2:0]),
					  .o_bus_axi_aw_burst	(o_bus_axi_aw_burst[1:0]),
					  .o_bus_axi_aw_lock	(o_bus_axi_aw_lock),
					  .o_bus_axi_aw_cache	(o_bus_axi_aw_cache[3:0]),
					  .o_bus_axi_aw_prot	(o_bus_axi_aw_prot[2:0]),
					  .o_bus_axi_aw_qos	(o_bus_axi_aw_qos[3:0]),
					  .o_bus_axi_aw_region	(o_bus_axi_aw_region[3:0]),
					  .o_bus_axi_aw_atop	(o_bus_axi_aw_atop[5:0]),
					  .o_bus_axi_aw_user	(o_bus_axi_aw_user[P_AXI_USER_W-1:0]),
					  .o_bus_axi_aw_valid	(o_bus_axi_aw_valid),
					  .o_bus_axi_w_data	(o_bus_axi_w_data[31:0]),
					  .o_bus_axi_w_strb	(o_bus_axi_w_strb[3:0]),
					  .o_bus_axi_w_last	(o_bus_axi_w_last),
					  .o_bus_axi_w_user	(o_bus_axi_w_user[P_AXI_USER_W-1:0]),
					  .o_bus_axi_w_valid	(o_bus_axi_w_valid),
					  .o_bus_axi_b_ready	(o_bus_axi_b_ready),
					  .o_bus_axi_ar_id	(o_bus_axi_ar_id[P_MST_ID_W-1:0]),
					  .o_bus_axi_ar_addr	(o_bus_axi_ar_addr[31:0]),
					  .o_bus_axi_ar_len	(o_bus_axi_ar_len[7:0]),
					  .o_bus_axi_ar_size	(o_bus_axi_ar_size[2:0]),
					  .o_bus_axi_ar_burst	(o_bus_axi_ar_burst[1:0]),
					  .o_bus_axi_ar_lock	(o_bus_axi_ar_lock),
					  .o_bus_axi_ar_cache	(o_bus_axi_ar_cache[3:0]),
					  .o_bus_axi_ar_prot	(o_bus_axi_ar_prot[2:0]),
					  .o_bus_axi_ar_qos	(o_bus_axi_ar_qos[3:0]),
					  .o_bus_axi_ar_region	(o_bus_axi_ar_region[3:0]),
					  .o_bus_axi_ar_user	(o_bus_axi_ar_user[P_AXI_USER_W-1:0]),
					  .o_bus_axi_ar_valid	(o_bus_axi_ar_valid),
					  .o_bus_axi_r_ready	(o_bus_axi_r_ready),
					  // Inputs
					  .i_clk_cpu		(i_clk_cpu),
					  .i_rst_n_cpu		(i_rst_n_cpu),
					  .i_mem_instr_addr	(w_ibex_bridge_instr_addr), // Templated
					  .i_mem_instr_req	(w_ibex_bridge_instr_req), // Templated
					  .i_mem_data_addr	(w_ibex_bridge_data_addr), // Templated
					  .i_mem_data_be	(w_ibex_bridge_data_be), // Templated
					  .i_mem_data_req	(w_ibex_bridge_data_req), // Templated
					  .i_mem_data_wdata	(w_ibex_bridge_data_wdata), // Templated
					  .i_mem_data_we	(w_ibex_bridge_data_we), // Templated
					  .i_bus_axi_aw_ready	(i_bus_axi_aw_ready),
					  .i_bus_axi_w_ready	(i_bus_axi_w_ready),
					  .i_bus_axi_b_id	(i_bus_axi_b_id[P_MST_ID_W-1:0]),
					  .i_bus_axi_b_resp	(i_bus_axi_b_resp[1:0]),
					  .i_bus_axi_b_user	(i_bus_axi_b_user[P_AXI_USER_W-1:0]),
					  .i_bus_axi_b_valid	(i_bus_axi_b_valid),
					  .i_bus_axi_ar_ready	(i_bus_axi_ar_ready),
					  .i_bus_axi_r_id	(i_bus_axi_r_id[P_MST_ID_W-1:0]),
					  .i_bus_axi_r_data	(i_bus_axi_r_data[31:0]),
					  .i_bus_axi_r_resp	(i_bus_axi_r_resp[1:0]),
					  .i_bus_axi_r_last	(i_bus_axi_r_last),
					  .i_bus_axi_r_user	(i_bus_axi_r_user[P_AXI_USER_W-1:0]),
					  .i_bus_axi_r_valid	(i_bus_axi_r_valid));

endmodule
// Local Variables:
// verilog-library-flags:("-f filelist_emacs_subsystem.f")
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: nil
// End:
