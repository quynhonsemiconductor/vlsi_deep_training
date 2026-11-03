// SBUS_002: an address in no window gets DECERR and reaches no slave. The holes: between ROM
// and the ISRAM debug window, just above ROM, ISRAM and DSRAM, the two unused APB slots (14 and
// 15 of the 256 KiB window), the first address past the window and the top of the space. A
// read of len+1 beats gets len+1 DECERR beats with RLAST on the last; a write gets one DECERR B.
task automatic sbus_002();
  logic [31:0] a_tab [10];
  int unsigned n_before;
  int          n_cases;

  a_tab[0] = C_ROM_END;                              // just above ROM
  a_tab[1] = 32'h1000_0000;                          // between ROM and ISRAM
  a_tab[2] = qnsc_pkg::C_ISRAM_DBG_BASE - 32'd4;     // just below the ISRAM debug window
  a_tab[3] = C_ISRAM_END;                            // just above ISRAM
  a_tab[4] = qnsc_pkg::C_DSRAM_BASE - 32'd4;         // just below DSRAM
  a_tab[5] = C_DSRAM_END;                            // just above DSRAM
  a_tab[6] = C_APB_END;                              // APB slot 14, no peripheral
  a_tab[7] = C_APB_END + 32'h0000_4000;              // APB slot 15, no peripheral
  a_tab[8] = qnsc_pkg::C_AXI2APB_BASE + 32'h0004_0000; // past the 256 KiB window
  a_tab[9] = 32'hFFFF_FFFC;                          // top of the address space
  n_cases  = 10;

  for (int k = 0; k < n_cases; k++) begin
    n_before = seen_total();
    axi_rd(1, k[0], a_tab[k], 2);
    chk(rd_beats[1] == 3 && rd_last_ok[1], $sformatf("read %08h: %0d beats or RLAST wrong", a_tab[k], rd_beats[1]));
    for (int i = 0; i < 3; i++)
      chk(rd_resp[1][i] == C_DECERR, $sformatf("read %08h beat %0d: response %0d, expected DECERR", a_tab[k], i, rd_resp[1][i]));
    chk(rd_id[1] == k[0], $sformatf("read %08h: ID came back as %0d", a_tab[k], rd_id[1]));
    axi_wr(1, k[0], a_tab[k], 1, 32'h0BAD_0000, 4'hF);
    chk(wr_resp[1] == C_DECERR, $sformatf("write %08h: response %0d, expected DECERR", a_tab[k], wr_resp[1]));
    chk(wr_id[1] == k[0], $sformatf("write %08h: ID came back as %0d", a_tab[k], wr_id[1]));
    chk(seen_total() == n_before, $sformatf("%08h: a slave saw the access", a_tab[k]));
  end
  $display("SBUS_002 ok: %0d unmapped addresses (incl. APB slots 14 and 15) get DECERR, no slave sees them", n_cases);
endtask
