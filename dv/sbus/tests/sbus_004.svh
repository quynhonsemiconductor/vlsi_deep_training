// SBUS_004: the ID through the crossbar. Slave port ID is 1 bit; the master port gets 3 bit,
// the slave-port number in the top two bits and the master's own ID below it. The slave sees
// {port, id}; the master gets its own 1-bit ID back on B and R.
task automatic sbus_004();
  logic [1:0] port_bits;
  logic [2:0] exp_id;
  logic [31:0] a;

  for (int p = 0; p < 3; p++) begin
    for (int i = 0; i < 2; i++) begin
      port_bits = 2'(p);
      exp_id    = {port_bits, 1'(i)};
      a = qnsc_pkg::C_DSRAM_BASE + 32'h40 * 32'(2 * p + i);
      axi_wr(p, 1'(i), a, 0, 32'h1D00_0000 + 32'(2 * p + i), 4'hF);
      chk(u_dsram.aw_id_seen == exp_id, $sformatf("s_%0d id %0d: DSRAM saw write ID %0d, expected %0d", p, i, u_dsram.aw_id_seen, exp_id));
      chk(wr_id[p] == 1'(i) && wr_resp[p] == C_OKAY, $sformatf("s_%0d id %0d: B came back with ID %0d", p, i, wr_id[p]));
      axi_rd(p, 1'(i), a, 0);
      chk(u_dsram.ar_id_seen == exp_id, $sformatf("s_%0d id %0d: DSRAM saw read ID %0d, expected %0d", p, i, u_dsram.ar_id_seen, exp_id));
      chk(rd_id[p] == 1'(i) && rd_resp[p][0] == C_OKAY, $sformatf("s_%0d id %0d: R came back with ID %0d", p, i, rd_id[p]));
      chk(rd_data[p][0] == 32'h1D00_0000 + 32'(2 * p + i), $sformatf("s_%0d id %0d: read back %08h", p, i, rd_data[p][0]));
    end
  end
  $display("SBUS_004 ok: master-port ID = {slave port, id} (3 bit); every master gets its own 1-bit ID back on B and R");
endtask
