// iomux_004 -- registers: PADSEL_1 [31:24] reserved (reads 0), an offset with no
// register reads 0 and ignores a write, a misaligned address or a partial PSTRB
// answers PSLVERR and changes nothing.
begin
  logic [31:0] rd; logic err;
  t_wr32(A_PADSEL_0, 32'hA5A5_A5A5);
  t_wr32(A_PADSEL_1, 32'hFFFF_FFFF);
  t_expect32("iomux_004", A_PADSEL_0, 32'hA5A5_A5A5);
  t_expect32("iomux_004", A_PADSEL_1, 32'h00FF_FFFF);
  t_wr32(14'h0008, 32'hFFFF_FFFF);
  t_expect32("iomux_004", 14'h0008, 32'h0000_0000);
  t_apb(1'b1, 14'h0002, 32'h0, 4'hF, rd, err);
  t_chk(err, "iomux_004: misaligned write without PSLVERR");
  t_apb(1'b1, A_PADSEL_0, 32'h0, 4'h1, rd, err);
  t_chk(err, "iomux_004: partial PSTRB write without PSLVERR");
  t_expect32("iomux_004", A_PADSEL_0, 32'hA5A5_A5A5);
  t_set_all(2'b00);
  t_check_all(2);
end
$display("iomux_004 ok: reserved bits, unmapped offset, PSLVERR");
