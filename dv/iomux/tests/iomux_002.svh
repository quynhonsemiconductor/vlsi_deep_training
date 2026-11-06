// iomux_002 -- every pad under both functions: A, OE and IE come from the
// selected function, Y reaches it, and every IP input no pad selects holds its
// idle value. Then each select bit alone, then random mixes.
t_set_all(1'b1);
t_check_all(8);
for (int b = 0; b < C_N_SEL; b++) begin
  i_iomux_sel = 24'b1 << b;
  t_check_all(2);
end
repeat (40) begin
  i_iomux_sel = 24'($urandom);
  t_check_all(2);
end
$display("iomux_002 ok: both functions of every pad, one-hot and random selects");
