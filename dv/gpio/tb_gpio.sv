`timescale 1ns/1ps

module tb_gpio;
  localparam logic [11:0] C_PADDIR    = 12'h000;
  localparam logic [11:0] C_GPIOEN    = 12'h004;
  localparam logic [11:0] C_PADIN     = 12'h008;
  localparam logic [11:0] C_PADOUT    = 12'h00c;
  localparam logic [11:0] C_PADOUTSET = 12'h010;
  localparam logic [11:0] C_PADOUTCLR = 12'h014;
  localparam logic [11:0] C_INTEN     = 12'h018;
  localparam logic [11:0] C_INTTYPE   = 12'h01c;
  localparam logic [11:0] C_INTSTATUS = 12'h024;
  localparam logic [11:0] C_PADCFG    = 12'h028;

  logic        clk;
  logic        rst_n;
  logic [11:0] paddr;
  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;
  logic [7:0]  pad_gpio_in;
  logic [7:0]  pad_gpio_out;
  logic [7:0]  pad_gpio_oe;
  logic [31:0] pad_gpio_cfg;
  logic        int_gpio;

  integer failures;

  m_qnsc_wrap_gpio dut (
    .i_clk_peri        (clk),
    .i_rst_n_peri      (rst_n),
    .i_bus_apb_paddr   (paddr),
    .i_bus_apb_penable (penable),
    .i_bus_apb_psel    (psel),
    .i_bus_apb_pwdata  (pwdata),
    .i_bus_apb_pwrite  (pwrite),
    .o_bus_apb_prdata  (prdata),
    .o_bus_apb_pready  (pready),
    .o_bus_apb_pslverr (pslverr),
    .i_pad_gpio        (pad_gpio_in),
    .o_pad_gpio        (pad_gpio_out),
    .o_pad_gpio_cfg    (pad_gpio_cfg),
    .o_pad_gpio_oe     (pad_gpio_oe),
    .o_int_gpio        (int_gpio)
  );

  always #5 clk = ~clk;

  task automatic apb_idle;
    begin
      paddr   = '0;
      psel    = 1'b0;
      penable = 1'b0;
      pwrite  = 1'b0;
      pwdata  = '0;
    end
  endtask

  task automatic apb_write(
    input logic [11:0] addr,
    input logic [31:0] data
  );
    begin
      @(negedge clk);
      paddr   = addr;
      psel    = 1'b1;
      penable = 1'b0;
      pwrite  = 1'b1;
      pwdata  = data;

      @(negedge clk);
      penable = 1'b1;
      @(posedge clk);
      if (!pready)
        $fatal(1, "APB write did not complete at offset %03x", addr);
      if (pslverr)
        $fatal(1, "Unexpected PSLVERR on APB write at offset %03x", addr);

      @(negedge clk);
      apb_idle();
    end
  endtask

  task automatic apb_read(
    input  logic [11:0] addr,
    output logic [31:0] data
  );
    begin
      @(negedge clk);
      paddr   = addr;
      psel    = 1'b1;
      penable = 1'b0;
      pwrite  = 1'b0;
      pwdata  = '0;

      @(negedge clk);
      penable = 1'b1;
      @(posedge clk);
      if (!pready)
        $fatal(1, "APB read did not complete at offset %03x", addr);
      if (pslverr)
        $fatal(1, "Unexpected PSLVERR on APB read at offset %03x", addr);
      data = prdata;

      @(negedge clk);
      apb_idle();
    end
  endtask

  task automatic check32(
    input string       name,
    input logic [31:0] got,
    input logic [31:0] expected
  );
    begin
      if (got !== expected) begin
        $display("FAIL %-40s got=%08x expected=%08x", name, got, expected);
        failures = failures + 1;
      end else begin
        $display("PASS %-40s value=%08x", name, got);
      end
    end
  endtask

  task automatic check_true(input string name, input logic condition);
    begin
      if (condition !== 1'b1) begin
        $display("FAIL %-40s", name);
        failures = failures + 1;
      end else begin
        $display("PASS %-40s", name);
      end
    end
  endtask

  task automatic wait_for_interrupt(
    input string name,
    output logic seen
  );
    integer k;
    begin
      seen = 1'b0;
      for (k = 0; k < 8; k = k + 1) begin
        @(posedge clk);
        #1;
        if (int_gpio)
          seen = 1'b1;
      end
      check_true(name, seen);
    end
  endtask

  initial begin
    logic [31:0] read_data;
    logic        irq_seen;

    clk         = 1'b0;
    rst_n       = 1'b0;
    pad_gpio_in = '0;
    failures    = 0;
    apb_idle();

    repeat (3) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);

    check32("reset output", {24'h0, pad_gpio_out}, 32'h0000_0000);
    check32("reset output enable", {24'h0, pad_gpio_oe}, 32'h0000_0000);
    check32("reset pad configuration", pad_gpio_cfg, 32'h0000_0000);
    check_true("reset interrupt low", !int_gpio);

    apb_write(C_PADDIR, 32'h0000_00a5);
    apb_read(C_PADDIR, read_data);
    check32("PADDIR full-word readback", read_data, 32'h0000_00a5);
    check32("PADDIR drives output enable", {24'h0, pad_gpio_oe}, 32'h0000_00a5);

    apb_write(C_PADOUT, 32'h0000_00a0);
    apb_write(C_PADOUTSET, 32'h0000_000f);
    check32("PADOUTSET", {24'h0, pad_gpio_out}, 32'h0000_00af);
    apb_write(C_PADOUTCLR, 32'h0000_0005);
    check32("PADOUTCLR", {24'h0, pad_gpio_out}, 32'h0000_00aa);

    apb_write(C_PADCFG, 32'h7654_3210);
    apb_read(C_PADCFG, read_data);
    check32("flattened PADCFG readback", read_data, 32'h7654_3210);
    check32("flattened PADCFG output", pad_gpio_cfg, 32'h7654_3210);

    apb_write(12'h080, 32'h0000_005a);
    apb_read(C_PADDIR, read_data);
    check32("PADDR bit 7 aliases PADDIR", read_data, 32'h0000_005a);

    apb_write(C_GPIOEN, 32'h0000_00ff);
    @(negedge clk);
    pad_gpio_in = 8'h3c;
    repeat (4) @(posedge clk);
    apb_read(C_PADIN, read_data);
    check32("synchronised input reaches PADIN", read_data, 32'h0000_003c);

    apb_write(C_INTEN, 32'h0000_0001);

    // Rising edge: INTTYPE[1:0] = 01.
    apb_write(C_INTTYPE, 32'h0000_0001);
    @(negedge clk);
    pad_gpio_in[0] = 1'b0;
    repeat (4) @(posedge clk);
    @(negedge clk);
    pad_gpio_in[0] = 1'b1;
    wait_for_interrupt("rising-edge interrupt", irq_seen);
    apb_read(C_INTSTATUS, read_data);
    check32("rising edge recorded in INTSTATUS", read_data, 32'h0000_0001);
    apb_read(C_INTSTATUS, read_data);
    check32("INTSTATUS read clears status", read_data, 32'h0000_0000);

    // Falling edge: INTTYPE[1:0] = 00.
    apb_write(C_INTTYPE, 32'h0000_0000);
    @(negedge clk);
    pad_gpio_in[0] = 1'b1;
    repeat (4) @(posedge clk);
    @(negedge clk);
    pad_gpio_in[0] = 1'b0;
    wait_for_interrupt("falling-edge interrupt", irq_seen);
    apb_read(C_INTSTATUS, read_data);
    check32("falling edge recorded in INTSTATUS", read_data, 32'h0000_0001);

    // Both edges: INTTYPE[1:0] = 10.
    apb_write(C_INTTYPE, 32'h0000_0002);
    @(negedge clk);
    pad_gpio_in[0] = 1'b1;
    wait_for_interrupt("both-edge mode detects rising edge", irq_seen);
    apb_read(C_INTSTATUS, read_data);
    check32("both-edge event recorded", read_data, 32'h0000_0001);

    // Align a rising event with an INTSTATUS read. Set must beat clear.
    apb_write(C_INTTYPE, 32'h0000_0001);
    @(negedge clk);
    pad_gpio_in[0] = 1'b0;
    repeat (4) @(posedge clk);
    apb_read(C_INTSTATUS, read_data); // clear any earlier status
    @(negedge clk);
    pad_gpio_in[0] = 1'b1;
    @(posedge clk);                  // synchroniser stage 0
    @(negedge clk);
    paddr   = C_INTSTATUS;
    psel    = 1'b1;
    penable = 1'b0;
    pwrite  = 1'b0;
    pwdata  = '0;
    @(posedge clk);                  // synchroniser stage 1
    @(negedge clk);
    penable = 1'b1;
    @(posedge clk);                  // event set and read-clear coincide
    @(negedge clk);
    apb_idle();
    apb_read(C_INTSTATUS, read_data);
    check32("interrupt set has priority over clear", read_data, 32'h0000_0001);

    if (failures == 0) begin
      $display("PASS GPIO regression");
      $finish;
    end else begin
      $fatal(1, "GPIO regression failed: %0d check(s)", failures);
    end
  end

endmodule
