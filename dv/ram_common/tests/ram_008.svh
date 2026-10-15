// RAM_008: BRESP and RRESP are 00 for every access, and RLAST marks the last beat only
// (MAS 7.5, item 8). The monitors in ram_tb.svh count any other response in every cycle
// of every test; this one adds accesses of every kind and fails on the count.
task automatic ram_008();
  logic [31:0] d[$];
  int unsigned n_resp0 = resp_err;
  wr1(32'h0000_0800, 32'h0BAD_F00D);
  wr_burst(32'h0000_0810, 8'd15, 2'b01, 7'h50, 500, 4'hF);
  wr_burst(32'h0000_0850, 8'd7, 2'b00, 7'h51, 501, 4'hF);
  rd_burst(32'h0000_0810, 8'd15, 2'b01, 7'h52, d);
  rd_burst(32'h0000_0850, 8'd7, 2'b00, 7'h53, d);
  rd_burst(32'h0000_0810, 8'd3, 2'b11, 7'h54, d);              // the reserved burst code
  rd_burst(32'h0000_0FFC, 8'd3, 2'b01, 7'h55, d);              // a burst across the end of a 4 KiB page
  if (resp_err != n_resp0) $fatal(1, "RAM_008: %0d response(s) other than OKAY", resp_err - n_resp0);
  $display("RAM_008 ok: BRESP and RRESP are 00 for every access, RLAST on the last beat only");
endtask
