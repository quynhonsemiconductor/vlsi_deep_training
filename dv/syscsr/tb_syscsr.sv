`timescale 1ns/1ps

// tb_syscsr -- testbench of m_qnsc_wrap_syscsr (QNSC_SYSCSR_MAS section 12).
//
// One APB master task, one DBG_EN pin, one power-on reset. Every test is a file
// in tests/, named after its MAS verification item, and all run in one
// simulation, in order. See README.md for the items covered.
module tb_syscsr;
  localparam logic [11:0] A_RESET_CAUSE = 12'h000;
  localparam logic [11:0] A_DOMAIN_RST  = 12'h004;
  localparam logic [11:0] A_CHIP_ID_REV = 12'h008;
  localparam logic [11:0] A_DBG_BOOT    = 12'h00C;
  localparam logic [31:0] CHIP_ID       = 32'h5153_4F43;   // 'QSOC', tied here as design/top does

  logic        clk = 1'b0;
  logic        rst_n = 1'b0;
  logic        psel = 1'b0, penable = 1'b0, pwrite = 1'b0;
  logic [11:0] paddr = '0;
  logic [31:0] pwdata = '0;
  logic [3:0]  pstrb = 4'hF;
  logic [31:0] prdata;
  logic        pready, pslverr;
  logic        dbg_en_pin = 1'b0;

  always #25 clk = ~clk;                                   // 20 MHz

  m_qnsc_wrap_syscsr u_dut (
    .i_clk_cpu         (clk),
    .i_rst_n_por       (rst_n),
    .i_bus_apb_psel    (psel),
    .i_bus_apb_penable (penable),
    .i_bus_apb_pwrite  (pwrite),
    .i_bus_apb_paddr   (paddr),
    .i_bus_apb_pwdata  (pwdata),
    .i_bus_apb_pstrb   (pstrb),
    .i_bus_apb_pprot   (3'b000),
    .o_bus_apb_prdata  (prdata),
    .o_bus_apb_pready  (pready),
    .o_bus_apb_pslverr (pslverr),
    .i_cause_we_wdt    (1'b0),
    .i_cause_we_sw     (1'b0),
    .i_domain_rst_stat (32'h0),
    .i_dbg_en          (dbg_en_pin),
    .i_cfg_chip_id     (CHIP_ID)
  );

  // One APB transfer. Signals change 1 ns after a rising edge, so the DUT
  // samples them at the next one.
  task automatic apb(input logic wr, input logic [11:0] a, input logic [31:0] wd,
                     output logic [31:0] rd);
    @(posedge clk); #1;
    psel = 1'b1; penable = 1'b0; pwrite = wr; paddr = a; pwdata = wd;
    @(posedge clk); #1;
    penable = 1'b1;
    do begin @(posedge clk); #1; end while (!pready);
    rd = prdata;
    if (pslverr) $fatal(1, "PSLVERR on %s 0x%03h", wr ? "write" : "read", a);
    psel = 1'b0; penable = 1'b0; pwrite = 1'b0;
  endtask

  task automatic rd32(input logic [11:0] a, output logic [31:0] v);
    apb(1'b0, a, 32'h0, v);
  endtask

  task automatic wr32(input logic [11:0] a, input logic [31:0] v);
    logic [31:0] unused;
    apb(1'b1, a, v, unused);
  endtask

  task automatic expect32(input string id, input logic [11:0] a, input logic [31:0] exp);
    logic [31:0] v;
    rd32(a, v);
    if (v !== exp) $fatal(1, "%s: 0x%03h read 0x%08h, expected 0x%08h", id, a, v, exp);
  endtask

  // Drive the DBG_EN pin just after an edge and count the edges until the
  // synchronised bit follows it: two, the depth of the synchroniser.
  task automatic pin_to(input string id, input logic v);
    @(posedge clk); #1;
    dbg_en_pin = v;
    @(posedge clk); #1;
    if (u_dut.u_dbg_en.o_dbg_en_masked === v && u_dut.u_dbg_en.i_dbg_en_mask === 1'b0)
      $fatal(1, "%s: dbg_en followed the pin after 1 edge; expected 2", id);
    @(posedge clk); #1;
  endtask

  initial begin
    string w;
    if ($value$plusargs("waves=%s", w)) begin
      $dumpfile(w);
      $dumpvars(0, tb_syscsr);
    end
  end

  initial begin
    repeat (3) @(posedge clk);
    #1 rst_n = 1'b1;

    `include "tests/syscsr_001.svh"
    `include "tests/syscsr_011.svh"
    `include "tests/syscsr_012.svh"
    `include "tests/syscsr_013.svh"

    $display("PASS");
    $finish;
  end
endmodule
