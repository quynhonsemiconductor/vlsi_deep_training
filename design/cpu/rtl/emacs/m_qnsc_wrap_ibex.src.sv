`default_nettype none
`timescale 1ns/1ps

module m_qnsc_wrap_ibex
  import ibex_pkg::*;
  import qnsc_pkg::*;
#(
)
(
//---------------------------------------------------------------
// Clock/Reset
//---------------------------------------------------------------
/*AUTOINPUT("^i_clk\|^i_rst")*/

//---------------------------------------------------------------
// Boot
//---------------------------------------------------------------
/*AUTOINPUT("^i_boot")*/

//---------------------------------------------------------------
// Debug
//---------------------------------------------------------------
/*AUTOINPUT("^i_dbg")*/
/*AUTOOUTPUT("^o_dbg")*/

//---------------------------------------------------------------
// Interrupt
//---------------------------------------------------------------
/*AUTOINPUT("^i_int")*/

//---------------------------------------------------------------
// Power
//---------------------------------------------------------------
/*AUTOOUTPUT("^o_pwr")*/

//---------------------------------------------------------------
// DFT
//---------------------------------------------------------------
/*AUTOINPUT("^i_dft")*/

//---------------------------------------------------------------
// Instruction memory interface
//---------------------------------------------------------------
/*AUTOINPUT("^i_mem_instr")*/
/*AUTOOUTPUT("^o_mem_instr")*/

//---------------------------------------------------------------
// Data memory interface
//---------------------------------------------------------------
/*AUTOINPUT("^i_mem_data")*/
/*AUTOOUTPUT("^o_mem_data")*/

//---------------------------------------------------------------
// Others (no QNSC-standard category: CHERIoT/TRVK unused, scrambling
// unused, lockstep/alert/diagnostic outputs unused -- SecureIbex=0,
// BaseIsa=RV32I in this project; kept as plain i_/o_ ports since they
// are still real ibex_top ports that must be terminated somewhere)
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
    .DbgTriggerEn     (1'b0),
    .DbgHwBreakNum    (1),
    .SecureIbex       (1'b0),
    .LockstepOffset   (1),
    .ICacheScramble   (1'b0),
    .DmBaseAddr       (qnsc_pkg::C_ISRAM_DBG_BASE),
    .DmAddrMask       (32'h0000_0FFF),
    .DmHaltAddr       (qnsc_pkg::C_ISRAM_DBG_BASE + 32'h0000_0800),
    .DmExceptionAddr  (qnsc_pkg::C_ISRAM_DBG_BASE + 32'h0000_0810),
    .CsrMvendorId     (32'h0),
    .CsrMimpId        (32'h0)
) u_ibex_top(/*AUTOINST*/);

endmodule
`default_nettype wire
// Local Variables:
// verilog-library-flags:("-f filelist_emacs.f")
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: nil
// End:
