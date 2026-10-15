// RAM_006: against an independent address model, an aligned WRAP burst produces INCR
// addresses (MAS 7.4, item 6). The IP's addr_wrap aligns the address and does not wrap
// it, so a WRAP burst that starts in the middle of its block does not wrap either; the
// test states that as the accepted limit and checks it.
function automatic logic [C_AW-1:0] exp_word(input logic [31:0] a0, input int unsigned i, input logic [1:0] bur);
  logic [31:0] a;
  a = (bur == 2'b00) ? a0 : (a0 & ~32'h3) + 4 * i;     // FIXED, or INCR with the 4-byte step
  return a[C_AW+1:2];
endfunction

task automatic ram_006();
  int unsigned tt;
  logic [31:0] d[$];
  logic [31:0] a0;
  logic [1:0] bur;
  int unsigned starts[4] = '{32'h1000, 32'h1008, 32'h1010, 32'h1004};
  for (int s = 0; s < 4; s++) begin
    a0 = starts[s];
    for (int bb = 2; bb <= 3; bb++) begin           // WRAP, then the reserved code
      bur = 2'(bb);
      wr_burst(a0, 8'd3, 2'b01, 7'h40, 300 + s, 4'hF);   // data first, with INCR
      acc_q.delete();
      rd_burst(a0, 8'd3, bur, 7'h41, d);
      if (acc_q.size() != 4) $fatal(1, "RAM_006: %0d macro accesses, expected 4", acc_q.size());
      for (int i = 0; i < 4; i++) begin
        if (acc_q[i].we) $fatal(1, "RAM_006: write at the macro during a read burst");
        if (acc_q[i].word !== exp_word(a0, i, 2'b01))
          $fatal(1, "RAM_006: burst %0d from %08h, beat %0d at word %0h, the INCR model says %0h",
                 bb, a0, i, acc_q[i].word, exp_word(a0, i, 2'b01));
      end
    end
  end
  $display("RAM_006 ok: WRAP and the reserved code give INCR addresses, aligned or not (accepted limit, MAS 7.4)");
endtask
