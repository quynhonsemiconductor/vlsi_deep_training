// iomux_003 -- what SYSCSR delivers while jtag_lock = 1 (o_iomux_sel[4:0] = 0,
// the other bits as software wrote them): PIN5-9 carry JTAG, the other pads
// follow their select. Then the JTAG idle values when PIN5-9 are GPIO: TCK = 0,
// TMS = 1, TDI = 1, TRSTN = 0 (TAP held in reset).
repeat (10) begin
  i_iomux_sel = 24'($urandom) & ~24'h1F;
  t_check_all(2);
end
i_iomux_sel = 24'h1F; #1;
t_chk(o_jtag_tck === 1'b0 && o_jtag_tms === 1'b1 && o_jtag_tdi === 1'b1 && o_jtag_trst_n === 1'b0,
      "iomux_003: JTAG idle values while PIN5-9 are GPIO");
t_set_all(1'b0);
$display("iomux_003 ok: JTAG on PIN5-9 under the SYSCSR lock, JTAG idle values");
