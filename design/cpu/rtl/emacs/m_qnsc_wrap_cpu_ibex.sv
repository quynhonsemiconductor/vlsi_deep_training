`default_nettype none
`timescale 1ns/1ps

module m_qnsc_wrap_cpu_ibex
#(
)
(
//---------------------------------------------------------------
// Clock/Reset
//---------------------------------------------------------------
/*AUTOINPUT("^i_clk\|^i_rst")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic		i_clk_cpu,		// To u_ibex_top of ibex_top.v
input logic		i_rst_n_cpu,		// To u_ibex_top of ibex_top.v
// End of automatics

//---------------------------------------------------------------
// Boot
//---------------------------------------------------------------
/*AUTOINPUT("^i_boot")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic [31:0]	i_boot_addr,		// To u_ibex_top of ibex_top.v
// End of automatics

//---------------------------------------------------------------
// Debug
//---------------------------------------------------------------
/*AUTOINPUT("^i_dbg")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic		i_dbg_req,		// To u_ibex_top of ibex_top.v
// End of automatics
/*AUTOOUTPUT("^o_dbg")*/

//---------------------------------------------------------------
// Interrupt
//---------------------------------------------------------------
/*AUTOINPUT("^i_int")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic		i_int_external,		// To u_ibex_top of ibex_top.v
input logic [14:0]	i_int_fast,		// To u_ibex_top of ibex_top.v
input logic		i_int_nm,		// To u_ibex_top of ibex_top.v
input logic		i_int_software,		// To u_ibex_top of ibex_top.v
input logic		i_int_timer,		// To u_ibex_top of ibex_top.v
// End of automatics

//---------------------------------------------------------------
// Power
//---------------------------------------------------------------
/*AUTOOUTPUT("^o_pwr")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic		o_pwr_sleep,		// From u_ibex_top of ibex_top.v
// End of automatics

//---------------------------------------------------------------
// DFT
//---------------------------------------------------------------
/*AUTOINPUT("^i_dft")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic		i_dft_scan_rst_n,	// To u_ibex_top of ibex_top.v
input logic		i_dft_test_en,		// To u_ibex_top of ibex_top.v
// End of automatics

//---------------------------------------------------------------
// Instruction memory interface
//---------------------------------------------------------------
/*AUTOINPUT("^i_mem_instr")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic		i_mem_instr_err,	// To u_ibex_top of ibex_top.v
input logic		i_mem_instr_gnt,	// To u_ibex_top of ibex_top.v
input logic [31:0]	i_mem_instr_rdata,	// To u_ibex_top of ibex_top.v
input logic [6:0]	i_mem_instr_rdata_intg,	// To u_ibex_top of ibex_top.v
input logic		i_mem_instr_rvalid,	// To u_ibex_top of ibex_top.v
// End of automatics
/*AUTOOUTPUT("^o_mem_instr")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic [31:0]	o_mem_instr_addr,	// From u_ibex_top of ibex_top.v
output logic [31:0]	o_mem_instr_addr_shadow,// From u_ibex_top of ibex_top.v
output logic		o_mem_instr_req,	// From u_ibex_top of ibex_top.v
output logic		o_mem_instr_req_shadow,	// From u_ibex_top of ibex_top.v
// End of automatics

//---------------------------------------------------------------
// Data memory interface
//---------------------------------------------------------------
/*AUTOINPUT("^i_mem_data")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic		i_mem_data_err,		// To u_ibex_top of ibex_top.v
input logic		i_mem_data_gnt,		// To u_ibex_top of ibex_top.v
input logic [31:0]	i_mem_data_rdata,	// To u_ibex_top of ibex_top.v
input logic [6:0]	i_mem_data_rdata_intg,	// To u_ibex_top of ibex_top.v
input logic		i_mem_data_rvalid,	// To u_ibex_top of ibex_top.v
input logic		i_mem_data_tag,		// To u_ibex_top of ibex_top.v
// End of automatics
/*AUTOOUTPUT("^o_mem_data")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic [31:0]	o_mem_data_addr,	// From u_ibex_top of ibex_top.v
output logic [31:0]	o_mem_data_addr_shadow,	// From u_ibex_top of ibex_top.v
output logic [3:0]	o_mem_data_be,		// From u_ibex_top of ibex_top.v
output logic [3:0]	o_mem_data_be_shadow,	// From u_ibex_top of ibex_top.v
output logic		o_mem_data_req,		// From u_ibex_top of ibex_top.v
output logic		o_mem_data_req_shadow,	// From u_ibex_top of ibex_top.v
output logic		o_mem_data_tag,		// From u_ibex_top of ibex_top.v
output logic [31:0]	o_mem_data_wdata,	// From u_ibex_top of ibex_top.v
output logic [6:0]	o_mem_data_wdata_intg,	// From u_ibex_top of ibex_top.v
output logic [6:0]	o_mem_data_wdata_intg_shadow,// From u_ibex_top of ibex_top.v
output logic [31:0]	o_mem_data_wdata_shadow,// From u_ibex_top of ibex_top.v
output logic		o_mem_data_we,		// From u_ibex_top of ibex_top.v
output logic		o_mem_data_we_shadow,	// From u_ibex_top of ibex_top.v
// End of automatics

//---------------------------------------------------------------
// Others (no QNSC-standard category: CHERIoT/TRVK unused, scrambling
// unused, lockstep/alert/diagnostic outputs unused -- SecureIbex=0,
// BaseIsa=RV32I in this project; kept as plain i_/o_ ports since they
// are still real ibex_top ports that must be terminated somewhere)
//---------------------------------------------------------------
/*AUTOINOUT*/
/*AUTOINPUT*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic [31:0]	i_hart_id,		// To u_ibex_top of ibex_top.v
input  ibex_pkg::ibex_mubi_t	i_cheriot_enable,	// To u_ibex_top of ibex_top.v
input  ibex_pkg::ibex_mubi_t	i_fetch_enable,		// To u_ibex_top of ibex_top.v
input  ibex_pkg::ibex_mubi_t	i_mcounteren_writable,	// To u_ibex_top of ibex_top.v
input  prim_ram_1p_pkg::ram_1p_cfg_req_t [ibex_pkg::IC_NUM_WAYS-1:0] i_mem_icache_data_cfg, // To u_ibex_top of ibex_top.v
input  prim_ram_1p_pkg::ram_1p_cfg_req_t [ibex_pkg::IC_NUM_WAYS-1:0] i_mem_icache_tag_cfg,  // To u_ibex_top of ibex_top.v
input logic [127:0] i_scramble_key,// To u_ibex_top of ibex_top.v
input logic		i_scramble_key_valid,	// To u_ibex_top of ibex_top.v
input logic [63:0] i_scramble_nonce,// To u_ibex_top of ibex_top.v
input logic [31:0]	i_trvk_heap_base_addr,	// To u_ibex_top of ibex_top.v
input logic		i_trvk_revbm_err,	// To u_ibex_top of ibex_top.v
input logic		i_trvk_revbm_gnt,	// To u_ibex_top of ibex_top.v
input logic [31:0]	i_trvk_revbm_rdata,	// To u_ibex_top of ibex_top.v
input logic [6:0]	i_trvk_revbm_rdata_intg,// To u_ibex_top of ibex_top.v
input logic		i_trvk_revbm_rvalid,	// To u_ibex_top of ibex_top.v
// End of automatics
/*AUTOOUTPUT*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic		o_alert_major_bus,	// From u_ibex_top of ibex_top.v
output logic		o_alert_major_internal,	// From u_ibex_top of ibex_top.v
output logic		o_alert_minor,		// From u_ibex_top of ibex_top.v
output logic		o_double_fault_seen,	// From u_ibex_top of ibex_top.v
output prim_ram_1p_pkg::ram_1p_cfg_rsp_t [ibex_pkg::IC_NUM_WAYS-1:0] o_mem_icache_data_cfg, // From u_ibex_top of ibex_top.v
output prim_ram_1p_pkg::ram_1p_cfg_rsp_t [ibex_pkg::IC_NUM_WAYS-1:0] o_mem_icache_tag_cfg,  // From u_ibex_top of ibex_top.v
output logic		o_scramble_req,		// From u_ibex_top of ibex_top.v
output logic [31:0]	o_trvk_revbm_addr,	// From u_ibex_top of ibex_top.v
output logic		o_trvk_revbm_req,	// From u_ibex_top of ibex_top.v
output ibex_pkg::crash_dump_t	o_crash_dump,		// From u_ibex_top of ibex_top.v
output ibex_pkg::ibex_mubi_t	o_lockstep_cmp_en	// From u_ibex_top of ibex_top.v
// End of automatics
);

/*AUTOWIRE*/
// Beginning of automatic wires (for undeclared instantiated-module outputs)
// End of automatics

/*AUTO_LISP(setq verilog-auto-inout-ignore-regexp
  (concat
  "unuse_inout"
  "\\|unuse_inout"
  ))
*/

/*AUTO_LISP(setq verilog-auto-input-ignore-regexp
  (concat
  "unuse_input"
  ))
*/

/*AUTO_LISP(setq verilog-auto-output-ignore-regexp
  (concat
  "unuse_output"
  ))
*/

/* ibex_top AUTO_TEMPLATE(
    .clk_i                    (i_clk_cpu),
    .rst_ni                   (i_rst_n_cpu),
    .boot_addr_i              (i_boot_addr[]),
    .debug_req_i              (i_dbg_req),
    .irq_software_i           (i_int_software),
    .irq_timer_i              (i_int_timer),
    .irq_external_i           (i_int_external),
    .irq_fast_i               (i_int_fast[]),
    .irq_nm_i                 (i_int_nm),
    .core_sleep_o             (o_pwr_sleep),
    .test_en_i                (i_dft_test_en),
    .scan_rst_ni              (i_dft_scan_rst_n),
    .instr_req_o              (o_mem_instr_req),
    .instr_gnt_i              (i_mem_instr_gnt),
    .instr_rvalid_i           (i_mem_instr_rvalid),
    .instr_addr_o             (o_mem_instr_addr[]),
    .instr_rdata_i            (i_mem_instr_rdata[]),
    .instr_rdata_intg_i       (i_mem_instr_rdata_intg[]),
    .instr_err_i              (i_mem_instr_err),
    .instr_req_shadow_o       (o_mem_instr_req_shadow),
    .instr_addr_shadow_o      (o_mem_instr_addr_shadow[]),
    .data_req_o               (o_mem_data_req),
    .data_gnt_i               (i_mem_data_gnt),
    .data_rvalid_i            (i_mem_data_rvalid),
    .data_we_o                (o_mem_data_we),
    .data_be_o                (o_mem_data_be[]),
    .data_addr_o              (o_mem_data_addr[]),
    .data_wdata_o             (o_mem_data_wdata[]),
    .data_wdata_intg_o        (o_mem_data_wdata_intg[]),
    .data_tag_o               (o_mem_data_tag),
    .data_rdata_i             (i_mem_data_rdata[]),
    .data_rdata_intg_i        (i_mem_data_rdata_intg[]),
    .data_tag_i               (i_mem_data_tag),
    .data_err_i               (i_mem_data_err),
    .data_req_shadow_o        (o_mem_data_req_shadow),
    .data_we_shadow_o         (o_mem_data_we_shadow),
    .data_be_shadow_o         (o_mem_data_be_shadow[]),
    .data_addr_shadow_o       (o_mem_data_addr_shadow[]),
    .data_wdata_shadow_o      (o_mem_data_wdata_shadow[]),
    .data_wdata_intg_shadow_o (o_mem_data_wdata_intg_shadow[]),
    .hart_id_i                (i_hart_id[]),
    .fetch_enable_i           (i_fetch_enable),
    .mcounteren_writable_i    (i_mcounteren_writable),
    .cheriot_enable_i         (i_cheriot_enable),
    .trvk_heap_base_addr_i    (i_trvk_heap_base_addr[]),
    .trvk_revbm_req_o         (o_trvk_revbm_req),
    .trvk_revbm_gnt_i         (i_trvk_revbm_gnt),
    .trvk_revbm_rvalid_i      (i_trvk_revbm_rvalid),
    .trvk_revbm_addr_o        (o_trvk_revbm_addr[]),
    .trvk_revbm_rdata_i       (i_trvk_revbm_rdata[]),
    .trvk_revbm_rdata_intg_i  (i_trvk_revbm_rdata_intg[]),
    .trvk_revbm_err_i         (i_trvk_revbm_err),
    .scramble_key_valid_i     (i_scramble_key_valid),
    .scramble_key_i           (i_scramble_key[]),
    .scramble_nonce_i         (i_scramble_nonce[]),
    .scramble_req_o           (o_scramble_req),
    .crash_dump_o             (o_crash_dump),
    .double_fault_seen_o      (o_double_fault_seen),
    .alert_minor_o            (o_alert_minor),
    .alert_major_internal_o  (o_alert_major_internal),
    .alert_major_bus_o        (o_alert_major_bus),
    .lockstep_cmp_en_o        (o_lockstep_cmp_en),
    .ram_cfg_icache_tag_i     (i_mem_icache_tag_cfg[]),
    .ram_cfg_icache_tag_o     (o_mem_icache_tag_cfg[]),
    .ram_cfg_icache_data_i    (i_mem_icache_data_cfg[]),
    .ram_cfg_icache_data_o    (o_mem_icache_data_cfg[]),
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
    .DbgTriggerEn     (1'b1),  // leader review 2026-09-28: enable hw trigger CSRs for HW breakpoints
    .DbgHwBreakNum    (2),     // leader review 2026-09-28: 2 HW breakpoints for GDB/OpenOCD debugging
    .SecureIbex       (1'b0),
    .LockstepOffset   (1),
    .ICacheScramble   (1'b0),
    // IP does not use qnsc_pkg (design/README.md) -- the debug/DM window base
    // is written as a fixed value with a contract tag instead of
    // qnsc_pkg::C_ISRAM_DBG_BASE; contract_tag.py checks the literal against
    // util/qsoc_contract.yml so it cannot silently drift from the real value.
    .DmBaseAddr       (32'h2000_0000),                    // contract: memory_map.isram_dbg.base
    .DmAddrMask       (32'h0000_0FFF),
    .DmHaltAddr       (32'h2000_0000 + 32'h0000_0800),     // contract: memory_map.isram_dbg.base
    .DmExceptionAddr  (32'h2000_0000 + 32'h0000_0810),     // contract: memory_map.isram_dbg.base
    .CsrMvendorId     (32'h0),
    .CsrMimpId        (32'h1)  // leader review 2026-09-28: encode implementation/revision
) u_ibex_top(/*AUTOINST*/
	     // Interfaces
	     .cheriot_enable_i		(i_cheriot_enable),	 // Templated
	     .crash_dump_o		(o_crash_dump),		 // Templated
	     .fetch_enable_i		(i_fetch_enable),	 // Templated
	     .mcounteren_writable_i	(i_mcounteren_writable), // Templated
	     .lockstep_cmp_en_o		(o_lockstep_cmp_en),	 // Templated
	     // Outputs
	     .ram_cfg_icache_tag_o	(o_mem_icache_tag_cfg),	 // Templated
	     .ram_cfg_icache_data_o	(o_mem_icache_data_cfg), // Templated
	     .instr_req_o		(o_mem_instr_req),	 // Templated
	     .instr_addr_o		(o_mem_instr_addr[31:0]), // Templated
	     .data_req_o		(o_mem_data_req),	 // Templated
	     .data_we_o			(o_mem_data_we),	 // Templated
	     .data_be_o			(o_mem_data_be[3:0]),	 // Templated
	     .data_addr_o		(o_mem_data_addr[31:0]), // Templated
	     .data_wdata_o		(o_mem_data_wdata[31:0]), // Templated
	     .data_wdata_intg_o		(o_mem_data_wdata_intg[6:0]), // Templated
	     .data_tag_o		(o_mem_data_tag),	 // Templated
	     .trvk_revbm_req_o		(o_trvk_revbm_req),	 // Templated
	     .trvk_revbm_addr_o		(o_trvk_revbm_addr[31:0]), // Templated
	     .scramble_req_o		(o_scramble_req),	 // Templated
	     .double_fault_seen_o	(o_double_fault_seen),	 // Templated
	     .alert_minor_o		(o_alert_minor),	 // Templated
	     .alert_major_internal_o	(o_alert_major_internal), // Templated
	     .alert_major_bus_o		(o_alert_major_bus),	 // Templated
	     .core_sleep_o		(o_pwr_sleep),		 // Templated
	     .data_req_shadow_o		(o_mem_data_req_shadow), // Templated
	     .data_we_shadow_o		(o_mem_data_we_shadow),	 // Templated
	     .data_be_shadow_o		(o_mem_data_be_shadow[3:0]), // Templated
	     .data_addr_shadow_o	(o_mem_data_addr_shadow[31:0]), // Templated
	     .data_wdata_shadow_o	(o_mem_data_wdata_shadow[31:0]), // Templated
	     .data_wdata_intg_shadow_o	(o_mem_data_wdata_intg_shadow[6:0]), // Templated
	     .instr_req_shadow_o	(o_mem_instr_req_shadow), // Templated
	     .instr_addr_shadow_o	(o_mem_instr_addr_shadow[31:0]), // Templated
	     // Inputs
	     .clk_i			(i_clk_cpu),		 // Templated
	     .rst_ni			(i_rst_n_cpu),		 // Templated
	     .test_en_i			(i_dft_test_en),	 // Templated
	     .ram_cfg_icache_tag_i	(i_mem_icache_tag_cfg),	 // Templated
	     .ram_cfg_icache_data_i	(i_mem_icache_data_cfg), // Templated
	     .hart_id_i			(i_hart_id[31:0]),	 // Templated
	     .boot_addr_i		(i_boot_addr[31:0]),	 // Templated
	     .trvk_heap_base_addr_i	(i_trvk_heap_base_addr[31:0]), // Templated
	     .instr_gnt_i		(i_mem_instr_gnt),	 // Templated
	     .instr_rvalid_i		(i_mem_instr_rvalid),	 // Templated
	     .instr_rdata_i		(i_mem_instr_rdata[31:0]), // Templated
	     .instr_rdata_intg_i	(i_mem_instr_rdata_intg[6:0]), // Templated
	     .instr_err_i		(i_mem_instr_err),	 // Templated
	     .data_gnt_i		(i_mem_data_gnt),	 // Templated
	     .data_rvalid_i		(i_mem_data_rvalid),	 // Templated
	     .data_rdata_i		(i_mem_data_rdata[31:0]), // Templated
	     .data_rdata_intg_i		(i_mem_data_rdata_intg[6:0]), // Templated
	     .data_tag_i		(i_mem_data_tag),	 // Templated
	     .data_err_i		(i_mem_data_err),	 // Templated
	     .trvk_revbm_gnt_i		(i_trvk_revbm_gnt),	 // Templated
	     .trvk_revbm_rvalid_i	(i_trvk_revbm_rvalid),	 // Templated
	     .trvk_revbm_rdata_i	(i_trvk_revbm_rdata[31:0]), // Templated
	     .trvk_revbm_rdata_intg_i	(i_trvk_revbm_rdata_intg[6:0]), // Templated
	     .trvk_revbm_err_i		(i_trvk_revbm_err),	 // Templated
	     .irq_software_i		(i_int_software),	 // Templated
	     .irq_timer_i		(i_int_timer),		 // Templated
	     .irq_external_i		(i_int_external),	 // Templated
	     .irq_fast_i		(i_int_fast[14:0]),	 // Templated
	     .irq_nm_i			(i_int_nm),		 // Templated
	     .scramble_key_valid_i	(i_scramble_key_valid),	 // Templated
	     .scramble_key_i		(i_scramble_key[127:0]), // Templated
	     .scramble_nonce_i		(i_scramble_nonce[63:0]), // Templated
	     .debug_req_i		(i_dbg_req),		 // Templated
	     .scan_rst_ni		(i_dft_scan_rst_n));	 // Templated

endmodule
`default_nettype wire
// Local Variables:
// verilog-library-flags:("-f filelist_emacs.f")
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: nil
// End:
