// SBUS_003: the DMA (slave port s_2) cannot reach ROM or ISRAM (the connectivity matrix): its
// read and write get DECERR and the slave never sees them. It still reaches DSRAM and the APB
// window. SYSDBG (s_0) and the CPU (s_1) reach ROM and ISRAM.
task automatic sbus_003();
  logic [31:0] a_tab [5];
  int unsigned n_before, d_before;

  a_tab[0] = qnsc_pkg::C_ROM_BASE;
  a_tab[1] = C_ROM_END - 32'd4;
  a_tab[2] = qnsc_pkg::C_ISRAM_DBG_BASE;
  a_tab[3] = qnsc_pkg::C_ISRAM_BASE;
  a_tab[4] = C_ISRAM_END - 32'd4;

  for (int k = 0; k < 5; k++) begin
    n_before = seen_total();
    axi_rd(2, 1'b1, a_tab[k], 1);
    chk(rd_beats[2] == 2 && rd_last_ok[2], $sformatf("DMA read %08h: %0d beats or RLAST wrong", a_tab[k], rd_beats[2]));
    chk(rd_resp[2][0] == C_DECERR && rd_resp[2][1] == C_DECERR, $sformatf("DMA read %08h: not DECERR", a_tab[k]));
    chk(rd_id[2] == 1'b1, $sformatf("DMA read %08h: ID came back as %0d", a_tab[k], rd_id[2]));
    axi_wr(2, 1'b0, a_tab[k], 0, 32'h0D3A_0000, 4'hF);
    chk(wr_resp[2] == C_DECERR, $sformatf("DMA write %08h: response %0d, expected DECERR", a_tab[k], wr_resp[2]));
    chk(wr_id[2] == 1'b0, $sformatf("DMA write %08h: ID came back as %0d", a_tab[k], wr_id[2]));
    chk(seen_total() == n_before, $sformatf("DMA access %08h reached a slave", a_tab[k]));
  end

  // what the DMA may still reach
  axi_rd(2, 1'b1, qnsc_pkg::C_DSRAM_BASE + 32'h20, 0);
  chk(rd_resp[2][0] == C_OKAY && rd_data[2][0] == pat_mem(2, qnsc_pkg::C_DSRAM_BASE + 32'h20), "DMA read of DSRAM failed");
  axi_rd(2, 1'b0, qnsc_pkg::C_AXI2APB_BASE + 32'h30, 0);
  chk(rd_resp[2][0] == C_OKAY && rd_data[2][0] == pat_apb(qnsc_pkg::C_AXI2APB_BASE + 32'h30), "DMA read of the APB window failed");

  // what SYSDBG and the CPU reach
  for (int p = 0; p < 2; p++) begin
    d_before = u_rom.n_ar;
    axi_rd(p, 1'b1, qnsc_pkg::C_ROM_BASE + 32'h10, 0);
    chk(rd_resp[p][0] == C_OKAY && rd_data[p][0] == pat_mem(0, qnsc_pkg::C_ROM_BASE + 32'h10) && u_rom.n_ar == d_before + 1,
        $sformatf("port s_%0d cannot read ROM", p));
    d_before = u_isram.n_ar;
    axi_rd(p, 1'b0, qnsc_pkg::C_ISRAM_BASE + 32'h10, 0);
    chk(rd_resp[p][0] == C_OKAY && rd_data[p][0] == pat_mem(1, qnsc_pkg::C_ISRAM_BASE + 32'h10) && u_isram.n_ar == d_before + 1,
        $sformatf("port s_%0d cannot read ISRAM", p));
  end
  $display("SBUS_003 ok: DMA to ROM and ISRAM gets DECERR, never seen; DMA reaches DSRAM and APB; SYSDBG and CPU reach ROM and ISRAM");
endtask
