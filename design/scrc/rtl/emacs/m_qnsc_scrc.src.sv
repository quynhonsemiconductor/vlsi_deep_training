`timescale 1ns/1ps

// =============================================================================
// m_qnsc_scrc -- System Clock and Reset Controller.
// Spec: `QNSC_SCRC_MAS` V3.4 on the team SharePoint.
//
// Edit this .src.sv, then `make wrap BLOCK=scrc`: emacs verilog-mode expands the
// AUTO comments and writes rtl/m_qnsc_scrc.sv, the file scrc.f compiles. No port
// is declared by hand and the level holds instances only; its one piece of logic,
// the bit map to the guards, is m_qnsc_scrc_map.
//
//   i_rst_n_pad -> qnsc_rst_filter -> qnsc_rst_sync -> o_rst_n_por -> RRC -> w_rst_n_sys
//   i_clk_pad   -> qnsc_clk_buf -> w_clk_root -> 18 x CTRL (gate + reset sync)
//                                                -> o_clk_<d>, o_rst_n_<d>
//   MCPU + CRM ROM -> WF (MCPU) -\
//                                 > APB BUS (generated) -> SCRC CSR (generated)
//   P_BUS APB_M0   -> WF (IBEX) -/                         -> map -> o_guard_blk
//
// Sequencing is software: MCPU is the only agent that opens a clock gate
// (ICG_EN), releases a reset (RST_REL) or opens an APB guard (APB_BLK). Ibex only
// writes requests (SW_RST, CLK_EN). No register field has two writers.
//
// Domain bits (MAS Table 6-3), shared with SYSCSR DOMAIN_RST_STATUS:
//   0 sbus  1 pbus  2 wdt  3 timer_0  4 timer_1  5 uart_0  6 uart_1  7 spi
//   8 i2c  9 gpio_0  10 dma  11 rom  12 ram  13 -  14 sysdbg  15 pwm
//   16 gpio_1  17 gpio_2  31 cpu
//   always-on (gate enable tied 1): cpu sbus pbus rom ram sysdbg wdt
//   gateable (CLK_EN/ICG_EN/APB_BLK/APB_BUSY bit, guard): 0x0003_87F8
// =============================================================================
module m_qnsc_scrc
(
//---------------------------------------------------------------
// Dedicated pads: CLKIN (20 MHz root clock), PORSTN (power-on reset)
//---------------------------------------------------------------
/*AUTOINPUT("^i_clk\|^i_rst")*/

//---------------------------------------------------------------
// Reset request: WDT aon_timer_rst_req_o (sticky, WDT domain)
//---------------------------------------------------------------
/*AUTOINPUT("^i_wdt")*/

//---------------------------------------------------------------
// P_BUS APB_M0 (Ibex). PPROT is not checked (no privilege check, MAS 10)
//---------------------------------------------------------------
/*AUTOINPUT("^i_bus_apb")*/
/*AUTOOUTPUT("^o_bus_apb")*/

//---------------------------------------------------------------
// The 11 APB guards in design/top
//---------------------------------------------------------------
/*AUTOINPUT("^i_guard")*/
/*AUTOOUTPUT("^o_guard")*/

//---------------------------------------------------------------
// Domain clocks and resets (MAS Table 5-2), and o_rst_n_por: the
// synchronised power-on reset, not affected by WDT or SW (to SYSCSR, SYSDBG)
//---------------------------------------------------------------
/*AUTOOUTPUT("^o_clk_\|^o_rst_n_")*/
/*AUTOOUTPUTEVERY("^o_rst_n_por")*/

//---------------------------------------------------------------
// To SYSCSR: cause enables, 1 while a WDT / SW chip reset lasts
//---------------------------------------------------------------
/*AUTOOUTPUT("^o_cause")*/

//---------------------------------------------------------------
// Others -- must stay empty once the templates below are complete
//---------------------------------------------------------------
/*AUTOINOUT*/
/*AUTOINPUT*/
/*AUTOOUTPUT*/
);

/*AUTOWIRE*/

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
// 1. Root clock and power-on input stage (MAS 7.1, 7.2). Technology cells.
//---------------------------------------------------------------
/* qnsc_clk_buf AUTO_TEMPLATE(
    .i_clk_src      (i_clk_pad),
    .o_clk_buf      (w_clk_root),
);
*/
qnsc_clk_buf u_clk_buf (/*AUTOINST*/);

/* qnsc_rst_filter AUTO_TEMPLATE(
    .i_rst_n_raw    (i_rst_n_pad),
    .o_rst_n_filt   (w_rst_n_filt),
);
*/
qnsc_rst_filter u_rst_filter (/*AUTOINST*/);

// Scan enable tied 0: no scan in QSOC v1 (MAS 10).
/* qnsc_rst_sync AUTO_TEMPLATE(
    .i_clk_dst      (w_clk_root),
    .i_rst_n_src    (w_rst_n_filt),
    .i_dft_scan_en  (1'b0),
    .o_rst_n_dst    (o_rst_n_por),
);
*/
qnsc_rst_sync u_rst_sync_por (/*AUTOINST*/);

//---------------------------------------------------------------
// 2. Reset Request Controller (MAS 7.3)
//---------------------------------------------------------------
/* m_qnsc_scrc_rrc AUTO_TEMPLATE(
    .i_clk_root     (w_clk_root),
    .i_rst_n_por    (o_rst_n_por),
    .i_sw_rst       (w_sw_rst),
    .o_rst_n_sys    (w_rst_n_sys),
);
*/
m_qnsc_scrc_rrc u_rrc (/*AUTOINST*/);

//---------------------------------------------------------------
// 3. MCPU and CRM ROM (MAS 7.5, 7.6). Polling only: i_interrupt tied 0.
//---------------------------------------------------------------
/* m_vlsit_mrv_cpu AUTO_TEMPLATE(
    .i_clk          (w_clk_root),
    .i_rst_n        (w_rst_n_sys),
    .i_interrupt    (1'b0),
    .o_imem_\(.*\)  (w_mcpu_imem_\1[]),
    .i_imem_\(.*\)  (w_mcpu_imem_\1[]),
    .o_p\(.*\)      (w_mcpu_p\1[]),
    .i_p\(.*\)      (w_mcpu_p\1[]),
);
*/
m_vlsit_mrv_cpu #(  // naming-check: ignore -- vendored module name
  .PARA_RESET_VECTOR (32'h0000_1000),  // hardcode-check: ignore -- MRV reset vector, the CRM ROM base, not an address of the chip map
  .PARA_INT_VECTOR   (12'h100)         // naming-check: ignore -- parameter of a vendored module; not used, i_interrupt tied 0
) u_mcpu (/*AUTOINST*/);

/* m_qnsc_scrc_crm_rom AUTO_TEMPLATE(
    .i_imem_addr    (w_mcpu_imem_addr[]),
    .o_imem_data    (w_mcpu_imem_data[]),
);
*/
m_qnsc_scrc_crm_rom u_crm_rom (/*AUTOINST*/);

//---------------------------------------------------------------
// 4. Write filters (MAS 7.4, Table 7-2). Offset = PADDR[13:0].
//---------------------------------------------------------------
/* m_qnsc_scrc_apb_wfilter AUTO_TEMPLATE(
    .i_bus_apb_s_0_paddr    (w_mcpu_paddr[13:0]),
    .\([io]\)_bus_apb_s_0_\(.*\)  (w_mcpu_\2[]),
    .\([io]\)_bus_apb_m_0_\(.*\)  (w_mcpu_fwd_\2[]),
);
*/
m_qnsc_scrc_apb_wfilter #(.P_WR_DENY(8'b0100_0011)) u_wf_mcpu (/*AUTOINST*/);

/* m_qnsc_scrc_apb_wfilter AUTO_TEMPLATE(
    .\([io]\)_bus_apb_s_0_\(.*\)  (\1_bus_apb_\2[]),
    .\([io]\)_bus_apb_m_0_\(.*\)  (w_ibex_fwd_\2[]),
);
*/
m_qnsc_scrc_apb_wfilter #(.P_WR_DENY(8'b0111_1000)) u_wf_ibex (/*AUTOINST*/);

//---------------------------------------------------------------
// 5. APB BUS (util/gen/scrc_bus): masters MCPU, IBEX; slave SCRC_CSR at
//    0x00-0x1F; 0x0020-0x3FFF answered with PSLVERR. MCPU has no PSTRB or
//    PPROT (MAS Table 10-1).
//---------------------------------------------------------------
/* m_qnsc_scrc_apb_bus AUTO_TEMPLATE(
    .i_clk                          (w_clk_root),
    .i_rstn                         (w_rst_n_sys),
    .i_paddr_mcpu                   (w_mcpu_paddr[13:0]),
    .i_protect_en_\(mcpu\|ibex\)    (1'b0),
    .i_slverr_en_\(mcpu\|ibex\)     (1'b1),
    .i_pprot_mcpu                   (3'b000),
    .i_pstrb_mcpu                   (4'hF),
    .i_\(penable\|psel\)_\(mcpu\|ibex\)  (w_\2_fwd_\1),
    .o_\(.*\)_\(mcpu\|ibex\)        (w_\2_fwd_\1[]),
    .i_\(.*\)_mcpu                  (w_mcpu_\1[]),
    .i_\(.*\)_ibex                  (i_bus_apb_\1[]),
    .\([io]\)_\(.*\)_scrc_csr       (w_csr_\2[]),
);
*/
m_qnsc_scrc_apb_bus u_apb_bus (/*AUTOINST*/);

//---------------------------------------------------------------
// 6. SCRC CSR (util/gen/scrc_csr; MAS 6). i_protect_en = 0 and
//    i_slverr_en = 1 come from the bus (MAS Table 10-1). CLK_EN is read by
//    MCPU over the bus; its field outputs are not used.
//---------------------------------------------------------------
/* m_qnsc_scrc_csr AUTO_TEMPLATE(
    .i_bus_clk                (w_clk_root),
    .i_bus_rstn               (w_rst_n_sys),
    .i_paddr                  ({11'd0, w_csr_paddr}),
    .o_swrst_sw_rst           (w_sw_rst),
    .o_clken_\(.*\)           (),
    .o_icgen_icg_\(.*\)       (w_icg_\1),
    .o_rstrel_rel_\(.*\)      (w_rel_\1),
    .o_apbblk_blk_\(.*\)      (w_blk_\1),
    .i_apbbusy_busy_\(.*\)    (w_busy_\1),
    .\([io]\)_\(.*\)          (w_csr_\2[]),
);
*/
m_qnsc_scrc_csr u_csr (/*AUTOINST*/);

/* m_qnsc_scrc_map AUTO_TEMPLATE(
    .i_blk_\(.*\)             (w_blk_\1),
    .o_busy_\(.*\)            (w_busy_\1),
);
*/
m_qnsc_scrc_map u_map (/*AUTOINST*/);

//---------------------------------------------------------------
// 7. Domain controllers (MAS 7.1, 7.8, Table 5-2). Gate enable = ICG_EN bit,
//    reset input = RST_REL bit, both named after the instance; the seven
//    always-on domains tie the gate enable to 1, sysdbg's reset input is the
//    power-on reset, so a debug session survives a WDT or SW reset.
//---------------------------------------------------------------
/* m_qnsc_scrc_ctrl AUTO_TEMPLATE "u_ctrl_\(.*\)" (
    .i_clk_root               (w_clk_root),
    .i_icg_en                 (w_icg_@),
    .i_rst_n_in               (w_rel_@),
    .o_clk_gated              (o_clk_@),
    .o_rst_n_sync             (o_rst_n_@),
);
*/
// ---- always-on ----------------------------------------------------------------
m_qnsc_scrc_ctrl u_ctrl_cpu     (.i_icg_en (1'b1), /*AUTOINST*/);
m_qnsc_scrc_ctrl u_ctrl_sbus    (.i_icg_en (1'b1), /*AUTOINST*/);
m_qnsc_scrc_ctrl u_ctrl_pbus    (.i_icg_en (1'b1), /*AUTOINST*/);
m_qnsc_scrc_ctrl u_ctrl_wdt     (.i_icg_en (1'b1), /*AUTOINST*/);
m_qnsc_scrc_ctrl u_ctrl_rom     (.i_icg_en (1'b1), /*AUTOINST*/);
m_qnsc_scrc_ctrl u_ctrl_ram     (.i_icg_en (1'b1), /*AUTOINST*/);
m_qnsc_scrc_ctrl u_ctrl_sysdbg  (.i_icg_en (1'b1), .i_rst_n_in (o_rst_n_por), /*AUTOINST*/);
// ---- gateable -----------------------------------------------------------------
m_qnsc_scrc_ctrl u_ctrl_timer_0 (/*AUTOINST*/);
m_qnsc_scrc_ctrl u_ctrl_timer_1 (/*AUTOINST*/);
m_qnsc_scrc_ctrl u_ctrl_uart_0  (/*AUTOINST*/);
m_qnsc_scrc_ctrl u_ctrl_uart_1  (/*AUTOINST*/);
m_qnsc_scrc_ctrl u_ctrl_spi     (/*AUTOINST*/);
m_qnsc_scrc_ctrl u_ctrl_i2c     (/*AUTOINST*/);
m_qnsc_scrc_ctrl u_ctrl_gpio_0  (/*AUTOINST*/);
m_qnsc_scrc_ctrl u_ctrl_dma     (/*AUTOINST*/);
m_qnsc_scrc_ctrl u_ctrl_pwm     (/*AUTOINST*/);
m_qnsc_scrc_ctrl u_ctrl_gpio_1  (/*AUTOINST*/);
m_qnsc_scrc_ctrl u_ctrl_gpio_2  (/*AUTOINST*/);

endmodule
// Local Variables:
// verilog-library-flags:("-f filelist_emacs.f")
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: t
// indent-tabs-mode: nil
// eval: (setq large-file-warning-threshold nil)
// End:
