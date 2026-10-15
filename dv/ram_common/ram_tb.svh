// The body shared by tb_isram and tb_dsram. Included inside the testbench module,
// which first defines
//   `RAM_DUT        the wrapper module, m_qnsc_wrap_isram or m_qnsc_wrap_dsram
//   C_WORDS         macro depth in words
//   C_AW            macro word-address bits, $clog2(C_WORDS)
//   `RAM_TB         the testbench module's own name, for the waveform
// Tests are tests/ram_NNN.svh; the numbers are the items of QNSC_RAM_MAS 12.

  // ---------------------------------------------------------------- clock, reset
  logic clk   = 1'b0;
  logic rst_n = 1'b0;
  always #25 clk = ~clk;                                  // 20 MHz

  // Cycle counter. A task that samples at a clock edge reads the value of the cycle
  // that edge ends, so every cycle number below is on the same scale.
  int unsigned cyc = 0;
  always @(posedge clk) cyc <= cyc + 1;

  // ---------------------------------------------------------------- AXI4 master side
  logic [31:0] aw_addr  = '0;  logic [7:0] aw_len = '0;  logic [1:0] aw_burst = '0;
  logic [6:0]  aw_id    = '0;  logic       aw_valid = 1'b0;  logic aw_ready;
  logic [31:0] w_data   = '0;  logic [3:0] w_strb = '0;  logic w_last = 1'b0;
  logic        w_valid  = 1'b0;  logic w_ready;
  logic [6:0]  b_id;  logic [1:0] b_resp;  logic b_valid;  logic b_ready = 1'b1;
  logic [31:0] ar_addr  = '0;  logic [7:0] ar_len = '0;  logic [1:0] ar_burst = '0;
  logic [6:0]  ar_id    = '0;  logic       ar_valid = 1'b0;  logic ar_ready;
  logic [6:0]  r_id;  logic [31:0] r_data;  logic [1:0] r_resp;  logic r_valid;  logic r_last;
  logic        r_ready  = 1'b1;

  // ---------------------------------------------------------------- macro side
  logic [C_AW-1:0] mem_addr;
  logic [31:0]     mem_wdata, mem_rdata;
  logic            mem_we, mem_oe;
  logic [3:0]      mem_be;

  `RAM_DUT dut (
    .i_clk_mem(clk), .i_rst_n_mem(rst_n),
    .i_bus_axi_aw_addr(aw_addr), .i_bus_axi_aw_burst(aw_burst), .i_bus_axi_aw_id(aw_id),
    .i_bus_axi_aw_len(aw_len), .i_bus_axi_aw_valid(aw_valid), .o_bus_axi_aw_ready(aw_ready),
    .i_bus_axi_w_data(w_data), .i_bus_axi_w_last(w_last), .i_bus_axi_w_strb(w_strb),
    .i_bus_axi_w_valid(w_valid), .o_bus_axi_w_ready(w_ready),
    .o_bus_axi_b_id(b_id), .o_bus_axi_b_resp(b_resp), .o_bus_axi_b_valid(b_valid),
    .i_bus_axi_b_ready(b_ready),
    .i_bus_axi_ar_addr(ar_addr), .i_bus_axi_ar_burst(ar_burst), .i_bus_axi_ar_id(ar_id),
    .i_bus_axi_ar_len(ar_len), .i_bus_axi_ar_valid(ar_valid), .o_bus_axi_ar_ready(ar_ready),
    .o_bus_axi_r_data(r_data), .o_bus_axi_r_id(r_id), .o_bus_axi_r_last(r_last),
    .o_bus_axi_r_resp(r_resp), .o_bus_axi_r_valid(r_valid), .i_bus_axi_r_ready(r_ready),
    .o_mem_addr(mem_addr), .o_mem_wdata(mem_wdata), .o_mem_we(mem_we), .o_mem_be(mem_be),
    .o_mem_oe(mem_oe), .i_mem_rdata(mem_rdata)
  );

  tb_sram_model #(.WORDS(C_WORDS)) u_mem (
    .i_clk(clk), .i_addr(mem_addr), .i_wdata(mem_wdata), .i_we(mem_we), .i_be(mem_be),
    .i_oe(mem_oe), .o_rdata(mem_rdata)
  );

  // ---------------------------------------------------------------- monitors
  typedef struct { logic [6:0] id; logic [1:0] resp; int unsigned at; } b_t;
  typedef struct { logic [6:0] id; logic [31:0] data; logic [1:0] resp; logic last; int unsigned at; } r_t;
  b_t b_q[$];
  r_t r_q[$];
  int unsigned resp_err = 0;          // a BRESP or RRESP other than OKAY (MAS 7.5)

  always @(posedge clk) if (rst_n) begin
    if (b_valid && b_ready) begin
      b_q.push_back('{b_id, b_resp, cyc});
      if (b_resp != 2'b00) resp_err++;
    end
    if (r_valid && r_ready) begin
      r_q.push_back('{r_id, r_data, r_resp, r_last, cyc});
      if (r_resp != 2'b00) resp_err++;
    end
  end

  // Every access at the macro, in order: {write, word address}. MAS 7.2, 7.4.
  typedef struct { logic we; logic [C_AW-1:0] word; } acc_t;
  acc_t acc_q[$];
  always @(posedge clk) if (rst_n && (mem_we || mem_oe)) acc_q.push_back('{mem_we, mem_addr});

  // STRBFIFO and WFIFO hold the same number of entries in every cycle (MAS 7.3, 12 item 2).
  int unsigned occ_err = 0, occ_max = 0;
  function automatic int unsigned occ_strb();
    return int'(dut.u_strbfifo.wr_ptr - dut.u_strbfifo.rd_ptr) & 'hF;
  endfunction
  function automatic int unsigned occ_wdata();
    return int'(dut.u_sram_ctrl.u_wfifo.wr_ptr - dut.u_sram_ctrl.u_wfifo.rd_ptr) & 'hF;
  endfunction
  always @(posedge clk) if (rst_n) begin
    if (occ_strb() != occ_wdata()) occ_err++;
    if (occ_wdata() > occ_max) occ_max = occ_wdata();
  end

  // ---------------------------------------------------------------- bus tasks
  // The testbench drives 1 ns after the clock edge with blocking assignments and samples
  // at the edge, so the DUT never sees a change at the edge it samples. (With nonblocking
  // assignments a burst of back-to-back beats stalled after its first beat, Verilator 5.052.)
  task automatic tick();
    @(posedge clk);
    #1;
  endtask

  // Each task drives its channel and returns the cycle of the handshake. Back to back
  // calls keep valid high: the last nonblocking assignment wins.
  task automatic send_aw(input logic [31:0] a, input logic [7:0] len, input logic [1:0] bur,
                         input logic [6:0] id, output int unsigned at);
    #1;                                    // 1 ns after an edge: never at the edge itself
    aw_addr = a; aw_len = len; aw_burst = bur; aw_id = id; aw_valid = 1'b1;
    for (int unsigned wd = 0; ; wd++) begin
      @(posedge clk);
      if (aw_valid && aw_ready) begin at = cyc; break; end
      if (wd > 100000) $fatal(1, "send_aw: no handshake in 100000 cycles");
    end
    #1;
    aw_valid = 1'b0;
  endtask

  task automatic send_w(input logic [31:0] d, input logic [3:0] s, input logic last,
                        output int unsigned at);
    #1;
    w_data = d; w_strb = s; w_last = last; w_valid = 1'b1;
    for (int unsigned wd = 0; ; wd++) begin
      @(posedge clk);
      if (w_valid && w_ready) begin at = cyc; break; end
      if (wd > 100000) $fatal(1, "send_w: no handshake in 100000 cycles");
    end
    #1;
    w_valid = 1'b0;
  endtask

  task automatic send_ar(input logic [31:0] a, input logic [7:0] len, input logic [1:0] bur,
                         input logic [6:0] id, output int unsigned at);
    #1;
    ar_addr = a; ar_len = len; ar_burst = bur; ar_id = id; ar_valid = 1'b1;
    for (int unsigned wd = 0; ; wd++) begin
      @(posedge clk);
      if (ar_valid && ar_ready) begin at = cyc; break; end
      if (wd > 100000) $fatal(1, "send_ar: no handshake in 100000 cycles");
    end
    #1;
    ar_valid = 1'b0;
  endtask

  task automatic wait_b(output b_t x);
    int unsigned t = 0;
    while (b_q.size() == 0) begin
      tick();
      if (++t > 20000) $fatal(1, "timeout: no B response");
    end
    x = b_q.pop_front();
  endtask

  task automatic wait_r(output r_t x);
    int unsigned t = 0;
    while (r_q.size() == 0) begin
      tick();
      if (++t > 20000) $fatal(1, "timeout: no R beat");
    end
    x = r_q.pop_front();
  endtask

  task automatic idle(input int unsigned n);
    repeat (n) tick();
  endtask

  // A burst of len+1 W beats, data from pat(seed, i), the same strobe on every beat.
  task automatic send_w_burst(input logic [7:0] len, input int unsigned seed, input logic [3:0] s,
                              input int unsigned gap);
    int unsigned at;
    for (int i = 0; i <= len; i++) begin
      send_w(pat(seed, i), s, i == len, at);
      if (gap != 0) idle(gap);
    end
  endtask

  function automatic logic [31:0] pat(input int unsigned seed, input int unsigned i);
    logic [31:0] x = 32'h9E3779B9 * (seed + 1) + 32'h85EBCA6B * (i + 1);
    return x ^ (x >> 15) ^ (x << 7);
  endfunction

  // A burst: AW and the W beats in parallel, then B.
  task automatic wr_burst(input logic [31:0] a, input logic [7:0] len, input logic [1:0] bur,
                          input logic [6:0] id, input int unsigned seed, input logic [3:0] s,
                          input int unsigned gap = 0);
    int unsigned t;
    b_t bx;
    fork
      send_aw(a, len, bur, id, t);
      send_w_burst(len, seed, s, gap);
    join
    wait_b(bx);
    if (bx.id !== id) $fatal(1, "B id %0h, expected %0h", bx.id, id);
  endtask

  // A burst read: the len+1 beats come back in d, ID and LAST checked.
  task automatic rd_burst(input logic [31:0] a, input logic [7:0] len, input logic [1:0] bur,
                          input logic [6:0] id, ref logic [31:0] d[$]);
    int unsigned t;
    r_t rx;
    d.delete();
    send_ar(a, len, bur, id, t);
    for (int i = 0; i <= len; i++) begin
      wait_r(rx);
      if (rx.id !== id) $fatal(1, "R id %0h, expected %0h (beat %0d)", rx.id, id, i);
      if (rx.last !== (i == len)) $fatal(1, "RLAST %0b on beat %0d of %0d", rx.last, i, len + 1);
      d.push_back(rx.data);
    end
  endtask

  // One beat, waits for B. The data is written as given with the strobe s.
  task automatic wr1(input logic [31:0] a, input logic [31:0] d,
                     input logic [3:0] s = 4'hF, input logic [6:0] id = 7'h01);
    int unsigned t1, t2;
    b_t bx;
    fork
      send_aw(a, 8'd0, 2'b01, id, t1);
      send_w(d, s, 1'b1, t2);
    join
    wait_b(bx);
    if (bx.id !== id) $fatal(1, "B id %0h, expected %0h", bx.id, id);
  endtask

  // One beat read, waits for R.
  task automatic rd1(input logic [31:0] a, output logic [31:0] d, input logic [6:0] id = 7'h02);
    int unsigned t;
    r_t rx;
    send_ar(a, 8'd0, 2'b01, id, t);
    wait_r(rx);
    if (rx.id !== id || !rx.last) $fatal(1, "R id %0h last %0b, expected %0h, 1", rx.id, rx.last, id);
    d = rx.data;
  endtask

  task automatic chk32(input string what, input logic [31:0] got, input logic [31:0] exp);
    if (got !== exp) $fatal(1, "%s: got %08h, expected %08h", what, got, exp);
  endtask

  task automatic reset_dut();
    #1;
    rst_n = 1'b0;
    aw_valid = 1'b0; w_valid = 1'b0; ar_valid = 1'b0;
    b_ready = 1'b1; r_ready = 1'b1;
    repeat (4) tick();
    rst_n = 1'b1;
    repeat (2) tick();
    b_q.delete(); r_q.delete(); acc_q.delete();
  endtask

  // ---------------------------------------------------------------- tests
  `include "tests/ram_001.svh"
  `include "tests/ram_002.svh"
  `include "tests/ram_004.svh"
  `include "tests/ram_005.svh"
  `include "tests/ram_006.svh"
  `include "tests/ram_007.svh"
  `include "tests/ram_008.svh"
  `include "tests/ram_009.svh"
  `include "tests/ram_012.svh"
  `include "tests/ram_013.svh"

  string test_sel = "all";
  function automatic bit run(input string n);
    return test_sel == "all" || test_sel == n;
  endfunction

  initial begin
    string w;
    if ($value$plusargs("waves=%s", w)) begin
      $dumpfile(w);
      $dumpvars(0, `RAM_TB);
    end
  end

  // Whatever else goes wrong, a test ends: 3 million cycles is far more than all of them.
  initial begin
    #(50ns * 3000000);
    $fatal(1, "watchdog: the testbench ran for 3 million cycles");
  end

  initial begin
    void'($value$plusargs("test=%s", test_sel));
    reset_dut();
    if (run("ram_001")) ram_001();
    if (run("ram_002")) ram_002();
    if (run("ram_004")) ram_004();
    if (run("ram_005")) ram_005();
    if (run("ram_006")) ram_006();
    if (run("ram_007")) ram_007();
    if (run("ram_008")) ram_008();
    if (run("ram_009")) ram_009();
    if (run("ram_012")) ram_012();
    if (run("ram_013")) ram_013();
    if (occ_err != 0)  $fatal(1, "STRBFIFO and WFIFO occupancy differed in %0d cycle(s)", occ_err);
    if (resp_err != 0) $fatal(1, "%0d response(s) other than OKAY", resp_err);
    $display("PASS (%s)", test_sel);
    $finish;
  end
