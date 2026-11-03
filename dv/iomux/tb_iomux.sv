`timescale 1ns/1ps

// tb_iomux -- testbench of m_qnsc_iomux (QNSC_IOMUX_MAS, verification).
//
// Every DUT port is a testbench signal of the same name, so the generated
// checks (util/gen/iomux/iomux_expect.svh, from the same pin table as the RTL)
// read them directly. The testbench keeps a shadow of PADSEL (r_sel_sw) and of
// the select each pad must use after the debug force (r_sel_eff). Each test is
// a file in tests/; all run in one simulation, in order.
module tb_iomux;
  localparam logic [13:0] A_PADSEL_0 = 14'h0000;
  localparam logic [13:0] A_PADSEL_1 = 14'h0004;

  // ---- DUT ports --------------------------------------------------------------
  logic        i_clk_peri = 1'b0;
  logic        i_rst_n_peri = 1'b0;
  logic        i_bus_apb_psel = 1'b0, i_bus_apb_penable = 1'b0, i_bus_apb_pwrite = 1'b0;
  logic [13:0] i_bus_apb_paddr = '0;
  logic [31:0] i_bus_apb_pwdata = '0;
  logic [3:0]  i_bus_apb_pstrb = 4'hF;
  logic [2:0]  i_bus_apb_pprot = 3'b000;
  logic [31:0] o_bus_apb_prdata;
  logic        o_bus_apb_pready, o_bus_apb_pslverr;
  logic        i_dbg_en = 1'b0;
  logic [7:0]  i_gpio_0_out, i_gpio_0_oe, o_gpio_0_in;
  logic [7:0]  i_gpio_1_out, i_gpio_1_oe, o_gpio_1_in;
  logic [7:0]  i_gpio_2_out, i_gpio_2_oe, o_gpio_2_in;
  logic        i_uart_0_tx, o_uart_0_rx, i_uart_1_tx, o_uart_1_rx;
  logic        i_spi_sck, i_spi_sck_oe, o_spi_sck;
  logic        i_spi_csb, i_spi_csb_oe, o_spi_csb;
  logic [3:0]  i_spi_sd, i_spi_sd_oe, o_spi_sd;
  logic        i_i2c_scl, i_i2c_scl_oe_n, o_i2c_scl;
  logic        i_i2c_sda, i_i2c_sda_oe_n, o_i2c_sda;
  logic [7:0]  i_pwm;
  logic [3:0]  o_tim_ext;
  logic        o_jtag_tck, o_jtag_tms, o_jtag_tdi, i_jtag_tdo, i_jtag_tdo_oe, o_jtag_trst_n;
  logic [27:0] o_pad_out, o_pad_oe, i_pad_in;

  always #25 i_clk_peri = ~i_clk_peri;                     // 20 MHz

  m_qnsc_iomux u_dut (.*);

  // ---- shadow of PADSEL ----------------------------------------------------------
  logic [1:0] r_sel_sw  [28];
  logic [1:0] r_sel_eff [28];

  task automatic t_chk(input bit ok, input string msg);
    if (!ok) $fatal(1, "%s", msg);
  endtask

  `include "iomux_expect.svh"

  function automatic void f_update_eff();
    for (int k = 0; k < C_N_PAD; k++)
      r_sel_eff[k] = (i_dbg_en && f_forced(k)) ? 2'b00 : r_sel_sw[k];
  endfunction

  // New random values on every IP output and every pad, then let the
  // combinational paths settle.
  task automatic t_drive_random();
    {i_gpio_0_out, i_gpio_0_oe, i_gpio_1_out, i_gpio_1_oe} = $urandom;
    {i_gpio_2_out, i_gpio_2_oe} = 16'($urandom);
    {i_uart_0_tx, i_uart_1_tx, i_spi_sck, i_spi_sck_oe, i_spi_csb, i_spi_csb_oe} = 6'($urandom);
    {i_spi_sd, i_spi_sd_oe} = 8'($urandom);
    {i_i2c_scl, i_i2c_scl_oe_n, i_i2c_sda, i_i2c_sda_oe_n} = 4'($urandom);
    i_pwm = 8'($urandom);
    {i_jtag_tdo, i_jtag_tdo_oe} = 2'($urandom);
    i_pad_in = 28'($urandom);
    #1;
  endtask

  // Check every pad against the select it must use, and every unselected IP
  // input against its idle value, for n random stimuli.
  task automatic t_check_all(input int n);
    f_update_eff();
    repeat (n) begin
      t_drive_random();
      for (int k = 0; k < C_N_PAD; k++) t_expect_pad(k, r_sel_eff[k]);
      t_expect_idle();
    end
  endtask

  // ---- APB master ------------------------------------------------------------------
  // Signals change 1 ns after a rising edge, so the DUT samples them at the next one.
  task automatic t_apb(input logic wr, input logic [13:0] a, input logic [31:0] wd,
                       input logic [3:0] strb, output logic [31:0] rd, output logic err);
    @(posedge i_clk_peri); #1;
    i_bus_apb_psel = 1'b1; i_bus_apb_penable = 1'b0; i_bus_apb_pwrite = wr;
    i_bus_apb_paddr = a; i_bus_apb_pwdata = wd; i_bus_apb_pstrb = strb;
    @(posedge i_clk_peri); #1;
    i_bus_apb_penable = 1'b1;
    // PREADY may already be high in the first access cycle (an error answer)
    while (!o_bus_apb_pready) begin @(posedge i_clk_peri); #1; end
    rd = o_bus_apb_prdata;
    err = o_bus_apb_pslverr;
    i_bus_apb_psel = 1'b0; i_bus_apb_penable = 1'b0; i_bus_apb_pwrite = 1'b0;
    i_bus_apb_pstrb = 4'hF;
  endtask

  task automatic t_wr32(input logic [13:0] a, input logic [31:0] v);
    logic [31:0] rd; logic err;
    t_apb(1'b1, a, v, 4'hF, rd, err);
    t_chk(!err, $sformatf("PSLVERR on write 0x%04h", a));
  endtask

  task automatic t_rd32(input logic [13:0] a, output logic [31:0] v);
    logic err;
    t_apb(1'b0, a, 32'h0, 4'hF, v, err);
    t_chk(!err, $sformatf("PSLVERR on read 0x%04h", a));
  endtask

  task automatic t_expect32(input string id, input logic [13:0] a, input logic [31:0] exp);
    logic [31:0] v;
    t_rd32(a, v);
    t_chk(v === exp, $sformatf("%s: 0x%04h read 0x%08h, expected 0x%08h", id, a, v, exp));
  endtask

  // Write the shadow to PADSEL_0 / PADSEL_1.
  task automatic t_write_sel();
    logic [55:0] v;
    for (int k = 0; k < C_N_PAD; k++) v[2*k +: 2] = r_sel_sw[k];
    t_wr32(A_PADSEL_0, v[31:0]);
    t_wr32(A_PADSEL_1, {8'h00, v[55:32]});
  endtask

  task automatic t_set_all(input logic [1:0] c);
    for (int k = 0; k < C_N_PAD; k++) r_sel_sw[k] = c;
    t_write_sel();
  endtask

  initial begin
    string w;
    if ($value$plusargs("waves=%s", w)) begin
      $dumpfile(w);
      $dumpvars(0, tb_iomux);
    end
  end

  initial begin
    for (int k = 0; k < C_N_PAD; k++) r_sel_sw[k] = 2'b00;
    t_drive_random();
    repeat (3) @(posedge i_clk_peri);
    #1 i_rst_n_peri = 1'b1;

    `include "tests/iomux_001.svh"
    `include "tests/iomux_002.svh"
    `include "tests/iomux_003.svh"
    `include "tests/iomux_004.svh"

    $display("PASS");
    $finish;
  end
endmodule
