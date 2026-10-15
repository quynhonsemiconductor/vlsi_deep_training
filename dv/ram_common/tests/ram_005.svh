// RAM_005: B and R return in the order the addresses were accepted, each with the ID of
// its request (MAS 7.1, item 5). Six bursts with distinct IDs and lengths, the response
// channel held back so the FIFOs fill, then released.
task automatic ram_005();
  int unsigned tt;
  logic [31:0] d[$];
  b_t bx;
  r_t rx;
  int unsigned base[6], len[6];
  for (int i = 0; i < 6; i++) begin base[i] = 32'h0000_0600 + 64 * i; len[i] = i % 4; end

  // B
  b_ready = 1'b0;
  fork
    for (int i = 0; i < 6; i++) send_aw(base[i], 8'(len[i]), 2'b01, 7'h11 + 7'(i), tt);
    for (int i = 0; i < 6; i++) send_w_burst(8'(len[i]), 200 + i, 4'hF, 0);
  join
  idle(30);
  b_ready = 1'b1;
  for (int i = 0; i < 6; i++) begin
    wait_b(bx);
    if (bx.id !== 7'h11 + 7'(i)) $fatal(1, "RAM_005: B %0d has id %0h, expected %0h", i, bx.id, 7'h11 + 7'(i));
  end

  // R: all six requested, R held back for 60 cycles
  r_ready = 1'b0;
  begin
    int unsigned a0;
    for (int i = 0; i < 6; i++) send_ar(base[i], 8'(len[i]), 2'b01, 7'h21 + 7'(i), a0);
  end
  idle(60);
  r_ready = 1'b1;
  for (int i = 0; i < 6; i++) begin
    for (int k = 0; k <= len[i]; k++) begin
      wait_r(rx);
      if (rx.id !== 7'h21 + 7'(i)) $fatal(1, "RAM_005: R burst %0d beat %0d has id %0h, expected %0h", i, k, rx.id, 7'h21 + 7'(i));
      if (rx.last !== (k == len[i])) $fatal(1, "RAM_005: RLAST %0b on burst %0d beat %0d", rx.last, i, k);
      chk32($sformatf("RAM_005 burst %0d beat %0d", i, k), rx.data, pat(200 + i, k));
    end
  end
  $display("RAM_005 ok: B and R in acceptance order, each with its request's ID, through full FIFOs");
endtask
