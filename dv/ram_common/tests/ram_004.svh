// RAM_004: every value of the timing table of MAS 7.1, measured at the block ports
// (item 4). A cycle number is the cycle a handshake is sampled in; the difference
// between two is the table's "cycles after".
task automatic ram_004();
  int unsigned t_ar, t_aw, t_w, spc[$];
  int unsigned d_r, d_b, d_rb, d_wb, d_ar, d_aw;
  logic [31:0] dd[$];
  b_t bx;
  r_t rx;

  wr1(32'h0000_0040, 32'h1234_5678);
  idle(8);

  // rvalid after the AR handshake cycle, single beat: 4
  send_ar(32'h0000_0040, 8'd0, 2'b01, 7'h05, t_ar);
  wait_r(rx);
  d_r = rx.at - t_ar;

  // bvalid after the AW handshake cycle, W accepted in the same cycle: 3
  idle(8);
  fork
    send_aw(32'h0000_0044, 8'd0, 2'b01, 7'h06, t_aw);
    send_w(32'hCAFE_F00D, 4'hF, 1'b1, t_w);
  join
  if (t_aw != t_w) $fatal(1, "RAM_004: AW and W were not accepted in the same cycle (%0d, %0d)", t_aw, t_w);
  wait_b(bx);
  d_b = bx.at - t_aw;

  // read burst, beats 8: one beat per 2 cycles
  idle(8);
  r_ready = 1'b1;
  send_ar(32'h0000_0100, 8'd7, 2'b01, 7'h07, t_ar);
  spc.delete();
  for (int i = 0; i < 8; i++) begin
    wait_r(rx);
    if (i > 0) spc.push_back(rx.at - d_rb);
    d_rb = rx.at;
  end
  d_rb = 0;
  foreach (spc[i]) if (spc[i] != 2) $fatal(1, "RAM_004: read beat spacing %0d at beat %0d, expected 2", spc[i], i + 1);

  // write burst, 16 beats: one beat per cycle on W, ready never drops
  idle(8);
  begin
    int unsigned at[16];
    int unsigned tt;
    fork
      send_aw(32'h0000_0400, 8'd15, 2'b01, 7'h08, tt);
      for (int i = 0; i < 16; i++) send_w(pat(1, i), 4'hF, i == 15, at[i]);
    join
    for (int i = 1; i < 16; i++)
      if (at[i] - at[i-1] != 1) $fatal(1, "RAM_004: W beat %0d accepted %0d cycles after the previous one, expected 1", i, at[i] - at[i-1]);
    wait_b(bx);
  end

  // address handshakes on one channel, N-beat bursts: one per N + 2 cycles (N = 4)
  idle(8);
  begin
    int unsigned a0, a1, a2;
    send_ar(32'h0000_0100, 8'd3, 2'b01, 7'h09, a0);
    send_ar(32'h0000_0110, 8'd3, 2'b01, 7'h0A, a1);
    send_ar(32'h0000_0120, 8'd3, 2'b01, 7'h0B, a2);
    d_ar = a1 - a0;
    if (a2 - a1 != d_ar) $fatal(1, "RAM_004: AR spacing %0d then %0d", d_ar, a2 - a1);
    repeat (12) wait_r(rx);
  end
  idle(8);
  begin
    int unsigned a0, a1, a2, tw;
    fork
      begin
        send_aw(32'h0000_0500, 8'd3, 2'b01, 7'h0C, a0);
        send_aw(32'h0000_0510, 8'd3, 2'b01, 7'h0D, a1);
        send_aw(32'h0000_0520, 8'd3, 2'b01, 7'h0E, a2);
      end
      for (int i = 0; i < 12; i++) send_w(pat(2, i), 4'hF, (i % 4) == 3, tw);
    join
    d_aw = a1 - a0;
    if (a2 - a1 != d_aw) $fatal(1, "RAM_004: AW spacing %0d then %0d", d_aw, a2 - a1);
    repeat (3) wait_b(bx);
  end

  if (d_r  != 4) $fatal(1, "RAM_004: rvalid %0d cycles after the AR handshake, MAS 7.1 says 4", d_r);
  if (d_b  != 3) $fatal(1, "RAM_004: bvalid %0d cycles after the AW handshake, MAS 7.1 says 3", d_b);
  if (d_ar != 6) $fatal(1, "RAM_004: AR handshakes %0d cycles apart for 4 beats, MAS 7.1 says N + 2 = 6", d_ar);
  if (d_aw != 6) $fatal(1, "RAM_004: AW handshakes %0d cycles apart for 4 beats, MAS 7.1 says N + 2 = 6", d_aw);
  $display("RAM_004 ok: rvalid %0d, bvalid %0d, read 2 per beat, write 1 per beat, address handshakes %0d and %0d apart for N = 4",
           d_r, d_b, d_ar, d_aw);
endtask
