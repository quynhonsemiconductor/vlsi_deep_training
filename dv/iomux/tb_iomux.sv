`timescale 1ns/1ps

// tb_iomux -- testbench of m_qnsc_iomux (QNSC_IOMUX_MAS, verification).
//
// Every DUT port is a testbench signal of the same name, so the generated
// checks (util/gen/iomux/iomux_expect.svh, from the same pin table as the RTL)
// read them directly. The DUT is combinational: the testbench drives
// i_iomux_sel (SYSCSR o_iomux_sel, 2 bits per muxed pad) and keeps the code of
// the function each pad must use (r_sel_eff). Each test is a file in
// tests/; all run in one simulation, in order.
module tb_iomux;
  localparam int C_N_FIELD = 22;   // muxed pads, 2 select bits each

  // ---- DUT ports --------------------------------------------------------------
  logic [43:0] i_iomux_sel = '0;
  logic [7:0]  i_gpio_0_out, i_gpio_0_oe, o_gpio_0_in;
  logic [7:0]  i_gpio_1_out, i_gpio_1_oe, o_gpio_1_in;
  logic [7:0]  i_gpio_2_out, i_gpio_2_oe, o_gpio_2_in;
  logic        i_uart_0_tx, o_uart_0_rx, i_uart_1_tx, o_uart_1_rx;
  logic        i_spih_sck, i_spih_sck_oe, i_spih_csb, i_spih_csb_oe;
  logic [1:0]  i_spih_sd, i_spih_sd_oe, o_spih_sd;
  logic        o_spid_sck, o_spid_csb, o_spid_mosi, i_spid_miso, i_spid_miso_oe;
  logic        i_i2c_scl, i_i2c_scl_oe, o_i2c_scl;
  logic        i_i2c_sda, i_i2c_sda_oe, o_i2c_sda;
  logic [7:0]  i_pwm;
  logic [3:0]  o_tim_ext;
  logic        o_jtag_tck, o_jtag_tms, o_jtag_tdi, i_jtag_tdo, i_jtag_tdo_oe, o_jtag_trst_n;
  logic [28:0] o_pad_out, o_pad_oe, o_pad_ie, i_pad_in;

  m_qnsc_iomux u_dut (.*);

  // ---- function each pad must use ------------------------------------------------
  logic [1:0] r_sel_eff [29];

  task automatic t_chk(input bit ok, input string msg);
    if (!ok) $fatal(1, "%s", msg);
  endtask

  `include "iomux_expect.svh"

  // A fixed pad uses b00; a muxed pad uses its field of i_iomux_sel.
  function automatic void f_update_eff();
    for (int k = 0; k < C_N_PAD; k++)
      r_sel_eff[k] = (C_SEL[k] < 0) ? 2'b00 : i_iomux_sel[2 * C_SEL[k] +: 2];
  endfunction

  // New random values on every IP output and every pad, then let the
  // combinational paths settle.
  task automatic t_drive_random();
    {i_gpio_0_out, i_gpio_0_oe, i_gpio_1_out, i_gpio_1_oe} = $urandom;
    {i_gpio_2_out, i_gpio_2_oe} = 16'($urandom);
    {i_uart_0_tx, i_uart_1_tx, i_spih_sck, i_spih_sck_oe, i_spih_csb, i_spih_csb_oe} = 6'($urandom);
    {i_spih_sd, i_spih_sd_oe, i_spid_miso, i_spid_miso_oe} = 6'($urandom);
    {i_i2c_scl, i_i2c_scl_oe, i_i2c_sda, i_i2c_sda_oe} = 4'($urandom);
    i_pwm = 8'($urandom);
    {i_jtag_tdo, i_jtag_tdo_oe} = 2'($urandom);
    i_pad_in = 29'($urandom);
    #1;
  endtask

  // Check every pad against the function it must use, and every unselected IP
  // input against its idle value, for n random stimuli.
  task automatic t_check_all(input int n);
    #1;
    f_update_eff();
    repeat (n) begin
      t_drive_random();
      for (int k = 0; k < C_N_PAD; k++) t_expect_pad(k, r_sel_eff[k]);
      t_expect_idle();
    end
  endtask

  // every muxed pad on code v
  task automatic t_set_all(input logic [1:0] v);
    i_iomux_sel = {C_N_FIELD{v}};
  endtask

  // muxed pad field f on code v, the others unchanged
  task automatic t_set_field(input int f, input logic [1:0] v);
    i_iomux_sel[2 * f +: 2] = v;
  endtask

  initial begin
    string w;
    if ($value$plusargs("waves=%s", w)) begin
      $dumpfile(w);
      $dumpvars(0, tb_iomux);
    end
  end

  initial begin
    t_drive_random();

    `include "tests/iomux_001.svh"
    `include "tests/iomux_002.svh"
    `include "tests/iomux_003.svh"
    `include "tests/iomux_004.svh"

    $display("PASS");
    $finish;
  end
endmodule
