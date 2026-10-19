// RAM_013 (added by QSOC, no MAS item): the write-response FIFO holds 8 responses and
// has no back-pressure on the write grant (MAS 7.1). With BREADY low, 8 single-beat
// writes all get their B. A ninth and tenth write still complete, but their responses
// are dropped: the accepted limit, stated here so that a change in it is a decision.
task automatic ram_013();
  int unsigned tt, got8, got10;
  logic [31:0] d;

  for (int run = 0; run < 2; run++) begin
    int n = (run == 0) ? 8 : 10;
    reset_dut();
    b_ready = 1'b0;
    fork
      for (int i = 0; i < n; i++) send_aw(32'h0000_0100 + 4 * i, 8'd0, 2'b01, 7'(i + 1), tt);
      for (int i = 0; i < n; i++) begin int unsigned t2; send_w(32'hA000_0000 + i, 4'hF, 1'b1, t2); end
    join
    idle(40);
    b_ready = 1'b1;
    idle(60);
    if (run == 0) got8 = b_q.size(); else got10 = b_q.size();
    for (int i = 0; i < ((run == 0) ? 8 : 8); i++)       // the first 8 are in order
      if (b_q[i].id !== 7'(i + 1)) $fatal(1, "RAM_013: B %0d has id %0h, expected %0h", i, b_q[i].id, 7'(i + 1));
    for (int i = 0; i < n; i++) begin                     // every write reached the macro
      rd1(32'h0000_0100 + 4 * i, d);
      chk32($sformatf("RAM_013 word %0d", i), d, 32'hA000_0000 + i);
    end
  end
  if (got8 != 8)  $fatal(1, "RAM_013: 8 writes with BREADY low gave %0d responses, expected 8", got8);
  if (got10 != 8) $fatal(1, "RAM_013: 10 writes with BREADY low gave %0d responses; the limit of MAS 7.1 says 8", got10);
  $display("RAM_013 ok: 8 responses held with BREADY low are all delivered; of 10 writes, 8 responses come back and the other 2 are dropped (accepted limit, MAS 7.1)");
endtask
