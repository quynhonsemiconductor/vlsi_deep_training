// SBUS_007: three masters at once. SYSDBG, the CPU and the DMA write bursts to DSRAM together,
// then read them back together; then each reads a different slave together (ROM, ISRAM, DSRAM);
// then the CPU and the DMA reach the APB window together. Nothing is lost, mixed or given to the
// wrong master: the data, the ID and the response of each port are its own.
task automatic sbus_007();
  logic [31:0] base [3];
  logic [31:0] seed [3];
  logic [31:0] a_ro [3];
  int          m_ro [3];
  logic [31:0] ap [2];

  base[0] = qnsc_pkg::C_DSRAM_BASE + 32'h400;  seed[0] = 32'h7000_0000;
  base[1] = qnsc_pkg::C_DSRAM_BASE + 32'h500;  seed[1] = 32'h7100_0000;
  base[2] = qnsc_pkg::C_DSRAM_BASE + 32'h600;  seed[2] = 32'h7200_0000;

  // three writes at once, to one slave
  fork
    axi_wr(0, 1'b0, base[0], 7, seed[0], 4'hF);
    axi_wr(1, 1'b1, base[1], 7, seed[1], 4'hF);
    axi_wr(2, 1'b1, base[2], 7, seed[2], 4'hF);
  join
  for (int p = 0; p < 3; p++)
    chk(wr_resp[p] == C_OKAY, $sformatf("concurrent write on s_%0d: response %0d", p, wr_resp[p]));
  chk(wr_id[0] == 1'b0 && wr_id[1] == 1'b1 && wr_id[2] == 1'b1, "concurrent writes: an ID came back wrong");

  // three reads at once, from one slave
  fork
    axi_rd(0, 1'b0, base[0], 7);
    axi_rd(1, 1'b1, base[1], 7);
    axi_rd(2, 1'b1, base[2], 7);
  join
  for (int p = 0; p < 3; p++) begin
    chk(rd_beats[p] == 8 && rd_last_ok[p], $sformatf("concurrent read on s_%0d: beats or RLAST wrong", p));
    for (int i = 0; i < 8; i++) begin
      chk(rd_data[p][i] == seed[p] + 32'h1111 * 32'(i), $sformatf("concurrent read on s_%0d beat %0d: %08h", p, i, rd_data[p][i]));
      chk(rd_resp[p][i] == C_OKAY, $sformatf("concurrent read on s_%0d beat %0d: not OKAY", p, i));
    end
  end
  chk(rd_id[0] == 1'b0 && rd_id[1] == 1'b1 && rd_id[2] == 1'b1, "concurrent reads: an ID came back wrong");

  // three reads at once, from three slaves: ROM, ISRAM (slow), DSRAM
  a_ro[0] = qnsc_pkg::C_ROM_BASE   + 32'h20;  m_ro[0] = 0;   // SYSDBG
  a_ro[1] = qnsc_pkg::C_ISRAM_BASE + 32'h20;  m_ro[1] = 1;   // CPU
  a_ro[2] = qnsc_pkg::C_DSRAM_BASE + 32'h20;  m_ro[2] = 2;   // DMA (cannot reach ROM or ISRAM, so DSRAM)
  fork
    axi_rd(0, 1'b0, a_ro[0], 3);
    axi_rd(1, 1'b1, a_ro[1], 3);
    axi_rd(2, 1'b0, a_ro[2], 3);
  join
  for (int p = 0; p < 3; p++) begin
    chk(rd_beats[p] == 4 && rd_last_ok[p], $sformatf("three-slave read on s_%0d: beats or RLAST wrong", p));
    for (int i = 0; i < 4; i++)
      chk(rd_data[p][i] == pat_mem(m_ro[p], a_ro[p] + 32'd4 * 32'(i)),
          $sformatf("three-slave read on s_%0d beat %0d: %08h", p, i, rd_data[p][i]));
  end

  // CPU and DMA on the APB window at once
  ap[0] = qnsc_pkg::C_AXI2APB_BASE + 32'h60;
  ap[1] = qnsc_pkg::C_AXI2APB_BASE + 32'h64;
  fork
    axi_rd(1, 1'b0, ap[0], 0);
    axi_rd(2, 1'b1, ap[1], 0);
  join
  chk(rd_data[1][0] == pat_apb(ap[0]) && rd_data[2][0] == pat_apb(ap[1]), "APB window read by two masters at once: data mixed or lost");
  chk(rd_resp[1][0] == C_OKAY && rd_resp[2][0] == C_OKAY && rd_id[1] == 1'b0 && rd_id[2] == 1'b1, "APB window read by two masters at once: response or ID wrong");
  $display("SBUS_007 ok: three masters at once to one slave, to three slaves, and two on the APB window; data, ID and response stay with their own master");
endtask
