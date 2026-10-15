// RAM_007: o_mem_addr is the controller's byte address [15:2] (ISRAM) or [14:2] (DSRAM);
// an unaligned single beat hits its word; the address bits above the macro are ignored
// (MAS 7.2, 7.5, item 7).
task automatic ram_007();
  logic [31:0] a, d, w0, up;
  logic [C_AW-1:0] word;
  for (int k = 0; k < 40; k++) begin
    a = ($urandom() & 32'hFFFF_FFFC);
    word = a[C_AW+1:2];
    w0 = pat(400, k);
    acc_q.delete();
    wr1(a, w0, 4'hF);
    if (acc_q.size() != 1 || !acc_q[0].we || acc_q[0].word !== word)
      $fatal(1, "RAM_007: write to %08h reached macro word %0h, expected %0h", a, acc_q[0].word, word);
    // the same word through the other upper bits, and unaligned
    up = {~a[31:C_AW+2], a[C_AW+1:0]};
    rd1(up, d);
    chk32($sformatf("RAM_007 read %08h", up), d, w0);
    for (int u = 1; u < 4; u++) begin
      acc_q.delete();
      rd1(a + u, d);
      chk32($sformatf("RAM_007 unaligned read %08h", a + u), d, w0);
      if (acc_q.size() != 1 || acc_q[0].we || acc_q[0].word !== word)
        $fatal(1, "RAM_007: unaligned read of %08h reached macro word %0h, expected %0h", a + u, acc_q[0].word, word);
    end
    // an unaligned byte write changes its byte only
    wr1(a + 2, 32'hFF00_0000 | 32'h0077_0000, 4'b0100);   // lane 2
    rd1(a, d);
    chk32($sformatf("RAM_007 unaligned write at %08h", a + 2), d, {w0[31:24], 8'h77, w0[15:0]});
  end
  $display("RAM_007 ok: o_mem_addr = byte address [%0d:2], unaligned beats hit their word, upper bits ignored", C_AW + 1);
endtask
