// =============================================================================
// tb_scrc -- self-checking testbench for SCRC and its APB guard
// (QNSC_SCRC_MAS V3.4 section 12)
//
// DUT: m_qnsc_scrc with the real MRV-CPU running the generated CRM ROM, the
// generated APB BUS and SCRC CSR, and the generic technology cells (their delay
// cells model 1 ns each); one m_qnsc_scrc_apb_guard on uart_0 in front of an APB
// slave model that inserts wait states and runs on the gated o_clk_uart_0; one
// stand-alone guard driven by the testbench.
//
// Models: aon_timer bite request (sticky, cleared by o_rst_n_wdt); Ibex as an APB
// master on APB_M0 and on the uart_0 slot. The pad clock can be stopped.
//
// Tests (all run by default; +test=<name> runs one):
//   rst_001  RRC: POR no stretch; WDT and SW resets exactly 16 cycles; WDT and SW
//            requests in one cycle: one reset, both causes; a request after the load
//            is absorbed                                   (SCRC_RST_001, RRC_001, RST_005)
//   rst_002  a domain reset releases 2 domain-clock edges after its input; PORSTN
//            asserts every reset with the clock stopped     (SCRC_RST_002)
//   rst_003  power-up order: ICG before RST_REL, non-CPU together, guards before CPU,
//            timer_1 gated and in reset, always-on clocks run (RST_003, RST_007, RST_008, CLK_002, CLK_003)
//   clk_001  every running domain clock equals the root clock (SCRC_CLK_001)
//   flt_001  PORSTN glitch filter: 2 ns pulse ignored, 5 ns pulse resets (SCRC_FLT_001)
//   csr_001  register reset values, per-master rights, PSLVERR table, 14-bit
//            window without alias                          (CSR_001, CSR_002)
//   seq_001  back-to-back CLK_EN writes end with ICG_EN = last value   (SEQ_001; SEQ_002 is a monitor)
//   bus_001  guard: blocked access never reaches the IP; gating waits for a slow IP;
//            recovery by CLK_EN; APB_BLK change mid-transfer        (BUS_001, BUS_002, BUS_003, 7.10)
//   wf_001   both write filters of the DUT, every offset, read and write (CSR_001, Table 7-2)
// =============================================================================
`timescale 1ns/1ps

module tb_scrc;

  localparam real C_T = 50.0;                     // 20 MHz

  // ---- clock, pads, requests ---------------------------------------------------
  logic clk = 1'b0;
  logic clk_run = 1'b1;                           // 0 stops the pad clock (low)
  always #(C_T / 2) clk = clk_run ? ~clk : 1'b0;

  logic rst_n_pad = 1'b0;
  logic wdt_bite = 1'b0;
  logic wdt_req;

  // ---- APB master: SCRC (APB_M0) ------------------------------------------------
  logic        m0_psel = 0, m0_penable = 0, m0_pwrite = 0;
  logic [13:0] m0_paddr = 0;
  logic [31:0] m0_pwdata = 0;
  logic [3:0]  m0_pstrb = 4'hF;
  logic [31:0] m0_prdata;
  logic        m0_pready, m0_pslverr;
  // ---- APB master: uart_0 slot through the guard ----------------------------------
  logic        m8_psel = 0, m8_penable = 0, m8_pwrite = 0;
  logic [13:0] m8_paddr = 0;
  logic [31:0] m8_pwdata = 0;
  logic [31:0] m8_prdata;
  logic        m8_pready, m8_pslverr;

  // ---- DUT outputs -------------------------------------------------------------------
  logic [17:0] guard_busy, guard_blk;
  logic clk_cpu, rst_n_cpu, clk_sbus, rst_n_sbus, clk_pbus, rst_n_pbus, clk_rom, rst_n_rom;
  logic clk_ram, rst_n_ram, clk_sysdbg, rst_n_sysdbg, clk_wdt, rst_n_wdt;
  logic clk_timer_0, rst_n_timer_0, clk_timer_1, rst_n_timer_1, clk_uart_0, rst_n_uart_0;
  logic clk_uart_1, rst_n_uart_1, clk_spi, rst_n_spi, clk_i2c, rst_n_i2c;
  logic clk_gpio_0, rst_n_gpio_0, clk_gpio_1, rst_n_gpio_1, clk_gpio_2, rst_n_gpio_2;
  logic clk_pwm, rst_n_pwm, clk_dma, rst_n_dma;
  logic rst_n_por, cause_we_wdt, cause_we_sw;

  m_qnsc_scrc u_dut (
    .i_clk_pad (clk), .i_rst_n_pad (rst_n_pad),
    .i_wdt_rst_req (wdt_req),
    .i_bus_apb_psel (m0_psel), .i_bus_apb_penable (m0_penable), .i_bus_apb_pwrite (m0_pwrite),
    .i_bus_apb_paddr (m0_paddr), .i_bus_apb_pwdata (m0_pwdata), .i_bus_apb_pstrb (m0_pstrb),
    .i_bus_apb_pprot (3'b000),
    .o_bus_apb_prdata (m0_prdata), .o_bus_apb_pready (m0_pready), .o_bus_apb_pslverr (m0_pslverr),
    .i_guard_busy (guard_busy), .o_guard_blk (guard_blk),
    .o_clk_cpu (clk_cpu), .o_rst_n_cpu (rst_n_cpu), .o_clk_sbus (clk_sbus), .o_rst_n_sbus (rst_n_sbus),
    .o_clk_pbus (clk_pbus), .o_rst_n_pbus (rst_n_pbus), .o_clk_rom (clk_rom), .o_rst_n_rom (rst_n_rom),
    .o_clk_ram (clk_ram), .o_rst_n_ram (rst_n_ram), .o_clk_sysdbg (clk_sysdbg), .o_rst_n_sysdbg (rst_n_sysdbg),
    .o_clk_wdt (clk_wdt), .o_rst_n_wdt (rst_n_wdt),
    .o_clk_timer_0 (clk_timer_0), .o_rst_n_timer_0 (rst_n_timer_0),
    .o_clk_timer_1 (clk_timer_1), .o_rst_n_timer_1 (rst_n_timer_1),
    .o_clk_uart_0 (clk_uart_0), .o_rst_n_uart_0 (rst_n_uart_0),
    .o_clk_uart_1 (clk_uart_1), .o_rst_n_uart_1 (rst_n_uart_1),
    .o_clk_spi (clk_spi), .o_rst_n_spi (rst_n_spi), .o_clk_i2c (clk_i2c), .o_rst_n_i2c (rst_n_i2c),
    .o_clk_gpio_0 (clk_gpio_0), .o_rst_n_gpio_0 (rst_n_gpio_0),
    .o_clk_gpio_1 (clk_gpio_1), .o_rst_n_gpio_1 (rst_n_gpio_1),
    .o_clk_gpio_2 (clk_gpio_2), .o_rst_n_gpio_2 (rst_n_gpio_2),
    .o_clk_pwm (clk_pwm), .o_rst_n_pwm (rst_n_pwm), .o_clk_dma (clk_dma), .o_rst_n_dma (rst_n_dma),
    .o_rst_n_por (rst_n_por), .o_cause_we_wdt (cause_we_wdt), .o_cause_we_sw (cause_we_sw)
  );

  // ---- aon_timer bite request model: sticky, cleared only by rst_aon_ni ----------
  logic r_wdt_req = 1'b0;
  always @(posedge clk_wdt or negedge rst_n_wdt)
    if (!rst_n_wdt)    r_wdt_req <= 1'b0;
    else if (wdt_bite) r_wdt_req <= 1'b1;
  assign wdt_req = r_wdt_req;

  // ---- uart_0: guard + slow APB slave on the gated clock -------------------------
  logic        ip_psel, ip_penable, ip_pready;
  logic [31:0] ip_prdata;
  logic        guard_busy_uart_0;
  integer      ip_wait = 0;                       // wait states the IP inserts
  integer      ip_cnt;
  logic [31:0] ip_reg;
  integer      ip_access_count = 0;

  m_qnsc_scrc_apb_guard u_guard_uart_0 (
    .i_clk_pbus (clk_pbus), .i_rst_n_pbus (rst_n_pbus),
    .i_guard_blk (guard_blk[5]), .o_guard_busy (guard_busy_uart_0),
    .i_bus_apb_s_0_psel (m8_psel), .i_bus_apb_s_0_penable (m8_penable),
    .o_bus_apb_s_0_pready (m8_pready), .o_bus_apb_s_0_pslverr (m8_pslverr), .o_bus_apb_s_0_prdata (m8_prdata),
    .o_bus_apb_m_0_psel (ip_psel), .o_bus_apb_m_0_penable (ip_penable),
    .i_bus_apb_m_0_pready (ip_pready), .i_bus_apb_m_0_pslverr (1'b0), .i_bus_apb_m_0_prdata (ip_prdata)
  );

  always @(posedge clk_uart_0 or negedge rst_n_uart_0)
    if (!rst_n_uart_0) begin
      ip_cnt <= 0; ip_reg <= 32'h0000_0055;
    end else if (ip_psel && ip_penable) begin
      if (ip_cnt == ip_wait) begin
        ip_cnt <= 0;
        if (m8_pwrite) ip_reg <= m8_pwdata;
        ip_access_count <= ip_access_count + 1;
      end else ip_cnt <= ip_cnt + 1;
    end
  assign ip_pready = ip_psel && ip_penable && (ip_cnt == ip_wait);
  assign ip_prdata = ip_reg;

  assign guard_busy = {12'd0, guard_busy_uart_0, 5'd0};      // bit 5 = uart_0

  // ---- stand-alone guard for BUS_002 (APB_BLK driven by the testbench) -----------
  logic g2_blk = 1'b0, g2_psel = 0, g2_penable = 0;
  logic g2_pready, g2_pslverr, g2_ip_psel, g2_ip_penable, g2_busy;
  logic [31:0] g2_prdata;
  m_qnsc_scrc_apb_guard u_guard_unit (
    .i_clk_pbus (clk), .i_rst_n_pbus (rst_n_pbus),
    .i_guard_blk (g2_blk), .o_guard_busy (g2_busy),
    .i_bus_apb_s_0_psel (g2_psel), .i_bus_apb_s_0_penable (g2_penable),
    .o_bus_apb_s_0_pready (g2_pready), .o_bus_apb_s_0_pslverr (g2_pslverr), .o_bus_apb_s_0_prdata (g2_prdata),
    .o_bus_apb_m_0_psel (g2_ip_psel), .o_bus_apb_m_0_penable (g2_ip_penable),
    .i_bus_apb_m_0_pready (g2_ip_psel & g2_ip_penable), .i_bus_apb_m_0_pslverr (1'b0), .i_bus_apb_m_0_prdata (32'hCAFE_F00D)
  );

  // ---- register state seen inside the DUT (per-domain wires of the top) ----
  logic [17:0] icg_en;
  logic [31:0] rst_rel;
  assign icg_en  = {u_dut.w_icg_gpio_2, u_dut.w_icg_gpio_1, u_dut.w_icg_pwm, 4'b0000, u_dut.w_icg_dma,
                    u_dut.w_icg_gpio_0, u_dut.w_icg_i2c, u_dut.w_icg_spi, u_dut.w_icg_uart_1,
                    u_dut.w_icg_uart_0, u_dut.w_icg_timer_1, u_dut.w_icg_timer_0, 3'b000};
  assign rst_rel = {u_dut.w_rel_cpu, 13'd0, u_dut.w_rel_gpio_2, u_dut.w_rel_gpio_1, u_dut.w_rel_pwm, 2'b00,
                    u_dut.w_rel_ram, u_dut.w_rel_rom, u_dut.w_rel_dma, u_dut.w_rel_gpio_0, u_dut.w_rel_i2c,
                    u_dut.w_rel_spi, u_dut.w_rel_uart_1, u_dut.w_rel_uart_0, u_dut.w_rel_timer_1,
                    u_dut.w_rel_timer_0, u_dut.w_rel_wdt, u_dut.w_rel_pbus, u_dut.w_rel_sbus};

  // the 18 domain clocks and resets
  logic [17:0] dom_clk, dom_rst_n;
  assign dom_clk   = {clk_cpu, clk_sbus, clk_pbus, clk_rom, clk_ram, clk_sysdbg, clk_wdt, clk_timer_0,
                      clk_timer_1, clk_uart_0, clk_uart_1, clk_spi, clk_i2c, clk_gpio_0, clk_gpio_1,
                      clk_gpio_2, clk_pwm, clk_dma};
  assign dom_rst_n = {rst_n_cpu, rst_n_sbus, rst_n_pbus, rst_n_rom, rst_n_ram, rst_n_sysdbg, rst_n_wdt,
                      rst_n_timer_0, rst_n_timer_1, rst_n_uart_0, rst_n_uart_1, rst_n_spi, rst_n_i2c,
                      rst_n_gpio_0, rst_n_gpio_1, rst_n_gpio_2, rst_n_pwm, rst_n_dma};

  initial begin
    string w;
    if ($value$plusargs("waves=%s", w)) begin
      $dumpfile(w);
      $dumpvars(0, tb_scrc);
    end
  end

  // =============================================================================
  // Helpers
  // =============================================================================
  integer cyc = 0;
  always @(posedge clk) cyc <= cyc + 1;

  integer errors = 0;
  task automatic check(input logic ok, input [8*80-1:0] what);
    if (ok !== 1'b1) begin                          // X or Z fails too (4-state simulators)
      $display("FAIL at cycle %0d: %0s", cyc, what);
      $fatal(1, "tb_scrc: check failed");
    end
  endtask

  task automatic wait_cycles(input integer n);
    repeat (n) @(posedge clk);
  endtask

  // Generic APB transfer. port 0 = SCRC (APB_M0), 8 = uart_0 slot.
  task automatic apb(input integer port, input logic wr, input [13:0] addr, input [31:0] wdata,
                     input [3:0] strb, output [31:0] rdata, output logic err);
    logic rdy;
    @(negedge clk);
    case (port)
      0: begin m0_psel = 1; m0_penable = 0; m0_pwrite = wr; m0_paddr = addr; m0_pwdata = wdata; m0_pstrb = strb; end
      default: begin m8_psel = 1; m8_penable = 0; m8_pwrite = wr; m8_paddr = addr; m8_pwdata = wdata; end
    endcase
    @(negedge clk);
    case (port) 0: m0_penable = 1; default: m8_penable = 1; endcase
    rdy = 0;
    while (!rdy) begin
      @(posedge clk);
      case (port)
        0: begin rdy = m0_pready; rdata = m0_prdata; err = m0_pslverr; end
        default: begin rdy = m8_pready; rdata = m8_prdata; err = m8_pslverr; end
      endcase
    end
    @(negedge clk);
    case (port)
      0: begin m0_psel = 0; m0_penable = 0; end
      default: begin m8_psel = 0; m8_penable = 0; end
    endcase
  endtask

  task automatic wr32(input integer port, input [13:0] addr, input [31:0] data, output logic err);
    logic [31:0] d;
    apb(port, 1'b1, addr, data, 4'hF, d, err);
  endtask

  task automatic rd32(input integer port, input [13:0] addr, output [31:0] data, output logic err);
    apb(port, 1'b0, addr, 32'd0, 4'hF, data, err);
  endtask

  task automatic expect_rd(input integer port, input [13:0] addr, input [31:0] exp, input logic exp_err,
                           input [8*80-1:0] what);
    logic [31:0] d; logic e;
    rd32(port, addr, d, e);
    if (e !== exp_err || (!exp_err && d !== exp)) begin
      $display("FAIL %0s: read 0x%04h = 0x%08h err=%0b, expected 0x%08h err=%0b", what, addr, d, e, exp, exp_err);
      $fatal(1, "tb_scrc: read mismatch");
    end
  endtask

  task automatic expect_wr(input integer port, input [13:0] addr, input [31:0] data, input [3:0] strb,
                           input logic exp_err, input [8*80-1:0] what);
    logic [31:0] d; logic e;
    apb(port, 1'b1, addr, data, strb, d, e);
    if (e !== exp_err) begin
      $display("FAIL %0s: write 0x%04h err=%0b, expected err=%0b", what, addr, e, exp_err);
      $fatal(1, "tb_scrc: write response mismatch");
    end
  endtask


  // Width of the next low pulse of w_rst_n_sys and of the o_cause_we_* pulse, in cycles,
  // measured between the edges (sampling at a clock edge would see pre-update values).
  realtime r_t0, r_t1, c_t0, c_t1;
  task automatic measure_sys_reset(input logic wdt, output integer n_sys, output integer n_cause);
    fork
      begin
        if (u_dut.w_rst_n_sys === 1'b1) @(negedge u_dut.w_rst_n_sys);
        r_t0 = $realtime;
        @(posedge u_dut.w_rst_n_sys);
        r_t1 = $realtime;
      end
      begin
        if (wdt) begin
          if (cause_we_wdt !== 1'b1) @(posedge cause_we_wdt);
          c_t0 = $realtime; @(negedge cause_we_wdt); c_t1 = $realtime;
        end else begin
          if (cause_we_sw !== 1'b1) @(posedge cause_we_sw);
          c_t0 = $realtime; @(negedge cause_we_sw); c_t1 = $realtime;
        end
      end
    join
    n_sys   = $rtoi((r_t1 - r_t0) / C_T + 0.5);
    n_cause = $rtoi((c_t1 - c_t0) / C_T + 0.5);
  endtask

  // Wait until the CPU leaves reset (the end of the power-up program).
  task automatic wait_cpu_released(input integer timeout);
    integer t;
    t = 0;
    while (rst_n_cpu !== 1'b1 && t < timeout) begin @(posedge clk); t = t + 1; end
    check(rst_n_cpu === 1'b1, "CPU released by the power-up program");
  endtask

  // Wait until MCPU has applied CLK_EN (ICG_EN and APB_BLK follow the request).
  task automatic wait_applied(input [31:0] clk_en, input integer timeout);
    integer t;
    t = 0;
    while (!(icg_en == clk_en[17:0] &&
             guard_blk == (~clk_en[17:0] & 18'h387F8)) && t < timeout) begin
      @(posedge clk); t = t + 1;
    end
    check(t < timeout, "MCPU applied CLK_EN");
  endtask

  task automatic power_on;
    rst_n_pad = 1'b0;
    wait_cycles(10);
    @(negedge clk) rst_n_pad = 1'b1;
  endtask

  // =============================================================================
  // Always-on monitors
  // =============================================================================
  // SCRC_SEQ_002: APB_BLK[n] = 0 only if domain n's clock runs (ICG_EN[n] = 1).
  always @(posedge clk)
    if (u_dut.w_rst_n_sys === 1'b1)
      if ((~guard_blk & 18'h387F8 & ~icg_en) != 18'd0) begin
        $display("FAIL SCRC_SEQ_002 at cycle %0d: APB_BLK=%h ICG_EN=%h", cyc, guard_blk, icg_en);
        $fatal(1, "tb_scrc: invariant broken");
      end

  // SCRC_BUS_003: the uart_0 clock is never disabled while a forwarded transfer is in flight.
  // Watched at the IP side (PSEL reaching the IP), not through the guard's own busy output,
  // so a guard that fails to report busy is caught too.
  always @(posedge clk)
    if (ip_psel === 1'b1 && icg_en[5] === 1'b0) begin
      $display("FAIL SCRC_BUS_003 at cycle %0d: ICG_EN[5]=0 with a transfer through the guard", cyc);
      $fatal(1, "tb_scrc: clock stopped under a transfer");
    end

  // =============================================================================
  // Tests
  // =============================================================================
  integer t_por, t_sys, n_low, n_cause, t_icg, t_rel, t_cpu, t_non_cpu, i;
  logic [31:0] d;
  logic e;
  logic [17:0] blk_at_cpu;
  integer n_both;
  logic e2;

  // free-running edge counters of two always-on clocks (SCRC_CLK_002)
  integer edges_wdt = 0, edges_cpu = 0;
  always @(posedge clk_wdt) edges_wdt = edges_wdt + 1;
  always @(posedge clk_cpu) edges_cpu = edges_cpu + 1;

  // ---- SCRC_RST_001 / RRC_001 / RST_005 -----------------------------------------
  task automatic t_rst_001;
    // POR: w_rst_n_sys releases one cycle after w_rst_n_por, no stretch.
    power_on();
    @(posedge rst_n_por); t_por = cyc;
    @(posedge u_dut.w_rst_n_sys); t_sys = cyc;
    check(t_sys - t_por == 1, "SCRC_RST_001: POR -> w_rst_n_sys release after 1 cycle");
    check(cause_we_wdt === 0 && cause_we_sw === 0, "POR sets no cause enable");
    wait_cpu_released(400);

    // WDT bite, cleared by the reset it causes: exactly 16 cycles, cause_we_wdt for those 16.
    @(negedge clk) wdt_bite = 1;
    @(negedge clk) wdt_bite = 0;
    fork
      measure_sys_reset(1'b1, n_low, n_cause);
      begin
        while (u_dut.w_rst_n_sys !== 1'b0) @(posedge clk);
        while (u_dut.w_rst_n_sys !== 1'b1) begin
          @(posedge clk);
          check(cause_we_sw === 1'b0, "SCRC_RRC_001: cause_we_sw stays 0 on a WDT reset");
          check(rst_n_por === 1'b1 && rst_n_sysdbg === 1'b1, "SCRC_RST_005: WDT reset leaves o_rst_n_por, sysdbg");
        end
      end
    join
    $display("  WDT reset: w_rst_n_sys low %0d cycles, cause_we_wdt high %0d cycles", n_low, n_cause);
    check(n_low == 16, "SCRC_RST_001: WDT chip reset is exactly 16 cycles");
    check(n_cause == 16, "SCRC_RRC_001: o_cause_we_wdt = 1 for exactly the 16 cycles");
    check(wdt_req === 1'b0, "the WDT reset cleared the bite request");
    wait_cpu_released(400);

    // SW_RST from Ibex: exactly 16 cycles, cause_we_sw.
    fork
      wr32(0, 14'h000, 32'h1, e);
      measure_sys_reset(1'b0, n_low, n_cause);
    join
    check(cause_we_wdt === 1'b0, "cause_we_wdt stays 0 on a SW reset");
    $display("  SW reset : w_rst_n_sys low %0d cycles, cause_we_sw high %0d cycles", n_low, n_cause);
    check(n_low == 16 && n_cause == 16, "SCRC_RST_001: SW chip reset is exactly 16 cycles");
    wait_cpu_released(400);

    // Both requests at RRC in the same cycle (MAS 7.3): one 16-cycle reset, both cause
    // enables for its whole length. SW_RST is written by Ibex; the synchronised WDT
    // request is forced for exactly the cycle in which SW_RST reaches RRC, so the
    // timing does not depend on where MCPU is in its loop.
    fork
      measure_sys_reset(1'b1, n_low, n_cause);
      wr32(0, 14'h000, 32'h1, e);
      begin
        @(posedge u_dut.u_rrc.i_sw_rst); #1;
        force u_dut.u_rrc.w_wdt_req = 1'b1;
        @(posedge clk); #1;
        release u_dut.u_rrc.w_wdt_req;
      end
      begin
        n_both = 0;
        @(negedge u_dut.w_rst_n_sys);
        while (u_dut.w_rst_n_sys !== 1'b1) begin
          @(negedge clk);
          if (u_dut.w_rst_n_sys === 1'b0 && cause_we_wdt === 1'b1 && cause_we_sw === 1'b1) n_both = n_both + 1;
        end
      end
    join
    $display("  SW + WDT same cycle: w_rst_n_sys low %0d cycles, both causes %0d cycles", n_low, n_both);
    check(n_low == 16, "WDT and SW requests in the same cycle: one 16-cycle reset");
    check(n_both == 16, "WDT and SW requests in the same cycle: both cause enables for the 16 cycles");
    repeat (60) begin
      @(posedge clk);
      check(u_dut.w_rst_n_sys === 1'b1, "no second chip reset after a joint request");
    end
    wait_cpu_released(400);

    // A WDT request arriving two cycles after an SW load is absorbed by that reset:
    // still one 16-cycle reset, cause SOFT only (the cause is captured in the load cycle).
    fork
      measure_sys_reset(1'b0, n_low, n_cause);
      wr32(0, 14'h000, 32'h1, e);
      begin
        @(negedge u_dut.w_rst_n_sys);               // the SW load
        repeat (2) @(posedge clk); #1;
        force u_dut.u_rrc.w_wdt_req = 1'b1;
        @(posedge clk); #1;
        release u_dut.u_rrc.w_wdt_req;
      end
      begin
        repeat (40) begin
          @(posedge clk);
          check(cause_we_wdt === 1'b0, "a WDT request after the SW load sets no WDT cause");
        end
      end
    join
    $display("  SW, then WDT 2 cycles later: w_rst_n_sys low %0d cycles", n_low);
    check(n_low == 16 && n_cause == 16, "a request after the load is absorbed: one 16-cycle reset");
    repeat (60) begin
      @(posedge clk);
      check(u_dut.w_rst_n_sys === 1'b1, "no second chip reset after an absorbed request");
    end
    wait_cpu_released(400);
    $display("PASS rst_001");
  endtask

  // ---- SCRC_RST_003 / RST_007 / RST_008 / CLK_002 / CLK_003 ------------------------
  task automatic t_rst_003;
    integer n_edges_wdt, n_edges_t1, n_edges_cpu;
    power_on();
    @(posedge u_dut.w_rst_n_sys);
    t_icg = -1; t_rel = -1; t_non_cpu = -1; t_cpu = -1;
    n_edges_wdt = 0; n_edges_t1 = 0; n_edges_cpu = 0;
    while (t_cpu < 0) begin
      @(posedge clk);
      if (t_icg < 0 && icg_en != 0)             t_icg = cyc;
      if (t_rel < 0 && rst_rel != 0)            t_rel = cyc;
      if (t_non_cpu < 0 && rst_n_sbus === 1'b1)         t_non_cpu = cyc;
      if (rst_n_cpu === 1'b1) begin t_cpu = cyc; blk_at_cpu = guard_blk; end
      if (t_non_cpu >= 0 && t_non_cpu == cyc) begin
        // every non-CPU domain except timer_1 (gated) released in the same cycle
        check(rst_n_pbus && rst_n_rom && rst_n_ram && rst_n_wdt && rst_n_timer_0 && rst_n_uart_0 &&
              rst_n_uart_1 && rst_n_spi && rst_n_i2c && rst_n_gpio_0 && rst_n_gpio_1 && rst_n_gpio_2 &&
              rst_n_pwm && rst_n_dma, "SCRC_RST_003: all non-CPU domains release in the same cycle");
        check(rst_n_cpu === 1'b0, "CPU still in reset when the others release");
      end
      check(cyc < 2000, "power-up completes");
    end
    $display("  ICG_EN@%0d RST_REL@%0d non-CPU@%0d CPU@%0d  APB_BLK at CPU release = %h",
             t_icg, t_rel, t_non_cpu, t_cpu, blk_at_cpu);
    check(icg_en == 18'h387E8, "step 1: ICG_EN = CLK_EN reset value 0x0003_87E8");
    check(t_rel - t_icg >= 3, "Table 7-4: ICG_EN[n] = 1 at least 3 cycles before RST_REL[n] = 1");
    check(t_cpu - t_non_cpu >= 16, "SCRC_RST_003: CPU released >= 16 cycles after the others");
    check(blk_at_cpu == 18'h00010, "SCRC_RST_007: APB_BLK = NOT CLK_EN (0x10) before the CPU releases");
    check(rst_rel == 32'h8003_9FFF, "step 6: RST_REL = 0x8003_9FFF");
    // 40 root cycles; the edge counters below run freely, so a stopped clock shows as
    // a count below 39 instead of a wait that never ends.
    n_edges_wdt = edges_wdt; n_edges_cpu = edges_cpu;
    repeat (40) @(posedge clk);
    n_edges_wdt = edges_wdt - n_edges_wdt; n_edges_cpu = edges_cpu - n_edges_cpu;
    check(n_edges_wdt >= 39 && n_edges_cpu >= 39, "SCRC_CLK_002: always-on clocks (wdt, cpu) run");
    check(clk_timer_1 === 1'b0 && rst_n_timer_1 === 1'b0, "SCRC_CLK_003/RST_008: timer_1 gated and in reset");
    // Using TIMER1 (Table 7-5): CLK_EN[4] = 1, done when APB_BLK[4] = 0.
    wr32(0, 14'h004, 32'h387F8, e);
    check(e === 1'b0, "Ibex writes CLK_EN");
    wait_applied(32'h387F8, 400);
    wait_cycles(3);
    check(rst_n_timer_1 === 1'b1, "SCRC_RST_008: timer_1 releases once CLK_EN[4] is set");
    $display("PASS rst_003");
  endtask

  // ---- SCRC_CSR_001 / CSR_002 ------------------------------------------------------------
  task automatic t_csr_001;
    power_on();
    wait_cpu_released(400);
    wait_cycles(20);
    expect_rd(0, 14'h000, 32'h0,         0, "SW_RST reset value");
    expect_rd(0, 14'h004, 32'h0003_87E8, 0, "CLK_EN reset value");
    expect_rd(0, 14'h008, 32'h0,         0, "0x08 reserved reads 0");
    expect_rd(0, 14'h00C, 32'h0003_87E8, 0, "ICG_EN after power-up");
    expect_rd(0, 14'h010, 32'h8003_9FFF, 0, "RST_REL after power-up");
    expect_rd(0, 14'h014, 32'h0000_0010, 0, "APB_BLK after power-up");
    expect_rd(0, 14'h018, 32'h0,         0, "APB_BUSY idle");
    // Ibex may not write MCPU registers: dropped, PSLVERR, unchanged (Table 7-2).
    expect_wr(0, 14'h00C, 32'h0, 4'hF, 1, "Ibex write ICG_EN");
    expect_wr(0, 14'h010, 32'h0, 4'hF, 1, "Ibex write RST_REL");
    expect_wr(0, 14'h014, 32'hFFFF_FFFF, 4'hF, 1, "Ibex write APB_BLK");
    expect_wr(0, 14'h018, 32'hFFFF_FFFF, 4'hF, 1, "Ibex write APB_BUSY");
    check(rst_n_cpu === 1'b1 && rst_rel == 32'h8003_9FFF, "dropped writes changed nothing");
    expect_rd(0, 14'h014, 32'h0000_0010, 0, "APB_BLK unchanged");
    // 0x1C: WF; 0x20..0xFFF: APB BUS; misaligned / partial strobe: CSR.
    expect_rd(0, 14'h01C, 32'h0, 1, "read 0x1C");
    expect_wr(0, 14'h01C, 32'h0, 4'hF, 1, "write 0x1C");
    expect_rd(0, 14'h020, 32'h0, 1, "read 0x20");
    expect_rd(0, 14'hFFC, 32'h0, 1, "read 0xFFC");
    expect_rd(0, 14'h3FFC, 32'h0, 1, "read 0x3FFC, the last word of the 16 KiB window");
    // V3.4: all 14 offset bits are decoded, so 0x1000 is no longer an alias of SW_RST.
    fork
      expect_wr(0, 14'h1000, 32'h1, 4'hF, 1, "write 1 to 0x1000 -> PSLVERR");
      begin
        repeat (30) begin
          @(posedge clk);
          check(u_dut.w_rst_n_sys === 1'b1, "a write to 0x1000 does not reset the chip");
        end
      end
    join
    expect_rd(0, 14'h1004, 32'h0, 1, "read 0x1004 -> PSLVERR (no CLK_EN alias)");
    expect_rd(0, 14'h006, 32'h0, 1, "misaligned read");
    expect_wr(0, 14'h004, 32'h0, 4'h1, 1, "partial-strobe write to CLK_EN");
    expect_rd(0, 14'h004, 32'h0003_87E8, 0, "CLK_EN unchanged after the faulting write");
    // Implemented bits only (0x0003_87F8 in CLK_EN).
    expect_wr(0, 14'h004, 32'hFFFF_FFFF, 4'hF, 0, "write all ones to CLK_EN");
    expect_rd(0, 14'h004, 32'h0003_87F8, 0, "CLK_EN implemented bits");
    wait_applied(32'h387F8, 400);
    $display("PASS csr_001");
  endtask

  // ---- SCRC_RST_002 -------------------------------------------------------------------------
  task automatic t_rst_002;
    integer n;
    // Release: o_rst_n_sbus rises on the 2nd rising edge of o_clk_sbus after RST_REL[0].
    power_on();
    @(posedge u_dut.w_rel_sbus);
    n = 0;
    while (rst_n_sbus !== 1'b1) begin
      @(posedge clk_sbus); #1;
      n = n + 1;
      check(n <= 4, "o_rst_n_sbus releases");
    end
    check(n == 2, "SCRC_RST_002: a domain reset releases 2 domain-clock edges after its input rises");
    wait_cpu_released(400);

    // Assertion needs no clock: stop CLKIN, pull PORSTN; every reset falls within the
    // filter delay (3 cells), before any clock edge.
    @(negedge clk) clk_run = 1'b0;
    #(C_T);
    rst_n_pad = 1'b0;
    #10;
    check(rst_n_por === 1'b0, "PORSTN with the clock stopped asserts o_rst_n_por");
    check(dom_rst_n === 18'd0, "PORSTN with the clock stopped asserts every o_rst_n_<d>");
    check(cause_we_wdt === 1'b0 && cause_we_sw === 1'b0, "power-on sets no cause enable");
    clk_run = 1'b1;
    power_on();
    wait_cpu_released(400);
    $display("PASS rst_002");
  endtask

  // ---- SCRC_CLK_001 -------------------------------------------------------------------------
  task automatic t_clk_001;
    power_on();
    wait_cpu_released(400);
    wr32(0, 14'h004, 32'h0003_87F8, e);             // every gateable clock on
    wait_applied(32'h387F8, 400);
    // Sample a quarter period after each edge: every domain clock equals the root.
    repeat (20) begin
      @(posedge clk); #(C_T / 4);
      check(dom_clk === 18'h3FFFF, "SCRC_CLK_001: every domain clock high with the root");
      @(negedge clk); #(C_T / 4);
      check(dom_clk === 18'h00000, "SCRC_CLK_001: every domain clock low with the root");
    end
    $display("PASS clk_001");
  endtask

  // ---- SCRC_FLT_001 -------------------------------------------------------------------------
  logic por_fell;
  always @(negedge rst_n_por) por_fell = 1'b1;

  task automatic t_flt_001;
    power_on();
    wait_cpu_released(400);
    // 2 ns low pulse, shorter than the three 1 ns delay cells plus the pad: ignored.
    por_fell = 1'b0;
    @(negedge clk); #5;
    rst_n_pad = 1'b0; #2; rst_n_pad = 1'b1;
    wait_cycles(10);
    check(por_fell === 1'b0 && rst_n_por === 1'b1, "SCRC_FLT_001: a 2 ns PORSTN glitch does not reset");
    check(rst_n_cpu === 1'b1, "the CPU keeps running after the glitch");
    // 5 ns low pulse, longer than the three delays: a power-on reset.
    @(negedge clk); #5;
    rst_n_pad = 1'b0; #5; rst_n_pad = 1'b1;
    wait_cycles(2);
    check(por_fell === 1'b1, "SCRC_FLT_001: a 5 ns PORSTN pulse is a power-on reset");
    wait_cpu_released(400);
    $display("PASS flt_001");
  endtask

  // ---- SCRC_SEQ_001 ----------------------------------------------------------------------
  task automatic t_seq_001;
    power_on();
    wait_cpu_released(400);
    // back-to-back writes, several bits at once, no waiting
    wr32(0, 14'h004, 32'h0003_8008, e);
    wr32(0, 14'h004, 32'h0000_07F8, e);
    wr32(0, 14'h004, 32'h0002_0428, e);
    wr32(0, 14'h004, 32'h0001_8790, e);
    wait_applied(32'h0001_8790, 2000);
    wait_cycles(100);
    check(icg_en == 18'h18790, "SCRC_SEQ_001: ICG_EN = last value written");
    expect_rd(0, 14'h00C, 32'h0001_8790, 0, "ICG_EN read back");
    $display("PASS seq_001");
  endtask

  // ---- SCRC_BUS_001 / 002 / 003, recovery (7.10) --------------------------------------------
  task automatic t_bus_001;
    integer n_ip_before;
    power_on();
    wait_cpu_released(400);
    wait_cycles(10);
    // forwarded access to uart_0 with 3 wait states
    ip_wait = 3;
    wr32(8, 14'h000, 32'h1234_5678, e);
    check(e === 1'b0, "forwarded write to uart_0");
    rd32(8, 14'h000, d, e);
    check(e === 1'b0 && d == 32'h1234_5678, "forwarded read from uart_0");

    // BUS_003: a slow transfer (200 wait states) is forwarded, and the clock stop is
    // requested while it is in flight. The transfer completes normally and the clock
    // stops only after it (always-on monitor above checks every cycle).
    ip_wait = 200;                                   // long enough for MCPU to act mid-transfer
    fork
      begin rd32(8, 14'h000, d, e); end
      begin wait (ip_psel === 1'b1); wr32(0, 14'h004, 32'h0003_87C8, e2); end   // CLK_EN[5] = 0
    join
    check(e === 1'b0 && d == 32'h1234_5678, "SCRC_BUS_003: the transfer in flight completes normally");
    check(e2 === 1'b0, "Ibex writes CLK_EN during the transfer");
    wait_applied(32'h0003_87C8, 400);
    check(clk_uart_0 === 1'b0, "uart_0 clock stopped");

    // BUS_001: a blocked access errors in one transfer and never reaches the IP.
    n_ip_before = ip_access_count;
    fork
      begin rd32(8, 14'h000, d, e); end
      begin repeat (6) begin @(posedge clk); check(ip_psel === 1'b0, "SCRC_BUS_001: PSEL never reaches the IP"); end end
    join
    check(e === 1'b1 && d == 32'h0, "SCRC_BUS_001: blocked access -> PSLVERR, PRDATA 0");
    check(ip_access_count == n_ip_before, "no IP access while blocked");

    // Recovery (Table 7-5): CLK_EN[5] = 1, wait APB_BLK[5] = 0, retry.
    ip_wait = 0;
    wr32(0, 14'h004, 32'h0003_87E8, e);
    rd32(0, 14'h014, d, e);
    while (d[5] !== 1'b0) rd32(0, 14'h014, d, e);     // done when APB_BLK[5] = 0
    rd32(8, 14'h000, d, e);
    check(e === 1'b0 && d == 32'h1234_5678, "retry after CLK_EN[5] = 1 succeeds, IP state kept");

    // BUS_002: APB_BLK changing during a transfer does not change its response.
    @(negedge clk); g2_blk = 1'b0; g2_psel = 1; g2_penable = 0;      // SETUP, not blocked
    @(negedge clk); g2_penable = 1; g2_blk = 1'b1;                    // blocked in ACCESS
    @(posedge clk); #1;
    check(g2_pready === 1'b1 && g2_pslverr === 1'b0 && g2_prdata == 32'hCAFE_F00D,
          "SCRC_BUS_002: sampled at SETUP, forwarded despite APB_BLK rising");
    @(negedge clk); g2_psel = 0; g2_penable = 0;
    @(negedge clk); g2_psel = 1; g2_penable = 0;                      // SETUP, blocked
    @(negedge clk); g2_penable = 1; g2_blk = 1'b0;                    // unblocked in ACCESS
    @(posedge clk); #1;
    check(g2_pready === 1'b1 && g2_pslverr === 1'b1 && g2_ip_psel === 1'b0,
          "SCRC_BUS_002: blocked at SETUP stays blocked");
    @(negedge clk); g2_psel = 0; g2_penable = 0;
    $display("PASS bus_001");
  endtask

  // ---- SCRC_CSR_001, the write-filter rows of Table 7-2 ---------------------------------
  // Each filter of the DUT, at each of the 8 word offsets of the window, for a write and a
  // read: forwarded to the APB BUS, or denied with PSLVERR. The filters are combinational:
  // MCPU's outputs are forced for a moment (the chip is power-cycled afterwards because
  // MCPU's own bus transfer is disturbed), the Ibex side is the testbench's APB_M0.
  task automatic wf_check(input logic mcpu, input logic [7:0] deny, input logic [13:0] base);
    logic [13:0] a;
    logic        wr, exp_deny;
    for (int k = 0; k < 8; k++) begin
      for (int w = 0; w < 2; w++) begin
        a = base + 14'(4 * k);
        wr = 1'(w);
        exp_deny = (base == 14'h0000) && ((k == 7) || (wr && deny[k]));   // 0x1C and the deny mask apply in 0x00-0x1F only
        if (mcpu) begin
          force u_dut.w_mcpu_psel = 1'b1;
          force u_dut.w_mcpu_penable = 1'b0;
          force u_dut.w_mcpu_pwrite = wr;
          force u_dut.w_mcpu_paddr = {18'd0, a};
          #1;
          check(u_dut.u_wf_mcpu.o_bus_apb_m_0_psel === !exp_deny, "SCRC_CSR_001: MCPU write filter forwards / denies");
          if (exp_deny)
            check(u_dut.u_wf_mcpu.o_bus_apb_s_0_pready === 1'b1 && u_dut.u_wf_mcpu.o_bus_apb_s_0_pslverr === 1'b1,
                  "SCRC_CSR_001: MCPU denied access answered by the filter");
        end else begin
          m0_psel = 1'b1; m0_penable = 1'b0; m0_pwrite = wr; m0_paddr = a;   // Ibex side: the TB drives APB_M0
          #1;
          check(u_dut.u_wf_ibex.o_bus_apb_m_0_psel === !exp_deny, "SCRC_CSR_001: Ibex write filter forwards / denies");
          if (exp_deny)
            check(u_dut.u_wf_ibex.o_bus_apb_s_0_pready === 1'b1 && u_dut.u_wf_ibex.o_bus_apb_s_0_pslverr === 1'b1,
                  "SCRC_CSR_001: Ibex denied access answered by the filter");
        end
      end
    end
    release u_dut.w_mcpu_psel;  release u_dut.w_mcpu_penable;
    release u_dut.w_mcpu_pwrite; release u_dut.w_mcpu_paddr;
    m0_psel = 1'b0; m0_penable = 1'b0; m0_pwrite = 1'b0; m0_paddr = '0;
  endtask

  task automatic t_wf_001;
    power_on();
    wait_cpu_released(400);
    @(negedge clk);
    // MCPU may write ICG_EN, RST_REL, APB_BLK only: writes to 0x00, 0x04, 0x18 denied.
    wf_check(1'b1, 8'b0100_0011, 14'h0000);
    // Ibex may write SW_RST, CLK_EN only: writes to 0x0C-0x18 denied.
    wf_check(1'b0, 8'b0111_1000, 14'h0000);
    // Above 0x1F the filters forward everything; the APB BUS answers (csr_001).
    wf_check(1'b1, 8'b0000_0000, 14'h0020);
    power_on();
    wait_cpu_released(400);
    $display("PASS wf_001");
  endtask

  // =============================================================================
  initial begin
    reg [8*16-1:0] name;
    logic all;
    integer n_run;
    all = !$value$plusargs("test=%s", name);
    n_run = 0;
    if (all || name == "rst_001") begin t_rst_001(); n_run = n_run + 1; end
    if (all || name == "rst_003") begin t_rst_003(); n_run = n_run + 1; end
    if (all || name == "csr_001") begin t_csr_001(); n_run = n_run + 1; end
    if (all || name == "seq_001") begin t_seq_001(); n_run = n_run + 1; end
    if (all || name == "bus_001") begin t_bus_001(); n_run = n_run + 1; end
    if (all || name == "rst_002") begin t_rst_002(); n_run = n_run + 1; end
    if (all || name == "clk_001") begin t_clk_001(); n_run = n_run + 1; end
    if (all || name == "flt_001") begin t_flt_001(); n_run = n_run + 1; end
    if (all || name == "wf_001")  begin t_wf_001();  n_run = n_run + 1; end
    if (n_run == 0) $fatal(1, "tb_scrc: no test named %0s", name);
    $display("PASS tb_scrc (%0d tests, %0d cycles)", n_run, cyc);
    $finish;
  end

  initial begin
    #(C_T * 200000);
    $fatal(1, "tb_scrc: global timeout");
  end

endmodule
