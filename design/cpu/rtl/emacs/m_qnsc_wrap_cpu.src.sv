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

//---------------------------------------------------------------
// AXI4 master bus -- flattened per QNSC naming rule, pass-through
// from m_qnsc_wrap_cpu2axi to the subsystem boundary.
//---------------------------------------------------------------
/*AUTOINPUT("^i_bus_axi")*/
/*AUTOOUTPUT("^o_bus_axi")*/
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
m_qnsc_wrap_ibex u_m_qnsc_wrap_ibex(/*AUTOINST*/);

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
m_qnsc_wrap_cpu2axi u_m_qnsc_wrap_cpu2axi(/*AUTOINST*/);

endmodule
// Local Variables:
// verilog-library-flags:("-f filelist_emacs_subsystem.f")
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: nil
// End:
