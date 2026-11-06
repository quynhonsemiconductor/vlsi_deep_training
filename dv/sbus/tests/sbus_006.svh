// SBUS_006: the AXI2APB path. A write and a read to the APB window come out of the APB port with
// the offset in the window (18 bit), data, strobes and direction; the APB setup/access protocol
// holds (checked in the model); a slave error becomes SLVERR; a burst is split into single APB
// accesses; the last word of the populated window still reaches the port with its full offset.
task automatic sbus_006();
  logic [31:0] a;
  int unsigned n_before;

  // write, then read back
  a = qnsc_pkg::C_AXI2APB_BASE + 32'h10;
  n_before = u_apb.n_access;
  axi_wr(1, 1'b1, a, 0, 32'hDEAD_BEEF, 4'hF);
  chk(wr_resp[1] == C_OKAY && wr_id[1] == 1'b1, "APB write: response or ID wrong");
  chk(u_apb.n_access == n_before + 1, "APB write: not exactly one APB access");
  chk(u_apb.last_pwrite && u_apb.last_paddr == 18'h00010 && u_apb.last_pwdata == 32'hDEAD_BEEF && u_apb.last_pstrb == 4'hF,
      $sformatf("APB write: paddr %05h pwdata %08h pstrb %h", u_apb.last_paddr, u_apb.last_pwdata, u_apb.last_pstrb));
  axi_rd(1, 1'b0, a, 0);
  chk(rd_resp[1][0] == C_OKAY && rd_data[1][0] == 32'hDEAD_BEEF, $sformatf("APB read back %08h", rd_data[1][0]));
  chk(!u_apb.last_pwrite && u_apb.last_paddr == 18'h00010, "APB read: paddr or pwrite wrong");

  // strobes reach PSTRB
  axi_wr(1, 1'b0, qnsc_pkg::C_AXI2APB_BASE + 32'h20, 0, 32'h5555_AAAA, 4'b0011);
  chk(u_apb.last_pstrb == 4'b0011 && u_apb.last_paddr == 18'h00020, "APB write: pstrb not 0011");

  // the last word of the populated window: the whole 18-bit offset
  a = C_APB_END - 32'd4;
  axi_wr(1, 1'b0, a, 0, 32'h7E57_0001, 4'hF);
  chk(u_apb.last_paddr == 18'(a - qnsc_pkg::C_AXI2APB_BASE), $sformatf("top of the window, write: paddr %05h", u_apb.last_paddr));
  axi_rd(1, 1'b0, a, 0);
  chk(u_apb.last_paddr == 18'(a - qnsc_pkg::C_AXI2APB_BASE), $sformatf("top of the window, read: paddr %05h", u_apb.last_paddr));
  chk(rd_resp[1][0] == C_OKAY && rd_data[1][0] == 32'h7E57_0001, $sformatf("top of the window: read back %08h", rd_data[1][0]));

  // PSLVERR becomes SLVERR
  a = qnsc_pkg::C_AXI2APB_BASE + 32'(C_APB_ERR_OFFSET);
  axi_rd(1, 1'b0, a, 0);
  chk(rd_resp[1][0] == C_SLVERR, $sformatf("APB read with PSLVERR: response %0d, expected SLVERR", rd_resp[1][0]));
  axi_wr(1, 1'b0, a, 0, 32'h0, 4'hF);
  chk(wr_resp[1] == C_SLVERR, $sformatf("APB write with PSLVERR: response %0d, expected SLVERR", wr_resp[1]));

  // A burst of more than one beat into the APB window. axi_to_axi_lite's burst splitter refuses to
  // split a non-modifiable (Device, AxCACHE 0) burst: it answers SLVERR and no APB access happens.
  // The CPU's data port and the DMA both drive AxCACHE 0 (the DMA IP has no cache pins).
  a = qnsc_pkg::C_AXI2APB_BASE + 32'h40;
  tb_cache = 4'b0000;
  n_before = u_apb.n_access;
  axi_rd(1, 1'b1, a, 1);
  chk(rd_beats[1] == 2 && rd_last_ok[1], "Device burst read: beats or RLAST wrong");
  chk(rd_resp[1][0] == C_SLVERR && rd_resp[1][1] == C_SLVERR, "Device burst read into the APB window: not SLVERR");
  axi_wr(1, 1'b1, a, 1, 32'hABCD_0000, 4'hF);
  chk(wr_resp[1] == C_SLVERR, "Device burst write into the APB window: not SLVERR");
  chk(u_apb.n_access == n_before, "Device burst into the APB window reached the APB slave");
  // With AxCACHE modifiable the same burst is split into one APB access per beat.
  tb_cache = axi_pkg::CACHE_MODIFIABLE;
  n_before = u_apb.n_access;
  axi_rd(1, 1'b1, a, 1);
  chk(rd_beats[1] == 2 && rd_last_ok[1], "split burst read: beats or RLAST wrong");
  chk(rd_resp[1][0] == C_OKAY && rd_resp[1][1] == C_OKAY, "split burst read: not OKAY");
  chk(u_apb.n_access == n_before + 2, $sformatf("split burst read made %0d APB accesses, expected 2", u_apb.n_access - n_before));
  chk(rd_data[1][0] == pat_apb(a) && rd_data[1][1] == pat_apb(a + 32'd4), "split burst read: data wrong");
  n_before = u_apb.n_access;
  axi_wr(1, 1'b1, a, 1, 32'hABCD_0000, 4'hF);
  chk(wr_resp[1] == C_OKAY && u_apb.n_access == n_before + 2, "split burst write: response or access count wrong");
  axi_rd(1, 1'b1, a, 1);
  chk(rd_data[1][0] == 32'hABCD_0000 && rd_data[1][1] == 32'hABCD_1111, "split burst write: read back wrong");
  tb_cache = 4'b0000;
  $display("SBUS_006 ok: AXI2APB paddr/pwdata/pstrb/pwrite right, 18-bit offset to the top of the window, PSLVERR -> SLVERR, a Device burst is refused (SLVERR), a modifiable one is split, APB protocol clean");
endtask
