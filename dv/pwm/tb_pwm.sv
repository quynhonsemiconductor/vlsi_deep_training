`timescale 1ns/1ps

// Testbench of m_qnsc_wrap_pwm (QNSC_PWM_MAS, section 12).
//
//   make sim BLOCK=pwm                     every test
//   make sim BLOCK=pwm TEST=pwm_004        one test, named after its MAS check
//   make sim BLOCK=pwm TEST=pwm_004 WAVES=1
//
// Each test is in tests/<name>.svh, starts from reset and is self-checking: a
// mismatch calls $fatal with the expected and the observed value. The run ends
// with PASS. Checks not yet covered are listed in dv/pwm/README.md.

module tb_pwm;

  // ------------------------------------------------------------ DUT
  logic        r_clk = 1'b0;
  logic        r_rst_n = 1'b0;
  logic [11:0] r_paddr = '0;
  logic        r_psel = 1'b0, r_penable = 1'b0, r_pwrite = 1'b0;
  logic [31:0] r_pwdata = '0;
  logic [3:0]  r_tim_ext = '0;
  logic [31:0] w_prdata;
  logic        w_pready, w_pslverr;
  logic [7:0]  w_pad_pwm;
  logic [3:0]  w_int_pwm;

  always #25 r_clk = ~r_clk;   // i_clk_peri, 20 MHz

  m_qnsc_wrap_pwm u_dut (
    .i_clk_peri        (r_clk),
    .i_rst_n_peri      (r_rst_n),
    .i_bus_apb_paddr   (r_paddr),
    .i_bus_apb_penable (r_penable),
    .i_bus_apb_psel    (r_psel),
    .i_bus_apb_pwdata  (r_pwdata),
    .i_bus_apb_pwrite  (r_pwrite),
    .o_bus_apb_prdata  (w_prdata),
    .o_bus_apb_pready  (w_pready),
    .o_bus_apb_pslverr (w_pslverr),
    .i_pad_tim_ext     (r_tim_ext),
    .o_pad_pwm         (w_pad_pwm),
    .o_int_pwm         (w_int_pwm)
  );

  // ------------------------------------------------------------ registers (MAS 6)
  localparam logic [11:0] C_CMD = 12'h000, C_CFG = 12'h004, C_TH = 12'h008, C_CH0_TH = 12'h00C,
                          C_CH0_LUT = 12'h01C, C_COUNTER = 12'h02C, C_EVENT_CFG = 12'h100,
                          C_CH_EN = 12'h104;
  localparam logic [31:0] C_START = 32'h01, C_STOP = 32'h02, C_UPDATE = 32'h04, C_RST = 32'h08;
  localparam int C_SETRST = 2, C_RST_MODE = 4, C_RSTSET = 6;

  function automatic logic [11:0] mod_base(input int unsigned m);
    return 12'(m * 32'h40);
  endfunction

  // ------------------------------------------------------------ APB driver
  task automatic apb_write(input logic [11:0] a, input logic [31:0] d);
    @(posedge r_clk);
    r_paddr <= a; r_pwdata <= d; r_pwrite <= 1'b1; r_psel <= 1'b1;
    @(posedge r_clk);
    r_penable <= 1'b1;
    @(posedge r_clk);
    r_psel <= 1'b0; r_penable <= 1'b0; r_pwrite <= 1'b0;
  endtask

  task automatic apb_read(input logic [11:0] a, output logic [31:0] d);
    @(posedge r_clk);
    r_paddr <= a; r_pwrite <= 1'b0; r_psel <= 1'b1;
    @(posedge r_clk);
    r_penable <= 1'b1;
    @(posedge r_clk);
    d = w_prdata;
    if (!w_pready) $fatal(1, "PREADY = 0 at 0x%03h", a);
    if (w_pslverr) $fatal(1, "PSLVERR = 1 at 0x%03h", a);
    r_psel <= 1'b0; r_penable <= 1'b0;
  endtask

  task automatic expect_reg(input logic [11:0] a, input logic [31:0] exp, input string what);
    logic [31:0] d;
    apb_read(a, d);
    if (d !== exp) $fatal(1, "%s: 0x%03h read 0x%08h, expected 0x%08h", what, a, d, exp);
  endtask

  // ------------------------------------------------------------ helpers
  task automatic reset_dut();
    r_rst_n = 1'b0;
    r_tim_ext = '0;
    repeat (4) @(posedge r_clk);
    r_rst_n = 1'b1;
    repeat (2) @(posedge r_clk);
  endtask

  // timer m: SAW, counter START..END, PRESC; every channel parked at MODE 4 (output 0)
  task automatic timer_setup(input int unsigned m, input int unsigned start, input int unsigned stop,
                             input int unsigned presc, input bit saw = 1'b1);
    apb_write(mod_base(m) + C_TH, (32'(stop) << 16) | 32'(start));
    apb_write(mod_base(m) + C_CFG, (32'(presc) << 16) | (32'(saw) << 12));
    for (int n = 0; n < 4; n++) channel(m, n, C_RST_MODE, 0);
  endtask

  task automatic channel(input int unsigned m, input int unsigned n, input int unsigned mode,
                         input int unsigned th);
    apb_write(mod_base(m) + C_CH0_TH + 12'(4 * n), (32'(mode) << 16) | 32'(th));
  endtask

  // cycles pad bit b is high, and its rising edges, over len cycles
  task automatic measure(input int unsigned b, input int unsigned len, output int unsigned high,
                         output int unsigned rises);
    logic prev = w_pad_pwm[b];
    high = 0; rises = 0;
    repeat (len) begin
      @(posedge r_clk);
      high += w_pad_pwm[b];
      rises += (w_pad_pwm[b] && !prev);
      prev = w_pad_pwm[b];
    end
  endtask

  // ------------------------------------------------------------ waveform (dv/README.md)
  initial begin
    string w;
    if ($value$plusargs("waves=%s", w)) begin
      $dumpfile(w);
      $dumpvars(0, tb_pwm);
    end
  end

  // ------------------------------------------------------------ tests
  `include "tests/pwm_001.svh"
  `include "tests/pwm_002.svh"
  `include "tests/pwm_003.svh"
  `include "tests/pwm_004.svh"
  `include "tests/pwm_005.svh"
  `include "tests/pwm_007.svh"
  `include "tests/pwm_008.svh"
  `include "tests/pwm_009.svh"
  `include "tests/pwm_010.svh"

  initial begin
    string t;
    if (!$value$plusargs("test=%s", t)) t = "all";
    if (t == "all" || t == "pwm_001") begin reset_dut(); pwm_001(); end
    if (t == "all" || t == "pwm_002") begin reset_dut(); pwm_002(); end
    if (t == "all" || t == "pwm_003") begin reset_dut(); pwm_003(); end
    if (t == "all" || t == "pwm_004") begin reset_dut(); pwm_004(); end
    if (t == "all" || t == "pwm_005") begin reset_dut(); pwm_005(); end
    if (t == "all" || t == "pwm_007") begin reset_dut(); pwm_007(); end
    if (t == "all" || t == "pwm_008") begin reset_dut(); pwm_008(); end
    if (t == "all" || t == "pwm_009") begin reset_dut(); pwm_009(); end
    if (t == "all" || t == "pwm_010") begin reset_dut(); pwm_010(); end
    $display("PASS (%s)", t);
    $finish;
  end

  initial begin
    #50ms;
    $fatal(1, "timeout");
  end

endmodule
