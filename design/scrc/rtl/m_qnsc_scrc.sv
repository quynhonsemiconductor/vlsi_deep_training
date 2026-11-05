`timescale 1ns/1ps

// =============================================================================
// m_qnsc_scrc -- System Clock and Reset Controller (QNSC_SCRC_MAS V3.5)
//
// In-house logic, written by hand. Emacs verilog-mode AUTOs are kept for the
// wrappers of existing IP (the mentor's rule); this block's top is ours.
//
//   i_rst_n_pad -> qnsc_rst_filter -> qnsc_rst_sync -> o_rst_n_por -> RRC -> w_rst_n_chip
//   i_clk_pad   -> qnsc_clk_buf -> w_clk_root -> 13 x CTRL (gate + reset sync)
//                                                -> o_clk_<d>, o_rst_n_<d>
//   MCPU + CRM ROM -> WF (MCPU) -\
//                                 > APB BUS (generated) -> SCRC CSR (generated)
//   P_BUS APB_M0   -> WF (IBEX) -/
//
// Sequencing is software: MCPU is the only agent that opens a clock gate
// (ICG_EN), releases a reset (RST_REL) or opens an APB guard (APB_BLK). Ibex only
// writes requests (SW_RST, CLK_EN). No register field has two writers. The CPU is
// never held (QNSC_SYSDBG_MAS V4.0): the only recovery is a chip reset.
//
// One clock/reset pair per DOMAIN, not per IP (MAS Table 5-2, V3.5). Domain bits
// (MAS Table 6-3), shared with SYSCSR DOMAIN_RST_STATUS:
//   0 sys  1 cpu  2 timer_0  3 timer_1  4 uart_0  5 uart_1  6 spi  7 i2c
//   8 gpio_0  9 gpio_1  10 gpio_2  11 dma  12 pwm
//   always-on (gate enable tied 1, no CLK_EN/ICG_EN/APB_BLK bit): sys, cpu
//     sys = S_BUS, P_BUS, ROM, ISRAM/DSRAM, WDT, SYSCSR, SYSDBG (clock only;
//     SYSDBG is reset by o_rst_n_por) and the 11 APB guards
//   gateable (CLK_EN/ICG_EN/APB_BLK/APB_BUSY bit, guard): 0x0000_1FFC
//
// Why software cannot stop sys or cpu (MAS 7.1): their CTRL gate enable is the
// constant 1, CLK_EN/ICG_EN/APB_BLK have no bit 0 or 1 (read 0, write ignored),
// and Ibex's write filter drops every write to ICG_EN, RST_REL and APB_BLK.
//
// APB guard handshake (MAS 7.7): o_csr_blk[n] = APB_BLK[n] closes guard n;
// i_csr_busy[n] = guard n has a transfer in progress (PSEL at the IP) and is
// read as APB_BUSY[n]. MCPU stops clock n only after APB_BLK[n] = 1 and
// APB_BUSY[n] = 0. Both are CSR fields, hence the csr group (Naming Rule V1.2).
//
// Library cells (clock buffer, clock gates, reset synchronisers, the WDT request
// synchroniser, the PORSTN filter) only through design/common/tech (MAS 4).
// =============================================================================
module m_qnsc_scrc (
  // ---- dedicated pads ------------------------------------------------------
  input  logic        i_clk_pad,            // CLKIN, root clock, 20 MHz
  input  logic        i_rst_n_pad,          // PORSTN, power-on reset
  // ---- reset request (group rst_req, proposed to Tâm, MAS 5) -----------------
  input  logic        i_rst_req_wdt,        // naming-check: ignore -- WDT aon_timer_rst_req_o, sticky, active high; group rst_req proposed to Tâm (MAS 5), not yet in Naming Rule V1.2
  // ---- P_BUS APB_M0 (Ibex) --------------------------------------------------
  input  logic        i_bus_apb_psel,
  input  logic        i_bus_apb_penable,
  input  logic        i_bus_apb_pwrite,
  input  logic [13:0] i_bus_apb_paddr,      // contract: meta.apb_paddr_width
  input  logic [31:0] i_bus_apb_pwdata,
  input  logic [3:0]  i_bus_apb_pstrb,
  input  logic [2:0]  i_bus_apb_pprot,      // not checked (MAS 10)
  output logic [31:0] o_bus_apb_prdata,
  output logic        o_bus_apb_pready,
  output logic        o_bus_apb_pslverr,
  // ---- CSR fields to/from the 11 APB guards in design/top (MAS 7.7) ----------
  input  logic [12:0] i_csr_busy,           // APB_BUSY[n]: guard n has a transfer in progress; bits 1:0 tied 0
  output logic [12:0] o_csr_blk,            // APB_BLK[n]: 1 = guard n blocks; bits 1:0 read 0
  // ---- domain clocks and resets, bit order (MAS Table 5-2) -------------------
  output logic        o_clk_sys,
  output logic        o_rst_n_sys,
  output logic        o_clk_cpu,
  output logic        o_rst_n_cpu,
  output logic        o_clk_timer_0,
  output logic        o_rst_n_timer_0,
  output logic        o_clk_timer_1,
  output logic        o_rst_n_timer_1,
  output logic        o_clk_uart_0,
  output logic        o_rst_n_uart_0,
  output logic        o_clk_uart_1,
  output logic        o_rst_n_uart_1,
  output logic        o_clk_spi,
  output logic        o_rst_n_spi,
  output logic        o_clk_i2c,
  output logic        o_rst_n_i2c,
  output logic        o_clk_gpio_0,
  output logic        o_rst_n_gpio_0,
  output logic        o_clk_gpio_1,
  output logic        o_rst_n_gpio_1,
  output logic        o_clk_gpio_2,
  output logic        o_rst_n_gpio_2,
  output logic        o_clk_dma,
  output logic        o_rst_n_dma,
  output logic        o_clk_pwm,
  output logic        o_rst_n_pwm,
  // ---- power-on reset: SYSCSR and SYSDBG (survive a WDT or SW reset) ---------
  output logic        o_rst_n_por,          // power-on only; not affected by WDT or SW
  // ---- CSR fields to SYSCSR RESET_CAUSE (hardware set, MAS 7.3) --------------
  output logic        o_csr_rst_cause_wdt,  // 1 for the whole WDT chip reset
  output logic        o_csr_rst_cause_sw    // 1 for the whole SW chip reset
);

  // ==========================================================================
  // 1. Root clock and power-on input stage (MAS 7.1, 7.2). Technology cells.
  // ==========================================================================
  logic w_clk_root, w_rst_n_filt, w_rst_n_chip;

  qnsc_clk_buf u_clk_buf (
    .i_clk_src (i_clk_pad),
    .o_clk_buf (w_clk_root)
  );

  qnsc_rst_filter u_rst_filter (
    .i_rst_n_raw  (i_rst_n_pad),
    .o_rst_n_filt (w_rst_n_filt)
  );

  // Scan enable tied 0: no scan in QSOC v1 (MAS 10).
  qnsc_rst_sync u_rst_sync_por (
    .i_clk_dst     (w_clk_root),
    .i_rst_n_src   (w_rst_n_filt),
    .i_dft_scan_en (1'b0),
    .o_rst_n_dst   (o_rst_n_por)
  );

  // ==========================================================================
  // 2. Reset Request Controller (MAS 7.3)
  // ==========================================================================
  logic w_sw_rst;

  m_qnsc_scrc_rrc u_rrc (
    .i_clk_root          (w_clk_root),
    .i_rst_n_por         (o_rst_n_por),
    .i_rst_req_wdt       (i_rst_req_wdt),
    .i_sw_rst            (w_sw_rst),
    .o_rst_n_chip        (w_rst_n_chip),
    .o_csr_rst_cause_wdt (o_csr_rst_cause_wdt),
    .o_csr_rst_cause_sw  (o_csr_rst_cause_sw)
  );

  // ==========================================================================
  // 3. MCPU and CRM ROM (MAS 7.5, 7.6). Polling only: i_interrupt tied 0.
  // ==========================================================================
  logic [31:0] w_mcpu_imem_addr, w_mcpu_imem_data;
  logic [31:0] w_mcpu_paddr, w_mcpu_pwdata, w_mcpu_prdata;
  logic        w_mcpu_pwrite, w_mcpu_psel, w_mcpu_penable, w_mcpu_pready;

  m_vlsit_mrv_cpu #(  // naming-check: ignore -- vendored module name
    .PARA_RESET_VECTOR (32'h0000_1000),  // hardcode-check: ignore -- MRV reset vector, the CRM ROM base, not an address of the chip map
    .PARA_INT_VECTOR   (12'h100)         // naming-check: ignore -- parameter of a vendored module; not used, i_interrupt tied 0
  ) u_mcpu (
    .i_clk       (w_clk_root),
    .i_rst_n     (w_rst_n_chip),
    .i_interrupt (1'b0),
    .o_imem_addr (w_mcpu_imem_addr),
    .i_imem_data (w_mcpu_imem_data),
    .o_paddr     (w_mcpu_paddr),
    .o_pwdata    (w_mcpu_pwdata),
    .i_prdata    (w_mcpu_prdata),
    .o_pwrite    (w_mcpu_pwrite),
    .o_psel      (w_mcpu_psel),
    .o_penable   (w_mcpu_penable),
    .i_pready    (w_mcpu_pready)
  );

  m_qnsc_scrc_crm_rom u_crm_rom (
    .i_imem_addr (w_mcpu_imem_addr),
    .o_imem_data (w_mcpu_imem_data)
  );

  // ==========================================================================
  // 4. Write filters (MAS 7.4, Table 7-2). Offset = PADDR[13:0].
  //    MCPU has no PSLVERR input: its filter's PSLVERR goes nowhere.
  // ==========================================================================
  logic        w_mcpu_pslverr;
  logic        w_mcpu_fwd_psel, w_mcpu_fwd_penable, w_mcpu_fwd_pready, w_mcpu_fwd_pslverr;
  logic [31:0] w_mcpu_fwd_prdata;
  logic        w_ibex_fwd_psel, w_ibex_fwd_penable, w_ibex_fwd_pready, w_ibex_fwd_pslverr;
  logic [31:0] w_ibex_fwd_prdata;

  m_qnsc_scrc_apb_wfilter #(.P_WR_DENY(8'b0100_0011)) u_wf_mcpu (
    .i_bus_apb_s_0_psel    (w_mcpu_psel),
    .i_bus_apb_s_0_penable (w_mcpu_penable),
    .i_bus_apb_s_0_pwrite  (w_mcpu_pwrite),
    .i_bus_apb_s_0_paddr   (w_mcpu_paddr[13:0]),
    .o_bus_apb_s_0_pready  (w_mcpu_pready),
    .o_bus_apb_s_0_pslverr (w_mcpu_pslverr),
    .o_bus_apb_s_0_prdata  (w_mcpu_prdata),
    .o_bus_apb_m_0_psel    (w_mcpu_fwd_psel),
    .o_bus_apb_m_0_penable (w_mcpu_fwd_penable),
    .i_bus_apb_m_0_pready  (w_mcpu_fwd_pready),
    .i_bus_apb_m_0_pslverr (w_mcpu_fwd_pslverr),
    .i_bus_apb_m_0_prdata  (w_mcpu_fwd_prdata)
  );

  m_qnsc_scrc_apb_wfilter #(.P_WR_DENY(8'b0111_1000)) u_wf_ibex (
    .i_bus_apb_s_0_psel    (i_bus_apb_psel),
    .i_bus_apb_s_0_penable (i_bus_apb_penable),
    .i_bus_apb_s_0_pwrite  (i_bus_apb_pwrite),
    .i_bus_apb_s_0_paddr   (i_bus_apb_paddr),
    .o_bus_apb_s_0_pready  (o_bus_apb_pready),
    .o_bus_apb_s_0_pslverr (o_bus_apb_pslverr),
    .o_bus_apb_s_0_prdata  (o_bus_apb_prdata),
    .o_bus_apb_m_0_psel    (w_ibex_fwd_psel),
    .o_bus_apb_m_0_penable (w_ibex_fwd_penable),
    .i_bus_apb_m_0_pready  (w_ibex_fwd_pready),
    .i_bus_apb_m_0_pslverr (w_ibex_fwd_pslverr),
    .i_bus_apb_m_0_prdata  (w_ibex_fwd_prdata)
  );

  // ==========================================================================
  // 5. APB BUS (util/gen/scrc_bus): masters MCPU, IBEX; slave SCRC_CSR at
  //    0x00-0x1F; 0x0020-0x3FFF answered with PSLVERR. MCPU has no PSTRB or
  //    PPROT (MAS Table 10-1).
  // ==========================================================================
  logic [4:0]  w_csr_paddr;
  logic [31:0] w_csr_pwdata, w_csr_prdata;
  logic [3:0]  w_csr_pstrb;
  logic [2:0]  w_csr_pprot;
  logic        w_csr_psel, w_csr_penable, w_csr_pwrite, w_csr_pready, w_csr_pslverr;
  logic        w_csr_protect_en, w_csr_slverr_en;

  m_qnsc_scrc_apb_bus u_apb_bus (
    .i_clk                 (w_clk_root),
    .i_rstn                (w_rst_n_chip),
    // master MCPU
    .i_paddr_mcpu          (w_mcpu_paddr[13:0]),
    .i_protect_en_mcpu     (1'b0),
    .i_slverr_en_mcpu      (1'b1),
    .i_pprot_mcpu          (3'b000),
    .i_pwdata_mcpu         (w_mcpu_pwdata),
    .i_pwrite_mcpu         (w_mcpu_pwrite),
    .i_penable_mcpu        (w_mcpu_fwd_penable),
    .i_psel_mcpu           (w_mcpu_fwd_psel),
    .i_pstrb_mcpu          (4'hF),
    .o_pslverr_mcpu        (w_mcpu_fwd_pslverr),
    .o_pready_mcpu         (w_mcpu_fwd_pready),
    .o_prdata_mcpu         (w_mcpu_fwd_prdata),
    // master IBEX: P_BUS APB_M0
    .i_paddr_ibex          (i_bus_apb_paddr),
    .i_protect_en_ibex     (1'b0),
    .i_slverr_en_ibex      (1'b1),
    .i_pprot_ibex          (i_bus_apb_pprot),
    .i_pwdata_ibex         (i_bus_apb_pwdata),
    .i_pwrite_ibex         (i_bus_apb_pwrite),
    .i_penable_ibex        (w_ibex_fwd_penable),
    .i_psel_ibex           (w_ibex_fwd_psel),
    .i_pstrb_ibex          (i_bus_apb_pstrb),
    .o_pslverr_ibex        (w_ibex_fwd_pslverr),
    .o_pready_ibex         (w_ibex_fwd_pready),
    .o_prdata_ibex         (w_ibex_fwd_prdata),
    // slave SCRC_CSR
    .o_paddr_scrc_csr      (w_csr_paddr),
    .o_protect_en_scrc_csr (w_csr_protect_en),
    .o_slverr_en_scrc_csr  (w_csr_slverr_en),
    .o_pprot_scrc_csr      (w_csr_pprot),
    .o_pwdata_scrc_csr     (w_csr_pwdata),
    .o_pwrite_scrc_csr     (w_csr_pwrite),
    .o_penable_scrc_csr    (w_csr_penable),
    .o_psel_scrc_csr       (w_csr_psel),
    .o_pstrb_scrc_csr      (w_csr_pstrb),
    .i_pslverr_scrc_csr    (w_csr_pslverr),
    .i_pready_scrc_csr     (w_csr_pready),
    .i_prdata_scrc_csr     (w_csr_prdata)
  );

  // ==========================================================================
  // 6. SCRC CSR (util/gen/scrc_csr; MAS 6). i_protect_en = 0 and i_slverr_en = 1
  //    come from the bus (MAS Table 10-1). CLK_EN is read by MCPU over the bus;
  //    its field outputs are not used. Only the 11 gateable domains (bits 2-12)
  //    have CLK_EN/ICG_EN/APB_BLK/APB_BUSY fields; RST_REL has all 13 bits.
  // ==========================================================================
  logic w_icg_timer_0, w_icg_timer_1, w_icg_uart_0, w_icg_uart_1, w_icg_spi, w_icg_i2c;
  logic w_icg_gpio_0, w_icg_gpio_1, w_icg_gpio_2, w_icg_dma, w_icg_pwm;
  logic w_rel_sys, w_rel_cpu, w_rel_timer_0, w_rel_timer_1, w_rel_uart_0, w_rel_uart_1;
  logic w_rel_spi, w_rel_i2c, w_rel_gpio_0, w_rel_gpio_1, w_rel_gpio_2, w_rel_dma, w_rel_pwm;
  logic w_blk_timer_0, w_blk_timer_1, w_blk_uart_0, w_blk_uart_1, w_blk_spi, w_blk_i2c;
  logic w_blk_gpio_0, w_blk_gpio_1, w_blk_gpio_2, w_blk_dma, w_blk_pwm;

  m_qnsc_scrc_csr u_csr (
    .i_bus_clk              (w_clk_root),
    .i_bus_rstn             (w_rst_n_chip),
    .i_paddr                ({11'd0, w_csr_paddr}),
    .i_protect_en           (w_csr_protect_en),
    .i_slverr_en            (w_csr_slverr_en),
    .i_pprot                (w_csr_pprot),
    .i_pwdata               (w_csr_pwdata),
    .i_pwrite               (w_csr_pwrite),
    .i_penable              (w_csr_penable),
    .i_psel                 (w_csr_psel),
    .i_pstrb                (w_csr_pstrb),
    .o_pslverr              (w_csr_pslverr),
    .o_pready               (w_csr_pready),
    .o_prdata               (w_csr_prdata),
    // 0x00 SW_RST (Ibex) -> RRC
    .o_swrst_sw_rst         (w_sw_rst),
    // 0x04 CLK_EN (Ibex): read by MCPU over the bus
    .o_clken_en_timer_0     (),
    .o_clken_en_timer_1     (),
    .o_clken_en_uart_0      (),
    .o_clken_en_uart_1      (),
    .o_clken_en_spi         (),
    .o_clken_en_i2c         (),
    .o_clken_en_gpio_0      (),
    .o_clken_en_gpio_1      (),
    .o_clken_en_gpio_2      (),
    .o_clken_en_dma         (),
    .o_clken_en_pwm         (),
    // 0x0C ICG_EN (MCPU) -> CTRL
    .o_icgen_icg_timer_0    (w_icg_timer_0),
    .o_icgen_icg_timer_1    (w_icg_timer_1),
    .o_icgen_icg_uart_0     (w_icg_uart_0),
    .o_icgen_icg_uart_1     (w_icg_uart_1),
    .o_icgen_icg_spi        (w_icg_spi),
    .o_icgen_icg_i2c        (w_icg_i2c),
    .o_icgen_icg_gpio_0     (w_icg_gpio_0),
    .o_icgen_icg_gpio_1     (w_icg_gpio_1),
    .o_icgen_icg_gpio_2     (w_icg_gpio_2),
    .o_icgen_icg_dma        (w_icg_dma),
    .o_icgen_icg_pwm        (w_icg_pwm),
    // 0x10 RST_REL (MCPU) -> CTRL
    .o_rstrel_rel_sys       (w_rel_sys),
    .o_rstrel_rel_cpu       (w_rel_cpu),
    .o_rstrel_rel_timer_0   (w_rel_timer_0),
    .o_rstrel_rel_timer_1   (w_rel_timer_1),
    .o_rstrel_rel_uart_0    (w_rel_uart_0),
    .o_rstrel_rel_uart_1    (w_rel_uart_1),
    .o_rstrel_rel_spi       (w_rel_spi),
    .o_rstrel_rel_i2c       (w_rel_i2c),
    .o_rstrel_rel_gpio_0    (w_rel_gpio_0),
    .o_rstrel_rel_gpio_1    (w_rel_gpio_1),
    .o_rstrel_rel_gpio_2    (w_rel_gpio_2),
    .o_rstrel_rel_dma       (w_rel_dma),
    .o_rstrel_rel_pwm       (w_rel_pwm),
    // 0x14 APB_BLK (MCPU) -> guards
    .o_apbblk_blk_timer_0   (w_blk_timer_0),
    .o_apbblk_blk_timer_1   (w_blk_timer_1),
    .o_apbblk_blk_uart_0    (w_blk_uart_0),
    .o_apbblk_blk_uart_1    (w_blk_uart_1),
    .o_apbblk_blk_spi       (w_blk_spi),
    .o_apbblk_blk_i2c       (w_blk_i2c),
    .o_apbblk_blk_gpio_0    (w_blk_gpio_0),
    .o_apbblk_blk_gpio_1    (w_blk_gpio_1),
    .o_apbblk_blk_gpio_2    (w_blk_gpio_2),
    .o_apbblk_blk_dma       (w_blk_dma),
    .o_apbblk_blk_pwm       (w_blk_pwm),
    // 0x18 APB_BUSY (live) <- guards, bit n of i_csr_busy
    .i_apbbusy_busy_timer_0 (i_csr_busy[2]),
    .i_apbbusy_busy_timer_1 (i_csr_busy[3]),
    .i_apbbusy_busy_uart_0  (i_csr_busy[4]),
    .i_apbbusy_busy_uart_1  (i_csr_busy[5]),
    .i_apbbusy_busy_spi     (i_csr_busy[6]),
    .i_apbbusy_busy_i2c     (i_csr_busy[7]),
    .i_apbbusy_busy_gpio_0  (i_csr_busy[8]),
    .i_apbbusy_busy_gpio_1  (i_csr_busy[9]),
    .i_apbbusy_busy_gpio_2  (i_csr_busy[10]),
    .i_apbbusy_busy_dma     (i_csr_busy[11]),
    .i_apbbusy_busy_pwm     (i_csr_busy[12])
  );

  // APB_BLK to the guards: bit n of a gateable domain; sys and cpu (bits 1:0)
  // have no guard and read 0.
  assign o_csr_blk = {w_blk_pwm,    w_blk_dma,     w_blk_gpio_2,  w_blk_gpio_1,  // 12..9
                          w_blk_gpio_0, w_blk_i2c,     w_blk_spi,     w_blk_uart_1,  //  8..5
                          w_blk_uart_0, w_blk_timer_1, w_blk_timer_0,                //  4..2
                          2'b00};                                                    //  1..0

  // ==========================================================================
  // 7. Domain controllers (MAS 7.1, Table 5-2). Gate enable = ICG_EN bit, reset
  //    input = RST_REL bit. The two always-on domains tie the gate enable to 1:
  //    no register bit can stop them. SYSDBG has no controller: it runs on
  //    o_clk_sys and is reset by o_rst_n_por, so a debug session survives a WDT
  //    or SW reset (MAS 7.8).
  // ==========================================================================
  // ---- always-on ---------------------------------------------------------------
  m_qnsc_scrc_ctrl u_ctrl_sys (
    .i_clk_root(w_clk_root), .i_icg_en(1'b1), .i_rst_n_in(w_rel_sys),
    .o_clk_gated(o_clk_sys), .o_rst_n_sync(o_rst_n_sys));
  m_qnsc_scrc_ctrl u_ctrl_cpu (
    .i_clk_root(w_clk_root), .i_icg_en(1'b1), .i_rst_n_in(w_rel_cpu),
    .o_clk_gated(o_clk_cpu), .o_rst_n_sync(o_rst_n_cpu));

  // ---- gateable ------------------------------------------------------------------
  m_qnsc_scrc_ctrl u_ctrl_timer_0 (
    .i_clk_root(w_clk_root), .i_icg_en(w_icg_timer_0), .i_rst_n_in(w_rel_timer_0),
    .o_clk_gated(o_clk_timer_0), .o_rst_n_sync(o_rst_n_timer_0));
  m_qnsc_scrc_ctrl u_ctrl_timer_1 (
    .i_clk_root(w_clk_root), .i_icg_en(w_icg_timer_1), .i_rst_n_in(w_rel_timer_1),
    .o_clk_gated(o_clk_timer_1), .o_rst_n_sync(o_rst_n_timer_1));
  m_qnsc_scrc_ctrl u_ctrl_uart_0 (
    .i_clk_root(w_clk_root), .i_icg_en(w_icg_uart_0), .i_rst_n_in(w_rel_uart_0),
    .o_clk_gated(o_clk_uart_0), .o_rst_n_sync(o_rst_n_uart_0));
  m_qnsc_scrc_ctrl u_ctrl_uart_1 (
    .i_clk_root(w_clk_root), .i_icg_en(w_icg_uart_1), .i_rst_n_in(w_rel_uart_1),
    .o_clk_gated(o_clk_uart_1), .o_rst_n_sync(o_rst_n_uart_1));
  m_qnsc_scrc_ctrl u_ctrl_spi (
    .i_clk_root(w_clk_root), .i_icg_en(w_icg_spi), .i_rst_n_in(w_rel_spi),
    .o_clk_gated(o_clk_spi), .o_rst_n_sync(o_rst_n_spi));
  m_qnsc_scrc_ctrl u_ctrl_i2c (
    .i_clk_root(w_clk_root), .i_icg_en(w_icg_i2c), .i_rst_n_in(w_rel_i2c),
    .o_clk_gated(o_clk_i2c), .o_rst_n_sync(o_rst_n_i2c));
  m_qnsc_scrc_ctrl u_ctrl_gpio_0 (
    .i_clk_root(w_clk_root), .i_icg_en(w_icg_gpio_0), .i_rst_n_in(w_rel_gpio_0),
    .o_clk_gated(o_clk_gpio_0), .o_rst_n_sync(o_rst_n_gpio_0));
  m_qnsc_scrc_ctrl u_ctrl_gpio_1 (
    .i_clk_root(w_clk_root), .i_icg_en(w_icg_gpio_1), .i_rst_n_in(w_rel_gpio_1),
    .o_clk_gated(o_clk_gpio_1), .o_rst_n_sync(o_rst_n_gpio_1));
  m_qnsc_scrc_ctrl u_ctrl_gpio_2 (
    .i_clk_root(w_clk_root), .i_icg_en(w_icg_gpio_2), .i_rst_n_in(w_rel_gpio_2),
    .o_clk_gated(o_clk_gpio_2), .o_rst_n_sync(o_rst_n_gpio_2));
  m_qnsc_scrc_ctrl u_ctrl_dma (
    .i_clk_root(w_clk_root), .i_icg_en(w_icg_dma), .i_rst_n_in(w_rel_dma),
    .o_clk_gated(o_clk_dma), .o_rst_n_sync(o_rst_n_dma));
  m_qnsc_scrc_ctrl u_ctrl_pwm (
    .i_clk_root(w_clk_root), .i_icg_en(w_icg_pwm), .i_rst_n_in(w_rel_pwm),
    .o_clk_gated(o_clk_pwm), .o_rst_n_sync(o_rst_n_pwm));

endmodule
