// QNSC wrapper of lowRISC/opentitan aon_timer: the QSoC watchdog, on APB_M2.
// Bark to the NMI, bite to a chip reset through SCRC, wake-up timer to INTMAP
// line 8. Spec: QNSC_WDT_MAS (team SharePoint).
//
// Edit this .src.sv, then expand it with emacs verilog-mode
// (`make wrap BLOCK=wdt` in the QSoC repository): the AUTO comments are
// expanded into m_qnsc_wrap_wdt.sv, the file the filelist compiles.
//
// Wrapper = core + bridge.
//   - Core: aon_timer, unmodified. It speaks TL-UL.
//   - Bridge: APB -> TL-UL, built from tlul_adapter_host (req/gnt host to
//     TL-UL) plus one pending flop, so each APB access phase issues exactly
//     one TL-UL request. PREADY is the TL-UL response valid (d_ready is always
//     1 inside tlul_adapter_host, so the response lasts one cycle).
//   - tlul_adapter_host generates the command and data integrity that
//     aon_timer_reg_top checks (EnableDataIntgGen = 1).
//   - PSTRB is the TL-UL a_mask of a write. OpenTitan registers reject a
//     sub-word write: such a write answers PSLVERR = 1 and changes nothing.
//   - PSLVERR = err_o of the adapter, per access: the TL-UL d_error (address
//     miss, sub-word write, command integrity error seen by aon_timer_reg_top,
//     which also drops the write) or a response integrity error.
//   - PPROT: aon_timer has no protection check, so the wrapper has no PPROT
//     port (mentor review of PR #104: a signal the IP does not support is not
//     ported out; design/top ties or floats it at integration).
//     PSTRB is kept: the bridge uses it as the TL-UL write mask.
//
// Outputs: o_int_wdt_bark (NMI), o_int_wdt_wakeup (INTMAP line 8),
// o_wdt_rst_req (bite, to SCRC). Nothing else leaves the wrapper.
//
// Tie-offs (vendor/manifest.yml, lowRISC/opentitan notes):
//   lc_escalate_en_i = lc_ctrl_pkg::Off  QSoC has no life-cycle controller.
//                                        Any other value stops the counters.
//   alert_rx_i       = ALERT_RX_DEFAULT  QSoC has no alert handler (idle)
//   racl_policies_i  = '0                QSoC has one host (CPU): RACL is off
//                                        (EnableRacl = 0), the input is not read
// Outputs left open:
//   aon_timer  alert_tx_o              no alert handler; integrity faults are
//                                      already answered with PSLVERR
//              racl_error_o            RACL off: .valid is always 0
//              intr_wdog_timer_bark_o  bark leaves on nmi_wdog_timer_bark_o
//              wkup_req_o              wake-up leaves on the interrupt
//   u_apb2tl   rdata_intg_o            APB has no data integrity
//              intg_err_o              sticky copy of the response integrity
//                                      error, for alerts; PSLVERR reports it
// Shared, not tied: clk_aon_i / rst_aon_ni = i_clk_wdt / i_rst_n_wdt: the
// wdt cluster has one clock and is never gated.
//
// Sleep (QNSC_WDT_MAS): i_wdt_sleep_mode -> sleep_mode_i. Asynchronous to
// i_clk_wdt; aon_timer synchronises it inside (prim_flop_2sync). With
// WDOG_CTRL.pause_in_sleep = 1, the watchdog stops counting while it is 1.
//
// A wrapper is IP: no import, no parameter, flat ports. Package items are
// used as pkg::item inside only.

module m_qnsc_wrap_wdt
(
//---------------------------------------------------------------
// Clock/Reset: wdt cluster, never gated
//---------------------------------------------------------------
/*AUTOINPUT("^i_clk\|^i_rst")*/

//---------------------------------------------------------------
// APB slave, from P_BUS (APB_M2)
//---------------------------------------------------------------
/*AUTOINPUT("^i_bus_apb")*/
input  logic [13:0]     i_bus_apb_paddr,        // contract: meta.apb_paddr_width
input  logic            i_bus_apb_psel,
input  logic            i_bus_apb_penable,
/*AUTOOUTPUT("^o_bus_apb")*/
output logic            o_bus_apb_pready,

//---------------------------------------------------------------
// Sleep indication: asynchronous, synchronised inside aon_timer
//---------------------------------------------------------------
/*AUTOINPUT("^i_wdt")*/

//---------------------------------------------------------------
// Interrupt / reset request
//---------------------------------------------------------------
/*AUTOOUTPUT("^o_int\|^o_wdt")*/

//---------------------------------------------------------------
// Others -- must stay empty
//---------------------------------------------------------------
/*AUTOINOUT*/
/*AUTOINPUT*/
/*AUTOOUTPUT*/

//---------------------------------------------------------------
// APB error response: declared by hand, last port, so this file
// stays valid SystemVerilog before expansion
//---------------------------------------------------------------
output logic            o_bus_apb_pslverr
);

/*AUTO_LISP(setq verilog-auto-input-ignore-regexp
  (concat
  "^w_"
  "\\|^i_bus_apb_paddr$"
  ))
*/

/*AUTO_LISP(setq verilog-auto-output-ignore-regexp
  (concat
  "^w_"
  ))
*/

//---------------------------------------------------------------
// Internal signals (declared by hand: TL-UL structs stay inside)
//---------------------------------------------------------------
tlul_pkg::tl_h2d_t      w_tl_h2d;               // bridge -> aon_timer
tlul_pkg::tl_d2h_t      w_tl_d2h;               // aon_timer -> bridge
logic [31:0]            w_tl_addr;
logic                   w_tl_req;
logic                   w_tl_gnt;
logic                   w_tl_valid;
logic                   r_tl_pending;           // request granted, response not yet back

//---------------------------------------------------------------
// Bridge: APB -> TL-UL
//---------------------------------------------------------------
// APB holds PSEL/PENABLE until PREADY; issue the request once per access.
always_ff @(posedge i_clk_wdt or negedge i_rst_n_wdt) begin
  if (!i_rst_n_wdt) begin
    r_tl_pending <= 1'b0;
  end else if (w_tl_valid) begin
    r_tl_pending <= 1'b0;
  end else if (w_tl_req && w_tl_gnt) begin
    r_tl_pending <= 1'b1;
  end
end

assign w_tl_req  = i_bus_apb_psel & i_bus_apb_penable & ~r_tl_pending;
assign w_tl_addr = 32'(i_bus_apb_paddr);       // offset inside the 16 KiB window
assign o_bus_apb_pready = w_tl_valid;

/* tlul_adapter_host AUTO_TEMPLATE(
    .clk_i              (i_clk_wdt),
    .rst_ni             (i_rst_n_wdt),
    .req_i              (w_tl_req),
    .gnt_o              (w_tl_gnt),
    .addr_i             (w_tl_addr),
    .we_i               (i_bus_apb_pwrite),
    .wdata_i            (i_bus_apb_pwdata[31:0]),
    .wdata_intg_i       ('0),
    .be_i               (i_bus_apb_pstrb[3:0]),
    .instr_type_i       (prim_mubi_pkg::MuBi4False),
    .user_rsvd_i        ('0),
    .valid_o            (w_tl_valid),
    .rdata_o            (o_bus_apb_prdata[31:0]),
    .rdata_intg_o       (),
    .err_o              (o_bus_apb_pslverr),
    .intg_err_o         (),
    .tl_o               (w_tl_h2d),
    .tl_i               (w_tl_d2h),
);
*/
tlul_adapter_host #(
  .MAX_REQS               (1),
  .EnableDataIntgGen      (1),
  .EnableRspDataIntgCheck (0)
) u_apb2tl (/*AUTOINST*/);

//---------------------------------------------------------------
// Core: aon_timer, unmodified
//---------------------------------------------------------------
/* aon_timer AUTO_TEMPLATE(
    .clk_i                      (i_clk_wdt),
    .clk_aon_i                  (i_clk_wdt),
    .rst_ni                     (i_rst_n_wdt),
    .rst_aon_ni                 (i_rst_n_wdt),
    .tl_i                       (w_tl_h2d),
    .tl_o                       (w_tl_d2h),
    .alert_rx_i                 (prim_alert_pkg::ALERT_RX_DEFAULT),
    .alert_tx_o                 (),
    .racl_policies_i            ('0),
    .racl_error_o               (),
    .lc_escalate_en_i           (lc_ctrl_pkg::Off),
    .intr_wkup_timer_expired_o  (o_int_wdt_wakeup),
    .intr_wdog_timer_bark_o     (),
    .nmi_wdog_timer_bark_o      (o_int_wdt_bark),
    .wkup_req_o                 (),
    .aon_timer_rst_req_o        (o_wdt_rst_req),
    .sleep_mode_i               (i_wdt_sleep_mode),
);
*/
aon_timer u_aon_timer (/*AUTOINST*/);

endmodule
// Local Variables:
// verilog-library-flags:("-f filelist_emacs.f")
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: t
// indent-tabs-mode: nil
// End:
