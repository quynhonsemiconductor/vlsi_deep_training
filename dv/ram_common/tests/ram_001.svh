// RAM_001: each of the 15 non-zero WSTRB patterns writes only its bytes; 0000 writes
// none (QNSC_RAM_MAS 7.3, item 1). The word is first filled with a known value, then
// written with the pattern, then read back through the bus and from the macro.
task automatic ram_001();
  logic [31:0] a, d, exp, bg, nw;
  bg = 32'hA5C3_96E1;
  nw = 32'h1122_3344;
  for (int s = 0; s < 16; s++) begin
    a = 32'h0000_0100 + 4 * s;
    wr1(a, bg, 4'hF);
    wr1(a, nw, s[3:0]);
    exp = bg;
    for (int b = 0; b < 4; b++) if (s[b]) exp[8*b +: 8] = nw[8*b +: 8];
    rd1(a, d);
    chk32($sformatf("RAM_001 wstrb %04b", s[3:0]), d, exp);
    chk32($sformatf("RAM_001 wstrb %04b in the macro", s[3:0]), u_mem.peek(int'(a >> 2)), exp);
  end
  $display("RAM_001 ok: 16 WSTRB patterns write exactly their bytes, 0000 writes none");
endtask
