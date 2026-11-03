// SBUS_001: the CPU's accesses reach the slave the address map names, and only that one.
// Both ends of every window (ROM, ISRAM debug window and ISRAM, DSRAM, the APB window), read
// and write. The data a read returns is the slave's own pattern, the response is OKAY and the
// ID comes back unchanged.
task automatic sbus_001();
  logic [31:0] a_tab [10];
  int          m_tab [10];
  int unsigned n_pre [4];
  logic [31:0] exp_data;
  int          n_cases;

  a_tab[0] = qnsc_pkg::C_ROM_BASE;                m_tab[0] = 0;
  a_tab[1] = C_ROM_END - 32'd4;                   m_tab[1] = 0;
  a_tab[2] = qnsc_pkg::C_ISRAM_DBG_BASE;          m_tab[2] = 1;
  a_tab[3] = qnsc_pkg::C_ISRAM_BASE - 32'd4;      m_tab[3] = 1;   // last word of the debug window
  a_tab[4] = qnsc_pkg::C_ISRAM_BASE;              m_tab[4] = 1;
  a_tab[5] = C_ISRAM_END - 32'd4;                 m_tab[5] = 1;
  a_tab[6] = qnsc_pkg::C_DSRAM_BASE;              m_tab[6] = 2;
  a_tab[7] = C_DSRAM_END - 32'd4;                 m_tab[7] = 2;
  a_tab[8] = qnsc_pkg::C_AXI2APB_BASE;            m_tab[8] = 3;
  a_tab[9] = C_APB_END - 32'd4;                   m_tab[9] = 3;
  n_cases  = 10;

  for (int k = 0; k < n_cases; k++) begin
    // read
    for (int m = 0; m < 4; m++) n_pre[m] = seen(m);
    axi_rd(1, k[0], a_tab[k], 0);
    for (int m = 0; m < 4; m++)
      chk(seen(m) - n_pre[m] == ((m == m_tab[k]) ? 1 : 0),
          $sformatf("read %08h: slave %0d saw %0d transaction(s), expected %0d", a_tab[k], m,
                    seen(m) - n_pre[m], (m == m_tab[k]) ? 1 : 0));
    exp_data = (m_tab[k] == 3) ? pat_apb(a_tab[k]) : pat_mem(m_tab[k], a_tab[k]);
    chk(rd_resp[1][0] == C_OKAY, $sformatf("read %08h: response %0d, expected OKAY", a_tab[k], rd_resp[1][0]));
    chk(rd_data[1][0] == exp_data, $sformatf("read %08h: data %08h, expected %08h", a_tab[k], rd_data[1][0], exp_data));
    chk(rd_id[1] == k[0], $sformatf("read %08h: ID came back as %0d", a_tab[k], rd_id[1]));
    chk(rd_beats[1] == 1 && rd_last_ok[1], $sformatf("read %08h: beats %0d or RLAST wrong", a_tab[k], rd_beats[1]));
    // write
    for (int m = 0; m < 4; m++) n_pre[m] = seen(m);
    axi_wr(1, k[0], a_tab[k], 0, 32'h5A5A_0000 + 32'(k), 4'hF);
    for (int m = 0; m < 4; m++)
      chk(seen(m) - n_pre[m] == ((m == m_tab[k]) ? 1 : 0),
          $sformatf("write %08h: slave %0d saw %0d transaction(s), expected %0d", a_tab[k], m,
                    seen(m) - n_pre[m], (m == m_tab[k]) ? 1 : 0));
    chk(wr_resp[1] == C_OKAY, $sformatf("write %08h: response %0d, expected OKAY", a_tab[k], wr_resp[1]));
    chk(wr_id[1] == k[0], $sformatf("write %08h: ID came back as %0d", a_tab[k], wr_id[1]));
  end
  $display("SBUS_001 ok: %0d addresses, read and write, each reaches only its slave, OKAY, ID kept", n_cases);
endtask
