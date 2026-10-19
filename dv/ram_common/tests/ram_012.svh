// RAM_012 (added by QSOC, no MAS item): bursts of every length and type, and random
// traffic against a reference memory, with the response channels stalled at random.
task automatic ram_012();
  logic [31:0] d[$];
  logic [31:0] refm [int unsigned];
  int unsigned lens[6] = '{0, 1, 2, 15, 16, 255};
  int unsigned n_wr = 0, n_rd = 0;

  // INCR of every length, written then read
  foreach (lens[k]) begin
    wr_burst(32'h0000_1000, 8'(lens[k]), 2'b01, 7'h70, 700 + k, 4'hF);
    rd_burst(32'h0000_1000, 8'(lens[k]), 2'b01, 7'h71, d);
    for (int i = 0; i <= lens[k]; i++) chk32($sformatf("RAM_012 INCR len %0d beat %0d", lens[k], i), d[i], pat(700 + k, i));
  end
  // FIXED, 1 to 16 beats: the last beat is what stays, and every read beat is that word
  for (int len = 0; len < 16; len++) begin
    wr_burst(32'h0000_2000, 8'(len), 2'b00, 7'h72, 800 + len, 4'hF);
    rd_burst(32'h0000_2000, 8'(len), 2'b00, 7'h73, d);
    for (int i = 0; i <= len; i++) chk32($sformatf("RAM_012 FIXED len %0d beat %0d", len, i), d[i], pat(800 + len, len));
  end

  // random traffic against a reference memory, B and R stalled at random
  fork
    begin : stall
      forever begin
        b_ready = 1'($urandom_range(0, 3) != 0);
        r_ready = 1'($urandom_range(0, 3) != 0);
        tick();
      end
    end
    begin
      for (int op = 0; op < 300; op++) begin
        logic [31:0] a;
        logic [7:0]  len;
        logic [3:0]  s;
        a   = 32'h0000_3000 + 4 * $urandom_range(0, 1023);
        len = 8'($urandom_range(0, 7));
        if ($urandom_range(0, 1) == 0) begin
          s = 4'($urandom_range(0, 15));
          // write the burst: reference first, as the bytes the strobe selects, beat by beat
          for (int i = 0; i <= len; i++) begin
            int unsigned w = (a >> 2) + i;
            logic [31:0] old = refm.exists(w) ? refm[w] : u_mem.peek(int'(w & (C_WORDS - 1)));
            logic [31:0] nw  = pat(900 + op, i);
            for (int b = 0; b < 4; b++) if (s[b]) old[8*b +: 8] = nw[8*b +: 8];
            refm[w] = old;
          end
          wr_burst(a, len, 2'b01, 7'(op), 900 + op, s, $urandom_range(0, 2));
          n_wr++;
        end else begin
          rd_burst(a, len, 2'b01, 7'(op), d);
          for (int i = 0; i <= len; i++) begin
            int unsigned w = (a >> 2) + i;
            if (refm.exists(w)) chk32($sformatf("RAM_012 op %0d word %0h", op, w), d[i], refm[w]);
          end
          n_rd++;
        end
      end
      disable stall;
    end
  join
  b_ready = 1'b1;
  r_ready = 1'b1;
  $display("RAM_012 ok: INCR 1..256 beats, FIXED 1..16, %0d random writes and %0d reads against a reference memory, B and R stalled at random", n_wr, n_rd);
endtask
