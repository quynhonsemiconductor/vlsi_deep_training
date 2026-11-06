`default_nettype none
`timescale 1ns/1ps
//==============================================================================
// Testbench : tb_sbus -- S_BUS (m_qnsc_wrap_sbus) with its three masters and four slaves
//   masters  s_0 SYSDBG, s_1 CPU, s_2 DMA: tasks axi_wr / axi_rd drive one slave port each
//   slaves   m_0 ROM, m_1 ISRAM, m_2 DSRAM: tb_axi_mem; the APB port: tb_apb_slave
// The DUT is wired the way TOP wires it: emacs AUTOINST with a template, so every flat port
// reaches the struct field of the same name. The structs are the testbench's own view of the
// ports (tb_s_req ... tb_m_resp), one element per port, zero at the start.
// Tie-offs: the ROM and RAM wrappers have no b_user and r_user, so TOP ties them to 0; the
// models of dv/sbus tie them to 0 too. Outputs no model has an input for are left open.
// Regenerate the instance: emacs --batch dv/sbus/tb_sbus.sv -f verilog-batch-auto
// Tests: tests/sbus_NNN.svh, one self-checking task each; "SBUS_NNN ok: ..." per test.
//==============================================================================
module tb_sbus;

  // ---- clock, reset ---------------------------------------------------------
  logic clk;
  logic rst_n;
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // ---- AXI ports as the testbench sees them ----------------------------------
  qnsc_sbus_pkg::slv_req_t  tb_s_req  [3];   // into S_BUS, from SYSDBG, CPU, DMA
  qnsc_sbus_pkg::slv_resp_t tb_s_resp [3];
  qnsc_sbus_pkg::mst_req_t  tb_m_req  [3];   // out of S_BUS, to ROM, ISRAM, DSRAM
  qnsc_sbus_pkg::mst_resp_t tb_m_resp [3];

  // ---- APB port ---------------------------------------------------------------
  logic [17:0] o_bus_apb_m_0_paddr;
  logic [31:0] o_bus_apb_m_0_pwdata;
  logic [3:0]  o_bus_apb_m_0_pstrb;
  logic        o_bus_apb_m_0_pwrite;
  logic        o_bus_apb_m_0_psel;
  logic        o_bus_apb_m_0_penable;
  logic [31:0] i_bus_apb_m_0_prdata;
  logic        i_bus_apb_m_0_pready;
  logic        i_bus_apb_m_0_pslverr;

  /* m_qnsc_wrap_sbus AUTO_TEMPLATE(
      .i_clk_cpu    (clk),
      .i_rst_n_cpu  (rst_n),
      // S_BUS slave port n: request channels come in, from the master
      .i_bus_axi_s_\([0-9]\)_\(aw\|w\|ar\)_valid  (tb_s_req[\1].\2_valid),
      .i_bus_axi_s_\([0-9]\)_\(b\|r\)_ready       (tb_s_req[\1].\2_ready),
      .i_bus_axi_s_\([0-9]\)_\(aw\|w\|ar\)_\(.*\)  (tb_s_req[\1].\2.\3),
      .o_bus_axi_s_\([0-9]\)_\(aw\|w\|ar\)_ready  (tb_s_resp[\1].\2_ready),
      .o_bus_axi_s_\([0-9]\)_\(b\|r\)_valid       (tb_s_resp[\1].\2_valid),
      .o_bus_axi_s_\([0-9]\)_\(b\|r\)_\(.*\)       (tb_s_resp[\1].\2.\3),
      // S_BUS master port n: request channels go out, to the slave
      .o_bus_axi_m_\([0-9]\)_\(aw\|w\|ar\)_valid  (tb_m_req[\1].\2_valid),
      .o_bus_axi_m_\([0-9]\)_\(b\|r\)_ready       (tb_m_req[\1].\2_ready),
      .o_bus_axi_m_\([0-9]\)_\(aw\|w\|ar\)_\(.*\)  (tb_m_req[\1].\2.\3),
      .i_bus_axi_m_\([0-9]\)_\(aw\|w\|ar\)_ready  (tb_m_resp[\1].\2_ready),
      .i_bus_axi_m_\([0-9]\)_\(b\|r\)_valid       (tb_m_resp[\1].\2_valid),
      .i_bus_axi_m_\([0-9]\)_\(b\|r\)_\(.*\)       (tb_m_resp[\1].\2.\3),
  );
  */
  m_qnsc_wrap_sbus u_dut (/*AUTOINST*/
                          // Outputs
                          .o_bus_apb_m_0_paddr  (o_bus_apb_m_0_paddr[17:0]),
                          .o_bus_apb_m_0_pwdata (o_bus_apb_m_0_pwdata[31:0]),
                          .o_bus_apb_m_0_pstrb  (o_bus_apb_m_0_pstrb[3:0]),
                          .o_bus_apb_m_0_pwrite (o_bus_apb_m_0_pwrite),
                          .o_bus_apb_m_0_psel   (o_bus_apb_m_0_psel),
                          .o_bus_apb_m_0_penable(o_bus_apb_m_0_penable),
                          .o_bus_axi_s_0_aw_ready(tb_s_resp[0].aw_ready), // Templated
                          .o_bus_axi_s_0_w_ready(tb_s_resp[0].w_ready), // Templated
                          .o_bus_axi_s_0_b_id   (tb_s_resp[0].b.id), // Templated
                          .o_bus_axi_s_0_b_resp (tb_s_resp[0].b.resp), // Templated
                          .o_bus_axi_s_0_b_user (tb_s_resp[0].b.user), // Templated
                          .o_bus_axi_s_0_b_valid(tb_s_resp[0].b_valid), // Templated
                          .o_bus_axi_s_0_ar_ready(tb_s_resp[0].ar_ready), // Templated
                          .o_bus_axi_s_0_r_id   (tb_s_resp[0].r.id), // Templated
                          .o_bus_axi_s_0_r_data (tb_s_resp[0].r.data), // Templated
                          .o_bus_axi_s_0_r_resp (tb_s_resp[0].r.resp), // Templated
                          .o_bus_axi_s_0_r_last (tb_s_resp[0].r.last), // Templated
                          .o_bus_axi_s_0_r_user (tb_s_resp[0].r.user), // Templated
                          .o_bus_axi_s_0_r_valid(tb_s_resp[0].r_valid), // Templated
                          .o_bus_axi_s_1_aw_ready(tb_s_resp[1].aw_ready), // Templated
                          .o_bus_axi_s_1_w_ready(tb_s_resp[1].w_ready), // Templated
                          .o_bus_axi_s_1_b_id   (tb_s_resp[1].b.id), // Templated
                          .o_bus_axi_s_1_b_resp (tb_s_resp[1].b.resp), // Templated
                          .o_bus_axi_s_1_b_user (tb_s_resp[1].b.user), // Templated
                          .o_bus_axi_s_1_b_valid(tb_s_resp[1].b_valid), // Templated
                          .o_bus_axi_s_1_ar_ready(tb_s_resp[1].ar_ready), // Templated
                          .o_bus_axi_s_1_r_id   (tb_s_resp[1].r.id), // Templated
                          .o_bus_axi_s_1_r_data (tb_s_resp[1].r.data), // Templated
                          .o_bus_axi_s_1_r_resp (tb_s_resp[1].r.resp), // Templated
                          .o_bus_axi_s_1_r_last (tb_s_resp[1].r.last), // Templated
                          .o_bus_axi_s_1_r_user (tb_s_resp[1].r.user), // Templated
                          .o_bus_axi_s_1_r_valid(tb_s_resp[1].r_valid), // Templated
                          .o_bus_axi_s_2_aw_ready(tb_s_resp[2].aw_ready), // Templated
                          .o_bus_axi_s_2_w_ready(tb_s_resp[2].w_ready), // Templated
                          .o_bus_axi_s_2_b_id   (tb_s_resp[2].b.id), // Templated
                          .o_bus_axi_s_2_b_resp (tb_s_resp[2].b.resp), // Templated
                          .o_bus_axi_s_2_b_user (tb_s_resp[2].b.user), // Templated
                          .o_bus_axi_s_2_b_valid(tb_s_resp[2].b_valid), // Templated
                          .o_bus_axi_s_2_ar_ready(tb_s_resp[2].ar_ready), // Templated
                          .o_bus_axi_s_2_r_id   (tb_s_resp[2].r.id), // Templated
                          .o_bus_axi_s_2_r_data (tb_s_resp[2].r.data), // Templated
                          .o_bus_axi_s_2_r_resp (tb_s_resp[2].r.resp), // Templated
                          .o_bus_axi_s_2_r_last (tb_s_resp[2].r.last), // Templated
                          .o_bus_axi_s_2_r_user (tb_s_resp[2].r.user), // Templated
                          .o_bus_axi_s_2_r_valid(tb_s_resp[2].r_valid), // Templated
                          .o_bus_axi_m_0_aw_id  (tb_m_req[0].aw.id), // Templated
                          .o_bus_axi_m_0_aw_addr(tb_m_req[0].aw.addr), // Templated
                          .o_bus_axi_m_0_aw_len (tb_m_req[0].aw.len), // Templated
                          .o_bus_axi_m_0_aw_size(tb_m_req[0].aw.size), // Templated
                          .o_bus_axi_m_0_aw_burst(tb_m_req[0].aw.burst), // Templated
                          .o_bus_axi_m_0_aw_lock(tb_m_req[0].aw.lock), // Templated
                          .o_bus_axi_m_0_aw_cache(tb_m_req[0].aw.cache), // Templated
                          .o_bus_axi_m_0_aw_prot(tb_m_req[0].aw.prot), // Templated
                          .o_bus_axi_m_0_aw_qos (tb_m_req[0].aw.qos), // Templated
                          .o_bus_axi_m_0_aw_region(tb_m_req[0].aw.region), // Templated
                          .o_bus_axi_m_0_aw_atop(tb_m_req[0].aw.atop), // Templated
                          .o_bus_axi_m_0_aw_user(tb_m_req[0].aw.user), // Templated
                          .o_bus_axi_m_0_aw_valid(tb_m_req[0].aw_valid), // Templated
                          .o_bus_axi_m_0_w_data (tb_m_req[0].w.data), // Templated
                          .o_bus_axi_m_0_w_strb (tb_m_req[0].w.strb), // Templated
                          .o_bus_axi_m_0_w_last (tb_m_req[0].w.last), // Templated
                          .o_bus_axi_m_0_w_user (tb_m_req[0].w.user), // Templated
                          .o_bus_axi_m_0_w_valid(tb_m_req[0].w_valid), // Templated
                          .o_bus_axi_m_0_b_ready(tb_m_req[0].b_ready), // Templated
                          .o_bus_axi_m_0_ar_id  (tb_m_req[0].ar.id), // Templated
                          .o_bus_axi_m_0_ar_addr(tb_m_req[0].ar.addr), // Templated
                          .o_bus_axi_m_0_ar_len (tb_m_req[0].ar.len), // Templated
                          .o_bus_axi_m_0_ar_size(tb_m_req[0].ar.size), // Templated
                          .o_bus_axi_m_0_ar_burst(tb_m_req[0].ar.burst), // Templated
                          .o_bus_axi_m_0_ar_lock(tb_m_req[0].ar.lock), // Templated
                          .o_bus_axi_m_0_ar_cache(tb_m_req[0].ar.cache), // Templated
                          .o_bus_axi_m_0_ar_prot(tb_m_req[0].ar.prot), // Templated
                          .o_bus_axi_m_0_ar_qos (tb_m_req[0].ar.qos), // Templated
                          .o_bus_axi_m_0_ar_region(tb_m_req[0].ar.region), // Templated
                          .o_bus_axi_m_0_ar_user(tb_m_req[0].ar.user), // Templated
                          .o_bus_axi_m_0_ar_valid(tb_m_req[0].ar_valid), // Templated
                          .o_bus_axi_m_0_r_ready(tb_m_req[0].r_ready), // Templated
                          .o_bus_axi_m_1_aw_id  (tb_m_req[1].aw.id), // Templated
                          .o_bus_axi_m_1_aw_addr(tb_m_req[1].aw.addr), // Templated
                          .o_bus_axi_m_1_aw_len (tb_m_req[1].aw.len), // Templated
                          .o_bus_axi_m_1_aw_size(tb_m_req[1].aw.size), // Templated
                          .o_bus_axi_m_1_aw_burst(tb_m_req[1].aw.burst), // Templated
                          .o_bus_axi_m_1_aw_lock(tb_m_req[1].aw.lock), // Templated
                          .o_bus_axi_m_1_aw_cache(tb_m_req[1].aw.cache), // Templated
                          .o_bus_axi_m_1_aw_prot(tb_m_req[1].aw.prot), // Templated
                          .o_bus_axi_m_1_aw_qos (tb_m_req[1].aw.qos), // Templated
                          .o_bus_axi_m_1_aw_region(tb_m_req[1].aw.region), // Templated
                          .o_bus_axi_m_1_aw_atop(tb_m_req[1].aw.atop), // Templated
                          .o_bus_axi_m_1_aw_user(tb_m_req[1].aw.user), // Templated
                          .o_bus_axi_m_1_aw_valid(tb_m_req[1].aw_valid), // Templated
                          .o_bus_axi_m_1_w_data (tb_m_req[1].w.data), // Templated
                          .o_bus_axi_m_1_w_strb (tb_m_req[1].w.strb), // Templated
                          .o_bus_axi_m_1_w_last (tb_m_req[1].w.last), // Templated
                          .o_bus_axi_m_1_w_user (tb_m_req[1].w.user), // Templated
                          .o_bus_axi_m_1_w_valid(tb_m_req[1].w_valid), // Templated
                          .o_bus_axi_m_1_b_ready(tb_m_req[1].b_ready), // Templated
                          .o_bus_axi_m_1_ar_id  (tb_m_req[1].ar.id), // Templated
                          .o_bus_axi_m_1_ar_addr(tb_m_req[1].ar.addr), // Templated
                          .o_bus_axi_m_1_ar_len (tb_m_req[1].ar.len), // Templated
                          .o_bus_axi_m_1_ar_size(tb_m_req[1].ar.size), // Templated
                          .o_bus_axi_m_1_ar_burst(tb_m_req[1].ar.burst), // Templated
                          .o_bus_axi_m_1_ar_lock(tb_m_req[1].ar.lock), // Templated
                          .o_bus_axi_m_1_ar_cache(tb_m_req[1].ar.cache), // Templated
                          .o_bus_axi_m_1_ar_prot(tb_m_req[1].ar.prot), // Templated
                          .o_bus_axi_m_1_ar_qos (tb_m_req[1].ar.qos), // Templated
                          .o_bus_axi_m_1_ar_region(tb_m_req[1].ar.region), // Templated
                          .o_bus_axi_m_1_ar_user(tb_m_req[1].ar.user), // Templated
                          .o_bus_axi_m_1_ar_valid(tb_m_req[1].ar_valid), // Templated
                          .o_bus_axi_m_1_r_ready(tb_m_req[1].r_ready), // Templated
                          .o_bus_axi_m_2_aw_id  (tb_m_req[2].aw.id), // Templated
                          .o_bus_axi_m_2_aw_addr(tb_m_req[2].aw.addr), // Templated
                          .o_bus_axi_m_2_aw_len (tb_m_req[2].aw.len), // Templated
                          .o_bus_axi_m_2_aw_size(tb_m_req[2].aw.size), // Templated
                          .o_bus_axi_m_2_aw_burst(tb_m_req[2].aw.burst), // Templated
                          .o_bus_axi_m_2_aw_lock(tb_m_req[2].aw.lock), // Templated
                          .o_bus_axi_m_2_aw_cache(tb_m_req[2].aw.cache), // Templated
                          .o_bus_axi_m_2_aw_prot(tb_m_req[2].aw.prot), // Templated
                          .o_bus_axi_m_2_aw_qos (tb_m_req[2].aw.qos), // Templated
                          .o_bus_axi_m_2_aw_region(tb_m_req[2].aw.region), // Templated
                          .o_bus_axi_m_2_aw_atop(tb_m_req[2].aw.atop), // Templated
                          .o_bus_axi_m_2_aw_user(tb_m_req[2].aw.user), // Templated
                          .o_bus_axi_m_2_aw_valid(tb_m_req[2].aw_valid), // Templated
                          .o_bus_axi_m_2_w_data (tb_m_req[2].w.data), // Templated
                          .o_bus_axi_m_2_w_strb (tb_m_req[2].w.strb), // Templated
                          .o_bus_axi_m_2_w_last (tb_m_req[2].w.last), // Templated
                          .o_bus_axi_m_2_w_user (tb_m_req[2].w.user), // Templated
                          .o_bus_axi_m_2_w_valid(tb_m_req[2].w_valid), // Templated
                          .o_bus_axi_m_2_b_ready(tb_m_req[2].b_ready), // Templated
                          .o_bus_axi_m_2_ar_id  (tb_m_req[2].ar.id), // Templated
                          .o_bus_axi_m_2_ar_addr(tb_m_req[2].ar.addr), // Templated
                          .o_bus_axi_m_2_ar_len (tb_m_req[2].ar.len), // Templated
                          .o_bus_axi_m_2_ar_size(tb_m_req[2].ar.size), // Templated
                          .o_bus_axi_m_2_ar_burst(tb_m_req[2].ar.burst), // Templated
                          .o_bus_axi_m_2_ar_lock(tb_m_req[2].ar.lock), // Templated
                          .o_bus_axi_m_2_ar_cache(tb_m_req[2].ar.cache), // Templated
                          .o_bus_axi_m_2_ar_prot(tb_m_req[2].ar.prot), // Templated
                          .o_bus_axi_m_2_ar_qos (tb_m_req[2].ar.qos), // Templated
                          .o_bus_axi_m_2_ar_region(tb_m_req[2].ar.region), // Templated
                          .o_bus_axi_m_2_ar_user(tb_m_req[2].ar.user), // Templated
                          .o_bus_axi_m_2_ar_valid(tb_m_req[2].ar_valid), // Templated
                          .o_bus_axi_m_2_r_ready(tb_m_req[2].r_ready), // Templated
                          // Inputs
                          .i_clk_cpu            (clk),           // Templated
                          .i_rst_n_cpu          (rst_n),         // Templated
                          .i_bus_apb_m_0_prdata (i_bus_apb_m_0_prdata[31:0]),
                          .i_bus_apb_m_0_pready (i_bus_apb_m_0_pready),
                          .i_bus_apb_m_0_pslverr(i_bus_apb_m_0_pslverr),
                          .i_bus_axi_s_0_aw_id  (tb_s_req[0].aw.id), // Templated
                          .i_bus_axi_s_0_aw_addr(tb_s_req[0].aw.addr), // Templated
                          .i_bus_axi_s_0_aw_len (tb_s_req[0].aw.len), // Templated
                          .i_bus_axi_s_0_aw_size(tb_s_req[0].aw.size), // Templated
                          .i_bus_axi_s_0_aw_burst(tb_s_req[0].aw.burst), // Templated
                          .i_bus_axi_s_0_aw_lock(tb_s_req[0].aw.lock), // Templated
                          .i_bus_axi_s_0_aw_cache(tb_s_req[0].aw.cache), // Templated
                          .i_bus_axi_s_0_aw_prot(tb_s_req[0].aw.prot), // Templated
                          .i_bus_axi_s_0_aw_qos (tb_s_req[0].aw.qos), // Templated
                          .i_bus_axi_s_0_aw_region(tb_s_req[0].aw.region), // Templated
                          .i_bus_axi_s_0_aw_atop(tb_s_req[0].aw.atop), // Templated
                          .i_bus_axi_s_0_aw_user(tb_s_req[0].aw.user), // Templated
                          .i_bus_axi_s_0_aw_valid(tb_s_req[0].aw_valid), // Templated
                          .i_bus_axi_s_0_w_data (tb_s_req[0].w.data), // Templated
                          .i_bus_axi_s_0_w_strb (tb_s_req[0].w.strb), // Templated
                          .i_bus_axi_s_0_w_last (tb_s_req[0].w.last), // Templated
                          .i_bus_axi_s_0_w_user (tb_s_req[0].w.user), // Templated
                          .i_bus_axi_s_0_w_valid(tb_s_req[0].w_valid), // Templated
                          .i_bus_axi_s_0_b_ready(tb_s_req[0].b_ready), // Templated
                          .i_bus_axi_s_0_ar_id  (tb_s_req[0].ar.id), // Templated
                          .i_bus_axi_s_0_ar_addr(tb_s_req[0].ar.addr), // Templated
                          .i_bus_axi_s_0_ar_len (tb_s_req[0].ar.len), // Templated
                          .i_bus_axi_s_0_ar_size(tb_s_req[0].ar.size), // Templated
                          .i_bus_axi_s_0_ar_burst(tb_s_req[0].ar.burst), // Templated
                          .i_bus_axi_s_0_ar_lock(tb_s_req[0].ar.lock), // Templated
                          .i_bus_axi_s_0_ar_cache(tb_s_req[0].ar.cache), // Templated
                          .i_bus_axi_s_0_ar_prot(tb_s_req[0].ar.prot), // Templated
                          .i_bus_axi_s_0_ar_qos (tb_s_req[0].ar.qos), // Templated
                          .i_bus_axi_s_0_ar_region(tb_s_req[0].ar.region), // Templated
                          .i_bus_axi_s_0_ar_user(tb_s_req[0].ar.user), // Templated
                          .i_bus_axi_s_0_ar_valid(tb_s_req[0].ar_valid), // Templated
                          .i_bus_axi_s_0_r_ready(tb_s_req[0].r_ready), // Templated
                          .i_bus_axi_s_1_aw_id  (tb_s_req[1].aw.id), // Templated
                          .i_bus_axi_s_1_aw_addr(tb_s_req[1].aw.addr), // Templated
                          .i_bus_axi_s_1_aw_len (tb_s_req[1].aw.len), // Templated
                          .i_bus_axi_s_1_aw_size(tb_s_req[1].aw.size), // Templated
                          .i_bus_axi_s_1_aw_burst(tb_s_req[1].aw.burst), // Templated
                          .i_bus_axi_s_1_aw_lock(tb_s_req[1].aw.lock), // Templated
                          .i_bus_axi_s_1_aw_cache(tb_s_req[1].aw.cache), // Templated
                          .i_bus_axi_s_1_aw_prot(tb_s_req[1].aw.prot), // Templated
                          .i_bus_axi_s_1_aw_qos (tb_s_req[1].aw.qos), // Templated
                          .i_bus_axi_s_1_aw_region(tb_s_req[1].aw.region), // Templated
                          .i_bus_axi_s_1_aw_atop(tb_s_req[1].aw.atop), // Templated
                          .i_bus_axi_s_1_aw_user(tb_s_req[1].aw.user), // Templated
                          .i_bus_axi_s_1_aw_valid(tb_s_req[1].aw_valid), // Templated
                          .i_bus_axi_s_1_w_data (tb_s_req[1].w.data), // Templated
                          .i_bus_axi_s_1_w_strb (tb_s_req[1].w.strb), // Templated
                          .i_bus_axi_s_1_w_last (tb_s_req[1].w.last), // Templated
                          .i_bus_axi_s_1_w_user (tb_s_req[1].w.user), // Templated
                          .i_bus_axi_s_1_w_valid(tb_s_req[1].w_valid), // Templated
                          .i_bus_axi_s_1_b_ready(tb_s_req[1].b_ready), // Templated
                          .i_bus_axi_s_1_ar_id  (tb_s_req[1].ar.id), // Templated
                          .i_bus_axi_s_1_ar_addr(tb_s_req[1].ar.addr), // Templated
                          .i_bus_axi_s_1_ar_len (tb_s_req[1].ar.len), // Templated
                          .i_bus_axi_s_1_ar_size(tb_s_req[1].ar.size), // Templated
                          .i_bus_axi_s_1_ar_burst(tb_s_req[1].ar.burst), // Templated
                          .i_bus_axi_s_1_ar_lock(tb_s_req[1].ar.lock), // Templated
                          .i_bus_axi_s_1_ar_cache(tb_s_req[1].ar.cache), // Templated
                          .i_bus_axi_s_1_ar_prot(tb_s_req[1].ar.prot), // Templated
                          .i_bus_axi_s_1_ar_qos (tb_s_req[1].ar.qos), // Templated
                          .i_bus_axi_s_1_ar_region(tb_s_req[1].ar.region), // Templated
                          .i_bus_axi_s_1_ar_user(tb_s_req[1].ar.user), // Templated
                          .i_bus_axi_s_1_ar_valid(tb_s_req[1].ar_valid), // Templated
                          .i_bus_axi_s_1_r_ready(tb_s_req[1].r_ready), // Templated
                          .i_bus_axi_s_2_aw_id  (tb_s_req[2].aw.id), // Templated
                          .i_bus_axi_s_2_aw_addr(tb_s_req[2].aw.addr), // Templated
                          .i_bus_axi_s_2_aw_len (tb_s_req[2].aw.len), // Templated
                          .i_bus_axi_s_2_aw_size(tb_s_req[2].aw.size), // Templated
                          .i_bus_axi_s_2_aw_burst(tb_s_req[2].aw.burst), // Templated
                          .i_bus_axi_s_2_aw_lock(tb_s_req[2].aw.lock), // Templated
                          .i_bus_axi_s_2_aw_cache(tb_s_req[2].aw.cache), // Templated
                          .i_bus_axi_s_2_aw_prot(tb_s_req[2].aw.prot), // Templated
                          .i_bus_axi_s_2_aw_qos (tb_s_req[2].aw.qos), // Templated
                          .i_bus_axi_s_2_aw_region(tb_s_req[2].aw.region), // Templated
                          .i_bus_axi_s_2_aw_atop(tb_s_req[2].aw.atop), // Templated
                          .i_bus_axi_s_2_aw_user(tb_s_req[2].aw.user), // Templated
                          .i_bus_axi_s_2_aw_valid(tb_s_req[2].aw_valid), // Templated
                          .i_bus_axi_s_2_w_data (tb_s_req[2].w.data), // Templated
                          .i_bus_axi_s_2_w_strb (tb_s_req[2].w.strb), // Templated
                          .i_bus_axi_s_2_w_last (tb_s_req[2].w.last), // Templated
                          .i_bus_axi_s_2_w_user (tb_s_req[2].w.user), // Templated
                          .i_bus_axi_s_2_w_valid(tb_s_req[2].w_valid), // Templated
                          .i_bus_axi_s_2_b_ready(tb_s_req[2].b_ready), // Templated
                          .i_bus_axi_s_2_ar_id  (tb_s_req[2].ar.id), // Templated
                          .i_bus_axi_s_2_ar_addr(tb_s_req[2].ar.addr), // Templated
                          .i_bus_axi_s_2_ar_len (tb_s_req[2].ar.len), // Templated
                          .i_bus_axi_s_2_ar_size(tb_s_req[2].ar.size), // Templated
                          .i_bus_axi_s_2_ar_burst(tb_s_req[2].ar.burst), // Templated
                          .i_bus_axi_s_2_ar_lock(tb_s_req[2].ar.lock), // Templated
                          .i_bus_axi_s_2_ar_cache(tb_s_req[2].ar.cache), // Templated
                          .i_bus_axi_s_2_ar_prot(tb_s_req[2].ar.prot), // Templated
                          .i_bus_axi_s_2_ar_qos (tb_s_req[2].ar.qos), // Templated
                          .i_bus_axi_s_2_ar_region(tb_s_req[2].ar.region), // Templated
                          .i_bus_axi_s_2_ar_user(tb_s_req[2].ar.user), // Templated
                          .i_bus_axi_s_2_ar_valid(tb_s_req[2].ar_valid), // Templated
                          .i_bus_axi_s_2_r_ready(tb_s_req[2].r_ready), // Templated
                          .i_bus_axi_m_0_aw_ready(tb_m_resp[0].aw_ready), // Templated
                          .i_bus_axi_m_0_w_ready(tb_m_resp[0].w_ready), // Templated
                          .i_bus_axi_m_0_b_id   (tb_m_resp[0].b.id), // Templated
                          .i_bus_axi_m_0_b_resp (tb_m_resp[0].b.resp), // Templated
                          .i_bus_axi_m_0_b_user (tb_m_resp[0].b.user), // Templated
                          .i_bus_axi_m_0_b_valid(tb_m_resp[0].b_valid), // Templated
                          .i_bus_axi_m_0_ar_ready(tb_m_resp[0].ar_ready), // Templated
                          .i_bus_axi_m_0_r_id   (tb_m_resp[0].r.id), // Templated
                          .i_bus_axi_m_0_r_data (tb_m_resp[0].r.data), // Templated
                          .i_bus_axi_m_0_r_resp (tb_m_resp[0].r.resp), // Templated
                          .i_bus_axi_m_0_r_last (tb_m_resp[0].r.last), // Templated
                          .i_bus_axi_m_0_r_user (tb_m_resp[0].r.user), // Templated
                          .i_bus_axi_m_0_r_valid(tb_m_resp[0].r_valid), // Templated
                          .i_bus_axi_m_1_aw_ready(tb_m_resp[1].aw_ready), // Templated
                          .i_bus_axi_m_1_w_ready(tb_m_resp[1].w_ready), // Templated
                          .i_bus_axi_m_1_b_id   (tb_m_resp[1].b.id), // Templated
                          .i_bus_axi_m_1_b_resp (tb_m_resp[1].b.resp), // Templated
                          .i_bus_axi_m_1_b_user (tb_m_resp[1].b.user), // Templated
                          .i_bus_axi_m_1_b_valid(tb_m_resp[1].b_valid), // Templated
                          .i_bus_axi_m_1_ar_ready(tb_m_resp[1].ar_ready), // Templated
                          .i_bus_axi_m_1_r_id   (tb_m_resp[1].r.id), // Templated
                          .i_bus_axi_m_1_r_data (tb_m_resp[1].r.data), // Templated
                          .i_bus_axi_m_1_r_resp (tb_m_resp[1].r.resp), // Templated
                          .i_bus_axi_m_1_r_last (tb_m_resp[1].r.last), // Templated
                          .i_bus_axi_m_1_r_user (tb_m_resp[1].r.user), // Templated
                          .i_bus_axi_m_1_r_valid(tb_m_resp[1].r_valid), // Templated
                          .i_bus_axi_m_2_aw_ready(tb_m_resp[2].aw_ready), // Templated
                          .i_bus_axi_m_2_w_ready(tb_m_resp[2].w_ready), // Templated
                          .i_bus_axi_m_2_b_id   (tb_m_resp[2].b.id), // Templated
                          .i_bus_axi_m_2_b_resp (tb_m_resp[2].b.resp), // Templated
                          .i_bus_axi_m_2_b_user (tb_m_resp[2].b.user), // Templated
                          .i_bus_axi_m_2_b_valid(tb_m_resp[2].b_valid), // Templated
                          .i_bus_axi_m_2_ar_ready(tb_m_resp[2].ar_ready), // Templated
                          .i_bus_axi_m_2_r_id   (tb_m_resp[2].r.id), // Templated
                          .i_bus_axi_m_2_r_data (tb_m_resp[2].r.data), // Templated
                          .i_bus_axi_m_2_r_resp (tb_m_resp[2].r.resp), // Templated
                          .i_bus_axi_m_2_r_last (tb_m_resp[2].r.last), // Templated
                          .i_bus_axi_m_2_r_user (tb_m_resp[2].r.user), // Templated
                          .i_bus_axi_m_2_r_valid(tb_m_resp[2].r_valid)); // Templated

  // ---- the slaves ---------------------------------------------------------------
  localparam logic [31:0] C_PAT_ROM   = 32'hA000_0000;
  localparam logic [31:0] C_PAT_ISRAM = 32'hB000_0000;
  localparam logic [31:0] C_PAT_DSRAM = 32'hC000_0000;
  localparam logic [31:0] C_PAT_APB   = 32'hD000_0000;   // tb_apb_slave's own pattern

  tb_axi_mem #(.P_DELAY(0), .P_PATTERN(C_PAT_ROM))   u_rom   (.clk(clk), .rst_n(rst_n), .req(tb_m_req[0]), .resp(tb_m_resp[0]));
  tb_axi_mem #(.P_DELAY(3), .P_PATTERN(C_PAT_ISRAM)) u_isram (.clk(clk), .rst_n(rst_n), .req(tb_m_req[1]), .resp(tb_m_resp[1]));
  tb_axi_mem #(.P_DELAY(1), .P_PATTERN(C_PAT_DSRAM)) u_dsram (.clk(clk), .rst_n(rst_n), .req(tb_m_req[2]), .resp(tb_m_resp[2]));

  localparam logic [17:0] C_APB_ERR_OFFSET = 18'h00100;
  tb_apb_slave #(.P_WAIT(2), .P_ERR_OFFSET(C_APB_ERR_OFFSET)) u_apb (
    .clk(clk), .rst_n(rst_n),
    .paddr(o_bus_apb_m_0_paddr), .psel(o_bus_apb_m_0_psel), .penable(o_bus_apb_m_0_penable),
    .pwrite(o_bus_apb_m_0_pwrite), .pwdata(o_bus_apb_m_0_pwdata), .pstrb(o_bus_apb_m_0_pstrb),
    .prdata(i_bus_apb_m_0_prdata), .pready(i_bus_apb_m_0_pready), .pslverr(i_bus_apb_m_0_pslverr));

  // ---- shorthand for the address map: the contract's, not retyped ------------------
  localparam logic [31:0] C_ROM_END   = qnsc_pkg::C_ROM_BASE   + qnsc_pkg::C_ROM_SIZE;
  localparam logic [31:0] C_ISRAM_END = qnsc_pkg::C_ISRAM_BASE + qnsc_pkg::C_ISRAM_SIZE;
  localparam logic [31:0] C_DSRAM_END = qnsc_pkg::C_DSRAM_BASE + qnsc_pkg::C_DSRAM_SIZE;
  localparam logic [31:0] C_APB_END   = qnsc_pkg::C_AXI2APB_BASE + qnsc_pkg::C_AXI2APB_SIZE;
  localparam logic [1:0]  C_OKAY   = axi_pkg::RESP_OKAY;
  localparam logic [1:0]  C_SLVERR = axi_pkg::RESP_SLVERR;
  localparam logic [1:0]  C_DECERR = axi_pkg::RESP_DECERR;

  // ---- results of the last transaction on each slave port -----------------------------
  logic [31:0] rd_data [3][16];
  logic [1:0]  rd_resp [3][16];
  logic [0:0]  rd_id   [3];
  int          rd_beats [3];
  logic        rd_last_ok [3];
  logic [1:0]  wr_resp [3];
  logic [0:0]  wr_id   [3];

  int unsigned n_checks;
  logic [3:0]  tb_cache = 4'b0000;   // AxCACHE the masters drive; 0 = Device, like the CPU's data port and the DMA

  task automatic fail(input string msg);
    $fatal(1, "FAIL: %s", msg);
  endtask

  task automatic chk(input bit cond, input string msg);
    n_checks++;
    if (!cond) fail(msg);
  endtask

  // ---- a master on slave port p: write ---------------------------------------------------
  // len+1 beats of data seed + 32'h1111 * beat, with strobes strb. AW and W are sent together,
  // B is taken when it comes (b_ready stays high).
  task automatic axi_wr(input int p, input logic [0:0] id, input logic [31:0] addr, input int len,
                        input logic [31:0] seed, input logic [3:0] strb);
    int guard;
    fork
      begin : aw_channel
        int g;
        @(posedge clk);
        tb_s_req[p].aw.id    <= id;
        tb_s_req[p].aw.addr  <= addr;
        tb_s_req[p].aw.len   <= 8'(len);
        tb_s_req[p].aw.size  <= 3'd2;
        tb_s_req[p].aw.burst <= axi_pkg::BURST_INCR;
        tb_s_req[p].aw.cache <= tb_cache;
        tb_s_req[p].aw_valid <= 1'b1;
        g = 0;
        do begin @(posedge clk); g++; end while (!tb_s_resp[p].aw_ready && g < 2000);
        chk(g < 2000, "timeout waiting for AWREADY");
        tb_s_req[p].aw_valid <= 1'b0;
      end
      begin : w_channel
        int g;
        @(posedge clk);
        for (int i = 0; i <= len; i++) begin
          tb_s_req[p].w.data  <= seed + 32'h1111 * 32'(i);
          tb_s_req[p].w.strb  <= strb;
          tb_s_req[p].w.last  <= (i == len);
          tb_s_req[p].w_valid <= 1'b1;
          g = 0;
          do begin @(posedge clk); g++; end while (!tb_s_resp[p].w_ready && g < 2000);
          chk(g < 2000, "timeout waiting for WREADY");
        end
        tb_s_req[p].w_valid <= 1'b0;
        tb_s_req[p].w.last  <= 1'b0;
      end
    join
    guard = 0;
    do begin @(posedge clk); guard++; end while (!tb_s_resp[p].b_valid && guard < 2000);
    chk(guard < 2000, "timeout waiting for BVALID");
    wr_resp[p] = tb_s_resp[p].b.resp;
    wr_id[p]   = tb_s_resp[p].b.id;
    @(posedge clk);   // let the slaves' counters settle (they update on the same edge)
  endtask

  // ---- a master on slave port p: read ------------------------------------------------------
  // The beats land in rd_data[p][0..len]; rd_last_ok[p] says RLAST came on the last beat only.
  task automatic axi_rd(input int p, input logic [0:0] id, input logic [31:0] addr, input int len);
    int g;
    @(posedge clk);
    tb_s_req[p].ar.id    <= id;
    tb_s_req[p].ar.addr  <= addr;
    tb_s_req[p].ar.len   <= 8'(len);
    tb_s_req[p].ar.size  <= 3'd2;
    tb_s_req[p].ar.burst <= axi_pkg::BURST_INCR;
    tb_s_req[p].ar.cache <= tb_cache;
    tb_s_req[p].ar_valid <= 1'b1;
    g = 0;
    do begin @(posedge clk); g++; end while (!tb_s_resp[p].ar_ready && g < 2000);
    chk(g < 2000, "timeout waiting for ARREADY");
    tb_s_req[p].ar_valid <= 1'b0;
    rd_beats[p]   = 0;
    rd_last_ok[p] = 1'b1;
    for (int i = 0; i <= len; i++) begin
      g = 0;
      do begin @(posedge clk); g++; end while (!tb_s_resp[p].r_valid && g < 2000);
      chk(g < 2000, "timeout waiting for RVALID");
      rd_data[p][i] = tb_s_resp[p].r.data;
      rd_resp[p][i] = tb_s_resp[p].r.resp;
      rd_id[p]      = tb_s_resp[p].r.id;
      if (tb_s_resp[p].r.last != (i == len)) rd_last_ok[p] = 1'b0;
      rd_beats[p]++;
    end
    @(posedge clk);   // let the slaves' counters settle (they update on the same edge)
  endtask

  // ---- what a slave returns for an address ----------------------------------------------------
  function automatic logic [31:0] pat_mem(input int m, input logic [31:0] addr);
    logic [31:0] base;
    case (m)
      0:       base = C_PAT_ROM;
      1:       base = C_PAT_ISRAM;
      default: base = C_PAT_DSRAM;
    endcase
    return base | 32'(addr[15:2]);
  endfunction

  function automatic logic [31:0] pat_apb(input logic [31:0] addr);
    logic [31:0] off;
    off = addr - qnsc_pkg::C_AXI2APB_BASE;
    return C_PAT_APB | 32'(off[9:2]);
  endfunction

  // transactions slave m has seen (0 ROM, 1 ISRAM, 2 DSRAM: AW + AR; 3 the APB slave: accesses)
  function automatic int unsigned seen(input int m);
    case (m)
      0:       return u_rom.n_aw   + u_rom.n_ar;
      1:       return u_isram.n_aw + u_isram.n_ar;
      2:       return u_dsram.n_aw + u_dsram.n_ar;
      default: return u_apb.n_access;
    endcase
  endfunction

  // all of them together, for "no slave saw it"
  function automatic int unsigned seen_total();
    return u_rom.n_aw + u_rom.n_ar + u_isram.n_aw + u_isram.n_ar + u_dsram.n_aw + u_dsram.n_ar
           + u_apb.n_access;
  endfunction

  // ---- the tests ---------------------------------------------------------------------------------
  `include "sbus_001.svh"
  `include "sbus_002.svh"
  `include "sbus_003.svh"
  `include "sbus_004.svh"
  `include "sbus_005.svh"
  `include "sbus_006.svh"
  `include "sbus_007.svh"

  initial begin : waves
    string f;
    if ($value$plusargs("waves=%s", f)) begin
      $dumpfile(f);
      $dumpvars(0, tb_sbus);
    end
  end

  initial begin : watchdog
    #5_000_000;
    fail("watchdog: the simulation did not finish");
  end

  initial begin : main
    for (int p = 0; p < 3; p++) begin
      tb_s_req[p] = '0;
      tb_s_req[p].b_ready = 1'b1;   // B and R are always taken
      tb_s_req[p].r_ready = 1'b1;
    end
    n_checks = 0;
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n <= 1'b1;
    repeat (3) @(posedge clk);

    sbus_001();
    sbus_002();
    sbus_003();
    sbus_004();
    sbus_005();
    sbus_006();
    sbus_007();

    chk(!u_rom.w_err && !u_isram.w_err && !u_dsram.w_err, "a write burst reached a slave with WLAST misplaced");
    chk(!u_apb.proto_err, "APB protocol error seen by the APB slave");
    $display("PASS: tb_sbus, %0d checks", n_checks);
    $finish;
  end

endmodule : tb_sbus
`default_nettype wire
// Local Variables:
// verilog-library-flags:("-v ../../design/sbus/rtl/m_qnsc_wrap_sbus.sv")
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: t
// indent-tabs-mode: nil
// End:
