// SBUS_005: bursts and byte strobes through the crossbar, to a fast slave (DSRAM, 1 wait cycle)
// and a slow one (ISRAM, 3 wait cycles). INCR bursts of 8 and 16 beats: every beat arrives
// intact and in order, RLAST on the last beat only. A write with partial strobes changes only
// the bytes the strobes name.
task automatic sbus_005();
  logic [31:0] a;
  logic [31:0] old_w, new_w, exp_w;
  int unsigned w_before;

  // DSRAM, 8 beats
  a = qnsc_pkg::C_DSRAM_BASE + 32'h100;
  w_before = u_dsram.n_w;
  axi_wr(1, 1'b1, a, 7, 32'h1000_0000, 4'hF);
  chk(u_dsram.n_w == w_before + 8, $sformatf("DSRAM saw %0d write beats, expected 8", u_dsram.n_w - w_before));
  chk(u_dsram.aw_len_seen == 8'd7, "DSRAM saw a wrong AWLEN");
  axi_rd(1, 1'b1, a, 7);
  chk(rd_beats[1] == 8 && rd_last_ok[1] && u_dsram.ar_len_seen == 8'd7, "8-beat read: beats or RLAST wrong");
  for (int i = 0; i < 8; i++) begin
    chk(rd_data[1][i] == 32'h1000_0000 + 32'h1111 * 32'(i), $sformatf("8-beat read beat %0d: %08h", i, rd_data[1][i]));
    chk(rd_resp[1][i] == C_OKAY, "8-beat read: not OKAY");
  end

  // DSRAM, 16 beats, from the DMA
  a = qnsc_pkg::C_DSRAM_BASE + 32'h200;
  axi_wr(2, 1'b0, a, 15, 32'h2000_0000, 4'hF);
  axi_rd(2, 1'b0, a, 15);
  chk(rd_beats[2] == 16 && rd_last_ok[2], "16-beat read: beats or RLAST wrong");
  for (int i = 0; i < 16; i++)
    chk(rd_data[2][i] == 32'h2000_0000 + 32'h1111 * 32'(i), $sformatf("16-beat read beat %0d: %08h", i, rd_data[2][i]));

  // ISRAM (slow), 4 beats, from SYSDBG
  a = qnsc_pkg::C_ISRAM_BASE + 32'h80;
  axi_wr(0, 1'b0, a, 3, 32'h3000_0000, 4'hF);
  axi_rd(0, 1'b0, a, 3);
  chk(rd_beats[0] == 4 && rd_last_ok[0], "ISRAM 4-beat read: beats or RLAST wrong");
  for (int i = 0; i < 4; i++)
    chk(rd_data[0][i] == 32'h3000_0000 + 32'h1111 * 32'(i), $sformatf("ISRAM read beat %0d: %08h", i, rd_data[0][i]));

  // partial strobes: bytes 0 and 2 change, bytes 1 and 3 keep what was there
  a = qnsc_pkg::C_DSRAM_BASE + 32'h300;
  old_w = pat_mem(2, a);
  new_w = 32'h1234_5678;
  exp_w = {old_w[31:24], new_w[23:16], old_w[15:8], new_w[7:0]};
  axi_wr(1, 1'b0, a, 0, new_w, 4'b0101);
  axi_rd(1, 1'b0, a, 0);
  chk(rd_data[1][0] == exp_w, $sformatf("strobe 0101: read %08h, expected %08h", rd_data[1][0], exp_w));
  $display("SBUS_005 ok: bursts of 4, 8 and 16 beats intact through fast and slow slaves, RLAST right, partial strobes keep the other bytes");
endtask
