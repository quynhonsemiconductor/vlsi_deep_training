// iomux_003 -- debug force: while i_dbg_en = 1 pads 0-4 (PIN5-9) use b00 (JTAG)
// whatever PADSEL holds; the other pads follow PADSEL; PADSEL reads back what
// software wrote. Released, the pads follow PADSEL again.
t_set_all(2'b01);
@(posedge i_clk_peri); #1 i_dbg_en = 1'b1;
t_check_all(8);
t_expect32("iomux_003", A_PADSEL_0, 32'h5555_5555);
t_expect32("iomux_003", A_PADSEL_1, 32'h0055_5555);
@(posedge i_clk_peri); #1 i_dbg_en = 1'b0;
t_check_all(8);
$display("iomux_003 ok: i_dbg_en forces PIN5-9 to JTAG, PADSEL unchanged");
