// RAM_009: the reset values of MAS 7.6, and a pattern that survives an i_rst_n_mem pulse
// (item 9). A request in flight when reset asserts is dropped without a response.
task automatic ram_009();
  logic [31:0] d, a;
  int unsigned tt;

  // reset values
  reset_dut();
  if (!(aw_ready && ar_ready && w_ready)) $fatal(1, "RAM_009: awready %0b arready %0b wready %0b after reset, expected 1 1 1", aw_ready, ar_ready, w_ready);
  if (b_valid || r_valid) $fatal(1, "RAM_009: bvalid %0b rvalid %0b after reset, expected 0 0", b_valid, r_valid);

  // a pattern survives a reset pulse
  for (int i = 0; i < 16; i++) wr1(32'h0000_0A00 + 4 * i, pat(600, i));
  rst_n = 1'b0;
  repeat (3) tick();
  rst_n = 1'b1;
  repeat (2) tick();
  for (int i = 0; i < 16; i++) begin
    rd1(32'h0000_0A00 + 4 * i, d);
    chk32($sformatf("RAM_009 word %0d after the reset pulse", i), d, pat(600, i));
  end

  // a read burst in flight when reset asserts: dropped, no beat afterwards
  send_ar(32'h0000_0A00, 8'd15, 2'b01, 7'h60, tt);
  repeat (3) tick();
  rst_n = 1'b0;
  repeat (3) tick();
  rst_n = 1'b1;
  repeat (2) tick();
  r_q.delete();
  idle(40);
  if (r_q.size() != 0) $fatal(1, "RAM_009: %0d R beat(s) after a reset dropped the request", r_q.size());
  if (!ar_ready || r_valid) $fatal(1, "RAM_009: arready %0b rvalid %0b after the dropped request", ar_ready, r_valid);
  rd1(32'h0000_0A04, d, 7'h61);
  chk32("RAM_009 read after the dropped request", d, pat(600, 1));
  $display("RAM_009 ok: reset values 1 1 1 / 0 0, contents survive a reset pulse, an in-flight read is dropped");
endtask
