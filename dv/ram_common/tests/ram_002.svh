// RAM_002: STRBFIFO and WFIFO hold the same number of entries in every cycle (MAS 7.3,
// item 2). The comparison runs in every cycle of every test (ram_tb.svh); this test
// drives the cases that move the two FIFOs apart if the pop were wrong: W beats long
// before their address, an address long before its W beats, a stalled B channel, and
// random mixes. It fails if the FIFOs never filled, so a weak run cannot pass.
task automatic ram_002();
  int unsigned t;
  b_t bx;
  occ_max = 0;

  // W before AW: the write-data FIFO fills (8 entries), wready drops
  b_ready = 1'b0;
  fork
    send_w_burst(8'd15, 7, 4'hF, 0);
    begin idle(40); send_aw(32'h0000_0200, 8'd15, 2'b01, 7'h31, t); end
  join
  idle(10);
  b_ready = 1'b1;
  wait_b(bx);

  // AW before W, with gaps between the beats
  fork
    send_aw(32'h0000_0300, 8'd7, 2'b01, 7'h32, t);
    begin idle(20); send_w_burst(8'd7, 8, 4'h5, 3); end
  join
  wait_b(bx);

  // random bursts, AW and W streams independent, B held back now and then
  begin
    int n = 24;
    int sent_aw = 0, sent_w = 0;
    fork
      for (int i = 0; i < n; i++) begin
        int unsigned t2;
        send_aw(32'h0000_0400 + 64 * i, 8'(i % 5), 2'b01, 7'(i), t2);
        idle($urandom_range(0, 6));
        sent_aw++;
      end
      for (int i = 0; i < n; i++) begin
        send_w_burst(8'(i % 5), 100 + i, 4'($urandom_range(0, 15)), $urandom_range(0, 2));
        sent_w++;
      end
      begin
        for (int k = 0; k < n; k++) begin
          b_ready = 1'($urandom_range(0, 1));
          idle($urandom_range(0, 12));
          b_ready = 1'b1;
          wait_b(bx);
        end
      end
    join
  end

  if (occ_err != 0) $fatal(1, "RAM_002: occupancy differed in %0d cycle(s)", occ_err);
  if (occ_max < 8) $fatal(1, "RAM_002: the write-data FIFO reached only %0d entries, the test is too weak", occ_max);
  $display("RAM_002 ok: STRBFIFO = WFIFO occupancy in every cycle, FIFO filled to %0d entries", occ_max);
endtask
